require File.expand_path('../websocket', __FILE__) unless defined?(Faye::WebSocket)

module Faye
  class EventSource
    DEFAULT_RETRY = 5
    
    attr_accessor :onclose, :onerror
    attr_reader :env, :url
    
    def self.event_source?(env)
      accept = (env['HTTP_ACCEPT'] || '').split(/\s*,\s*/)
      accept.include?('text/event-stream')
    end
    
    def self.determine_url(env)
      secure = if env.has_key?('HTTP_X_FORWARDED_PROTO')
                 env['HTTP_X_FORWARDED_PROTO'] == 'https'
               else
                 env['HTTP_ORIGIN'] =~ /^https:/i
               end
      
      scheme = secure ? 'https:' : 'http:'
      "#{ scheme }//#{ env['HTTP_HOST'] }#{ env['REQUEST_URI'] }"
    end
    
    def initialize(env, options = {})
      @env    = env
      @retry  = (options[:retry] || DEFAULT_RETRY).to_i
      @url    = EventSource.determine_url(env)
      @stream = Stream.new(self)
      
      callback = @env['async.callback']
      callback.call([101, {}, @stream])
      
      @stream.write("HTTP/1.1 200 OK\r\n" +
                    "Content-Type: text/event-stream\r\n" +
                    "Cache-Control: no-cache, no-store\r\n" +
                    "\r\n\r\n" +
                    "retry: #{@retry * 1000}\r\n\r\n")
    end
    
    def last_event_id
      @env['HTTP_LAST_EVENT_ID'] || ''
    end
    
    def rack_response
      [ -1, {}, [] ]
    end
    
    def send(message, options = {})
      frame  = ""
      frame << "event: #{options[:event]}\n" if options[:event]
      frame << "id: #{options[:id]}\n" if options[:id]
      frame << "data: #{WebSocket.encode(message)}\r\n\r\n"
      @stream.write(frame)
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

