require 'json'

def load_config
    begin
        file = File.open File.dirname(__FILE__) + "/Config.json"
        str = file.read
        $config = JSON.parse str
    rescue => exception
        throw new error 'failed to load config.'
    end
end

load_config