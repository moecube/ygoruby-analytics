require 'sqlite3'
require "#{File.dirname(__FILE__)}/../Config.rb"

class Card
	@@cards = {}
	@@datas = nil

	def self.query(id)
		if @@cards[id] == nil
			card = Card.new(id)
			return card.effective ? card : nil
		else
			return @@cards[id]
		end
	end

	def self.queryname(name)
		card_data = self.search_named_card name
		return nil if card_data == nil
		self.query card_data[0]
	end

	def self.[](id)
		if id.is_a? Integer
			return self.query id
		elsif id.is_a? String
			return self.queryname id
		else
			logger.error "Unknown card query request #{id}"
			return nil
		end
	end


	def self.open_database
		@@database = SQLite3::Database.new $config["CardDatabase"]
	end

	def self.database
		self.open_database if !defined? @@database
		@@database
	end

	def self.execute_command(command)
		self.open_database if !defined? @@database
		@@database.execute command
	end

	RACE_WARRIOR       = 1
	RACE_SPELLCASTER   = 2
	RACE_FAIRY         = 4
	RACE_FIEND         = 8
	RACE_ZOMBIE        = 16
	RACE_MACHINE       = 32
	RACE_AQUA          = 64
	RACE_PYRO          = 128
	RACE_ROCK          = 256
	RACE_WINDBEAST     = 512
	RACE_PLANT         = 1024
	RACE_INSECT        = 2048
	RACE_THUNDER       = 4096
	RACE_DRAGON        = 8192
	RACE_BEAST         = 16384
	RACE_BEASTWARRIOR  = 32768
	RACE_DINOSAUR      = 65536
	RACE_FISH          = 131072
	RACE_SEASERPENT    = 262144
	RACE_REPTILE       = 524288
	RACE_PSYCHO        = 1048576
	RACE_DEVINE        = 2097152
	RACE_CREATORGOD    = 4194304
	RACE_PHANTOMDRAGON = 8388608

	@@race_texts = {
			"warrior"       => "战士",
			"spellcaster"   => "魔法使",
			"fairy"         => "天使",
			"fiend"         => "恶魔",
			"zombie"        => "不死",
			"machine"       => "机械",
			"aqua"          => "水",
			"pyro"          => "炎",
			"rock"          => "岩石",
			"windbeast"     => "鸟兽",
			"plant"         => "植物",
			"insect"        => "昆虫",
			"thunder"       => "雷",
			"dragon"        => "龙",
			"beast"         => "兽",
			"beastwarrior"  => "兽战士",
			"dinosaur"      => "恐龙",
			"fish"          => "鱼",
			"seaserpent"    => "海龙",
			"reptile"       => "爬行类",
			"psycho"        => "念动力",
			"devine"        => "幻兽神",
			"creatorgod"    => "创世神",
			"phantomdragon" => "幻龙"
	}

	def self.is_race?(race, race_name)
		race_name = "RACE_" + race_name.upcase
		return false if !const_defined? race_name
		race & eval(race_name) > 0
	end

	@@race_texts.keys.each do |race_name|
		self.class.send :define_method, "is_race_#{race_name}?".to_sym, Proc.new { |race| Card.is_race?(race, race_name) }
	end

	def self.race_str(race)
		@@race_texts.keys.each do |race_name|
			return @@race_texts[race_name] + "族" if self.class.send "is_race_#{race_name}?".to_sym, race
		end
		"神秘种族"
	end

	ATTRIBUTE_EARTH  = 1
	ATTRIBUTE_WATER  = 2
	ATTRIBUTE_FIRE   = 4
	ATTRIBUTE_WIND   = 8
	ATTRIBUTE_LIGHT  = 16
	ATTRIBUTE_DARK   = 32
	ATTRIBUTE_DEVINE = 64

	@@attribute_texts = {
			"earth"  => "地",
			"water"  => "水",
			"fire"   => "火",
			"wind"   => "风",
			"light"  => "光",
			"dark"   => "暗",
			"devine" => "神"
	}

	def self.is_attribute?(attribute, attribute_name)
		attribute_name = "ATTRIBUTE_" + attribute_name.upcase
		return false if !const_defined? attribute_name
		attribute & eval(attribute_name) > 0
	end

	@@attribute_texts.keys.each do |attribute_name|
		self.class.send :define_method, "is_attribute_#{attribute_name}?".to_sym, Proc.new { |attribute| Card.is_attribute?(attribute, attribute_name) }
	end

	def self.attribute_str(attribute)
		@@attribute_texts.keys.each do |attribute_name|
			return @@attribute_texts[attribute_name] if self.class.send "is_attribute_#{attribute_name}?".to_sym, attribute
		end
		"神秘属性"
	end

	TYPE_MONSTER     = 1
	TYPE_SPELL       = 2
	TYPE_TRAP        = 4
	TYPE_NORMAL      = 16
	TYPE_EFFECT      = 32
	TYPE_FUSION      = 64
	TYPE_RITUAL      = 128
	TYPE_TRAPMONSTER = 256
	TYPE_SPIRIT      = 512
	TYPE_UNION       = 1024
	TYPE_DUAL        = 2048
	TYPE_TUNER       = 4096
	TYPE_SYNCHRO     = 8192
	TYPE_TOKEN       = 16384
	TYPE_QUICKPLAY   = 65536
	TYPE_CONTINUOUS  = 131072
	TYPE_EQUIP       = 262144
	TYPE_FIELD       = 524288
	TYPE_COUNTER     = 1048576
	TYPE_FLIP        = 2097152
	TYPE_TOON        = 4194304
	TYPE_XYZ         = 8388608
	TYPE_PENDULUM    = 16777216

	@@main_type_texts = {
			"monster" => "怪兽",
			"spell"   => "魔法",
			"trap"    => "陷阱"
	}

	@@assistant_type_texts = {
			"normal"      => "通常",
			"fusion"      => "融合",
			"ritual"      => "仪式",
			"trapmonster" => "陷阱怪兽",
			"synchro"     => "同调",
			"token"       => "衍生物",
			"quickplay"   => "速攻",
			"continuous"  => "永续",
			"equip"       => "装备",
			"field"       => "场地",
			"counter"     => "反击",
			"xyz"         => "XYZ",
			"pendulum"    => "灵摆",
			"effect"      => "效果"
	}

	@@sub_type_texts = {
			"effect"   => "效果",
			"synchro"  => "同调",
			"xyz"      => "XYZ",
			"fusion"   => "融合",
			"ritual"   => "仪式",
			"pendulum" => "灵摆",

			"spirit"   => "灵魂",
			"union"    => "同盟",
			"dual"     => "二重",
			"tuner"    => "调整",
			"flip"     => "反转",
			"toon"     => "卡通"
	}

	def self.is_type?(type, type_name)
		type_name = "TYPE_" + type_name.upcase
		return false if !const_defined? type_name
		type & eval(type_name) > 0
	end

	@@types = @@main_type_texts.keys | @@assistant_type_texts.keys | @@sub_type_texts.keys
	@@types.each do |type_name|
		self.class.send :define_method, "is_#{type_name}?".to_sym, Proc.new { |type| Card.is_type?(type, type_name) }
	end

	def is_ex?
		is_synchro? or is_xyz? or is_fusion?
	end

	def self.type_str(type)
		sub_type_str  = self.sub_type_str type
		main_type_str = self.main_type_str type
		main_type_str + (sub_type_str.length == 0 ? "" : "|") + sub_type_str
	end

	def self.main_type_str(type)
		@@main_type_texts.keys.each do |type_name|
			return @@main_type_texts[type_name] if self.class.send "is_#{type_name}?".to_sym, type
		end
		"卡片"
	end

	def self.assistant_type_str(type)
		@@assistant_type_texts.keys.each do |type_name|
			return @@assistant_type_texts[type_name] if self.class.send "is_#{type_name}?".to_sym, type
		end
		""
	end

	def self.main_type_desc(type)
		assistant_type_str = self.assistant_type_str(type)
		(assistant_type_str.length == 0 ? "通常" : assistant_type_str) + self.main_type_str(type)
	end

	def self.sub_type_str(type)
		sub_type_text = []
		@@sub_type_texts.keys.each do |type_name|
			sub_type_text.push @@sub_type_texts[type_name] if self.class.send "is_#{type_name}?".to_sym, type
		end
		sub_type_text.join "|"
	end

	def self.atk_str(atk)
		return "∞" if atk == -2
		atk.to_s
	end

	def self.level_str(card)
		card.is_xyz? ? "[☆#{card.level}]" : "[★#{card.level}]"
	end

	attr_accessor :name, :desc
	attr_accessor :id, :ot, :alias, :setcode, :type, :atk, :def, :level, :race, :attribute, :category
	attr_accessor :left_scale, :right_scale
	attr_accessor :effective

	def initialize(id)
		@@cards[id] = self
		data = read_sqlite_data(id)
		data = [id, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, "神秘卡片#{id}", "SECRET"] if data == nil
		set_data data
		@effective  = true
		@@cards[id] = self
	end

	QueryCommand         = "select * from datas, texts on datas.id == texts.id where datas.id == %s;"
	NameQueryCommand     = "select * from datas, texts on datas.id == texts.id where texts.name == '%s'"
	NameLikeQueryCommand = "select * from datas, texts on datas.id == texts.id where texts.name like '%%%s%%'"
	AliasQueryCommand    = "select id, alias from datas where alias > 0"
	PendulumMagicNumber  = 256

	def read_sqlite_data(id)
		command = sprintf QueryCommand, id
		answer  = Card.execute_command command
		if answer.length == 0
			logger.warn "No card id [#{id}]"
			return nil
		end
		return answer[0]
	end

	def self.search_named_card(name)
		# Exact query first
		command = sprintf NameQueryCommand, name
		answer  = Card.execute_command command
		# alias check
		answer = answer.select { |card_data| card_data[2] == 0 }
		return answer[0] if answer.count > 0
		# Then do other
		command = sprintf NameLikeQueryCommand, name
		answer = Card.execute_command command
		# again alias check
		answer = answer.select { |card_data| card_data[2] == 0 }
		if answer.count == 0
			logger.warn "No card named #{name}"
			return nil
		end
		if answer.count > 1
			logger.warn "#{answer.count} Cards named like #{name}."
		end
		logger.info "Name [#{name}] is searched for #{answer[0][12]}"
		return answer[0]
	end

	def set_data(data)
		@id          = data[0]
		@ot          = data[1]
		@alias       = data[2]
		@setcode     = data[3]
		@type        = data[4]
		@atk         = data[5]
		@def         = data[6]
		@level       = data[7] % PendulumMagicNumber
		@left_scale  = (data[7] / (PendulumMagicNumber ** 2)) % PendulumMagicNumber
		@right_scale = data[7] / (PendulumMagicNumber ** 3)
		@race        = data[8]
		@attribute   = data[9]
		@category    = data[10]
		@name        = data[12]
		@desc        = data[13]
	end

	@@types.each do |type_name|
		define_method "is_#{type_name}?".to_sym, Proc.new { self.class.send "is_#{type_name}?".to_sym, self.type }
	end

	@@race_texts.keys.each do |race_name|
		define_method "is_race_#{race_name}?".to_sym, Proc.new { self.class.send "is_race_#{race_name}?".to_sym, self.race }
	end

	@@attribute_texts.keys.each do |attribute_name|
		define_method "is_attribute_#{attribute_name}?".to_sym, Proc.new { self.class.send "is_attribute_#{attribute_name}?".to_sym, self.attribute }
	end

	def main_type_desc
		Card.main_type_desc self.type
	end

	def main_type_str
		Card.main_type self.type
	end

	def race_str
		Card.race_str self.race
	end

	def attribute_str
		Card.attribute_str self.attribute
	end

	def to_hash
		{
				id:          @id,
				ot:          @ot,
				alias:       @alias,
				setcode:     @setcode,
				type:        @type,
				atk:         @atk,
				def:         @def,
				level:       @level,
				left_scale:  @left_scale,
				right_scale: @right_scale,
				race:        @race,
				attribute:   @attribute,
				category:    @category,
				name:        @name,
				desc:        @desc
		}
	end

	def to_json(*args)
		to_hash().to_json
	end

	def inspect
		to_hash().inspect
	end

	def to_s
		if is_monster?
			line0 = "#{@name}[#{@id}]"
			line1 = "[#{Card.type_str @type}] #{Card.race_str @race}/#{Card.attribute_str @attribute}"
			line2 = "#{Card.level_str self} #{Card.atk_str @atk}/#{Card.atk_str @def}" + (is_pendulum? ? "\t#{@left_scale}/#{@right_scale}" : "")
			return [line0, line1, line2, @desc].join "\n"
		else
			line0 = "#{@name}[#{@id}]"
			line1 = "[#{Card.type_str @type}]"
			return [line0, line1, @desc].join "\n"
		end
	end

	def from_hash(hash)
		@id          = hash["id"]
		@ot          = hash["ot"]
		@alias       = hash["alias"]
		@setcode     = hash["setcode"]
		@type        = hash["type"]
		@atk         = hash["atk"]
		@def         = hash["def"]
		@level       = hash["level"]
		@left_scale  = hash["left_scale"]
		@right_scale = hash["right_scale"]
		@race        = hash["race"]
		@attribute   = hash["attribute"]
		@category    = hash["category"]
		@name        = hash["name"]
		@desc        = hash["desc"]
	end

	def self.load_alias_list
		aliases = execute_command AliasQueryCommand
		hash    = {}
		aliases.each do |group|
			hash[group[0]] = group[1] if (group[1] - group[0]).abs < 40
		end
		@@alias_list = hash
	end

	def self.alias_list
		self.load_alias_list unless class_variable_defined?("@@alias_list")
		@@alias_list
	end
end