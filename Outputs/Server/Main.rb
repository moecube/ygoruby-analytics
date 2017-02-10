require 'sinatra'
require 'sinatra/base'
require 'webrick'

require File.join File.dirname(__FILE__), '/../../Config.rb'
require File.join File.dirname(__FILE__), '/LinkStatic.rb'

module Outputs
	
	class SinatraServer < Sinatra::Application
		
		def self.require_api(api)
			case api[0]
				when 'get', 'post', 'delete'
					__send__ api[0].to_sym, api[1], &api[2]
				when 'static'
					use Rack::LinkStatic, :urls => api[1].keys[0], :root => api[1].values[0]
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
			
			# disable default sinatra logs.
			configure do
				disable :logging
				set :server_settings, { Logger: WEBrick::Log.new("/dev/null"), AccessLog: [] }
			end
			
		end
		
		
		def self.start!
			self.define_defaults
			run!
		end
		
		@@config  = $config['Outputs.Server']
		self.port = @@config['Port'].to_i if @@config['Port'] != @@config
		self.bind = @@config['Bind'].to_i if @@config['Bind'] != @@config
	
	end
	
	def self.authorize_check(req)
		key = $config['Access Key']
		return true if key == nil
		user_key = req['accesskey']
		return false if user_key == nil
		key == user_key
	end
end