require 'sinatra'
require 'sinatra/base'
require "#{File.dirname __FILE__}/../../Config.rb"

module Outputs
	
	class SinatraServer < Sinatra::Application
		def self.require_api(api)
			case api[0]
				when "get", "post", "delete"
					__send__ api[0].to_sym, api[1], &api[2]
			end
		end

		def self.require_apis(apis)
			apis.each { |api| self.require_api api }
		end

		def self.define_defaults
			not_found do
				'Not found'
			end

			error 403 do
				'refused'
			end
			
			before do
				logger.level = Logger::INFO
			end
		end

		def self.start!
			self.define_defaults
			run!
		end

		@@config = $config["Outputs.Server"]
		self.port = @@config["Port"].to_i if @@config["Port"] != @@config
		self.bind = @@config["Bind"].to_i if @@config["Bind"] != @@config
	end
end
