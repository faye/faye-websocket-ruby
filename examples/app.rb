require File.expand_path('../../lib/faye/websocket', __FILE__)
require 'rack'

static = Rack::File.new(File.dirname(__FILE__))

App = lambda do |env|
  if Faye::WebSocket.web_socket?(env)
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
  
  elsif Faye::EventSource.event_source?(env)
    socket = Faye::EventSource.new(env)
    time   = 0
    
    loop = EM.add_periodic_timer(2) do
      time += 1
      socket.send("Time: #{time}")
    end
    
    socket.onclose = lambda do
      EM.cancel_timer(loop)
      socket = nil
    end
    
    socket.rack_response
  
  else
    static.call(env)
  end
end

