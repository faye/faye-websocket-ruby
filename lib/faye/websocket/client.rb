require 'websocket'

module Faye
  class WebSocket

    class Client
      include API

      def initialize(url, protocols = nil)
        @url    = url
        @uri    = URI.parse(url)
        @driver = ::WebSocket::Driver.client(self)

        super()

        port = @uri.port || (@uri.scheme == 'wss' ? 443 : 80)

        EventMachine.connect(@uri.host, port, Connection) do |conn|
          @stream = conn
          conn.parent = self
        end
      end

      def parse(data)
        if @handshake
          @handshake << data
          return unless @handshake.finished?
          if @handshake.valid?
            leftovers  = @handshake.leftovers
            @version   = @handshake.version
            @parser    = ::WebSocket::Frame::Incoming::Client.new(:version => @version)
            @handshake = nil

            open
            parse(leftovers)
            @queue.each { |msg| send(msg) } if @queue
            @queue = nil

          else
            finalize
          end
        else
          @parser << data
          while message = @parser.next
            case message.type

            when :text
              receive_message(message.data)

            when :binary
              receive_message(message.data.bytes.to_a)

            when :ping
              frame = ::WebSocket::Frame::Outgoing::Client.new(
                :version => @version,
                :data    => message.data,
                :type    => :pong
              )
              @stream.write(frame.to_s)

            when :close

              code = if message.data.bytesize == 1
                       1002
                     elsif message.data.bytesize >= 2
                       payload = message.data.bytes.to_a[2..-1].pack('C*').force_encoding('UTF-8')
                       if payload.valid_encoding?
                         message.data.getbyte(0) * 256 + message.data.getbyte(1)
                       else
                         1002
                       end
                     else
                       1000
                     end

              unless [(1000..1003), (1007..1011), (3000..4999)].any? { |range| range === code }
                code = 1002
              end

              frame = ::WebSocket::Frame::Outgoing::Client.new(
                :version => @version,
                :data    => '',
                :code    => code,
                :type    => :close
              )
              @stream.write(frame.to_s)
              finalize
            end
          end
          if error = @parser.error
            messages = {
              :control_frame_payload_too_long  => [1002, 'Received control frame having too long payload'],
              :data_frame_instead_continuation => [1002, 'Received new data frame but previous continuous frame is unfinished'],
              :fragmented_control_frame        => [1002, 'Received fragmented control frame'],
              :invalid_payload_encoding        => [1007, 'Could not decode a text frame as UTF-8'],
              :reserved_bit_used               => [1002, 'One or more reserved bits are on'],
              :unexpected_continuation_frame   => [1002, 'Received unexpected continuation frame'],
              :unknown_opcode                  => [1002, 'Unrecognized frame opcode']
            }
            frame = ::WebSocket::Frame::Outgoing::Client.new(
              :version => @version,
              :data    => messages[error][1],
              :code    => messages[error][0],
              :type    => :close
            )
            @stream.write(frame.to_s)
            finalize
          end
        end
      end

      def send(message)
        if @handshake
          @queue ||= []
          @queue << message
        else
          if String === message
            frame = ::WebSocket::Frame::Outgoing::Client.new(
              :version => @version,
              :data    => message,
              :type    => :text
            )
          else
            frame = ::WebSocket::Frame::Outgoing::Client.new(
              :version => @version,
              :data    => message.pack('C*'),
              :type    => :binary
            )
          end
          @stream.write(frame.to_s)
        end
      end

    private

      def on_connect
        @stream.start_tls if @uri.scheme == 'wss'
        @handshake = ::WebSocket::Handshake::Client.new(:url => @url)
        @stream.write(@handshake.to_s)
      end

      module Connection
        attr_accessor :parent

        def connection_completed
          parent.__send__(:on_connect)
        end

        def receive_data(data)
          parent.__send__(:parse, data)
        end

        def unbind
          parent.__send__(:finalize, '', 1006)
        end

        def write(data)
          send_data(data) rescue nil
        end
      end
    end

  end
end
