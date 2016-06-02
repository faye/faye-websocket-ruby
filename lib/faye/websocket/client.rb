require 'forwardable'

module Faye
  class WebSocket

    class Client
      extend Forwardable
      include API

      DEFAULT_PORTS    = {'http' => 80, 'https' => 443, 'ws' => 80, 'wss' => 443}
      SECURE_PROTOCOLS = ['https', 'wss']

      def_delegators :@driver, :headers, :status

      def initialize(url, protocols = nil, options = {})
        @url = url
        super(options) { ::WebSocket::Driver.client(self, :max_length => options[:max_length], :protocols => protocols) }

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

            if secure
              origin_tls = {:sni_hostname => uri.host}.merge(@origin_tls)
              @stream.start_tls(origin_tls)
            end

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

        if @secure
          socket_tls = {:sni_hostname => URI.parse(@url).host}.merge(@socket_tls)
          @stream.start_tls(socket_tls)
        end

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
