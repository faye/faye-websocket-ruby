# API references:
#
# * http://dev.w3.org/html5/websockets/
# * http://dvcs.w3.org/hg/domcore/raw-file/tip/Overview.html#interface-eventtarget
# * http://dvcs.w3.org/hg/domcore/raw-file/tip/Overview.html#interface-event

require 'forwardable'
require 'stringio'
require 'uri'
require 'eventmachine'
require 'websocket/protocol'

module Faye
  autoload :EventSource, File.expand_path('../eventsource', __FILE__)

  class WebSocket
    root = File.expand_path('../websocket', __FILE__)

    autoload :Adapter, root + '/adapter'
    autoload :API,     root + '/api'
    autoload :Client,  root + '/client'

    ADAPTERS = {
      'thin'     => :Thin,
      'rainbows' => :Rainbows,
      'goliath'  => :Goliath
    }

    def self.determine_url(env)
      secure = Rack::Request.new(env).ssl?
      scheme = secure ? 'wss:' : 'ws:'
      "#{ scheme }//#{ env['HTTP_HOST'] }#{ env['REQUEST_URI'] }"
    end

    def self.load_adapter(backend)
      const = Kernel.const_get(ADAPTERS[backend]) rescue nil
      require(backend) unless const
      require File.expand_path("../adapters/#{backend}", __FILE__)
    end

    def self.websocket?(env)
      ::WebSocket::Protocol.websocket?(env)
    end

    attr_reader :env
    include API

    def initialize(env, protocols = nil, options = {})
      @env     = env
      @stream  = Stream.new(self)
      @ping    = options[:ping]
      @ping_id = 0
      @url     = WebSocket.determine_url(@env)
      @parser  = ::WebSocket::Protocol.rack(self, :protocols => protocols)

      @callback = @env['async.callback']
      @callback.call([101, {}, @stream])

      super()
      @parser.start
    end

    def rack_response
      [ -1, {}, [] ]
    end
  end

  class WebSocket::Stream
    include EventMachine::Deferrable

    extend Forwardable
    def_delegators :@connection, :close_connection, :close_connection_after_writing

    def initialize(web_socket)
      @web_socket  = web_socket
      @connection  = web_socket.env['em.connection']
      @stream_send = web_socket.env['stream.send']

      @connection.socket_stream = self if @connection.respond_to?(:socket_stream)
    end

    def each(&callback)
      @stream_send ||= callback
    end

    def fail
      @web_socket.__send__(:finalize, '', 1006)
    end

    def receive(data)
      @web_socket.__send__(:parse, data)
    end

    def write(data)
      return unless @stream_send
      @stream_send.call(data) rescue nil
    end
  end
end

Faye::WebSocket::ADAPTERS.each do |name, const|
  klass = Kernel.const_get(const) rescue nil
  Faye::WebSocket.load_adapter(name) if klass
end

