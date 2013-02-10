module Faye
  class WebSocket

    class Client
      include API
      attr_reader :protocol, :uri

      def initialize(url, protocols = nil)
        @parser = HybiParser.new(self, :masking => true, :protocols => protocols)
        @url    = url
        @uri    = URI.parse(url)

        @protocol = ''
        @ready_state = CONNECTING
        @buffered_amount = 0

        port = @uri.port || (@uri.scheme == 'wss' ? 443 : 80)

        EventMachine.connect(@uri.host, port, Connection) do |conn|
          @stream = conn
          conn.parent = self
        end
      end

    private

      def on_connect
        @stream.start_tls if @uri.scheme == 'wss'
        @handshake = @parser.create_handshake
        @message = []
        @stream.write(@handshake.request_data)
      end

      def receive_data(data)
        data = WebSocket.encode(data)

        case @ready_state
          when CONNECTING then
            @message += @handshake.parse(data)
            return unless @handshake.complete?

            if @handshake.valid?
              @protocol = @handshake.protocol || ''
              @ready_state = OPEN
              event = Event.new('open')
              event.init_event('open', false, false)
              dispatch_event(event)

              receive_data(@message)
            else
              @ready_state = CLOSED
              event = Event.new('close', :code => 1006, :reason => '')
              event.init_event('close', false, false)
              dispatch_event(event)
            end

          when OPEN, CLOSING then
            @parser.parse(data)
        end
      end

      module Connection
        attr_accessor :parent

        def connection_completed
          parent.__send__(:on_connect)
        end

        def receive_data(data)
          parent.__send__(:receive_data, data)
        end

        def unbind
          parent.close(1006, '', false)
        end

        def write(data)
          send_data(data) rescue nil
        end
      end
    end

  end
end
