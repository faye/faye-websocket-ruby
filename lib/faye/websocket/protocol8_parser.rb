module Faye
  class WebSocket
    
    class Protocol8Parser
      root = File.expand_path('../protocol8_parser', __FILE__)
      autoload :Handshake, root + '/handshake'
      autoload :StreamReader, root + '/stream_reader'
      
      FIN = MASK = 0b10000000
      RSV1       = 0b01000000
      RSV2       = 0b00100000
      RSV3       = 0b00010000
      OPCODE     = 0b00001111
      LENGTH     = 0b01111111
      
      OPCODES = {
        :continuation => 0,
        :text         => 1,
        :binary       => 2,
        :close        => 8,
        :ping         => 9,
        :pong         => 10
      }
      
      FRAGMENTED_OPCODES = OPCODES.values_at(:continuation, :text, :binary)
      OPENING_OPCODES = OPCODES.values_at(:text, :binary)
      
      ERRORS = {
        :normal_closure   => 1000,
        :going_away       => 1001,
        :protocol_error   => 1002,
        :unacceptable     => 1003,
        :encoding_error   => 1007,
        :policy_violation => 1008,
        :too_large        => 1009,
        :extension_error  => 1010
      }
      
      ERROR_CODES = ERRORS.values
      
      def initialize(web_socket, options = {})
        reset
        @socket  = web_socket
        @reader  = StreamReader.new
        @stage   = 0
        @masking = options[:masking]
      end
      
      def version
        "protocol-#{@socket.env['HTTP_SEC_WEBSOCKET_VERSION']}"
      end
      
      def handshake_response
        sec_key = @socket.env['HTTP_SEC_WEBSOCKET_KEY']
        return '' unless String === sec_key
        
        accept = Base64.encode64(Digest::SHA1.digest(sec_key + Handshake::GUID)).strip
        
        upgrade =  "HTTP/1.1 101 Switching Protocols\r\n"
        upgrade << "Upgrade: websocket\r\n"
        upgrade << "Connection: Upgrade\r\n"
        upgrade << "Sec-WebSocket-Accept: #{accept}\r\n"
        upgrade << "\r\n"
        upgrade
      end
      
      def create_handshake
        Handshake.new(@socket.uri)
      end
      
      def parse(data)
        @reader.put(data.bytes.to_a)
        buffer = true
        while buffer
          case @stage
            when 0 then
              buffer = @reader.read(1)
              parse_opcode(buffer[0]) if buffer
              
            when 1 then
              buffer = @reader.read(1)
              parse_length(buffer[0]) if buffer
              
            when 2 then
              buffer = @reader.read(@length_size)
              parse_extended_length(buffer) if buffer
              
            when 3 then
              buffer = @reader.read(4)
              if buffer
                @mask  = buffer
                @stage = 4
              end
              
            when 4 then
              buffer = @reader.read(@length)
              if buffer
                @payload = buffer
                emit_frame
                @stage = 0
              end
          end
        end
        
        nil
      end
      
      def frame(data, type = nil, code = nil)
        return nil if @closed
        
        type ||= (String === data ? :text : :binary)
        data   = data.bytes.to_a if data.respond_to?(:bytes)
        
        if code
          data = [code].pack('n').bytes.to_a + data
        end
        
        frame  = (FIN | OPCODES[type]).chr
        length = data.size
        masked = @masking ? MASK : 0
        
        case length
          when 0..125 then
            frame << (masked | length).chr
          when 126..65535 then
            frame << (masked | 126).chr
            frame << [length].pack('n')
          else
            frame << (masked | 127).chr
            frame << [length >> 32, length & 0xFFFFFFFF].pack('NN')
        end
        
        if @masking
          mask = (1..4).map { rand 256 }
          data.each_with_index do |byte, i|
            data[i] = byte ^ mask[i % 4]
          end
          frame << mask.pack('C*')
        end
        
        WebSocket.encode(frame) + WebSocket.encode(data)
      end
      
      def close(code = nil, reason = nil, &callback)
        return if @closed
        @closing_callback ||= callback
        @socket.send(reason || '', :close, code || ERRORS[:normal_closure])
        @closed = true
      end
      
    private
      
      def parse_opcode(data)
        if [RSV1, RSV2, RSV3].any? { |rsv| (data & rsv) == rsv }
          return @socket.close(ERRORS[:protocol_error], nil, false)
        end
        
        @final   = (data & FIN) == FIN
        @opcode  = (data & OPCODE)
        @mask    = []
        @payload = []
        
        unless OPCODES.values.include?(@opcode)
          return @socket.close(ERRORS[:protocol_error], nil, false)
        end
        
        unless FRAGMENTED_OPCODES.include?(@opcode) or @final
          return @socket.close(ERRORS[:protocol_error], nil, false)
        end
        
        if @mode and OPENING_OPCODES.include?(@opcode)
          return @socket.close(ERRORS[:protocol_error], nil, false)
        end
        
        @stage = 1
      end
      
      def parse_length(data)
        @masked = (data & MASK) == MASK
        @length = (data & LENGTH)
        
        if @length <= 125
          @stage = @masked ? 3 : 4
        else
          @length_size = (@length == 126) ? 2 : 8
          @stage       = 2
        end
      end
      
      def parse_extended_length(buffer)
        @length = integer(buffer)
        @stage  = @masked ? 3 : 4
      end
      
      def emit_frame
        payload = unmask(@payload, @mask)
        
        case @opcode
          when OPCODES[:continuation] then
            return @socket.close(ERRORS[:protocol_error], nil, false) unless @mode
            @buffer += payload
            if @final
              message = @buffer
              message = WebSocket.encode(message, true) if @mode == :text
              reset
              if message
                @socket.receive(message)
              else
                @socket.close(ERRORS[:encoding_error], nil, false)
              end
            end

          when OPCODES[:text] then
            if @final
              message = WebSocket.encode(payload, true)
              if message
                @socket.receive(message)
              else
                @socket.close(ERRORS[:encoding_error], nil, false)
              end
            else
              @mode = :text
              @buffer += payload
            end

          when OPCODES[:binary] then
            if @final
              @socket.receive(payload)
            else
              @mode = :binary
              @buffer += payload
            end

          when OPCODES[:close] then
            code = (payload.size >= 2) ? 256 * payload[0] + payload[1] : nil
            
            unless (payload.size == 0) or
                   (code && code >= 3000 && code < 5000) or
                   ERROR_CODES.include?(code)
              code = ERRORS[:protocol_error]
            end
            
            if payload.size > 125 or not WebSocket.valid_utf8?(payload[2..-1] || [])
              code = ERRORS[:protocol_error]
            end
            
            reason = (payload.size > 2) ? WebSocket.encode(payload[2..-1], true) : nil
            @socket.close(code, reason, false)
            @closing_callback.call if @closing_callback

          when OPCODES[:ping] then
            return @socket.close(ERRORS[:protocol_error], nil, false) if payload.size > 125
            @socket.send(payload, :pong)
        end
      end

      def reset
        @buffer = []
        @mode   = nil
      end
      
      def integer(bytes)
        number = 0
        bytes.each_with_index do |data, i|
          number += data << (8 * (bytes.size - 1 - i))
        end
        number
      end
      
      def unmask(payload, mask)
        unmasked = []
        payload.each_with_index do |byte, i|
          byte = byte ^ mask[i % 4] if mask.size > 0
          unmasked << byte
        end
        unmasked
      end
    end
    
  end
end

