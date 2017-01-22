Thread.abort_on_exception = true
require File.dirname(__FILE__) + '/Analyzers/Analyzer.rb'
require File.dirname(__FILE__) + '/Plugins/Plugin.rb'
Analyzer.autoload
Plugin.autoload

require File.dirname(__FILE__) + '/Outputs/Server/Main.rb'

Outputs::SinatraServer.require_apis Analyzer.api
Outputs::SinatraServer.require_apis Plugin.api
Outputs::SinatraServer.start!