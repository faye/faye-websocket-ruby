# API and protocol references:
#
# * http://dev.w3.org/html5/websockets/
# * http://dvcs.w3.org/hg/domcore/raw-file/tip/Overview.html#interface-eventtarget
# * http://dvcs.w3.org/hg/domcore/raw-file/tip/Overview.html#interface-event
# * http://tools.ietf.org/html/draft-hixie-thewebsocketprotocol-75
# * http://tools.ietf.org/html/draft-hixie-thewebsocketprotocol-76
# * http://tools.ietf.org/html/draft-ietf-hybi-thewebsocketprotocol-17

require 'base64'
require 'digest/md5'
require 'digest/sha1'
require 'forwardable'
require 'net/http'
require 'stringio'
require 'uri'
require 'eventmachine'

module Faye
  autoload :EventSource, File.expand_path('../eventsource', __FILE__)

  class WebSocket
    root = File.expand_path('../websocket', __FILE__)
    require root + '/../../faye_websocket_mask'

    def self.jruby?
      defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby'
    end

    def self.rbx?
      defined?(RUBY_ENGINE) && RUBY_ENGINE == 'rbx'
    end

    if jruby?
      require 'jruby'
      com.jcoglan.faye.FayeWebsocketMaskService.new.basicLoad(JRuby.runtime)
    end

    unless WebSocketMask.respond_to?(:mask)
      def WebSocketMask.mask(payload, mask)
        @instance ||= new
        @instance.mask(payload, mask)
      end
    end

    unless String.instance_methods.include?(:force_encoding)
      require root + '/utf8_match'
    end

    autoload :Adapter,         root + '/adapter'
    autoload :API,             root + '/api'
    autoload :Client,          root + '/client'
    autoload :Draft75Parser,   root + '/draft75_parser'
    autoload :Draft76Parser,   root + '/draft76_parser'
    autoload :HybiParser,      root + '/hybi_parser'

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

    def self.utf8_string(string)
      string = string.pack('C*') if Array === string
      string.respond_to?(:force_encoding) ?
          string.force_encoding('UTF-8') :
          string
    end

    def self.encode(string, validate_encoding = false)
      if Array === string
        string = utf8_string(string)
        return nil if validate_encoding and !valid_utf8?(string)
      end
      utf8_string(string)
    end

    def self.valid_utf8?(byte_array)
      string = utf8_string(byte_array)
      if defined?(UTF8_MATCH)
        UTF8_MATCH =~ string ? true : false
      else
        string.valid_encoding?
      end
    end

    def self.websocket?(env)
      env['REQUEST_METHOD'] == 'GET' and
      env['HTTP_CONNECTION'] and
      env['HTTP_CONNECTION'].split(/\s*,\s*/).include?('Upgrade') and
      env['HTTP_UPGRADE'].downcase == 'websocket'
    end

    def self.parser(env)
      if env['HTTP_SEC_WEBSOCKET_VERSION']
        HybiParser
      elsif env['HTTP_SEC_WEBSOCKET_KEY1']
        Draft76Parser
      else
        Draft75Parser
      end
    end

    def self.determine_url(env)
      secure = if env.has_key?('HTTP_X_FORWARDED_PROTO')
                 env['HTTP_X_FORWARDED_PROTO'] == 'https'
               else
                 env['HTTP_ORIGIN'] =~ /^https:/i
               end

      scheme = secure ? 'wss:' : 'ws:'
      "#{ scheme }//#{ env['HTTP_HOST'] }#{ env['REQUEST_URI'] }"
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
      response = @parser.parse(data)
      return unless response
      @stream.write(response)
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
      @web_socket.close(1006, '', false)
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

