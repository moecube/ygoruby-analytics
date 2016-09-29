require File.dirname(__FILE__) + "/../Helper.rb"

module Ygoruby
	module Plugins
		@@apis = APIs.new
		def self.api
			return @@apis
		end
	end
end