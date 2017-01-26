require 'pg'
require File.join File.dirname(__FILE__), '/../Log.rb'
require File.join File.dirname(__FILE__), '/Analyzer.rb'
require File.join File.dirname(__FILE__), '/AnalyzerBase.rb'
require File.join File.dirname(__FILE__), '/../YgorubyBase/Deck.rb'
require File.join File.dirname(__FILE__), '/../YgorubyBase/Card.rb'
require File.join File.dirname(__FILE__), '/../YgorubyBase/Replay.rb'

#==========================================
# PGSQLAnalyzer
#   Helper Base class to set PG analyzer.
#------------------------------------------
# Methods to override:
# + output(*args)
# + load_commands
# + generate_data(deck)
# + generate_cache_sql_string(data)
# + Cache#add(key, data)
#-------------------------------------------
# Methods can override:
# + load_names
# + create_caches
# + Names#table_name(period)
# + Names#create_table_names
# + add_data_to_cache(data, options)
#===========================================
class PGSQLAnalyzer < AnalyzerBase
	def initialize
		load_configs
		load_database
		load_commands
		load_names
		create_tables
		create_caches
		create_process_thread
	end
	
	def load_configs
		@config = $config[__FILE__]
		if @config == nil
			logger.error 'No config set for PGSQLAnalyzer.'
			throw ArgumentError.new 'No config set for PGSQLAnalyzer.'
		end
	end
	
	def load_database
		load_configs if @config == nil
		begin
			connect_args = @config['ConnectArgs']
			@sql         = PG.connect connect_args
		rescue => exception
			logger.error 'Failed to connect to sql. Message:'
			logger.error exception
		end
		# Database operation Mutex.
		@database_mutex = Mutex.new
	end
	
	def load_commands
		@commands                = {}
		@commands[:create_table] = ''
		@commands[:update_deck]  = ''
		@commands[:search]       = ''
		@commands[:union]        = ''
		@commands[:output]       = ''
	
	end
	
	def load_names
		@names = Names.new
	end
	
	def create_tables
		@names.periods.each { |table_name| create_table(table_name) }
	end
	
	def create_table(table_name)
		execute_command sprintf @commands[:create_table], @names.table_name(table_name)
	end
	
	def create_caches
		@cache = Cache.new
	end
	
	def create_process_thread
		return unless @config['UseProcessingPool']
		@processing_pool   = []
		@processing_thread = Thread.new { process_thread() }
	end
	
	def execute_command(command)
		@database_mutex.synchronize {
			begin
				logger.debug "execute sql command:\n#{command}"
				@sql.exec command
			rescue => exception
				logger.error 'error while running command. Message: \n'
				logger.error exception.to_s
			end
		}
	end
	
	def execute_parameter_command(command, parameters)
		@database_mutex.synchronize {
			begin
				logger.debug 'execute sql command:\n#{command}'
				logger.debug 'with commands:' + parameters
				@sql.exec_params command, params
			rescue => exception
				logger.error 'error while running command. Message: \n'
				logger.error exception.to_s
			end
		}
	end
	
	def execute_commands(commands)
		@database_mutex.synchronize {
			begin
				logger.debug 'execute sql commands:'
				commands.map { |command| logger.debug(command); @sql.exec command }
			rescue => exception
				logger.error 'error while running command. Message: \n'
				logger.error exception.to_s
			end
		}
	end
	
	def check_database_connection
		if @sql == nil
			load_database
			logger.fatal('Database is reloaded during connection check. Make sure database connection is fine.')
		end
		if @sql.connect_poll == PG::Connection::PGRES_POLLING_FAILED
			@sql.reset
			logger.warn 'Reseted SQL connection.'
		end
	end
	
	def analyze(obj, *args)
		if obj.is_a? Replay
			analyze_replay obj, *args
		elsif obj.is_a? Deck
			analyze_deck obj, *args
		else
			logger.warn "Can't recognize analyze parameter #{obj}. Nothing will be done."
		end
	end
	
	def finish(*args)
		check_database_connection
		push_cache @cache, @names, :day#, *args
		@cache.clear
	end
	
	def clear(*args)
		time = draw_time *args
		@names.periods.each { |period| union_table @names.basic_period, period, time if period != @names.basic_period }
	end
	
	def output(*args)
		# must override
	end
	
	def heartbeat(*args)
		time = draw_time *args
		clear time
		output time
		nil
	end
	
	def analyze_replay(replay, *args)
		replay.decks.each { |deck| analyze_deck deck, *args }
	end
	
	def analyze_deck(deck, *args)
		if @config['UseProcessingPool']
			@processing_pool.push({ :deck => deck, :args => args })
		else
			process_deck deck
		end
	end
	
	def process_thread
		loop do
			if @processing_pool.count == 0
				sleep(1)
			else
				process_deck @processing_pool.pop
			end
		end
	end
	
	def process_deck(deck, *args)
		hash   = args[0] || {}
		source = hash[:source] || ''
		source = @names.source_name source
		time   = draw_time hash[:time]
		options = {source: source, time: time}
		add_data_to_cache generate_data(deck), options
	end
	
	def generate_data(deck)
		# must override
	end
	
	def add_data_to_cache(data, options)
		@cache.add options, data
	end
	
	def push_cache(cache, names, period)
		if cache.cache.count == 0
			logger.info 'No data in the pool to update.'
			return
		end
		time_period = names.time_period_length period
		table_name  = names.table_name period
		data        = cache.cache.map { |key, value| [time_period, *key, *value] }
		add_data_to_sql table_name, data
	end
	
	def generate_cache_sql_string(data)
		# must override
	end
	
	def add_data_to_sql(table_name, data)
		values  = data.map { |piece| generate_cache_sql_string piece }
		value   = values.join ",\n "
		command = sprintf @commands[:update_deck], table_name, value
		execute_command command
	end
	
	def union_table(from_period, to_period, time)
		from_table_name = @names.table_name from_period
		to_table_name   = @names.table_name to_period
		time_start      = @names.time_period_start to_period, time
		time_end        = time
		time_length     = @names.time_period_length to_period
		union_custom_table from_table_name, to_table_name, time_end, time_length, time_start
	end
	
	def union_custom_table(from_table_name, to_table_name, time_end, time_length, time_start = nil)
		time_start = (time_end - 86400 * time_length) if time_start == nil
		time_start = time_start.strftime @names.database_time_format
		time_end   = time_end.strftime @names.database_time_format
		command    = sprintf @commands[:union], from_table_name, to_table_name, time_start, time_end, time_length
		execute_command command
	end
	
	def check_pg_result(pg_result)
		if pg_result == nil
			logger.warn 'try to translate a pg_result: nil'
			return false
		end
		return false if pg_result.count == 0
		if pg_result.result_status != PG::PGRES_TUPLES_OK
			logger.error 'try to translate a not tuples result.' + pg_result
			return false
		end
		true
	end
	
	class Cache
		attr_accessor :cache
		def initialize
			@cache = {}
		end
		
		def add(key, data)
			@cache[key] = data
		end
		
		def clear
			@cache.clear
		end
	end
	
	class Names
		attr_accessor :periods
		attr_accessor :table_names
		attr_accessor :basic_period
		attr_accessor :database_time_format
		attr_accessor :unknown_flag
		attr_accessor :sources
		
		def initialize
			create_constants
			create_periods
			create_table_names
			create_sources
			create_season_times
		end
		
		def create_constants
			@unknown_flag         = :unknown
			@database_time_format = '%Y-%m-%d'
		end
		
		def create_periods
			@periods       = [:day, :week, :halfmonth, :month, :season]
			@basic_period  = :day
			@season_period = :season
			
			@period_time_length = {
					day:       1,
					week:      7,
					halfmonth: 15,
					month:     30,
					season:    0
			}
		end
		
		def create_table_names
			@table_names = {
					day:       'day',
					week:      'week',
					halfmonth: 'halfmonth',
					month:     'month',
					season:    'season'
			}
		end
		
		def create_sources
			@sources                = {
					athletic:    'athletic',
					entertain:   'entertainment',
					direct:      'direct',
					handWritten: 'handwritten'
			}
			@sources[@unknown_flag] = 'unknown'
		end
		
		def create_season_times
			@season_times = [
					Time.new(2000, 1, 1),
					Time.new(2000, 4, 1),
					Time.new(2000, 7, 1),
					Time.new(2000, 10, 1)
			]
		end
		
		def table_name(period)
			period    = period.downcase
			tableName = @table_names[period]
			if tableName != nil
				return tableName
			else
				logger.warn 'Unrecognized time type ' + period
				@table_names[@periods[0]]
			end
		end
		
		def time_period_length(period)
			period = period.downcase
			length = @period_time_length[period]
			if length != nil
				return length
			else
				logger.warn "Unrecognized time type #{period}."
				1
			end
		end
		
		def time_period_start(period, time_end)
			if period == @season_period
				return season_time_period_start time_end
			else
				return time_end - 86400 * time_period_length(period)
			end
		end
		
		def season_time_period_start(time_end)
			match_times = []
			@season_times.each do |time|
				time1 = Time.new time_end.year, time.month, time.day
				time2 = Time.new time_end.year - 1, time.month, time.day
				match_times.push time1
				match_times.push time2
			end
			match_times.select { |time| time_end > time }.min { |time1, time2| (time_end - time1) <=> (time_end - time2) }
		end
		
		def type_arguments(period, time)
			time_flag   = time.strftime @database_time_format
			time_period = time_period_length period
			table_name  = table_name period
			{
					TimePeriod: time_period,
					TimeStr:    time_flag,
					TableName:  table_name
			}
		end
		
		def source_name(source)
			source_str = @sources[source.to_sym]
			source_str == nil ? @sources[@unknown_flag] : source_str
		end
	end
end