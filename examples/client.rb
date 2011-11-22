require 'rubygems'
require File.expand_path('../../lib/faye/websocket', __FILE__)
require 'eventmachine'

port   = ARGV[0] || 7000
secure = ARGV[1] == 'ssl'

EM.run {
  scheme = secure ? 'wss' : 'ws'
  url    = "#{scheme}://localhost:#{port}/"
  
  puts "Connecting to #{url}"
  
  socket = Faye::WebSocket::Client.new(url)
  
  socket.onopen = lambda do |event|
    p [:open]
    socket.send("Hello, WebSocket!")
  end
  
  socket.onmessage = lambda do |event|
    p [:message, event.data]
    # socket.close 1002, 'Going away'
  end
  
  socket.onclose = lambda do |event|
    p [:close, event.code, event.reason]
    EM.stop
  end
}

