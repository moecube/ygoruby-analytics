require File.dirname(__FILE__) + '/SQLAnalyzer.rb'

class SQLDeckAnalyzer < SQLSingleCardAnalyzer
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
	
	def create_caches
		@deck_cache = Cache.new
		@tag_cache = Cache.new
	end
	
	def load_names
		@deck_names = Names.new
		@tag_names  = Names.new
		
		@names = @deck_names
		
		@deck_names.table_names = { day: 'deck_day', week: 'deck_week', halfmonth: 'deck_halfmonth', month: 'deck_month', season: 'deck_season' }
		@tag_names.table_names = { day: 'tag_day', week: 'tag_week', halfmonth: 'tag_halfmonth', month: 'tag_month', season: 'tag_season' }
	end
	
	def load_commands
		@commands = {}
		super
		@commands[:create_table] = <<-Command
			create table if not exists %1$s (
				name varchar,
				time date,
				timePeriod integer default 1,
				source varchar default 'unknown',
        count integer default 0,
				constraint card_environment_%1$s primary key (name, time, timePeriod, source)
			);
		Command
		
		# [     1    ,       2     ]
		# [Table Name, Card Message]
		@commands[:update_deck] = <<-Command
			insert into %1$s values
				%2$s
			on conflict on constraint card_environment_%1$s
			  do update set
			    count = %1$s.count + excluded.count
		Command
		
		# [     1    ,  2  ,  3  ,   4   ]
		# [Table Name, Name，Time, Source]
		@commands[:search] = <<-Command
			select * from %1$s where name = %2$s and time = '%3$s' and source = '%4$s'
		Command
		
		# [        1      ,        2     ,     3    ,    4   ,      5    ]
		# [From Table Name, To Table Name, TimeStart, TimeEnd, TimePeriod]
		@commands[:union] = <<-Command
			insert into %2$s
			select name, '%4$s', %5$s, source, sum(count) from %1$s
			where %1$s.time > '%3$s' and %1$s.time <= '%4$s' group by (id, category, source)
			on conflict on constraint card_environment_%2$s do update set
				count = excluded.count
		Command
		
		# [     1    ,   2 ,   3   ,   4   ,  5  ]
		# [Table Name, Time, Source, Number, Page]
		@commands[:output] = <<-Command
			select * from %1$s where time = '%2$s' and source = '%3$s' order by frequency desc count %4$s
		Command
	end
	
	def generate_data(deck)
		deck, tags = DeckIdentifier.global[deck]
		if deck == nil
			deck = '迷之卡组'
			tags = []
		end
		[deck, tags]
	end
	
	def generate_cache_sql_string(data)
		time_period, time, source, name, count = data
		inner = ["'#{name}'", "'#{time}'", time_period, "'#{source}'", count].join ', '
		"(#{inner})"
	end
	
	def add_data_to_cache(data, options)
		@deck_cache.add [options[:time], options[:source], data[0]]
		data[1].each { |tag| @tag_cache.add [options[:time], options[:source], data[0] + '-' + tag] }
	end
	
	def create_tables
		@deck_names.periods.each { |table_name| create_table(table_name, @deck_names) }
		@tag_names.periods.each { |table_name| create_table(table_name, @tag_names) }
	end
	
	def create_table(table_name, names)
		execute_command sprintf @commands[:create_table], names.table_name(table_name)
	end
	
	def clear(*args)
		time = draw_time *args
		@deck_names.periods.each { |period| union_table @deck_names.basic_period, period, time if period != @deck_names.basic_period }
		@tag_names.periods.each { |period| union_table @tag_names.basic_period, period, time if period != @tag_names.basic_period }
	end
	
	def finish(*args)
		check_database_connection
		push_cache @deck_cache, @deck_names, :day, *args
		push_cache @tag_cache, @tag_names, :day, *args
		@deck_cache.clear
		@tag_cache.clear
	end
	
	def output(*args)
		
	end
	
	def output_deck(*args)
		check_database_connection
		time    = draw_time *args
		periods = @deck_names.periods
		sources = @deck_names.sources.values - [@deck_names.sources[:unknown], @deck_names.sources[:handWritten]]
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
				logger.info "Deck Analyzer #{period}, #{source}: #{period_hash[source]} decks."
			end
			result[period.to_s] = period_hash
		end
		@deck_last_result = result
	end
	
	def output_table(type, source, time)
		arguments  = @names.type_arguments type, time
		table_name = arguments[:TableName]
		time_flag  = arguments[:TimeStr]
		command    = sprintf @commands[:output], table_name, category, time_flag, source, number, 1
		execute_command command
	end
	
	def translate_result_to_hash(pg_result)
		return [] unless check_pg_result pg_result
		pg_result.map {|piece| piece['count'].to_i }
	end
end

class SQLDeckAnalyzer
	def query_deck_summary
		@deck_last_result
	end
	
	
	def query_deck_child(period = '', source = '')
		period_str   = period
		source_str   = @deck_names.source_name source
		@last_result = {} if @last_result == nil
		result       = @deck_last_result[period_str] || {}
		return result if source == ''
		result = result[source_str] || {}
		result.to_json
	end
end

analyzer = SQLDeckAnalyzer.new
Analyzer.push analyzer


#region Interfaces
#==================================
# GET /deck
#----------------------------------
# direct return all the cache.
#==================================
Analyzer.api.push 'get', '/analyze/deck' do
	content = analyzer.query_deck_summary.to_json
	content_type 'application/json'
	content
end


#==================================
# PUSH /deck/type
#----------------------------------
# given
# * parameter: type
# * parameter: source
# return
# + Count
#==================================
Analyzer.api.push 'get', '/analyze/deck/type' do
	type   = params['type'] || ''
	source = params['source'] || ''
	
	content = analyzer.query_deck_child type, source
	content_type 'application/json'
	content.to_json
end

#endregion