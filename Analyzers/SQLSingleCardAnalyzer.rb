require File.dirname(__FILE__) + '/SQLAnalyzer.rb'

class SQLSingleCardAnalyzer < PGSQLAnalyzer
	def load_names
		@names = SQLSingleCardAnalyzer::Names.new
	end
	
	def create_caches
		@cache = Cache.new
	end
	
	class Cache < Cache
		def add(card_environment, data)
			@cache[card_environment] = [0, 0, 0, 0, 0, 0] if self.cache[card_environment] == nil
			(0..5).each { |i| @cache[card_environment][i] += data[i] }
		end
	end
	
	class Names < Names
		attr_accessor :categories
		
		def initialize
			super
			create_categories
		end
		
		def create_table_names
			@table_names = {
					day:       'single_day',
					week:      'single_week',
					halfmonth: 'single_halfmonth',
					month:     'single_month',
					season:    'single_season'
			}
		end
		
		def create_categories
			@categories                = {
					main:        'main',
					mainMonster: 'monster',
					mainSpell:   'spell',
					mainTrap:    'trap',
					side:        'side',
					ex:          'ex',
			}
			@categories[@unknown_flag] = 'unknown'
		end
		
		def category_flag_name(category, card)
			category.downcase!
			card = Card[card] if card.is_a? Integer
			return @categories[:unknown] if card == nil
			if category == 'side'
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
		
		def category_name(category)
			category_str = @categories[category.to_sym]
			category_str == nil ? @categories[@unknown_flag] : category_str
		end
	end
	
	def load_commands
		super
		# [Table Name, Constraint Name]
		@commands[:create_table] = <<-Command
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
				putOverThree integer default 0,
				constraint card_environment_%1$s primary key (id, category, time, timePeriod, source)
			);
		Command
		
		# [     1    ,       2     ]
		# [Table Name, Card Message]
		@commands[:update_deck] = <<-Command
			insert into %1$s values
				%2$s
			on conflict on constraint card_environment_single_day
			  do update set
			    frequency = %1$s.frequency + excluded.frequency,
			    numbers   = %1$s.numbers + excluded.numbers,
			    putOne    = %1$s.putOne + excluded.putOne,
			    putTwo    = %1$s.putTwo + excluded.putTwo,
			    putThree  = %1$s.putThree + excluded.putThree,
					putOverThree = %1$s.putOverThree + excluded.putOverThree
		Command
		
		# [     1    ,  2,    3    ,  4  ,   5   ]
		# [Table Name, ID，Category, Time, Source]
		@commands[:search] = <<-Command
			select * from %1$s where id = %2$s and category = '%3$s' and time = '%4$s' and source = '%5$s'
		Command
		
		# [        1      ,        2     ,     3    ,    4   ,      5    ]
		# [From Table Name, To Table Name, TimeStart, TimeEnd, TimePeriod]
		@commands[:union] = <<-Command
			insert into %2$s
			select id, category, '%4$s', %5$s, source, sum(frequency), sum(numbers), sum(putOne), sum(putTwo), sum(putThree) from %1$s
			where %1$s.time > '%3$s' and %1$s.time <= '%4$s' group by (id, category, source)
			on conflict on constraint card_environment_%2$s do update set
				frequency = excluded.frequency,
				numbers = excluded.numbers,
				putOne = excluded.putOne,
				putTwo = excluded.putTwo,
				putThree = excluded.putThree,
				putOverThree = excluded.putOverThree;
		Command
		
		# [     1    ,     2   ,   3 ,   4   ,   5   ,  6  ]
		# [Table Name, Category, Time, Source, Number, Page]
		@commands[:output] = <<-Command
			select * from %1$s where category = '%2$s' and time = '%3$s' and source = '%4$s' order by frequency desc limit %5$s
		Command
	end
	
	# id, category, source, time => number, frequency, putOne, putTwo, putThree, putOverThree
	def generate_cache_sql_string(keys_and_values)
		time_period, id, category, source, time, number, frequency, putOne, putTwo, putThree, putOverThree = keys_and_values
		
		inner = [id, "'#{category}'", "'#{time}'", time_period, "'#{source}'", frequency, number, putOne, putTwo, putThree, putOverThree].join ', '
		"(#{inner})"
	end
	
	def generate_data(deck, options)
		data = {
				@names.categories[:main] => generate_pack_data(deck.main_classified),
				@names.categories[:side] => generate_pack_data(deck.side_classified),
				@names.categories[:ex]   => generate_pack_data(deck.ex_classified)
		}
		separate_types_from_main data
		data
	end
	
	def add_data_to_cache(data, options)
		time   = options[:time].strftime @names.database_time_format
		source = options[:source]
		data.each do |category, hash|
			hash.each do |id, data|
				@cache.add [id, category, source, time], data
			end
		end
	end
	
	def generate_pack_data(pack)
		hash = {}
		pack.each do |id, use|
			value                   = [1, use, 0, 0, 0, 0]
			value[[use, 4].min + 1] = 1
			hash[id]                = value
		end
		hash
	end
	
	def separate_types_from_main(deck_data)
		main_data = deck_data[@names.categories[:main]]
		[:mainMonster, :mainSpell, :mainTrap, :unknown].each { |category| deck_data[@names.categories[category]] = {} }
		main_data.each do |id, data|
			card                = Card[id]
			name                = @names.category_flag_name 'main', card
			deck_data[name][id] = data
		end
		deck_data.delete @names.categories[:main]
	end
	
	def output(*args)
		check_database_connection
		time       = draw_time *args
		periods    = @names.periods
		categories = @names.categories.values - [@names.categories[:unknown], @names.categories[:main]]
		sources    = @names.sources.values - [@names.sources[:unknown], @names.sources[:handWritten]]
		number     = @config['Output.Numbers']
		number     = 50 unless number.is_a? Integer
		result     = {}
		logger.info 'Start to output.'
		periods.each do |period|
			period_hash = {}
			sources.each do |source|
				source_hash = {}
				categories.each do |category|
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
		result
	end
	
	def output_table(type, category, source, time, number)
		arguments  = @names.type_arguments type, time
		table_name = arguments[:TableName]
		time_flag  = arguments[:TimeStr]
		command    = sprintf @commands[:output], table_name, category, time_flag, source, number, 1
		execute_command command
	end
	
	def translate_result_to_hash(pg_result)
		if pg_result == nil
			logger.warn 'try to translate a pg_result: nil'
			return {}
		end
		if pg_result.result_status != PG::PGRES_TUPLES_OK
			logger.error 'try to translate a not tuples result. ' + pg_result
			return {}
		end
		pg_result.map { |piece| process_result piece }
	end
	
	def process_result(piece)
		add_extra_message piece
		piece
	end
	
	def add_extra_message(card_hash)
		if @output_methods == nil
			ans             = generate_card_method_list_for_extra_message
			@output_methods = [] if ans == nil
		end
		id = card_hash['id']
		return if id == nil
		card = Card[id.to_i]
		return if card == nil
		@output_methods.each { |method| card_hash[method] = card.send method }
	end
	
	def generate_card_method_list_for_extra_message
		method_names = @config['Output.ExtraMessage']
		return nil unless method_names.is_a? Array
		@output_methods = method_names.select { |name| Card.method_defined? name }
		@output_methods
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
	category = params['category'] || ''
	source   = params['source'] || ''
	time     = params['time']
	card     = params['card'] || 0
	
	content = analyzer.query_card card, type, source, category, time
	content = content.to_json
	content_type 'application/json'
	content
end
#endregion
