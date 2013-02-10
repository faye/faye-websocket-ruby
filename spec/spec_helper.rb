require 'rubygems'
require 'bundler/setup'

unless RUBY_PLATFORM =~ /java/
  require 'thin'
  Thin::Logging.silent = true
  require 'rainbows'
  Unicorn::Configurator::DEFAULTS[:logger] = Logger.new(StringIO.new)
end

require File.expand_path('../../lib/faye/websocket', __FILE__)
require File.expand_path('../../vendor/em-rspec/lib/em-rspec', __FILE__)
require File.expand_path('../faye/websocket/draft75_parser_examples', __FILE__)

module EncodingHelper
  def encode(message)
    message.respond_to?(:force_encoding) ?
        message.force_encoding("UTF-8") :
        message
  end

  def bytes(string)
    string.bytes.to_a
  end

  def parse(bytes)
    @parser.parse(bytes.pack('C*'))
  end
end

class EchoServer
  def call(env)
    socket = Faye::WebSocket.new(env, ["echo"])
    socket.onmessage = lambda do |event|
      socket.send(event.data)
    end
    socket.rack_response
  end

  def listen(port, backend, ssl = false)
    case backend
    when :rainbows
      rackup = Unicorn::Configurator::RACKUP
      rackup[:port] = port
      rackup[:set_listener] = true
      options = rackup[:options]
      options[:config_file] = File.expand_path('../rainbows.conf', __FILE__)
      @server = Rainbows::HttpServer.new(self, options)
      @server.start
    when :thin
      Rack::Handler.get('thin').run(self, :Port => port) do |s|
        if ssl
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

  def stop
    @server.stop
  end
end

