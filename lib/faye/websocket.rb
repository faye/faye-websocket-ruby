# API references:
#
# * http://dev.w3.org/html5/websockets/
# * http://dvcs.w3.org/hg/domcore/raw-file/tip/Overview.html#interface-eventtarget
# * http://dvcs.w3.org/hg/domcore/raw-file/tip/Overview.html#interface-event

require 'forwardable'
require 'stringio'
require 'uri'
require 'eventmachine'
require 'faye/websocket/parser'

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

    def self.load_adapter(backend)
      const = Kernel.const_get(ADAPTERS[backend]) rescue nil
      require(backend) unless const
      require File.expand_path("../adapters/#{backend}", __FILE__)
    end

    extend Forwardable
    def_delegators :@parser, :version

    attr_reader :env
    include API

    def initialize(env, supported_protos = nil, options = {})
      @env     = env
      @stream  = Stream.new(self)
      @ping    = options[:ping]
      @ping_id = 0

      @url = WebSocket.determine_url(@env)
      @ready_state = CONNECTING
      @buffered_amount = 0

      @parser = WebSocket.parser(@env).new(self, :protocols => supported_protos)
      @parser.onmessage { |message| receive_message(message) }
      @parser.onclose { |code, reason| finalize(code, reason) }

      @send_buffer = []
      EventMachine.next_tick { open }

      @callback = @env['async.callback']
      @callback.call([101, {}, @stream])
      @stream.write(@parser.handshake_response)

      @ready_state = OPEN if @parser.open?

      if @ping
        @ping_timer = EventMachine.add_periodic_timer(@ping) do
          @ping_id += 1
          ping(@ping_id.to_s)
        end
      end
    end

    def ping(message = '', &callback)
      return false unless @parser.respond_to?(:ping)
      @parser.ping(message, &callback)
    end

    def protocol
      @parser.protocol || ''
    end

    def rack_response
      [ -1, {}, [] ]
    end

  private

    def parse(data)
      @parser.parse(data)
      open
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
      @web_socket.__send__(:finalize, 1006, '')
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

