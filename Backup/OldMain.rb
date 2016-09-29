require "#{File.dirname __FILE__}/RecordUnzipper/Unzipper.rb"
require "#{File.dirname __FILE__}/RecordAnalyzer/Analyzer.rb"
# select your analyzers here
require "#{File.dirname __FILE__}/RecordAnalyzer/SQLSingleCardAnalyzer.rb"
# generator
require "#{File.dirname __FILE__}/HTMLGenerator/HTMLGenerator.rb"

module Main
	def self.analyze_deck(deck_path)
		begin
			deck = Deck.load_ydk deck_path
			puts "Analyzing deck #{deck_path}"
			Analyzer.analyze deck
		rescue => exception
			puts "Failed to analyze deck #{deck_path} for"
			puts exception
		end
	end

	def self.analyze_decks(folder)
		path = File.join(folder, "*.ydk")
		puts "analyzing folder #{path}"
		files = Dir.glob path
		files.each { |file| Main.analyze_deck file }
		puts "finish analyzing #{folder} for #{files.count} ydks"
	end

	def self.analyze_replay(replay_path)
		begin
			replay = Unzipper.open_file replay_path
			puts "Analyzing replay #{replay_path}"
			Analyzer.analyze replay
		rescue => exception
			puts "Failed to analyze replay #{replay_path} for"
			puts exception
		end
	end

	def self.analyze_replays(folder)
		path = File.join(folder, "*.yrp")
		puts "analyzing folder #{path}"
		files = Dir.glob path
		files.each { |file| Main.analyze_replay file }
		puts "finish analyzing #{folder} for #{files.count} yrps"
	end

	def self.clear(*args)
		puts "cleared analyzer with #{args.size} args"
		Analyzer.clear *args
	end

	def self.output(*args)
		puts "outputing datas with #{args.size} args"
		Analyzer.output *args
	end

	def self.finish
		puts "temp data pushed"
		Analyzer.finish
	end

	def self.generate
		puts "generating html"
		HTMLGenerator.generate
	end

	# 指令
	# D analyze_decks
	# d analyze_deck
	# R analyze_replays
	# r analyze_replay
	# C/c clear
	# O/o output
	# G/g generate
	# F/f finish
	def self.execute_commands(command_str)
		commands = command_str.scan /(([A-Za-z])(\((.*?)\)){0,})/
		for command in commands
			command_name = command[1]
			command_args = command[3] == nil ? nil : command[3].split(',')
			case command_name
				when 'D'
					self.analyze_decks command_args[0] if command_args != nil and command_args.size > 0
				when 'd'
					self.analyze_deck command_args[0] if command_args != nil and command_args.size > 0
				when 'R'
					self.analyze_replays command_args[0] if command_args != nil and command_args.size > 0
				when 'r'
					self.analyze_replay command_args[0] if command_args != nil and command_args.size > 0
				when 'C', 'c'
					self.clear *command_args
				when 'O', 'o'
					self.output *command_args
				when 'G', 'g'
					self.generate
				when 'F', 'f'
					self.finish
			end
		end
	end
end

ARGV.each { |commands| Main.execute_commands commands }