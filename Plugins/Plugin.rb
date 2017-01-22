require File.dirname(__FILE__) + '/../Helper.rb'
require File.dirname(__FILE__) + '/../Config.rb'

module Plugin
	@@apis = APIs.new
	
	def self.api
		return @@apis
	end
	
	def self.autoload
		@@config = $config[__FILE__]
		return if @@config.nil?
		keys = @@config
		keys.each { |name| require_plugin name }
	end
end