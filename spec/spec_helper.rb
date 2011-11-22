require 'rubygems'
require 'bundler/setup'
require File.expand_path('../../lib/faye/websocket', __FILE__)
require File.expand_path('../../vendor/em-rspec/lib/em-rspec', __FILE__)

Thin::Logging.silent = true

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
    socket = Faye::WebSocket.new(env)
    socket.onmessage = lambda do |event|
      socket.send(event.data)
    end
    [-1, {}, []]
  end
  
  def listen(port)
    Rack::Handler.get('thin').run(self, :Port => port) do |server|
      @server = server
    end
  end
  
  def stop
    @server.stop
  end
end

