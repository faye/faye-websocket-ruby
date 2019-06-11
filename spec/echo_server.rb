require 'puma'
require 'puma/binder'
require 'puma/events'

unless RUBY_PLATFORM =~ /java/
  Faye::WebSocket.load_adapter('thin')
  Thin::Logging.silent = true
end

class EchoServer
  def call(env)
    socket = Faye::WebSocket.new(env, ["echo"])
    socket.onmessage = lambda do |event|
      socket.send(event.data)
    end
    socket.rack_response
  end

  def log(*args)
  end

  def listen(port, backend, tls = false)
    case backend
    when :puma then listen_puma(port, tls)
    when :thin then listen_thin(port, tls)
    end
  end

  def stop
    case @server
    when Puma::Server then @server.stop(true)
    else @server.stop
    end
  end

private

  def listen_puma(port, tls)
    events = Puma::Events.new(StringIO.new, StringIO.new)
    binder = Puma::Binder.new(events)
    binder.parse(["tcp://0.0.0.0:#{ port }"], self)
    @server = Puma::Server.new(self, events)
    @server.binder = binder
    @server.run
  end

  def listen_thin(port, tls)
    Rack::Handler.get('thin').run(self, :Port => port) do |s|
      if tls
        s.ssl = true
        s.ssl_options = {
          :private_key_file => File.expand_path('../server.key', __FILE__),
          :cert_chain_file  => File.expand_path('../server.crt', __FILE__)
        }
      end
      @server = s
    end
  end
end
