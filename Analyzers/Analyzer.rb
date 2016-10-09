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
			[413, {}, "TOo big file"]
		else
			request.body.rewind
			json = JSON.parse request.body.read
			source = json["arena"]
			deck_content = json["deck"]
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
		logger.info "Finished from http request."
		Analyzer.finish Time.now
		"Finished"
	end

	Analyzer.api.push "delete", "/analyze" do
		logger.info "Cleared from http request."
		Analyzer.clear Time.now
		"Cleared"
	end
end