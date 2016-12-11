require "#{File.dirname __FILE__}/AnalyzerBase.rb"
require "#{File.dirname __FILE__}/AnalyzerHelp.rb"
require "#{File.dirname __FILE__}/../Log.rb"
require "#{File.dirname __FILE__}/../Helper.rb"
require "#{File.dirname __FILE__}/../YgorubyBase/Deck.rb"

module Analyzer
	@@analyzers = {}
	
	def self.push(analyzer)
		@@analyzers[analyzer.class] = analyzer if analyzer.is_a? AnalyzerBase
	end
	
	def self.analyze(data_array, *args)
		data_array = [data_array] unless data_array.is_a? Array
		for data in data_array
			@@analyzers.values.each { |analyzer| analyzer.analyze data, *args }
		end
	end
	
	def self.output(*args)
		@@analyzers.values.each { |analyzer| analyzer.output(*args) }
	end
	
	def self.clear(*args)
		@@analyzers.values.each { |analyzer| analyzer.clear(*args) }
	end
	
	def self.finish(*args)
		@@analyzers.values.each { |analyzer| analyzer.finish(*args) }
	end
	
	def self.heartbeat(*args)
		@@analyzers.values.each { |analyzer| analyzer.heartbeat(*args) }
	end
	
	def self.[](index)
		return @@analyzers[index]
	end
	
	def self.autoload
		require "#{File.dirname __FILE__}/../Config.rb"
		require "#{File.dirname __FILE__}/../Log.rb"
		@@config = $config[__FILE__]
		return if @@config.nil?
		keys = @@config
		keys.each { |name| self.push_analyzer_by_name name }
	end
	
	def self.push_analyzer_by_name(str)
		return if str.start_with? "#"
		path = File.join File.dirname(__FILE__), "#{str}.rb"
		if File.exist? path
			logger.info "loaded analyzer #{str} from #{path}"
			require path
		else
			logger.warn "Failed to load analyzer #{str}"
		end
	end
	
	
	@@apis = APIs.new
	
	def self.api
		@@apis
	end
	
	Analyzer.api.push "post", "/analyze/deck" do
		call! env.merge("PATH_INFO" => "/analyze/deck/file")
	end
	
	Analyzer.api.push "post", "/analyze/deck/json" do
		request.body.rewind
		require 'json'
		require "#{File.dirname __FILE__}/../YgorubyBase/Deck.rb"
		request_payload = JSON.parse request.body.read
		Analyzer.analyze Deck.from_hash request_payload
		"Deck read"
	end
	
	Analyzer.api.push "post", "/analyze/deck/file" do
		if request.body.length > 3072
			[413, {}, "Too big file"]
		elsif !(Outputs.authorize_check params)
			logger.warn "refused Analyzer file post."
			[401, {}, "not correct access key."]
		else
			request.body.rewind
			source = params["source"]
			Analyzer.analyze Deck.load_ydk_str(request.body.read), source: source
			"Deck read"
		end
	end
	
	Analyzer.api.push "post", "/analyze/deck/text" do
		# Temporary set for mercury 233
		if request.body.length > 8192
			[413, {}, "Too big file"]
		elsif !(Outputs.authorize_check params)
			logger.warn "refused Analyzer text post."
			[401, {}, "not correct access key."]
		else
			source       = params["arena"]
			deck_content = params["deck"]
			Analyzer.analyze Deck.load_ydk_str(deck_content), source: source
			"Deck read"
		end
	end
	
	Analyzer.api.push "post", "/analyze/record" do
		[501, {}, "not supported now"]
	end
	
	Analyzer.api.push "post", "/analyze/tar" do
		[501, {}, "not supported now"]
	end
	
	Analyzer.api.push "post", "/analyze/finish" do
		if false#!(Outputs.authorize_check params)
			logger.warn "refused Analyzer finish post."
			[401, {}, "not correct access key."]
		else
			logger.info "Received finish request."
			time = params["time"]
			Analyzer.finish time
			logger.info "Finished from http request."
			[200, {}, "Finished"]
		end
	end
	
	Analyzer.api.push "delete", "/analyze" do
		if !(Outputs.authorize_check params)
			logger.warn "refused Analyzer delete post."
			[401, {}, "not correct access key."]
		else
			logger.info "Received clear request."
			time = params["time"]
			Analyzer.clear time
			logger.info "Cleared from http request."
			"Cleared"
		end
	end
	
	Analyzer.api.push "get", "/analyze/heartbeat" do
		if !(Outputs.authorize_check params)
			logger.warn "refused Analyzer text post."
			[401, {}, "not correct access key."]
		else
			logger.info "Received heartbeat."
			time = params["time"]
			time = Time.now if time == nil
			if $analyzer_heartbeat_thread == nil
				$analyzer_heartbeat_thread = Thread.new do
					Analyzer.heartbeat time
					$analyzer_heartbeat_thread = nil
					logger.info "Heart beat finished."
				end
				"Beating."
			else
				logger.fatal "Heartbeat thread doesn't work fine. Killed."
				Thread.kill $analyzer_heartbeat_thread
				$analyzer_heartbeat_thread = nil
				[403, {}, "A heart is beating. Killed it."]
			end
		end
	end
end