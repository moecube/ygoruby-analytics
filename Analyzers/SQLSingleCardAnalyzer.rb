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
	end

	def check_database_connection()
		load_database if @sql == nil
		if @sql.connect_poll == PG::Connection::PGRES_POLLING_FAILED
			@sql.reset
			logger.warn "Reseted SQL connection."
		end
	end

	def execute_command(command)
		begin
			logger.debug "execute sql command:\n#{command}"
			@sql.exec command
		rescue => exception
			logger.error "error while running command. Message:"
			logger.error "\n" + exception.to_s
		end
	end

	def execute_commands(commands)
		begin
			logger.debug "execute sql commands:"
			commands.map { |command| logger.debug(command); @sql.exec command }
		rescue => exception
			logger.error "error while running commands. Message:"
			logger.error "\n" + exception.to_s
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
		push_cache_to_sql(@day_cache, Names::Day)
		@day_cache.clear
	end

	def clear(*args)
		time = draw_time *args
		union_table Names::Day, Names::Week, time
		union_table Names::Day, Names::HalfMonth, time
		union_table Names::Day, Names::Month, time
		union_season Names::Day, time
		@last_result = nil
	end

	def output(*args)
		check_database_connection
		time       = draw_time *args
		periods    = [Names::Day, Names::Week, Names::HalfMonth, Names::Month, Names::Season]
		categories = Names::Categories.values
		sources    = Names::Sources.values
		number     = @config["Output.Numbers"]
		number     = 50 if number.nil?
		result     = {}
		for period in periods
			period_hash = {}
			for source in sources
				hash = {}
				for category in categories
					hash[category] = translate_result_to_hash output_table period, category, time, number
				end
				period_hash[source] = hash
			end
			result[period] = period_hash
		end
		@last_result = result
		write_output_json result
		result
	end

	def draw_time(*args)
		time = args[0]
		time = Time.now if time == nil
		time = Time.at time if time.is_a? Fixnum
		time = Time.gm *time.split("-") if time.is_a? String
		if time.is_a? Time
			# do nothing
		elsif time == args[0]
			logger.warn "Unrecognized time arg #{args}. Returned Time.now"
			time = Time.now
		end
		time
	end

	def analyze_replay(replay, *args)
		replay.decks.each { |deck| analyze_deck deck, *args }
	end

	def analyze_deck(deck, *args)
		data   = generate_deck_data deck
		manual = @config["Manual"]
		hash   = args[0] || {}
		source = hash[:source] || "Unknown"
		source = Names::Sources[source.to_sym]
		source = Names::Sources[:unknown] if source == nil
		time   = draw_time hash[:time]
		if manual
			add_deck_data_to_cache data, source, time
		else
			add_deck_data_to_sql data, Names::Day, source, Time.now
		end
	end

	def generate_deck_data(deck)
		data = {
				Names::Categories[:main] => generate_pack_data(deck.main_classified),
				Names::Categories[:side] => generate_pack_data(deck.side_classified),
				Names::Categories[:ex]   => generate_pack_data(deck.ex_classified)
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
		main_data = deck_data[Names::Categories[:main]]
		[:mainMonster, :mainSpell, :mainTrap, :unknown].each { |category| deck_data[Names::Categories[category]] = {} }
		main_data.each do |id, data|
			card                = Card[id]
			name                = Names.CategoryFlagName "Main", card
			deck_data[name][id] = data
		end
		deck_data.delete Names::Categories[:main]
	end

	def translate_result_to_hash(pg_result)
		if pg_result == nil
			logger.warn "try to translate a pg_result: nil"
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

	module Names
		Day       = "day"
		Week      = "week"
		HalfMonth = "halfmonth"
		Month     = "month"
		Season    = "season"

		DatabaseTimeFormat = "%Y-%m-%d"

		# 已弃用
		DayFlag            = "%Y-%m-%d"
		WeekFlag           = "%Y-%m-%d-7" # 最近 7 天
		HalfMonthFlag      = "%Y-%m-%d-15" # 最近 15 天
		MonthFlag          = "%Y-%m-%d-30" # 最近 30 天

		DayTimePeriod       = 1
		WeekTimePeriod      = 7
		HalfMonthTimePeriod = 15
		MonthTimePeriod     = 30

		Categories = {
				main:        "main",
				mainMonster: "monster",
				mainSpell:   "spell",
				mainTrap:    "trap",
				side:        "side",
				ex:          "ex",
				unknown:     "unknown"
		}

		Sources = {
				athletic:      "athletic",
				entertain:     "entertainment",
				handWritten:   "handwritten",
				unknown:       "unknown"
		}

		def self.CategoryFlagName(area, card)
			area.downcase!
			card = Card[card] if card.is_a? Integer
			return UnknownFlag if card == nil
			if area == "side"
				return SideFlag
			else # main or ex or else
				if card.is_ex?
					return Categories[:main]
				elsif card.is_monster?
					return Categories[:mainMonster]
				elsif card.is_spell?
					return Categories[:mainSpell]
				elsif card.is_trap?
					return Categories[:mainTrap]
				else
					return Categories[:unknown]
				end
			end
		end

		def self.TableName(type)
			type = type.downcase
			case type
				when Names::Day, Names::Week, Names::HalfMonth, Names::Month, Names::Season
					return type
				else
					logger.warn "Unrecognized time type #{type}."
					Names::Day
			end
		end

		def self.TimeFlagName(type, time)
			type = type.downcase
			case type
				when Names::Day
					time.strftime DayFlag
				when Names::Week
					time.strftime WeekFlag
				when Names::HalfMonth
					time.strftime HalfMonthFlag
				when Names::Month
					time.strftime MonthFlag
				when Names::Season
					time.strftime("%Y-") + ((time.month - 1) / 3 * 3 + 1).to_s + "-01"
				else
					logger.warn "Unrecognized time type #{type}."
					time.strftime DayFlag
			end
		end

		def self.TimePeriodLength(type)
			type = type.downcase
			case type
				when Names::Day
					DayTimePeriod
				when Names::Week
					WeekTimePeriod
				when Names::HalfMonth
					HalfMonthTimePeriod
				when Names::Month
					MonthTimePeriod
				when Names::Season
					0
				else
					logger.warn "Unrecognized time type #{type}."
					1
			end
		end
	end

	def type_arguments(type, time)
		time_flag   = time.strftime Names::DatabaseTimeFormat
		time_period = Names.TimePeriodLength type
		table_name  = Names.TableName type
		{
				TimePeriod: time_period,
				TimeStr:    time_flag,
				TableName:  table_name
		}
	end

	module Commands
		# [Table Name]
		CreateTableCommand = <<-Command
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
		UpdateCardCommand = <<-Command
			insert into %1$s values(%2$s, '%3$s', '%4$s', %5$s, '%6$s', %7$s, %8$s, %9$s, %10$s, %11$s)
			on conflict on constraint card_environment_%1$s do update set
				frequency = %1$s.frequency + %7$s,
				numbers = %1$s.numbers + %8$s,
				putOne = %1$s.putOne + %9$s,
				putTwo = %1$s.putTwo + %10$s,
				putThree = %1$s.putThree + %11$s
			where %1$s.id = %2$s and %1$s.category = '%3$s' and %1$s.time = '%4$s' and %1$s.timePeriod = '%5$s' and %1$s.source = '%6$s'
		Command

		# [     1    ,     2   ,   3 ,   4   ,   5   ,  6  ]
		# [Table Name, Category, Time, Source, Number, Page]
		SearchRankedCardCommand = <<-Command
			select * from %1$s where category = '%2$s' and time = '%3$s' order by frequency desc limit %4$s
		Command

		# [     1    ,   2 , 3 ]
		# [Table Name, Time, ID]
		SearchCardCommand = <<-Command
			select * from %1$s where time = '%2$s' and id = %3$s
		Command

		# [        1      ,        2     ,     3    ,    4   ,      5    ]
		# [From Table Name, To Table Name, TimeStart, TimeEnd, TimePeriod]
		UnionCardCommand = <<-Command
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
		create_table Names::Day
		create_table Names::Week
		create_table Names::HalfMonth
		create_table Names::Month
		create_table Names::Season
	end

	def create_caches
		@day_cache = Cache.new
	end

	def create_table(table_name)
		command = sprintf Commands::CreateTableCommand, table_name
		execute_command command
	end

	def add_deck_data_to_cache(hash_data, source, time)
		time = time.strftime Names::DatabaseTimeFormat if time.is_a? Time
		hash_data.each do |category, hash|
			hash.each do |id, data|
				add_data_to_cache id, category, source, time, data
			end
		end
	end

	def add_deck_data_to_sql(hash_data, type, source, time)
		check_database_connection
		arguments = type_arguments type, time
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
		time_flag = time.strftime Names::DatabaseTimeFormat
		command   = sprintf Commands::UpdateCardCommand, table_name, id, category, time_flag, time_period, source, *data
		execute_command command
	end

	def push_cache_to_sql(cache, type)
		time_period = Names.TimePeriodLength type
		table_name  = Names.TableName type
		commands    = ["begin;"]
		# [id, category, source, time] => data
		for key, value in cache.cache
			commands.push sprintf Commands::UpdateCardCommand, table_name, key[0], key[1], key[3], time_period, key[2], *value
		end
		commands.push "commit;"
		execute_commands commands
	end

	def union_table(from_type, to_type, time)
		from_table_name = Names.TableName(from_type)
		to_table_name   = Names.TableName(to_type)
		time_end        = time
		time_length     = Names.TimePeriodLength to_type
		union_custom_table from_table_name, to_table_name, time_end, time_length
	end

	def union_custom_table(from_table_name, to_table_name, time_end, time_length, time_start = nil)
		time_start = (time_end - 86400 * time_length) if time_start == nil
		time_start = time_start.strftime Names::DatabaseTimeFormat
		time_end   = time_end.strftime Names::DatabaseTimeFormat
		command    = sprintf Commands::UnionCardCommand, from_table_name, to_table_name, time_start, time_end, time_length
		execute_command command
	end

# todo: fix it.
	def union_season(from_type, time)
		from_table_name = Names.TableName from_type
		to_table_name   = Names.TableName Names::Season
		time_end        = time.strftime Names::DatabaseTimeFormat
		time_start      = Time.new(time.year, (time.month - 1) / 3 * 3 + 1, 1)
		time_length     = Names.TimePeriodLength Names::Season
		command         = sprintf Commands::UnionCardCommand, from_table_name, to_table_name, time_start, time_end, time_length
		execute_command command
	end

	def output_table(type, category, time, number)
		arguments  = type_arguments type, time
		table_name = arguments[:TableName]
		time_flag  = arguments[:TimeStr]
		command    = sprintf Commands::SearchRankedCardCommand, table_name, category, time_flag, number
		execute_command command
	end

	def output_card(type, time, id)
		arguments  = type_arguments type, time
		table_name = arguments[:TableName]
		time_flag  = arguments[:TimeStr]
		command    = sprintf Commands::SearchCardCommand, table_name, time_flag, id
		execute_command command
	end
end

# Server API
class SQLSingleCardAnalyzer
	def query_summary
		output if @last_result == nil
		@last_result
	end

	def query_child(period = "", source = "", category = "")
		period_str   = period
		source_str   = Names::Sources[source.to_sym] || Names::Sources[:unknown]
		category_str = Names::Categories[category.to_sym] || Names::Categories[:unknown]
		output if @last_result == nil
		result = @last_result[period_str] || {}
		result = result[source_str] || {}
		result = result[category_str] || {}
		result
	end

	def query_card(card = 0, type = "", time = nil)
		time   = draw_time time
		card   = check_id_str card.to_s
		type   = check_legal_str type
		result = output_card type, time, card
		result = translate_result_to_hash result
		result
	end

	def check_legal_str(str)
		str.gsub! "'", ""
		str
	end

	def check_time_str(str)
		str.replace str[/\d\d-\d\d\-\d\d/]
	end

	def check_id_str(str)
		str.replace str.scan(/\d/).join("")
	end
end

analyzer = SQLSingleCardAnalyzer.new
Analyzer.push analyzer
Analyzer.api.push "get", "/analyze/single" do
	content = analyzer.query_summary.to_json
	content_type 'application/json'
	content
end

Analyzer.api.push "get", "/analyze/single/type" do
	type     = params["type"] || ""
	category = params["category"] || ""
	source   = params["source"] || ""

	content = analyzer.query_child type, source, category
	content = content.to_json
	content_type 'application/json'
	content
end

Analyzer.api.push "get", "/analyze/single/card" do
	type = params["type"] || ""
	time = params["time"]
	card = params["card"] || 0

	content = analyzer.query_card card, type, time
	content = content.to_json
	content_type 'application/json'
	content
end
