module Faye
  class WebSocket
    
    class Draft75Parser
      def initialize(web_socket)
        @socket    = web_socket
        @buffer    = []
        @buffering = false
      end
      
      def version
        'draft-75'
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
      
      def parse(data)
        data.each_byte do |byte|
          case byte
            when 0x00 then
              @buffering = true
              
            when 0xFF then
              @socket.receive(WebSocket.encode(@buffer))
              @buffer = []
              @buffering = false
              
            else
              @buffer.push(byte) if @buffering
          end
        end
        
        nil
      end
      
      def frame(data, type = nil, error_type = nil)
        ["\x00", data, "\xFF"].map(&WebSocket.method(:encode)) * ''
      end
    end
    
  end
end

