require File.expand_path('../websocket', __FILE__) unless defined?(Faye::WebSocket)

module Faye
  class EventSource
    attr_accessor :onclose, :onerror
    attr_reader :env
    
    def self.event_source?(env)
      accept = (env['HTTP_ACCEPT'] || '').split(/\s*,\s*/)
      accept.include?('text/event-stream')
    end
    
    def initialize(env)
      @env = env
      @stream = Stream.new(self)
    end
    
    def rack_response
      [200, {'Content-Type' => 'text/event-stream'}, @stream]
    end
    
    def send(message)
      @stream.write("data: #{WebSocket.encode(message)}\r\n\r\n")
    end
    
    def close
      @stream.close_connection_after_writing
    end
  end
  
  class EventSource::Stream
    include EventMachine::Deferrable
    
    extend Forwardable
    def_delegators :@connection, :close_connection, :close_connection_after_writing
    
    def initialize(event_source)
      @event_source = event_source
      @connection   = event_source.env['em.connection']
      @stream_send  = event_source.env['stream.send']
      
      @connection.web_socket = self if @connection.respond_to?(:web_socket)
    end
    
    def each(&callback)
      yield("\r\n\r\n")
      @stream_send ||= callback
    end
    
    def fail
      @event_source.close
    end
    
    def receive(data)
    end
    
    def write(data)
      return unless @stream_send
      @stream_send.call(data)
    end
  end
end

