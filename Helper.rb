require "#{File.dirname __FILE__}/Log.rb"

module Ygoruby
	YgoRubyPluginPath = "./Plugins/"

	def self.require_plugin(name)
		filename = File.join YgoRubyPluginPath, name, "Main.rb"
		if File.exist? filename
			logger.info "required plugin #{name}"
			require filename
		else
			logger.warn "can't find plugin file [#{name}]#{filename}"
		end
	end
end

def require_plugin(name)
	Ygoruby.require_plugin name
end

class APIs
	attr_accessor :apis

	def initialize
		@apis = []
	end
	def push(name, path, &block)
		@apis.push [name, path, block]
	end
	def clear
		@apis.clear
	end
	def each(&block)
		@apis.each &block
	end
end