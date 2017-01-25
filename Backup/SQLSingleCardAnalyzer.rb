require "#{File.dirname __FILE__}/../Log.rb"
require "#{File.dirname __FILE__}/Analyzer.rb"
require "#{File.dirname __FILE__}/AnalyzerBase.rb"
require "#{File.dirname __FILE__}/../YgorubyBase/Deck.rb"
require "#{File.dirname __FILE__}/../YgorubyBase/Card.rb"
require "#{File.dirname __FILE__}/../YgorubyBase/Replay.rb"
require "pg"

class SQLSingleCardAnalyzer < AnalyzerBase
	def initialize
		load_database
		load_commands
		load_names
		create_tables
		create_caches
	end
	
	def load_configs
		@config = $config[__FILE__]
		if @config == nil
			logger.error "No config set for SQLSingleCardAnalyzer."
			throw ArgumentError.new "No config set for SQLSingleCardAnalyzer."
		end
	end
	
	def load_database
		load_configs if @config == nil
		begin
			connect_args = @config["ConnectArgs"]
			@sql         = PG.connect connect_args
		rescue => exception
			logger.error "Failed to connect to sql. Message:"
			logger.error exception
		end
		# Database operation Mutex.
		@database_mutex = Mutex.new
	end
	
	def check_database_connection()
		if @sql == nil
			load_database
			logger.fatal("Database is reloaded during connection check. Make sure database connection is fine.")
		end
		if @sql.connect_poll == PG::Connection::PGRES_POLLING_FAILED
			@sql.reset
			logger.warn "Reseted SQL connection."
		end
	end
	
	def execute_command(command)
		@database_mutex.synchronize {
			begin
				logger.debug "execute sql command:\n#{command}"
				@sql.exec command
			rescue => exception
				logger.error "error while running command. Message:"
				logger.error "\n" + exception.to_s
			end
		}
	end
	
	def execute_parameter_command(command, parameters)
		@database_mutex.synchronize {
			begin
				logger.debug "execute sql command:\n#{command}"
				logger.debug "with commands: #{parameters}"
				@sql.exec_params command, params
			rescue => exception
				logger.error "error while running command. Message:"
				logger.error "\n" + exception.to_s
			end
		}
	end
	
	def execute_commands(commands)
		@database_mutex.synchronize {
			begin
				logger.debug "execute sql commands:"
				commands.map { |command| logger.debug(command); @sql.exec command }
			rescue => exception
				logger.error "error while running commands. Message:"
				logger.error "\n" + exception.to_s
			end
		}
	end
	
	#region Basic I/O parts
	
	#==============================================
	# Analyze
	#----------------------------------------------
	# basic I/O interface
	# set the analyzed data to database.
	# @obj:
	#==============================================
	def analyze(obj, *args)
		if obj.is_a? Replay
			analyze_replay obj, *args
		elsif obj.is_a? Deck
			analyze_deck obj, *args
		else
			logger.warn "Can't recognize analyze parameter #{obj}. Nothing will be done."
		end
	end
	
	#==============================================
	# Finish
	#----------------------------------------------
	# basic I/O interface
	# add the saving cache to the real database.
	#==============================================
	def finish(*args)
		check_database_connection
		push_cache_to_sql(@day_cache, :day)
		@day_cache.clear
	end
	
	#==============================================
	# Clear
	#----------------------------------------------
	# basic I/O interface
	# clear all the data from now.
	# In @SQLSingleCardAnalyzer, only calculate the
	# last numbers.
	#==============================================
	def clear(*args)
		time = draw_time *args
		@names.periods.each { |period| union_table @names.basic_period, period, time if period != @names.basic_period }
	end
	
	#==============================================
	# Output
	#----------------------------------------------
	# basic I/O interface
	# output the data to the set output port.
	#==============================================
	def output(*args)
		check_database_connection
		time       = draw_time *args
		periods    = @names.periods
		categories = @names.categories.values - [@names.categories[:unknown], @names.categories[:main]]
		sources    = @names.sources.values - [@names.sources[:unknown], @names.sources[:handWritten]]
		number     = @config["Output.Numbers"]
		number     = 50 if number.nil?
		result     = {}
		logger.info "Start to output."
		for period in periods
			period_hash = {}
			for source in sources
				source_hash = {}
				for category in categories
					begin
						source_hash[category] = translate_result_to_hash output_table period, category, source, time, number
					rescue => ex
						logger.warn ex
					end
					logger.info "Set [#{period}, #{source}, #{category}] Length: #{source_hash[category].length}"
					source_hash[category] = source_hash[category]
				end
				period_hash[source] = source_hash
			end
			result[period.to_s] = period_hash
		end
		@last_result = result
		# write_output_json result
		result
	end
	
	#==============================================
	# Heartbeat
	#----------------------------------------------
	# basic I/O interface
	# active the daily work.
	#==============================================
	def heartbeat(*args)
		time = draw_time *args
		clear time
		output time
		nil
	end
	
	#endregion
	
	def analyze_replay(replay, *args)
		replay.decks.each { |deck| analyze_deck deck, *args }
	end
	
	def analyze_deck(deck, *args)
		data   = generate_deck_data deck
		manual = @config["Manual"]
		hash   = args[0] || {}
		source = hash[:source] || ""
		source = @names.source_name source
		time   = draw_time hash[:time]
		if manual
			add_deck_data_to_cache data, source, time
		else
			add_deck_data_to_sql data, @names.basic_period, source, Time.now
		end
	end
	
	def generate_deck_data(deck)
		data = {
				@names.categories[:main] => generate_pack_data(deck.main_classified),
				@names.categories[:side] => generate_pack_data(deck.side_classified),
				@names.categories[:ex]   => generate_pack_data(deck.ex_classified)
		}
		seprate_types_from_main data
		data
	end
	
	def generate_pack_data(pack)
		hash = {}
		pack.each do |id, use|
			value          = [1, use, 0, 0, 0]
			value[use + 1] = 1 if use <= 3
			hash[id]       = value
		end
		hash
	end
	
	def seprate_types_from_main(deck_data)
		main_data = deck_data[@names.categories[:main]]
		[:mainMonster, :mainSpell, :mainTrap, :unknown].each { |category| deck_data[@names.categories[category]] = {} }
		main_data.each do |id, data|
			card                = Card[id]
			name                = @names.category_flag_name "main", card
			deck_data[name][id] = data
		end
		deck_data.delete @names.categories[:main]
	end
	
	def translate_result_to_hash(pg_result)
		if pg_result == nil
			logger.warn "try to translate a pg_result: nil"
			return {}
		end
		if pg_result.result_status != PG::PGRES_TUPLES_OK
			logger.error "try to translate a not tuples result. #{pg_result}"
			return {}
		end
		pg_result.map { |piece| add_extra_message(piece); piece }
	end
	
	def add_extra_message(card_hash)
		if @output_methods == nil
			ans             = generate_card_method_list_for_extra_message
			@output_methods = [] if ans == nil
		end
		id = card_hash["id"]
		return if id == nil
		card = Card[id.to_i]
		return if card == nil
		@output_methods.each { |method| card_hash[method] = card.send method }
	end
	
	def generate_card_method_list_for_extra_message
		method_names = @config["Output.ExtraMessage"]
		return nil if method_names == nil
		@output_methods = method_names.select { |name| Card.method_defined? name }
		@output_methods
	end
	
	def write_output_json(data)
		file = @config["Output.JsonName"]
		if file == nil
			logger.warn "No Output.JsonName set for SQLSingleCardAnalyzer."
			file = "Data/Output.json"
		end
		str = JSON.pretty_generate data
		begin
			f = File.open(file, "w")
			f.write str
			f.close
		rescue => ex
			logger.error "Failed to write output to #{file}"
			logger.error "\n" + ex
		end
	end
	
	def load_names
		@names = Names.new
	end
	
	class Names
		attr_accessor :periods
		attr_accessor :table_names
		attr_accessor :basic_period
		attr_accessor :database_time_format
		attr_accessor :unknown_flag
		attr_accessor :categories
		attr_accessor :sources
		
		def initialize
			@periods       = [:day, :week, :halfmonth, :month, :season]
			@basic_period  = @periods[0]
			@season_period = :season
			
			@unknown_flag = :unknown
			
			@table_names = {
					day:       "day",
					week:      "week",
					halfmonth: "halfmonth",
					month:     "month",
					season:    "season"
			}
			
			@period_time_length = {
					day:       1,
					week:      7,
					halfmonth: 15,
					month:     30,
					season:    0
			}
			
			@database_time_format = "%Y-%m-%d"
			
			@categories = {
					main:        "main",
					mainMonster: "monster",
					mainSpell:   "spell",
					mainTrap:    "trap",
					side:        "side",
					ex:          "ex",
					unknown:     "unknown"
			}
			
			@sources = {
					athletic:    "athletic",
					entertain:   "entertainment",
					handWritten: "handwritten",
					unknown:     "unknown"
			}
			
			@season_times = [
					Time.new(2000, 1, 1),
					Time.new(2000, 4, 1),
					Time.new(2000, 7, 1),
					Time.new(2000, 10, 1)
			]
		end
		
		def category_flag_name(category, card)
			category.downcase!
			card = Card[card] if card.is_a? Integer
			return @categories[:unknown] if card == nil
			if category == "side"
				return @categories[:side]
			else # main or ex or else
				if card.is_ex?
					return @categories[:main]
				elsif card.is_monster?
					return @categories[:mainMonster]
				elsif card.is_spell?
					return @categories[:mainSpell]
				elsif card.is_trap?
					return @categories[:mainTrap]
				else
					return @categories[:unknown]
				end
			end
		end
		
		def table_name(period)
			period    = period.downcase
			tableName = @table_names[period]
			if tableName != nil
				return tableName
			else
				logger.warn "Unrecognized time type #{period}."
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
		
		def category_name(category)
			category_str = @categories[category.to_sym]
			category_str == nil ? @categories[@unknown_flag] : category_str
		end
		
		def source_name(source)
			source_str = @sources[source.to_sym]
			source_str == nil ? @sources[@unknown_flag] : source_str
		end
	end
	
	def load_commands
		@commands                      = {}
		# [Table Name]
		@commands[:CreateTableCommand] = <<-Command
			create table if not exists %1$s (
				id integer,
				category varchar,
				time date,
				timePeriod integer default 1,
				source varchar default 'unknown',
        frequency integer default 0,
        numbers integer default 0,
        putOne integer default 0,
				putTwo integer default 0,
        putThree integer default 0,
				constraint card_environment_%1$s primary key (id, category, time, timePeriod, source)
			);
		Command
		
		# [    1     ,  2,    3    ,   4 ,      5    ,   6   ,     7    ,    8   ,    9  ,    10  ,    11    ]
		# [Table Name, ID, Category, Time, TimePeriod, source, frequency, numbers, putOne, putTwo, putThree]
		@commands[:UpdateCardCommand] = <<-Command
			insert into %1$s values(%2$s, '%3$s', '%4$s', %5$s, '%6$s', %7$s, %8$s, %9$s, %10$s, %11$s)
			on conflict on constraint card_environment_%1$s do update set
				frequency = %1$s.frequency + %7$s,
				numbers = %1$s.numbers + %8$s,
				putOne = %1$s.putOne + %9$s,
				putTwo = %1$s.putTwo + %10$s,
				putThree = %1$s.putThree + %11$s
			where and %1$s.time = '%4$s' and %1$s.timePeriod = '%5$s' and %1$s.source = '%6$s'
		Command
		
		# [ 1,    2    ,   3 ,      4    ,   5   ,     6    ,    7   ,    9  ,   9   ,    10   ]
		# [ID, Category, Time, TimePeriod, source, frequency, numbers, putOne, putTwo, putThree]
		@commands[:CardValueForMultiCommand] = <<-Value
			(%1$s, '%2$s', '%3$s', '%4$s', '%5$s', '%6$s', '%7$s', '%8$s', '%9$s', '%10$s')
		Value
		
		@commands[:CardValueJoinner]       = ",\n"
		
		# [     1    ,       2     ]
		# [Table Name, Card Message]
		@commands[:UpdateMultiCardCommand] = <<-Command
			insert into %1$s values
				%2$s
			on conflict on constraint card_environment_day
			  do update set
			    frequency = %1$s.frequency + excluded.frequency,
			    numbers   = %1$s.numbers + excluded.numbers,
			    putone    = %1$s.putone + excluded.putone,
			    puttwo    = %1$s.puttwo + excluded.puttwo,
			    putthree  = %1$s.putthree + excluded.putthree
		Command
		
		# [     1    ,     2   ,   3 ,   4   ,   5   ,  6  ]
		# [Table Name, Category, Time, Source, Number, Page]
		@commands[:SearchRankedCardCommand] = <<-Command
			select * from %1$s where category = '%2$s' and time = '%3$s' and source = '%4$s' order by frequency desc limit %5$s
		Command
		
		# [     1    ,  2,    3    ,  4  ,   5   ]
		# [Table Name, ID，Category, Time, Source]
		@commands[:SearchCardCommand] = <<-Command
			select * from %1$s where id = %2$s and category = '%3$s' and time = '%4$s' and source = '%5$s'
		Command
		
		# [        1      ,        2     ,     3    ,    4   ,      5    ]
		# [From Table Name, To Table Name, TimeStart, TimeEnd, TimePeriod]
		@commands[:UnionCardCommand] = <<-Command
			insert into %2$s
			select id, category, '%4$s', %5$s, source, sum(frequency), sum(numbers), sum(putOne), sum(putTwo), sum(putThree) from %1$s
			where %1$s.time > '%3$s' and %1$s.time <= '%4$s' group by (id, category, source)
			on conflict on constraint card_environment_%2$s do update set
				frequency = excluded.frequency,
				numbers = excluded.numbers,
				putOne = excluded.putOne,
				putTwo = excluded.putTwo,
				putThree = excluded.putThree;
		Command
	end
	
	
	class Cache
		attr_accessor :cache
		
		def initialize
			@cache = {}
		end
		
		def clear
			@cache.clear
		end
		
		def add(card_environment, data)
			@cache[card_environment] = [0, 0, 0, 0, 0] if self.cache[card_environment] == nil
			(0..4).each { |i| @cache[card_environment][i] += data[i] }
		end
	end
	
	def create_tables
		@names.periods.each { |period| create_table @names.table_name period }
	end
	
	def create_caches
		@day_cache = Cache.new
	end
	
	def create_table(table_name)
		command = sprintf @commands[:CreateTableCommand], table_name
		execute_command command
	end
	
	def add_deck_data_to_cache(hash_data, source, time)
		time = time.strftime @names.database_time_format if time.is_a? Time
		hash_data.each do |category, hash|
			hash.each do |id, data|
				add_data_to_cache id, category, source, time, data
			end
		end
	end
	
	def add_deck_data_to_sql(hash_data, type, source, time)
		multi = @config['Multi']
		if multi
			add_deck_data_to_sql_multi hash_data, type, source, time
		else
			add_deck_data_to_sql_single hash_data, type, source, time
		end
	end
	
	def add_deck_data_to_sql_multi(hash_data, type, source, time)
		check_database_connection
		arguments   = @names.type_arguments type, time
		table_name  = arguments[:TableName]
		time_period = arguments[:TimePeriod]
		time        = time.strftime @names.database_time_format if time.is_a? Time
		datas       = []
		hash_data.each do |category, hash|
			hash.each do |id, data|
				id = check_card_alias id
				datas.push [id, category, time, time_period, source, *data]
			end
		end
		add_multi_data_to_sql table_name, datas
	end
	
	def add_deck_data_to_sql_single(hash_data, type, source, time)
		check_database_connection
		arguments = @names.type_arguments type, time
		hash_data.each do |category, hash|
			hash.each do |id, data|
				add_data_to_sql arguments[:TableName], id, category, time, arguments[:TimePeriod], source, data
			end
		end
	end
	
	def check_card_alias(id)
		if Card.alias_list[id] != nil
			logger.debug "alias set card [#{id}] to be [#{Card.alias_list[id]}]"
			id = Card.alias_list[id]
		end
		id
	end
	
	def add_data_to_cache(id, category, source, time, data)
		id = check_card_alias id
		create_caches if @day_cache.nil?
		@day_cache.add [id, category, source, time], data
	end
	
	def add_data_to_sql(table_name, id, category, time, time_period, source, data)
		id        = check_card_alias id
		time_flag = time.strftime @names.database_time_format
		command   = sprintf @commands[:UpdateCardCommand], table_name, id, category, time_flag, time_period, source, *data
		execute_command command
	end
	
	def add_multi_data_to_sql(table_name, card_datas)
		if card_datas == []
			logger.info 'No data in the pool to update.'
			return
		end
		values  = card_datas.map { |card_data| sprintf @commands[:CardValueForMultiCommand], *card_data }
		value   = values.join @commands[:CardValueJoinner]
		command = sprintf @commands[:UpdateMultiCardCommand], table_name, value
		execute_command command
	end
	
	def push_cache_to_sql(cache, type)
		multi = @config['Multi']
		if multi
			push_cache_to_sql_multi cache, type
		else
			push_cache_to_sql_single cache, type
		end
	end
	
	def push_cache_to_sql_single(cache, period)
		time_period = @names.time_period_length period
		table_name  = @names.table_name period
		commands    = ['begin;']
		# [id, category, source, time] => data
		cache.cache.each { |key, value|
			commands.push sprintf @commands[:UpdateCardCommand], table_name, key[0], key[1], key[3], time_period, key[2], *value
		}
		commands.push 'commit;'
		execute_commands commands
	end
	
	def push_cache_to_sql_multi(cache, period)
		time_period = @names.time_period_length period
		table_name  = @names.table_name period
		card_data   = cache.cache.map { |key, value| [key[0], key[1], key[3], time_period, key[2], *value] }
		add_multi_data_to_sql table_name, card_data
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
		command    = sprintf @commands[:UnionCardCommand], from_table_name, to_table_name, time_start, time_end, time_length
		execute_command command
	end
	
	def output_table(type, category, source, time, number)
		arguments  = @names.type_arguments type, time
		table_name = arguments[:TableName]
		time_flag  = arguments[:TimeStr]
		command    = sprintf @commands[:SearchRankedCardCommand], table_name, category, time_flag, source, number
		execute_command command
	end
	
	def output_card(type, source, category, time, id)
		arguments    = @names.type_arguments type, time
		table_name   = arguments[:TableName]
		time_flag    = arguments[:TimeStr]
		source_str   = @names.source_name source
		category_str = @names.category_name category
		# Table Name, ID，Category, Time, Source
		command      = sprintf @commands[:SearchCardCommand], table_name, id.to_s, category_str, time_flag, source_str
		execute_command command
	end
