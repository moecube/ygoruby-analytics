require "#{File.dirname(__FILE__)}/Deck.rb"
require "#{File.dirname(__FILE__)}/ReplayHeader.rb"

class Replay
	attr_accessor :data
	attr_accessor :header
	attr_accessor :pointer

	def initialize(data, header)
		self.data    = data.unpack "C*"
		self.header  = header
		self.pointer = 0
		analyze_data
	end

	def read_data(length)
		data         = self.data[self.pointer, length]
		self.pointer += length
		data
	end

	def read_int8
		data         = self.data[self.pointer]
		self.pointer += 1
		data
	end

	def read_int16
		num = read_int8
		num += read_int8 * 0x100
		num
	end

	def read_int32
		num = read_int8
		num += read_int8 * 0x100
		num += read_int8 * 0x10000
		num += read_int8 * 0x1000000
		num
	end

	def read_next_response
		length = read_int8
		read_data length
	end

	def rewind
		self.pointer = 0
	end

	attr_accessor :host_name
	attr_accessor :client_name
	attr_accessor :start_lp
	attr_accessor :start_hand
	attr_accessor :draw_count
	attr_accessor :opt
	attr_accessor :host_deck
	attr_accessor :client_deck

	# TAG data
	attr_accessor :host_tag_name
	attr_accessor :client_tag_name
	attr_accessor :host_tag_deck
	attr_accessor :client_tag_deck

	# FILE data
	attr_accessor :birth_time
	attr_accessor :file_position

	def analyze_data
		self.host_name       = self.convert_str read_data(40)
		self.host_tag_name   = self.convert_str read_data(40) if header.isTAG
		self.client_tag_name = self.convert_str read_data(40) if header.isTAG
		self.client_name     = self.convert_str read_data(40)

		self.start_lp        = read_int32
		self.start_hand      = read_int32
		self.draw_count      = read_int32
		self.opt             = read_int32
		self.host_deck       = Deck.from_replay self
		self.host_tag_deck   = Deck.from_replay self if header.isTAG
		self.client_tag_deck = Deck.from_replay self if header.isTAG
		self.client_deck     = Deck.from_replay self
	end

	def convert_str(bytes)
		s = bytes.pack "C*"
		s = s.split("\x00\x00").first
		s += "\x00" if s.length % 2 != 0
		s.force_encoding("UTF-16LE").encode("UTF-8")
	end

	def format_time(time)
		return time.strftime "%Y-%m-%d %H-%M-%S"
	end

	def format_names
		"#{self.format_time(self.birth_time)} #{self.host_name} vs #{self.client_name}"
	end

	def decks
		if self.header.isTAG
			return [self.host_deck, self.client_deck, self.host_tag_deck, self.client_tag_deck]
		else
			return [self.host_deck, self.client_deck]
		end
	end

	def to_hash
		{
				# header
				header:          @header,
				# names
				host_name:       @host_name,
				client_name:     @client_name,
				host_tag_name:   @host_tag_name,
				client_tag_name: @client_tag_name,
				# decks
				host_deck:       @host_deck,
				client_deck:     @client_deck,
				host_tag_deck:   @host_tag_deck,
				client_tag_deck: @client_tag_deck,
				# start information
				start_lp:        @start_lp,
				start_hand:      @start_hand,
				draw_count:      @draw_count,
				opt:             @opt,
				# reading stream ignored.
				# file information
				file_position:   @file_position,
				birth_time:      @birth_time.to_i
		}
	end

	def inspect
		to_hash().inspect
	end

	def to_json
		to_hash().to_json
	end

	def self.from_hash(hash)
		answer                 = Replay.allocate
		answer.header          = ReplayHeader.from_hash hash["header"]
		answer.host_name       = hash["host_name"]
		answer.client_name     = hash["client_name"]
		answer.host_tag_name   = hash["host_tag_name"]
		answer.client_tag_name = hash["client_tag_name"]
		answer.host_deck       = Deck.from_hash hash["host_deck"]
		answer.client_deck     = Deck.from_hash hash["client_deck"]
		answer.host_tag_deck   = Deck.from_hash hash["host_tag_deck"]
		answer.client_tag_deck = Deck.from_hash hash["client_tag_deck"]
		answer.start_lp        = hash["start_lp"]
		answer.start_hand      = hash["start_hand"]
		answer.draw_count      = hash["draw_count"]
		answer.opt             = hash["opt"]
		answer.file_position   = hash["file_position"]
		answer.birth_time      = Time.at hash["birth_time"]
		answer
	end

	def self.json_create(hash)
		self.from_hash(hash)
	end

	def json_creatable?
		true
	end
end