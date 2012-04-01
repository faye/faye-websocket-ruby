module Faye
  class WebSocket
    class HybiParser

      class Handshake
        GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'

        attr_reader :protocol

        def initialize(uri, protocols)
          @uri       = uri
          @protocols = protocols
          @key       = Base64.encode64((1..16).map { rand(255).chr } * '').strip
          @accept    = Base64.encode64(Digest::SHA1.digest(@key + GUID)).strip
          @buffer    = []
        end

        def request_data
          hostname = @uri.host + (@uri.port ? ":#{@uri.port}" : '')
          path = (@uri.path == '') ? '/' : @uri.path
          headers = [
            "GET #{path}#{@uri.query ? '?' : ''}#{@uri.query} HTTP/1.1",
            "Host: #{hostname}",
            "Upgrade: websocket",
            "Connection: Upgrade",
            "Sec-WebSocket-Key: #{@key}",
            "Sec-WebSocket-Version: 13"
          ]

          if @protocols
            headers << "Sec-WebSocket-Protocol: #{@protocols * ', '}"
          end

          (headers + ['','']).join("\r\n")
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

          upgrade    = response['Upgrade']
          connection = response['Connection']
          protocol   = response['Sec-WebSocket-Protocol']

          @protocol = @protocols && @protocols.include?(protocol) ?
                      protocol :
                      nil

          upgrade and upgrade =~ /^websocket$/i and
          connection and connection.split(/\s*,\s*/).include?('Upgrade') and
          ((!@protocols and !protocol) or @protocol) and
          response['Sec-WebSocket-Accept'] == @accept
        end
      end

    end
  end
end
