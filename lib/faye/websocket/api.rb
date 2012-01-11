module Faye
  class WebSocket
    
    module API
      module ReadyStates
        CONNECTING = 0
        OPEN       = 1
        CLOSING    = 2
        CLOSED     = 3
      end
      
      require File.expand_path('../api/event_target', __FILE__)
      require File.expand_path('../api/event', __FILE__)
      include EventTarget
      include ReadyStates
      
      attr_reader :url, :ready_state, :buffered_amount
      
      def receive(data)
        return false unless ready_state == OPEN
        event = Event.new('message')
        event.init_event('message', false, false)
        event.data = data
        dispatch_event(event)
      end
      
      def send(data, type = nil, error_type = nil)
        return false if ready_state == CLOSED
        data = WebSocket.encode(data) if String === data
        frame = @parser.frame(data, type, error_type)
        @stream.write(frame) if frame
      end
      
      def close(code = nil, reason = nil, ack = true)
        return if [CLOSING, CLOSED].include?(ready_state)
        
        @ready_state = CLOSING
        
        close = lambda do
          @ready_state = CLOSED
          @stream.close_connection_after_writing
          event = Event.new('close', :code => code || 1000, :reason => reason || '')
          event.init_event('close', false, false)
          dispatch_event(event)
        end
        
        if ack
          if @parser.respond_to?(:close)
            @parser.close(code, reason, &close)
          else
            close.call
          end
        else
          @parser.close(code, reason) if @parser.respond_to?(:close)
          close.call
        end
      end
    end
    
  end
end
