require 'json'
require File.dirname(__FILE__) + "/Log.rb"

module YgorubyConfig
	def self.load_config
		begin
			file    = File.open File.dirname(__FILE__) + "/Config.json"
			str     = file.read
			$config = JSON.parse str
		rescue => exception
			logger.error 'failed to load config. Message:'
			logger.error exception
			throw exception
		end
		self.define_config_chain $config
	end


	def self.value(path, start = nil)
		# todo: experimental
		path = path.gsub Dir.pwd, "." if path.start_with? Dir.pwd
		path = path.gsub /\.rb$/, ""

		path = path.split /\.|\/|\,|_/
		hash = start.nil? ? $config : start
		for part in path
			next if part == "." or part == ".." or part == ""
			hash = hash.fetch part if hash.has_key? part
			return nil if hash == nil
		end
		self.define_config_chain hash
		hash
	end


	def self.define_config_chain(obj)
		return unless obj.is_a? Hash or obj.is_a? Class or obj.is_a? Module
		obj.define_singleton_method :[] do |path|
			YgorubyConfig.value(path, obj)
		end
		#obj.define_singleton_method :method_missing do |symbol, *args|
		#	YgorubyConfig.value(symbol.to_s, obj)
		#end
	end

	self.define_config_chain YgorubyConfig
end

YgorubyConfig.load_config
