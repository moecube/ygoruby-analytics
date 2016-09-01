require "#{File.dirname __FILE__}/AnalyzerBase.rb"

module Analyzer
    @@analyzers = []
    def self.push(analyzer)
        @@analyzers.push analyzer if analyzer.is_a? AnalyzerBase
    end

    def self.analyze(*args)
        for data in args
            @@analyzers.each {|analyzer| analyzer.analyze data}
        end
    end

    def self.output(*args)
        @@analyzers.each{|analyzer| analyzer.output(*args)}
    end

    def self.clear(*args)
        @@analyzers.each {|analyzer| analyzer.clear(*args)}
    end

    def self.finish
        @@analyzers.each {|analyzer| analyzer.finish}
    end
end