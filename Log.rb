unless defined? Log and Log.is_a? Class
	require 'better-logger'
	
	# Multiway output change for Better::Logger
	module Better
		module Logger
			class Logger
				def _log io, level, msg
					@hooks.values.each { |hook| hook.log(level, msg) } if @hooks != nil
					# It's a stupid makeup. But it's only way to avoid override number 4 in _format
					io = [io] unless io.is_a? Array
					io[0].puts _format(msg, level) if _should_log? level
					return if io.length == 1
					io[1].puts _format(msg, level) if _should_log? level
				end
			end
			
			class Config
				alias old_set_log_to log_to=
				
				def log_to=(value)
					if value.is_a? Array
						@log_to = value.map { |new_log_to| old_set_log_to(new_log_to); @log_to }
					else
						old_set_log_to value
					end
				end
				
				alias old_set_error_to error_to=
				
				def error_to=(value)
					if value.is_a? Array
						@error_to = value.map { |new_error_to| old_set_error_to(new_error_to); @error_to }
					else
						old_set_error_to value
					end
				end
			end
		end
	end
	
	
	class Better::Logger::Logger
		class Hook
			attr_accessor :name
			attr_accessor :level
			attr_accessor :content
			
			def initialize(name, level = 0)
				@name    = name
				@content = ''
				@level   = level
				@level   = Better::Logger::LEVELS[level] if @level.is_a? Symbol
			end
			
			def log(level, content)
				@content += "\n[#{level}] #{content}" if Better::Logger::LEVELS[level] >= @level
			end
		end
		
		attr_accessor :hooks
		alias old_initialize initialize
		
		def initialize(*args)
			old_initialize *args
			@hooks = {}
		end
		
		alias old_mm method_missing
		
		def method_missing(name, *args, &block)
			if @hooks != nil and @hooks.include? name
				resolve name
			else
				old_mm name, *args, &block
			end
		end
		
		def hang(hook_name, level = 0)
			hook_name         = hook_name.to_sym if hook_name.is_a? String
			@hooks[hook_name] = Hook.new hook_name, level
		end
		
		def resolve(hook_name)
			hook_name = hook_name.to_sym if hook_name.is_a? String
			if @hooks == nil or not @hooks.include? hook_name
				logger.warn "Can't find hook named #{hook_name}"
				return ''
			end
			hook = @hooks[hook_name]
			@hooks.delete hook_name
			hook.content
		end
	end
	
	module Log
		def self.initialize_better_logger
			Better::Logger.config :logger do |conf|
				conf.color    = true
				conf.log_to   = [STDOUT, 'log_output.log']
				conf.error_to = [STDERR, 'log_error.log']
				conf.log_level= :info
			end
		end
	end
	
	Log.initialize_better_logger
	
	def base_logger
		Better::Logger::Loggers._log_hash[:logger]
	end
end