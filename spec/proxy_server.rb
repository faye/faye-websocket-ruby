class ProxyServer
  def initialize(options = {})
    @options = options
  end

  def listen(port, tls = false)
    @server = EM.start_server('localhost', port, Frontend) do |frontend|
      if tls
        frontend.start_tls(
          :private_key_file => File.expand_path('../server.key', __FILE__),
          :cert_chain_file  => File.expand_path('../server.crt', __FILE__)
        )
      end
      frontend.debug = @options[:debug]
    end
  end

  def stop
    EM.stop_server(@server) if @server
  end

  def self.format(data)
    data.bytes.map { |b| "%02x" % b }.join(' ')
  end

  module Frontend
    attr_writer :debug

    def post_init
      @request = WebSocket::HTTP::Request.new
      @backend = nil
    end

    def receive_data(data)
      if @backend
        p [:I, ProxyServer.format(data)] if @debug
        return @backend.send_data(data)
      end

      @request.parse(data)
      return unless @request.complete?

      unless @request.env['REQUEST_METHOD'] == 'CONNECT'
        send_data("HTTP/1.1 403 Forbidden\r\n\r\n")
        return close_connection_after_writing
      end

      p @request.env if @debug
      hostname, port = @request.env['PATH_INFO'].split(':', 2)

      EM.connect(hostname, port, Backend) do |backend|
        backend.debug    = @debug
        backend.frontend = self
      end
    end

    def unbind
      @backend.close_connection_after_writing if @backend
    end

    def return_handshake(backend)
      @backend = backend
      send_data("HTTP/1.1 200 OK\r\n\r\n")
    end
  end

  module Backend
    attr_writer :debug, :frontend

    def connection_completed
      @frontend.return_handshake(self)
    end

    def receive_data(data)
      p [:O, ProxyServer.format(data)] if @debug
      @frontend.send_data(data)
    end

    def unbind
      @frontend.close_connection_after_writing
    end
  end
end
