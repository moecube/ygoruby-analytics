require File.dirname(__FILE__) + '/../Log.rb'
require File.dirname(__FILE__) + '/../Config.rb'
require File.dirname(__FILE__) + '/Card.rb'
require 'sqlite3'

class CardSet
	attr_accessor :name
	attr_accessor :origin_name
	attr_accessor :code
	attr_accessor :ids
	
	def initialize(code, name = '', origin_name = '')
		@code        = code
		@name        = name
		@origin_name = origin_name
		load_ids
	end
	
	def [](card)
		card = card.id unless card.is_a?(Integer)
		ids.include? card
	end
	
	SqlQuerySet    = 'select id from datas where (setcode & 0x0000000000000FFF == %s or setcode & 0x000000000FFF0000 == %s or setcode & 0x00000FFF00000000 == %s or setcode & 0x0FFF000000000000 == %s)'
	SqlQuerySubSet = 'select id from datas where (setcode & 0x000000000000FFFF == %s or setcode & 0x00000000FFFF0000 == %s or setcode & 0x0000FFFF00000000 == %s or setcode & 0xFFFF000000000000 == %s)'
	
	def load_ids
		CardSet.load_sql if @@database == nil
		sql_query = (code <= 0xFF ? SqlQuerySet : SqlQuerySubSet)
		query     = sprintf sql_query, @code, @code << 16, @code << 32, @code << 48
		answer    = @@database.execute query
		@ids      = answer.map { |id| id[0] }
		answer.count
	end
	
	def to_s
		"[#{@code}]#{@name}" + (@ids.nil? ? '' : " (#{@ids.count} cards)")
	end
	
	def to_hash
		{
				name:        @name,
				origin_name: @origin_name,
				code:        @code,
				ids:         @ids
		}
	end
	
	def to_json
		to_hash().to_json
	end
	
	def self.from_hash(hash_set, environment = nil)
		set             = CardSet.allocate
		set.name        = hash_set['name']
		set.origin_name = hash_set['origin_name']
		set.ids         = hash_set['ids']
		set.name        = 'unnamed' if set.name == nil
		set.origin_name = 'unnamed' if set.origin_name == nil
		set.ids         = [] if set.ids == nil
		set.ids.map! do |id|
			if id.is_a? Integer
				id
			elsif id.is_a? Hash and environment != nil
				inner_set = environment.search_set id['name']
				if inner_set != nil
					inner_set.ids
				else
					-1
				end
			else
				-1
			end
		end
		set.ids.flatten!
		if set.ids.count == 0 or set.name == 'unnamed'
			logger.warn 'loaded a set with no name or no cards in.'
		else
			logger.info "loaded USER DEFINED set with hash named #{set.name} with #{set.ids.count} cards."
		end
		set
	end
	
	Reg              = /\!setname(\s+)(0x([0-9a-f])*)(\s+)(.+?)(\t(.+)){0,1}$/
	@@database       = nil
	@@last_file_sets = nil
	
	def self.load_line(line)
		line.strip!
		return nil if line.start_with? '#'
		matches = line.scan Reg
		matches.map do |match|
			code        = eval(match[1])
			name        = match[4]
			origin_name = match[6]
			origin_name = '' if origin_name.nil?
			set         = CardSet.new code, name, origin_name
			logger.info "loaded set #{name} with #{set.ids.count} proper cards."
			set
		end
	end
	
	def self.load_lines(file)
		until file.eof
			line = file.readline
			break if line.strip.start_with? '!setname' or line.strip.start_with? '#setnames'
		end
		sets = []
		until file.eof
			line = file.readline
			set = load_line line
			sets += set if set != nil
		end
		sets
	end
	
	def self.load_file_sets
		if @@last_file_sets != nil
			logger.info "Loaded file #{@@last_file_sets.count} sets from cache."
			return @@last_file_sets
		end
		begin
			file_path = $config['YgorubyBase.Strings.zh-CN']
			file      = File.open file_path
			sets      = CardSet.load_lines file
			file.close
			@@last_file_sets = sets
			return sets
		rescue => ex
			logger.error "Failed to load conf file #{file_path}, for:"
			logger.error ex
		end
	end
	
	def self.load_sql
		@@database = Card.database
	end
end

class CardSet
	SqlNameSet = 'select id from texts where name like \'%%%s%%\''
	
	def self.extra_set(name)
		set             = CardSet.allocate
		set.name        = name
		set.code        = ''
		set.origin_name = ''
		set.load_named_ids name
		set = nil if set.ids.count == 0
		set
	end
	
	def load_named_ids(name)
		CardSet.load_sql if @@database == nil
		query  = sprintf SqlNameSet, name
		answer = @@database.execute query
		@ids   = answer.map { |id| id[0] }
		if @ids.count == 0
			logger.warn "no card named with #{name}"
		else
			logger.info "created EXTRA set #{name} with #{@ids.count} proper cards."
		end
		answer.count
	end
end

class CardSets
	@@set_environments = { }
	
	def self.initialize
		@@set_environments[:global] = CardSets.new
	end
	
	def initialize
		@card_sets  = CardSet.load_file_sets
		@extra_sets = []
		@user_sets  = []
	end
	
	def [](id)
		return search_set(id) if id.is_a? String
		@card_sets[id]
	end
	
	def search_set(name)
		sets = @card_sets.select { |set| set.name == (name) or set.origin_name == (name) or set.code.to_s == (name) }
		sets += @extra_sets.select { |set| set.name == (name) or set.origin_name == (name) or set.code.to_s == (name) }
		sets += @user_sets.select { |set| set.name == (name) or set.origin_name == (name) or set.code.to_s == (name) }
		set  = sets[0]
		if set == nil
			set = CardSet.extra_set name
			@extra_sets.push set if set != nil
		end
		if set == nil
			logger.warn "Can't find set named #{name} and no card named like it."
			return nil
		end
		if sets.size > 1
			logger.warn "More than one set named #{name}"
		end
		return set
	end
	
	def create_set(hash)
		CardSet.from_hash hash, self
	end
	
	def define_set(set)
		@user_sets.push set if set != nil
	end
	
	def clear_extra
		@extra_sets.clear
		@user_sets.clear
	end
	
	class << self
		def [](index)
			index = index.to_sym if index.is_a? String
			@@set_environments[index]
		end
		
		def []=(index, value)
			index = index.to_sym if index.is_a? String
			@@set_environments[index] = value
		end
		
		alias old_mm method_missing
		
		def method_missing(name, *args, &block)
			if @@set_environments.include? name.to_sym
				return @@set_environments[name.to_sym]
			else
				old_mm name, *args, &block
			end
		end
	end
end

CardSets.initialize