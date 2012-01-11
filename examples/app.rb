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
    time   = socket.last_event_id.to_i
    
    p [:open, socket.url, socket.last_event_id]
    
    loop = EM.add_periodic_timer(2) do
      time += 1
      socket.send("Time: #{time}")
      EM.add_timer(1) do
        socket.send('Update!!', :event => 'update', :id => time)
      end
    end
    
    socket.send("Welcome!\n\nThis is an EventSource server.")
    
    socket.onclose = lambda do
      EM.cancel_timer(loop)
      socket = nil
    end
    
    socket.rack_response
  
  else
    static.call(env)
  end
end

