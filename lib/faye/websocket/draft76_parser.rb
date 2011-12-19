module Faye
  class WebSocket
    
    class Draft76Parser < Draft75Parser
      def version
        'hixie-76'
      end
      
      def handshake_response
        env = @socket.env
        signature = handshake_signature(env['rack.input'].read)
        
        upgrade =  "HTTP/1.1 101 Web Socket Protocol Handshake\r\n"
        upgrade << "Upgrade: WebSocket\r\n"
        upgrade << "Connection: Upgrade\r\n"
        upgrade << "Sec-WebSocket-Origin: #{env['HTTP_ORIGIN']}\r\n"
        upgrade << "Sec-WebSocket-Location: #{@socket.url}\r\n"
        upgrade << "\r\n"
        upgrade << signature if signature
        upgrade
      end
      
      def handshake_signature(head)
        return nil if head.empty?
        @handshake_complete = true
        
        env = @socket.env
        
        key1   = env['HTTP_SEC_WEBSOCKET_KEY1']
        value1 = number_from_key(key1) / spaces_in_key(key1)
        
        key2   = env['HTTP_SEC_WEBSOCKET_KEY2']
        value2 = number_from_key(key2) / spaces_in_key(key2)
        
        Digest::MD5.digest(big_endian(value1) +
                           big_endian(value2) +
                           head)
      end
      
      def parse(data)
        return super if @handshake_complete
        handshake_signature(data)
      end
      
    private
      
      def number_from_key(key)
        key.scan(/[0-9]/).join('').to_i(10)
      end
      
      def spaces_in_key(key)
        key.scan(/ /).size
      end
      
      def big_endian(number)
        string = ''
        [24,16,8,0].each do |offset|
          string << (number >> offset & 0xFF).chr
        end
        string
      end
    end
    
  end
end

