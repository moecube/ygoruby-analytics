class AnalyzerBase
	def analyze(record, *args)
		
	end

	def clear(*args)
		
	end

	def output(*args)
		
	end

	def push(*args)

	end
	
	#==============================================
	# draw_time
	#----------------------------------------------
	# helper
	# draw the time argument from *args.
	#==============================================
	def draw_time(*args)
		time = args[0]
		time = Time.now if time == nil
		time = Time.at time if time.is_a? Fixnum
		if time.is_a? String
			time = time.downcase
			if time == 'yesterday'
				time = Time.now - 86400
			elsif time == 'tomorrow'
				time = Time.now + 86400
			elsif time == 'now' or time == 'today'
				time = Time.now
			else
				time = Time.gm *time.split("-")
			end
		end
		if time.is_a? Time
			# do nothing
		elsif time == args[0]
			logger.warn "Unrecognized time arg #{args}. Returned Time.now"
			time = Time.now
		end
		time
	end
end