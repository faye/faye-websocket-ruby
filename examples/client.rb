require 'rubygems'
require File.expand_path('../../lib/faye/websocket', __FILE__)
require 'eventmachine'

port   = ARGV[0] || 7000
secure = ARGV[1] == 'ssl'

EM.run {
  scheme = secure ? 'wss' : 'ws'
  url    = "#{scheme}://localhost:#{port}/"
  socket = Faye::WebSocket::Client.new(url)
  
  puts "Connecting to #{socket.url}"
  
  socket.onopen = lambda do |event|
    p [:open]
    socket.send("Hello, WebSocket!")
  end
  
  socket.add_event_listener('message', lambda { |event|
    p [:message, event.data]
    # socket.close 1002, 'Going away'
  })
  
  socket.onclose = lambda do |event|
    p [:close, event.code, event.reason]
    EM.stop
  end
}

