module Faye
  class WebSocket

    class Client
      include API

      DEFAULT_PORTS    = {'http' => 80, 'https' => 443, 'ws' => 80, 'wss' => 443}
      SECURE_PROTOCOLS = ['https', 'wss']

      attr_reader :headers, :status

      def initialize(url, protocols = nil, options = {})
        @driver = ::WebSocket::Driver.client(self, :max_length => options[:max_length], :protocols => protocols, :proxy => options[:proxy])

        [:open, :error].each do |event|
          @driver.on(event) do
            @headers = @driver.headers
            @status  = @driver.status
          end
        end

        super(options)

        @url   = url
        @uri   = URI.parse(url)
        @proxy = options[:proxy] && URI.parse(options[:proxy])

        endpoint = @proxy || @uri
        port     = endpoint.port || DEFAULT_PORTS[endpoint.scheme]
        secure   = SECURE_PROTOCOLS.include?(endpoint.scheme)

        EventMachine.connect(endpoint.host, port, Connection) do |conn|
          @stream = conn
          conn.parent = self
          conn.secure = secure
        end
      rescue => error
        event = Event.create('error', :message => "Network error: #{url}: #{error.message}")
        event.init_event('error', false, false)
        dispatch_event(event)
        finalize(error.message, 1006)
      end

    private

      def on_connect(secure)
        @stream.start_tls if secure
        @driver.start
      end

      module Connection
        attr_accessor :parent, :secure

        def connection_completed
          parent.__send__(:on_connect, secure)
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
