require "#{File.dirname __FILE__}/Analyzers/Analyzer.rb"
Analyzer.autoload

require "#{File.dirname __FILE__}/Outputs/Server/Main.rb"

Outputs::SinatraServer.require_apis Analyzer.api
Outputs::SinatraServer.start!