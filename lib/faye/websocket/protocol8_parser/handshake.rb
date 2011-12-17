module Faye
  class WebSocket
    class Protocol8Parser
      
      class Handshake
        GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'
        
        def initialize(uri)
          @uri    = uri
          @key    = Base64.encode64((1..16).map { rand(255).chr } * '').strip
          @accept = Base64.encode64(Digest::SHA1.digest(@key + GUID)).strip
          @buffer = []
        end
        
        def request_data
          hostname = @uri.host + (@uri.port ? ":#{@uri.port}" : '')
          
          handshake  = "GET #{@uri.path}#{@uri.query ? '?' : ''}#{@uri.query} HTTP/1.1\r\n"
          handshake << "Host: #{hostname}\r\n"
          handshake << "Upgrade: websocket\r\n"
          handshake << "Connection: Upgrade\r\n"
          handshake << "Sec-WebSocket-Key: #{@key}\r\n"
          handshake << "Sec-WebSocket-Version: 8\r\n"
          handshake << "\r\n"
          
          handshake
        end
        
        def parse(data)
          message  = []
          complete = false
          data.each_byte do |byte|
            if complete
              message << byte
            else
              @buffer << byte
              complete ||= complete?
            end
          end
          message
        end
        
        def complete?
          @buffer[-4..-1] == [0x0D, 0x0A, 0x0D, 0x0A]
        end
        
        def valid?
          data = WebSocket.encode(@buffer)
          response = Net::HTTPResponse.read_new(Net::BufferedIO.new(StringIO.new(data)))
          return false unless response.code.to_i == 101
          
          upgrade, connection = response['Upgrade'], response['Connection']
          
          upgrade and upgrade =~ /^websocket$/i and
          connection and connection.split(/\s*,\s*/).include?('Upgrade') and
          response['Sec-WebSocket-Accept'] == @accept
        end
      end
      
    end
  end
end

