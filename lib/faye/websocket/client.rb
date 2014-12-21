module Faye
  class WebSocket

    class Client
      include API

      DEFAULT_PORTS    = {'http' => 80, 'https' => 443, 'ws' => 80, 'wss' => 443}
      SECURE_PROTOCOLS = ['https', 'wss']

      attr_reader :headers, :status

      def initialize(url, protocols = nil, options = {})
        @url    = url
        @driver = ::WebSocket::Driver.client(self, :max_length => options[:max_length], :protocols => protocols)

        [:open, :error].each do |event|
          @driver.on(event) do
            @headers = @driver.headers
            @status  = @driver.status
          end
        end

        super(options)

        proxy       = options.fetch(:proxy, {})
        endpoint    = URI.parse(proxy[:origin] || @url)
        port        = endpoint.port || DEFAULT_PORTS[endpoint.scheme]
        @secure     = SECURE_PROTOCOLS.include?(endpoint.scheme)
        @origin_tls = options.fetch(:tls, {})
        @socket_tls = proxy[:origin] ? proxy.fetch(:tls, {}) : @origin_tls

        if proxy[:origin]
          @proxy = @driver.proxy(proxy[:origin])
          if headers = proxy[:headers]
            headers.each { |name, value| @proxy.set_header(name, value) }
          end

          @proxy.on(:connect) do
            uri    = URI.parse(@url)
            secure = SECURE_PROTOCOLS.include?(uri.scheme)
            @proxy = nil

            @stream.start_tls(@origin_tls) if secure
            @driver.start
          end

          @proxy.on(:error) do |error|
            @driver.emit(:error, error)
          end
        end

        EventMachine.connect(endpoint.host, port, Connection) do |conn|
          conn.parent = self
        end
      rescue => error
        emit_error("Network error: #{url}: #{error.message}")
        finalize_close
      end

    private

      def on_connect(stream)
        @stream = stream
        @stream.start_tls(@socket_tls) if @secure
        worker = @proxy || @driver
        worker.start
      end

      module Connection
        attr_accessor :parent

        def connection_completed
          parent.__send__(:on_connect, self)
        end

        def receive_data(data)
          parent.__send__(:parse, data)
        end

        def unbind
          parent.__send__(:finalize_close)
        end

        def write(data)
          send_data(data) rescue nil
        end
      end
    end

  end
end
