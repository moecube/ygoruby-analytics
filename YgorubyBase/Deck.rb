require "#{File.dirname __FILE__}/Card.rb"

class Deck
	attr_accessor :main
	attr_accessor :ex
	attr_accessor :side

	attr_accessor :main_classified
	attr_accessor :ex_classified
	attr_accessor :cards_classified
	attr_accessor :side_classified

	def initialize
		@main = []
		@ex   = []
		@side = []
		@pointer = @main
	end

	def self.from_replay(replay)
		deck      = Deck.new
		deck.main = deck.read_pack replay
		deck.ex   = deck.read_pack replay
		deck.side = []
		deck.classify
		deck
	end

	def read_pack(replay)
		answer = []
		num    = replay.read_int32
		(1..num).each { answer.push replay.read_int32 }
		answer
	end

	def classify
		self.main_classified  = classify_pack self.main
		self.ex_classified    = classify_pack self.ex
		self.side_classified  = classify_pack self.side
		self.cards_classified = classify_pack self.main + self.ex + self.side
	end

	def classify_pack(pack)
		hash = {}
		for card in pack
			if hash[card] == nil
				hash[card] = 1
			else
				hash[card] += 1
			end
		end
		hash
	end

	def separate_ex_from_main
		# experimental
		return if @ex != []
		new_main = []
		new_ex   = []
		@main.each do |card_id|
			card = Card[card_id]
			# TODO: 未知卡的处理
			if card.nil?
				new_main.push card_id
			else
				(card.is_ex? ? new_ex : new_main).push card_id
			end
		end
		@main = new_main
		@ex   = new_ex
	end

	DECKFILE_HEAD      = "created by RecordAnalyser."
	DECKFILE_MAIN_FLAG = "#main"
	DECKFILE_EX_FLAG   = "#extra"
	DECKFILE_SIDE_FLAG = "!side"
	DECKFILE_NEWLINE   = "\n"

	def save_ydk(file_name)
		file = File.open(file_name, "w")
		file.write DECKFILE_HEAD + DECKFILE_NEWLINE
		file.write DECKFILE_MAIN_FLAG + DECKFILE_NEWLINE
		self.main.each { |card| file.write card.to_s + DECKFILE_NEWLINE }
		file.write DECKFILE_EX_FLAG + DECKFILE_NEWLINE
		self.ex.each { |card| file.write card.to_s + DECKFILE_NEWLINE }
		file.write DECKFILE_SIDE_FLAG + DECKFILE_NEWLINE
		self.side.each { |card| file.write card.to_s + DECKFILE_NEWLINE }
		file.close
	end

	def accept_line(line)
		return if line == nil or line == "" or line.start_with? "#"
		if line == DECKFILE_MAIN_FLAG
			@pointer = @main
		elsif line == DECKFILE_EX_FLAG
			@pointer = @ex
		elsif line == DECKFILE_SIDE_FLAG
			@pointer = @side
		else
			@pointer.push line.to_i
		end
	end

	def self.load_ydk(file_path)
		deck = Deck.new
		file = File.open file_path
		while !file.eof?
			line = file.readline.chomp
			deck.accept_line line
		end
		file.close
		deck.separate_ex_from_main
		deck.classify
		deck
	end

	def self.load_ydk_str(str)
		lines = str.split "\n"
		deck = Deck.new
		lines.each { |line| deck.accept_line line }
		deck.separate_ex_from_main
		deck.classify
		deck
	end

	def to_hash
		{
				main: @main,
				side: @side,
				ex:   @ex
		}
	end

	def to_json(*args)
		to_hash().to_json
	end

	def self.from_hash(hash)
		return nil if hash == nil
		answer      = Deck.allocate
		answer.main = hash["main"]
		answer.side = hash["side"]
		answer.ex   = hash["ex"]
		answer.classify
		answer
	end

	def inspect
		to_hash().inspect
	end
end