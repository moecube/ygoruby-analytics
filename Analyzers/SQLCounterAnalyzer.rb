require File.dirname(__FILE__)+ "/SQLSingleCardAnalyzer.rb"

class SQLCounterAnalyzer < SQLSingleCardAnalyzer
	def initialize
		super
	end
	
	def load_configs
		super
	end
	
	def analyze(obj, *args)
		super
	end
	
	def finish(*args)
		super
	end
	
	def clear(*args)
		super
	end
	
	def output(*args)
		check_database_connection
		time    = draw_time *args
		periods = @names.periods
		sources = @names.sources.values - [@names.sources[:unknown], @names.sources[:handWritten]]
		result  = {}
		logger.info "Start to output."
		for period in periods
			period_hash = {}
			for source in sources
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
	
	def heartbeat(*args)
		super
	end
	
	def generate_deck_data(deck)
		{ category: { count: 1 } }
	end
	
	def translate_result_to_hash(pg_result)
		if pg_result == nil
			logger.warn "try to translate a pg_result: nil"
			return 0
		end
		return 0 if pg_result.count == 0
		if pg_result.result_status != PG::PGRES_TUPLES_OK
			logger.error "try to translate a not tuples result. #{pg_result}"
			return 0
		end
		pg_result[0]["count"].to_i
	end
	
	def load_commands
		super
		# [Table Name]
		@commands[:CreateTableCommand] = <<-Command
			create table if not exists %1$s (
				time date,
				timePeriod integer default 1,
				source varchar default 'unknown',
				count integer,
				constraint count_environment primary key (time, timePeriod, source)
			);
		Command
		
		# [    1     ,   4 ,      5    ,   6   ,   7  ]
		# [Table Name, Time, TimePeriod, source, count]
		@commands[:UpdateCardCommand] = <<-Command
			insert into %1$s values('%4$s', %5$s, '%6$s', %7$s)
			on conflict on constraint count_environment do update set
				count = %1$s.count + %7$s
			where %1$s.time = '%4$s' and %1$s.timePeriod = '%5$s' and %1$s.source = '%6$s'
		Command
		
		
		# [  3 ,      4    ,   5   ,   6  ]
		# [Time, TimePeriod, source, count]
		@commands[:CardValueForMultiCommand] = <<-Value
			('%3$s', '%4$s', '%5$s', %6$s)
		Value
		
		@commands[:CardValueJoinner]       = ",\n"
		
		# [     1    ,       2     ]
		# [Table Name, Card Message]
		@commands[:UpdateMultiCardCommand] = <<-Command
			insert into %1$s values
				%2$s
			on conflict on constraint count_environment
			  do update set
			    count = %1$s.count + excluded.count
		Command
		
		# Rewrite
		# [     1    ,  2  ,   3   ,      4    ]
		# [Table Name, Time, Source, TimePeriod]
		@commands[:SearchCountCommand] = <<-Command
			select * from %1$s where timePeriod = %4$s and time = '%2$s' and source = '%3$s'
		Command
		
		# [        1      ,        2     ,     3    ,    4   ,      5    ]
		# [From Table Name, To Table Name, TimeStart, TimeEnd, TimePeriod]
		@commands[:UnionCardCommand] = <<-Command
			insert into %2$s
			select '%4$s', %5$s, source, sum(count) from %1$s
			where %1$s.time > '%3$s' and %1$s.time <= '%4$s' and counts.timeperiod = 1  group by (source)
			on conflict on constraint count_environment do update set
				count = excluded.count
		Command
	end
	
	def load_names
		super
		class << @names
			alias origin_table_name table_name
			
			def table_name(period)
				"counts"
			end
		end
		@names.categories = [""]
	end
	
	class Cache < Cache
		def add(card_environment, data)
			@cache[card_environment] = 0 if @cache[card_environment] == nil
			@cache[card_environment] += 1
		end
	end
	
	def create_caches
		@day_cache = Cache.new
	end
	
	def create_tables
		create_table @names.table_name(nil)
	end
	
	def output_table(type, source, time)
		# category ignored.
		arguments   = @names.type_arguments type, time
		table_name  = arguments[:TableName]
		time_flag   = arguments[:TimeStr]
		time_period = arguments[:TimePeriod]
		command     = sprintf @commands[:SearchCountCommand], table_name, time_flag, source, time_period
		execute_command command
	end
 
end

class SQLCounterAnalyzer
	def query_summary
		@last_result
	end
	
	def query_child(period = "", source = "", category = "")
		period_str   = period
		source_str   = @names.source_name source
		@last_result = {} if @last_result == nil
		result       = @last_result[period_str] || {}
		return result if source == ""
		result = result[source_str] || 0
		result
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
Analyzer.api.push "get", "/analyze/counter" do
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
Analyzer.api.push "get", "/analyze/counter/type" do
	type   = params["type"] || ""
	source = params["source"] || ""
	
	content = analyzer.query_child type, source
	content = content.to_s
	content
end
#endregion
