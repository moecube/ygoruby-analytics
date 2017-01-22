module Rack
	class LinkStatic < Static
		def route_file(path)
			return false unless @urls.kind_of? Array
			@urls.each do |url|
				next unless path.index(url) == 0
				path.replace path[url.length - 1 .. -1]
				return true
			end
			return false
		end
	end
end