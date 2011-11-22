require 'rubygems'
require File.expand_path('../../lib/faye/websocket', __FILE__)
require 'rack'
require 'eventmachine'

port   = ARGV[0] || 7000
secure = ARGV[1] == 'ssl'

app = lambda do |env|
  if env['HTTP_UPGRADE']
    socket = Faye::WebSocket.new(env)
    
    socket.onmessage = lambda do |event|
      socket.send(event.data)
    end
    
    socket.onclose = lambda do |event|
      p [:close, event.code, event.reason]
      socket = nil
    end
    
    [-1, {}, []]
  else
    [200, {'Content-Type' => 'text/plain'}, ['Hello']]
  end
end

EM.run {
  thin = Rack::Handler.get('thin')
  thin.run(app, :Port => port) do |server|
    if secure
      server.ssl = true
      server.ssl_options = {
        :private_key_file => File.expand_path('../../spec/server.key', __FILE__),
        :cert_chain_file  => File.expand_path('../../spec/server.crt', __FILE__)
      }
    end
  end
}

