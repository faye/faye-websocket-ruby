require 'rubygems'
require 'bundler/setup'
require 'faye/websocket'
require 'eventmachine'

EM.run {
  url     = ARGV[0]
  headers = {'Origin' => 'http://faye.jcoglan.com'}
  proxy   = {:origin => ARGV[1], :headers => {'User-Agent' => 'Echo'}}
  ws      = Faye::WebSocket::Client.new(url, nil, :headers => headers, :proxy => proxy)

  ws.onopen = lambda do |event|
    p [:socket_open, ws.headers]
    ws.send('mic check')
  end

  ws.onclose = lambda do |close|
    p [:socket_close, close.code, close.reason]
    EM.stop
  end

  ws.onerror = lambda do |error|
    p [:socket_error, error.message]
  end

  ws.onmessage = lambda do |message|
    p [:socket_message, message.data]
  end
}
