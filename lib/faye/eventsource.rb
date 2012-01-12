require File.expand_path('../websocket', __FILE__) unless defined?(Faye::WebSocket)

module Faye
  class EventSource
    DEFAULT_RETRY = 5
    
    include WebSocket::API::EventTarget
    include WebSocket::API::ReadyStates
    attr_reader :env, :url, :ready_state
    
    def self.eventsource?(env)
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
      
      @ready_state = CONNECTING
      
      callback = @env['async.callback']
      callback.call([101, {}, @stream])
      
      @stream.write("HTTP/1.1 200 OK\r\n" +
                    "Content-Type: text/event-stream\r\n" +
                    "Cache-Control: no-cache, no-store\r\n" +
                    "\r\n\r\n" +
                    "retry: #{@retry * 1000}\r\n\r\n")
      
      @ready_state = OPEN
    end
    
    def last_event_id
      @env['HTTP_LAST_EVENT_ID'] || ''
    end
    
    def rack_response
      [ -1, {}, [] ]
    end
    
    def send(message, options = {})
      return false unless @ready_state == OPEN
      
      message = WebSocket.encode(message)
      lines   = message.split(/\r\n|\r|\n/)
      frame   = ""
      
      frame << "event: #{options[:event]}\r\n" if options[:event]
      frame << "id: #{options[:id]}\r\n" if options[:id]
      lines.each { |l| frame << "data: #{l}\r\n" }
      frame << "\r\n\r\n"
      
      @stream.write(frame)
      true
    end
    
    def close
      return if [CLOSING, CLOSED].include?(@ready_state)
      @ready_state = CLOSED
      @stream.close_connection_after_writing
      event = WebSocket::API::Event.new('close')
      event.init_event('close', false, false)
      dispatch_event(event)
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
      
      @connection.socket_stream = self if @connection.respond_to?(:socket_stream)
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

