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
              @stream.send_data(frame.to_s)
            when :close
              finalize
            end
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
          @stream.send_data(frame.to_s)
        end
      end

    private

      def on_connect
        @stream.start_tls if @uri.scheme == 'wss'
        @handshake = ::WebSocket::Handshake::Client.new(:url => @url)
        @stream.send_data(@handshake.to_s)
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
