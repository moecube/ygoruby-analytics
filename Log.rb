unless defined? Log and Log.is_a? Class
	require 'better-logger'

	# Multiway output change for Better::Logger
	module Better
		module Logger
			class Logger
				def _log io, level, msg
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

	module Log
		def self.initialize_better_logger
=begin
			Better::Logger.config :consoleLogger do |conf|
				conf.color     = true
				conf.log_to    = STDOUT
				conf.error_to  = STDERR
				conf.log_level = :info
			end

			Better::Logger.config :fileLogger do |conf|
				conf.color     = true
				conf.log_to    = "log_output.log"
				conf.error_to  = "log_error.log"
				conf.log_level = :info
			end
=end
			Better::Logger.config :logger do |conf|
				conf.color    = true
				conf.log_to   = [STDOUT, "log_output.log"]
				conf.error_to = [STDERR, "log_error.log"]
				conf.log_level= :info
			end

=begin
			def logger.info(*args)
				consoleLogger.info *args
				fileLogger.info *args
			end

			def logger.error(*args)
				consoleLogger.error *args
				fileLogger.error *args
			end

			def logger.warn(*args)
				consoleLogger.warn *args
				fileLogger.warn *args
			end

			def logger.debug(*args)
				consoleLogger.debug *args
				fileLogger.debug *args
			end

			def logger.fatal(*args)
				consoleLogger.fatal *args
				fileLogger.fatal *args
			end
=end
		end
	end

	Log.initialize_better_logger
end