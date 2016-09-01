require 'lzma'
require "#{File.dirname(__FILE__)}/Replay.rb"

module Unzipper
    def self.open_file(file_path)
        stream = File.open file_path
        header = self.read_record_header stream
        compressed_data = stream.read.force_encoding("utf-16le")
        stream.close
        lzma_file = self.make_lzma_header(header) + compressed_data
        if !(header.isCompressed)
            replay = Replay.new(compressed_data, header)
            replay.file_position = file_path
            replay.birth_time = File.mtime file_path
            return replay
        end
        data = LZMA.decompress lzma_file
        return nil if data == ""
        replay = Replay.new(data, header)
        replay.file_position = file_path
        replay.birth_time = File.mtime file_path
        return replay
    end

    def self.read_record_header(file)
        pheader = ReplayHeader.new;
        pheader.id = self.read_int file
        pheader.version = self.read_int file
        pheader.flag = self.read_int file
        pheader.seed = self.read_int file
        pheader.data_size_raw = self.read_byte_array file, 4
        pheader.hash = self.read_int file
        pheader.props = self.read_byte_array file, 8
        pheader
    end

    def self.make_lzma_header(record_header)
        # props -> 0
        # dict_length -> 1-4
        # uncompressed_legth -> 5-12
        byte_array = record_header.props[0, 5] + record_header.data_size_raw + [0, 0, 0, 0]
        lzma_haeder = byte_array.pack("C*").force_encoding("utf-16le")
    end

    def self.read_int(file)
        c = 0
        c += file.readbyte
        c += file.readbyte * 0x100
        c += file.readbyte * 0x10000
        c += file.readbyte * 0x1000000
        c
    end

    def self.read_byte_array(file, length)
        a = []
        (1..length).each { a.push file.readbyte }
        a
    end
end