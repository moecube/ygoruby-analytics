require File.dirname(__FILE__) + '/SQLAnalyzer.rb'

class SQLCounterAnalyzer < PGSQLAnalyzer
	def output(*args)
		check_database_connection
		time    = draw_time *args
		periods = @names.periods
		sources = @names.sources.values - [@names.sources[:unknown], @names.sources[:handWritten]]
		result  = {}
		logger.info 'Start to output.'
		periods.each do |period|
			period_hash = {}
			sources.each do |source|
				begin
					period_hash[source] = translate_result_to_hash output_table period, source, time
				rescue => ex
					logger.warn ex
				end
				logger.info "Counter #{period}, #{source}: #{period_hash[source]} decks."
			end
			result[period.to_s] = period_hash
		end
		@last_result = result
	end
	
	def output_table(type, source, time)
		# category ignored.
		arguments   = @names.type_arguments type, time
		table_name  = arguments[:TableName]
		time_flag   = arguments[:TimeStr]
		time_period = arguments[:TimePeriod]
		command     = sprintf @commands[:output], table_name, time_flag, source, time_period
		execute_command command
	end
	
	def translate_result_to_hash(pg_result)
		if pg_result == nil
			logger.warn 'try to translate a pg_result: nil'
			return 0
		end
		return 0 if pg_result.count == 0
		if pg_result.result_status != PG::PGRES_TUPLES_OK
			logger.error 'try to translate a not tuples result.' + pg_result
			return 0
		end
		pg_result[0]['count'].to_i
	end
	
	def load_commands
		super
		# [Table Name]
		@commands[:create_table] = <<-Command
			create table if not exists %1$s (
				time date,
				timePeriod integer default 1,
				source varchar default 'unknown',
				count integer,
				constraint count_environment primary key (time, timePeriod, source)
			);
		Command
		
		# [     1    ,       2     ]
		# [Table Name, Card Message]
		@commands[:update_deck] = <<-Command
			insert into %1$s values
				%2$s
			on conflict on constraint count_environment
			  do update set
			    count = %1$s.count + excluded.count
		Command
		
		# [     1    ,  2  ,   3   ,      4    ]
		# [Table Name, Time, Source, TimePeriod]
		@commands[:output] = <<-Command
			select * from %1$s where timePeriod = %4$s and time = '%2$s' and source = '%3$s'
		Command
		
		# [        1      ,        2     ,     3    ,    4   ,      5    ]
		# [From Table Name, To Table Name, TimeStart, TimeEnd, TimePeriod]
		@commands[:union] = <<-Command
			insert into %2$s
			select '%4$s', %5$s, source, sum(count) from %1$s
			where %1$s.time > '%3$s' and %1$s.time <= '%4$s' and %1$s.timeperiod = 1  group by (source)
			on conflict on constraint count_environment do update set
				count = excluded.count
		Command
	end
	
	def generate_data(deck)
		1
	end
	
	def add_data_to_cache(data, options)
		@cache.add [options[:time].strftime(@names.database_time_format), options[:source]]
	end
	
	def generate_cache_sql_string(data)
		time_period, time, source, count = data
		inner = ["'#{time}'", time_period, "'#{source}'", count].join ', '
		"(#{inner})"
	end
	
	def create_caches
		@cache = Cache.new
	end
	
	def load_names
		@names = Names.new
	end
	
	class Cache < Cache
		def initialize
			super
			@cache = {}
		end
		
		def add(environment)
			@cache[environment] = 0 unless @cache[environment] != nil
			@cache[environment] += 1
		end
		
		def clear
			@cache.clear
		end
	end
	
	class Names < Names
		def table_name(period)
			'counter'
		end
	end
end

class SQLCounterAnalyzer
	def query_summary
		@last_result
	end
	
	def query_child(period = '', source = '')
		period_str   = period
		source_str   = @names.source_name source
		@last_result = {} if @last_result == nil
		result       = @last_result[period_str] || {}
		return result if source == ''
		result = result[source_str] || {}
		result.to_json
	end
end

analyzer = SQLCounterAnalyzer.new
Analyzer.push analyzer

#region Interfaces
#==================================
# GET /counter
#----------------------------------
# direct return all the cache.
#==================================
Analyzer.api.push 'get', '/analyze/counter' do
	content = analyzer.query_summary.to_json
	content_type 'application/json'
	content
end

#==================================
# PUSH /counter/type
#----------------------------------
# given
# * parameter: type
# * parameter: source
# return
# + Count
#==================================
Analyzer.api.push 'get', '/analyze/counter/type' do
	type   = params['type'] || ''
	source = params['source'] || ''
	
	content = analyzer.query_child type, source
	content = content.to_s
	content
end
#endregion
