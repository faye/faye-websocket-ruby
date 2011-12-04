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
require 'uri'

require 'eventmachine'
require 'thin'
require File.dirname(__FILE__) + '/thin_extensions'

module Faye
  class WebSocket
    
    root = File.expand_path('../websocket', __FILE__)
    
    autoload :API,             root + '/api'
    autoload :Client,          root + '/client'
    autoload :Draft75Parser,   root + '/draft75_parser'
    autoload :Draft76Parser,   root + '/draft76_parser'
    autoload :Protocol8Parser, root + '/protocol8_parser'
    
    # http://www.w3.org/International/questions/qa-forms-utf-8.en.php
    UTF8_MATCH = /^([\x00-\x7F]|[\xC2-\xDF][\x80-\xBF]|\xE0[\xA0-\xBF][\x80-\xBF]|[\xE1-\xEC\xEE\xEF][\x80-\xBF]{2}|\xED[\x80-\x9F][\x80-\xBF]|\xF0[\x90-\xBF][\x80-\xBF]{2}|[\xF1-\xF3][\x80-\xBF]{3}|\xF4[\x80-\x8F][\x80-\xBF]{2})*$/
    
    def self.encode(string, validate_encoding = false)
      if Array === string
        return nil if validate_encoding and !valid_utf8?(string)
        string = string.pack('C*')
      end
      return string unless string.respond_to?(:force_encoding)
      string.force_encoding('UTF-8')
    end
    
    def self.valid_utf8?(byte_array)
      UTF8_MATCH =~ byte_array.pack('C*') ? true : false
    end
    
    def self.parser(env)
      if env['HTTP_SEC_WEBSOCKET_VERSION']
        Protocol8Parser
      elsif env['HTTP_SEC_WEBSOCKET_KEY1']
        Draft76Parser
      else
        Draft75Parser
      end
    end
    
    extend Forwardable
    def_delegators :@parser, :version
    
    attr_reader :env
    include API
    
    def initialize(env)
      @env      = env
      @callback = @env['async.callback']
      @stream   = Stream.new(self, @env['em.connection'])
      @callback.call [200, {}, @stream]
      
      @url = determine_url
      @ready_state = CONNECTING
      @buffered_amount = 0
      
      @parser = WebSocket.parser(@env).new(self)
      @stream.write(@parser.handshake_response)
      
      @ready_state = OPEN
      
      event = Event.new('open')
      event.init_event('open', false, false)
      dispatch_event(event)
      
      @env[Thin::Request::WEBSOCKET_RECEIVE_CALLBACK] = lambda do |data|
        response = @parser.parse(data)
        @stream.write(response) if response
      end
    end
    
  private
    
    def determine_url
      secure = if @env.has_key?('HTTP_X_FORWARDED_PROTO')
                 @env['HTTP_X_FORWARDED_PROTO'] == 'https'
               else
                 @env['HTTP_ORIGIN'] =~ /^https:/i
               end
      
      scheme = secure ? 'wss:' : 'ws:'
      "#{ scheme }//#{ @env['HTTP_HOST'] }#{ @env['REQUEST_URI'] }"
    end
  end
  
  class WebSocket::Stream
    include EventMachine::Deferrable
    
    extend Forwardable
    def_delegators :@connection, :close_connection, :close_connection_after_writing
    
    def initialize(web_socket, connection)
      @web_socket = web_socket
      @connection = connection
    end
    
    def each(&callback)
      @data_callback = callback
    end
    
    def fail
      @web_socket.close(1006, '', false)
    end
    
    def write(data)
      return unless @data_callback
      @data_callback.call(data)
    end
  end
  
end

