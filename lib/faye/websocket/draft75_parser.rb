module Faye
  class WebSocket

    class Draft75Parser
      attr_reader :protocol

      def initialize(web_socket, options = {})
        @socket = web_socket
        @stage  = 0
      end

      def version
        'hixie-75'
      end

      def handshake_response
        upgrade =  "HTTP/1.1 101 Web Socket Protocol Handshake\r\n"
        upgrade << "Upgrade: WebSocket\r\n"
        upgrade << "Connection: Upgrade\r\n"
        upgrade << "WebSocket-Origin: #{@socket.env['HTTP_ORIGIN']}\r\n"
        upgrade << "WebSocket-Location: #{@socket.url}\r\n"
        upgrade << "\r\n"
        upgrade
      end

      def open?
        true
      end

      def parse(buffer)
        buffer.each_byte do |data|
          case @stage
            when 0 then
              parse_leading_byte(data)

            when 1 then
              value = (data & 0x7F)
              @length = value + 128 * @length

              if @closing and @length.zero?
                @socket.close(nil, nil, false)
              elsif (0x80 & data) != 0x80
                if @length.zero?
                  @socket.receive('')
                  @stage = 0
                else
                  @buffer = []
                  @stage = 2
                end
              end

            when 2 then
              if data == 0xFF
                @socket.receive(WebSocket.encode(@buffer))
                @stage = 0
              else
                @buffer << data
                if @length and @buffer.size == @length
                  @stage = 0
                end
              end
          end
        end

        nil
      end

      def parse_leading_byte(data)
        if (0x80 & data) == 0x80
          @length = 0
          @stage = 1
        else
          @length = nil
          @buffer = []
          @stage = 2
        end
      end

      def frame(data, type = nil, error_type = nil)
        return WebSocket.encode(data) if Array === data
        ["\x00", data, "\xFF"].map(&WebSocket.method(:encode)) * ''
      end
    end

  end
end

