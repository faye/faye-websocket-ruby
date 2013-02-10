module Faye
  class WebSocket

    class HybiParser
      root = File.expand_path('../hybi_parser', __FILE__)
      autoload :Handshake, root + '/handshake'
      autoload :StreamReader, root + '/stream_reader'

      BYTE       = 0b11111111
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
        :normal_closure       => 1000,
        :going_away           => 1001,
        :protocol_error       => 1002,
        :unacceptable         => 1003,
        :encoding_error       => 1007,
        :policy_violation     => 1008,
        :too_large            => 1009,
        :extension_error      => 1010,
        :unexpected_condition => 1011
      }

      ERROR_CODES = ERRORS.values

      attr_reader :protocol

      def initialize(web_socket, options = {})
        reset
        @socket    = web_socket
        @reader    = StreamReader.new
        @stage     = 0
        @masking   = options[:masking]
        @protocols = options[:protocols]
        @protocols = @protocols.split(/\s*,\s*/) if String === @protocols

        @ping_callbacks = {}
      end

      def version
        "hybi-#{@socket.env['HTTP_SEC_WEBSOCKET_VERSION']}"
      end

      def handshake_response
        sec_key = @socket.env['HTTP_SEC_WEBSOCKET_KEY']
        return '' unless String === sec_key

        accept    = Base64.encode64(Digest::SHA1.digest(sec_key + Handshake::GUID)).strip
        protos    = @socket.env['HTTP_SEC_WEBSOCKET_PROTOCOL']
        supported = @protocols
        proto     = nil

        headers = [
          "HTTP/1.1 101 Switching Protocols",
          "Upgrade: websocket",
          "Connection: Upgrade",
          "Sec-WebSocket-Accept: #{accept}"
        ]

        if protos and supported
          protos = protos.split(/\s*,\s*/) if String === protos
          proto = protos.find { |p| supported.include?(p) }
          if proto
            @protocol = proto
            headers << "Sec-WebSocket-Protocol: #{proto}"
          end
        end

        (headers + ['','']).join("\r\n")
      end

      def create_handshake
        Handshake.new(@socket.uri, @protocols)
      end

      def open?
        true
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

        is_text = (String === data)
        opcode  = OPCODES[type || (is_text ? :text : :binary)]
        buffer  = data.respond_to?(:bytes) ? data.bytes.to_a : data
        insert  = code ? 2 : 0
        length  = buffer.size + insert
        header  = (length <= 125) ? 2 : (length <= 65535 ? 4 : 10)
        offset  = header + (@masking ? 4 : 0)
        masked  = @masking ? MASK : 0
        frame   = Array.new(offset)

        frame[0] = FIN | opcode

        if length <= 125
          frame[1] = masked | length
        elsif length <= 65535
          frame[1] = masked | 126
          frame[2] = (length >> 8) & BYTE
          frame[3] = length & BYTE
        else
          frame[1] = masked | 127
          frame[2] = (length >> 56) & BYTE
          frame[3] = (length >> 48) & BYTE
          frame[4] = (length >> 40) & BYTE
          frame[5] = (length >> 32) & BYTE
          frame[6] = (length >> 24) & BYTE
          frame[7] = (length >> 16) & BYTE
          frame[8] = (length >> 8)  & BYTE
          frame[9] = length & BYTE
        end

        if code
          buffer = [(code >> 8) & BYTE, code & BYTE] + buffer
        end

        if @masking
          mask = [rand(256), rand(256), rand(256), rand(256)]
          frame[header...offset] = mask
          buffer = WebSocketMask.mask(buffer, mask)
        end

        frame.concat(buffer)

        WebSocket.encode(frame)
      end

      def ping(message = '', &callback)
        @ping_callbacks[message] = callback if callback
        @socket.send(message, :ping)
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
        payload = @masked ? WebSocketMask.mask(@payload, @mask) : @payload

        case @opcode
          when OPCODES[:continuation] then
            return @socket.close(ERRORS[:protocol_error], nil, false) unless @mode
            @buffer.concat(payload)
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
              @buffer.concat(payload)
            end

          when OPCODES[:binary] then
            if @final
              @socket.receive(payload)
            else
              @mode = :binary
              @buffer.concat(payload)
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

          when OPCODES[:pong] then
            message = WebSocket.encode(payload, true)
            callback = @ping_callbacks[message]
            @ping_callbacks.delete(message)
            callback.call if callback
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
    end

  end
end
