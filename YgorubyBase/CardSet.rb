require File.dirname(__FILE__) + "/../Log.rb"
require File.dirname(__FILE__) + "/../Config.rb"
require File.dirname(__FILE__) + "/Card.rb"
require "sqlite3"

class CardSet
	attr_accessor :name
	attr_accessor :origin_name
	attr_accessor :code
	attr_reader :ids

	def initialize(code, name = "", origin_name = "")
		@code        = code
		@name        = name
		@origin_name = origin_name
		load_ids
	end

	def [](card)
		card = card.id unless card.is_a?(Integer)
		ids.include? card
	end

	SqlQuerySet    = "select id from datas where (setcode & 0x0000000000000FFF == %s or setcode & 0x000000000FFF0000 == %s or setcode & 0x00000FFF00000000 == %s or setcode & 0x0FFF000000000000 == %s)"
	SqlQuerySubSet = "select id from datas where (setcode & 0x000000000000FFFF == %s or setcode & 0x00000000FFFF0000 == %s or setcode & 0x0000FFFF00000000 == %s or setcode & 0xFFFF000000000000 == %s)"

	def load_ids
		CardSet.load_sql if @@database == nil
		sql_query = (code <= 0xFF ? SqlQuerySet : SqlQuerySubSet)
		query     = sprintf sql_query, @code, @code << 16, @code << 32, @code << 48
		answer    = @@database.execute query
		@ids = answer.map { |id| id[0] }
		answer.count
	end

	Reg = /\!setname(\s+)(0x([0-9a-f])*)(\s+)(\S+)((\s+)(\S+)){0,1}/

	def self.load_line(line)
		line.strip!
		return nil if line.start_with? "#"
		matches = line.scan Reg
		matches.map do |match|
			code        = eval(match[1])
			name        = match[4]
			origin_name = match[7]
			origin_name = "" if origin_name.nil?
			set = CardSet.new code, name, origin_name
			logger.info "loaded set #{name} with #{set.ids.count} proper cards."
			set
		end
	end

	def to_s
		"[#{@code}]#{name}" + (@ids.nil? ? "" : "(#{@ids.count})")
	end

	def self.load_lines(file)
		until file.eof
			line = file.readline
			break if line.strip.start_with? "!setname"
		end
		until file.eof
			line        = file.readline
			sets        = load_line line
			@@card_sets += sets unless sets.nil?
		end
	end

	def self.initialize
		begin
			@@card_sets.clear
			file_path = $config["Strings"]
			file      = File.open file_path
			CardSet.load_lines file
			file.close
		rescue => ex
			logger.error "Failed to load conf file #{file_path}, for:"
			logger.error ex
		end
	end

	@@card_sets = []

	def self.[](id)
		return CardSet.search_set(id) if id.is_a? String
		@@card_sets[id]
	end

	def self.search_set(name)
		sets = @@card_sets.select { |set| set.name == (name) or set.origin_name == (name) }
		if sets == []
			logger.warn "Can't find set named #{name}"
			return nil
		end
		if sets.size > 1
			logger.warn "More then one set named #{name}"
		end
		return sets[0]
	end

	@@database = nil

	def self.load_sql
		@@database = Card.database
	end
end

CardSet.initialize