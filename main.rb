Thread.abort_on_exception = true
require File.dirname(__FILE__) + '/Analyzers/Analyzer.rb'
require File.dirname(__FILE__) + '/Plugins/Plugin.rb'
Analyzer.autoload
Plugin.autoload

require File.dirname(__FILE__) + '/Outputs/Server/Main.rb'

# 预输出
begin
  Thread.new { Analyzer.output(Time.now - 86400) }
rescue => ex
  Thread.fatal 'Failed to pre output.'
  Thread.fatal ex
end

Outputs::SinatraServer.require_apis Analyzer.api
Outputs::SinatraServer.require_apis Plugin.api

logger.info 'Server started on ' + Time.now.strftime('%Y-%m-%d %H:%M:%S')
Outputs::SinatraServer.start!