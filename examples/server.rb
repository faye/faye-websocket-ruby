require 'rubygems'
require File.expand_path('../../lib/faye/websocket', __FILE__)
require 'rack'

port   = ARGV[0] || 7000
secure = ARGV[1] == 'ssl'
engine = ARGV[2] || 'thin'

static = Rack::File.new(File.dirname(__FILE__))

app = lambda do |env|
  if env['HTTP_UPGRADE']
    socket = Faye::WebSocket.new(env, ['irc', 'xmpp'])
    p [:open, socket.url, socket.version, socket.protocol]
    
    socket.onmessage = lambda do |event|
      socket.send(event.data)
    end
    
    socket.onclose = lambda do |event|
      p [:close, event.code, event.reason]
      socket = nil
    end
    
    socket.rack_response
  else
    static.call(env)
  end
end

spec = File.expand_path('../../spec', __FILE__)
case engine

when 'rainbows'
  require 'rainbows'
  rackup = Unicorn::Configurator::RACKUP
  rackup[:port] = port
  rackup[:set_listener] = true
  options = rackup[:options]
  options[:config_file] = spec + '/rainbows.conf'
  Rainbows::HttpServer.new(app, options).start.join

when 'thin'
  require 'eventmachine'
  EM.run {
    thin = Rack::Handler.get('thin')
    thin.run(app, :Port => port) do |server|
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

