require "#{File.dirname __FILE__}/../Log.rb"
require "#{File.dirname __FILE__}/../YgorubyBase/Deck.rb"
require "#{File.dirname __FILE__}/../YgorubyBase/Unzipper.rb"

module Analyzer
	def self.analyze_folder(folder_path, *args)
		file_paths = Dir.glob File.join folder_path, "*.*"
		logger.info "Analyzing folder #{folder_path}, #{file_paths.count} Files globbed."
		for file_path in file_paths
			extname = File.extname file_path
			case extname
				when ".ydk"
					Analyzer.analyze(Deck.load_ydk(file_path), *args)
					logger.debug "Analyzing deck file #{file_path}"
				when ".yrp"
					Analyzer.analyze(Unzipper.open_file(file_path), *args)
					logger.debug "Analyzing replay file #{file_path}"
				else
					logger.warn "Unrecognized analyzing file #{file_path}"
			end
		end
	end
end