end

#region Server APIs
class SQLSingleCardAnalyzer
	def query_summary
		@last_result
	end
	
	def query_child(period = '', source = '', category = '')
		period_str   = period
		source_str   = @names.source_name source
		category_str = @names.category_name category
		@last_result = {} if @last_result == nil
		result       = @last_result[period_str] || {}
		return result if source == ''
		result = result[source_str] || {}
		return result if category == ''
		result = result[category_str] || {}
		result.to_json
	end
	
	def query_card(card = 0, type = '', source = '', category = '', time = nil)
		time   = draw_time time
		card   = check_id_str card.to_s
		result = output_card type, source, category, time, card
		result = translate_result_to_hash result
		result
	end
	
	def check_legal_str(str)
		str.gsub! "'", ''
		str
	end
	
	def check_time_str(str)
		str.replace str[/\d\d-\d\d\-\d\d/]
	end
	
	def check_id_str(str)
		str.replace str.scan(/\d/).join('')
	end
end

#endregion

analyzer = SQLSingleCardAnalyzer.new
Analyzer.push analyzer

#region Interfaces
#==================================
# GET /single
#----------------------------------
# direct return all the cache.
#==================================
Analyzer.api.push 'get', '/analyze/single' do
	content = analyzer.query_summary.to_json
	content_type 'application/json'
	content
end

#==================================
# PUSH /single/type
#----------------------------------
# given
# * parameter: type
# * parameter: category
# * parameter: source
# return
# + [cards]
#==================================
Analyzer.api.push 'get', '/analyze/single/type' do
	type     = params['type'] || ''
	category = params['category'] || ''
	source   = params['source'] || ''
	
	content = analyzer.query_child type, source, category
	content = content.to_json
	content_type 'application/json'
	content
end

#==================================
# PUSH /single/card
#----------------------------------
# given
# * type
# * category
# * source
# * card id
# return
# + [card]
#==================================
Analyzer.api.push 'get', '/analyze/single/card' do
	type     = params['type'] || ''
	category = paramas['category'] || ''
	source   = params['source'] || ''
	time     = params['time']
	card     = params['card'] || 0
	
	content = analyzer.query_card card, type, source, category, time
	content = content.to_json
	content_type 'application/json'
	content
end
#endregion
