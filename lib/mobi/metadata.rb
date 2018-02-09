require 'forwardable'

module Mobi
  class Metadata
    extend Forwardable

    EXTH_RECORDS = %w(author publisher imprint description isbn subject
                      published_at review contributor rights subject_code type
                      source asin version adult coveroffset thumboffset)

    # Raw data stream
    attr_reader :data
    # Individual header classes for your reading pleasure.
    attr_reader :palm_doc_header, :mobi_header, :exth_header

    def initialize(file)
      @file = file
      @data = StreamSlicer.new(file)

      raise InvalidMobi, "The supplied file is not in a valid mobi format" unless bookmobi?

      @record_zero_stream = MetadataStreams.record_zero_stream(file)
      @palm_doc_header    = Header::PalmDocHeader.new @record_zero_stream
      @mobi_header        = Header::MobiHeader.new @record_zero_stream

      @exth_stream = MetadataStreams.exth_stream(file, @mobi_header.header_length)
      @exth_header = Header::ExthHeader.new @exth_stream
    end

    def read_uint32(offset)
      @data[offset, 4].unpack('N*')[0]
    end

    def read_pdb_record_offset(index)
      offset = 78 + 8 * index
      read_uint32(offset)
    end

    def ensure_magic!(magic, offset)
      if @data[offset, magic.length] != magic
        raise "Invalid file format. Magic string `#{magic}` not found at offset #{offset}"
      end
    end

    def read_variable_length(offset, bytes)
      @data[offset, bytes].unpack('N*')[0]
    end

    def read_exth_record(offset, record_type)
      new_offset = offset + 8
      exth_record_count = read_uint32(new_offset)
      new_offset += 4
      exth_record_count.times do |t|
        found_type = read_uint32(new_offset)
        new_offset += 4
        record_length = read_uint32(new_offset) - 8
        new_offset += 4
        if found_type == record_type
          return read_variable_length(new_offset, record_length)
        end
        new_offset += record_length
      end
    end

    def save_cover_image(filename)
      File.open(filename, 'wb') { |f| f.write(extract_cover_image) }
    end

    def extract_cover_image
      first_record_offset = read_pdb_record_offset(0)
      mobi_header_offset = first_record_offset + 16

      ensure_magic!('MOBI', mobi_header_offset)

      mobi_header_length = read_uint32(first_record_offset + 20)
      first_image_record_index = read_uint32(first_record_offset + 108)
      exth_flags = read_uint32(first_record_offset + 128)

      if exth_flags & 0x40 == 0
        return nil
      end

      exth_offset = mobi_header_offset + mobi_header_length

      ensure_magic!('EXTH', exth_offset)

      cover_record_offset = read_exth_record(exth_offset, 201)

      if cover_record_offset == nil
        return nil
      end

      cover_record_index = first_image_record_index + cover_record_offset
      cover_offset = read_pdb_record_offset(cover_record_index)
      next_record = read_pdb_record_offset(cover_record_index + 1)

      @data[cover_offset, next_record - cover_offset]
    end

    # Gets the title of the book.
    #
    # Returns a String.
    def title
      return @title if @title

      offset = @mobi_header.full_name_offset
      length = @mobi_header.full_name_length

      @title = @record_zero_stream[offset, length]
    end

    # Determines if the file is a valid mobi file.
    #
    # Returns true if the file is a valid MOBI.
    def bookmobi?
      @data[60, 8] == "BOOKMOBI"
    end

    # Delegate EXTH records types to the EXTH header.
    EXTH_RECORDS.each do |type|
      def_delegators :@exth_header, type.to_sym, type.to_sym
    end

    class InvalidMobi < ArgumentError;end;
  end
end
