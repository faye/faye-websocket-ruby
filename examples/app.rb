require File.expand_path('../../lib/faye/websocket', __FILE__)
require 'rack'

static = Rack::File.new(File.dirname(__FILE__))

App = lambda do |env|
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

