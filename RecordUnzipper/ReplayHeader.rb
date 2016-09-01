class ReplayHeader
    attr_accessor :id
    attr_accessor :version
    attr_accessor :flag
    attr_accessor :seed
    attr_accessor :data_size_raw
    attr_accessor :hash
    attr_accessor :props

    Replay_Compressed = 0x1
    Replay_TAG = 0x2
    Replay_Decoded = 0x4

    def data_size
        return self.data_size_raw[0] + 
            self.data_size_raw[1] * 0x100 + 
            self.data_size_raw[2] * 0x10000 + 
            self.data_size_raw[3] * 0x1000000
    end
    
    def isTAG
        return self.flag & Replay_TAG > 0
    end

    def isCompressed
        return self.flag & Replay_Compressed > 0
    end

    def to_hash
        {
            id: @id,
            version: @version,
            flag: @flag,
            seed: @seed,
            data_size_raw: @data_size_raw,
            hash: @hash,
            props: @props
        }
    end

    def to_json(*args)
        to_hash().to_json
    end

    def self.from_hash(hash)
        answer = ReplayHeader.new()
        answer.id = hash["id"]
        answer.version = hash["version"]
        answer.flag = hash["flag"]
        answer.seed = hash["seed"]
        answer.data_size_raw = hash["data_size_raw"]
        answer.hash = hash["hash"]
        answer.props = hash["props"]
        answer
    end

    def self.json_create(hash)
        self.from_hash(hash)
    end

    def inspect
        to_hash().inspect
    end

    def json_creatable?
        true
    end
end