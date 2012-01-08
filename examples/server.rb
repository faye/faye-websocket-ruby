require 'rubygems'
require 'rack/content_length'
require 'rack/chunked'

port   = ARGV[0] || 7000
secure = ARGV[1] == 'ssl'
engine = ARGV[2] || 'thin'
spec   = File.expand_path('../../spec', __FILE__)

require File.expand_path('../app', __FILE__)
Faye::WebSocket.load_adapter(engine)

case engine

when 'goliath'
  class WebSocketServer < Goliath::API
    def response(env)
      App.call(env)
    end
  end

when 'rainbows'
  rackup = Unicorn::Configurator::RACKUP
  rackup[:port] = port
  rackup[:set_listener] = true
  options = rackup[:options]
  options[:config_file] = spec + '/rainbows.conf'
  Rainbows::HttpServer.new(App, options).start.join

when 'thin'
  EM.run {
    thin = Rack::Handler.get('thin')
    thin.run(App, :Port => port) do |server|
      if secure
        server.ssl_options = {
          :private_key_file => spec + '/server.key',
          :cert_chain_file  => spec + '/server.crt'
        }
        server.ssl = true
      end
    end
  }
end

