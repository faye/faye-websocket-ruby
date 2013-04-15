module Faye
  class WebSocket

    module API
      module ReadyStates
        CONNECTING = 0
        OPEN       = 1
        CLOSING    = 2
        CLOSED     = 3
      end

      class IllegalStateError < StandardError
      end

      require File.expand_path('../api/event_target', __FILE__)
      require File.expand_path('../api/event', __FILE__)
      include EventTarget
      include ReadyStates

      attr_reader :url, :ready_state, :buffered_amount

    private

      def open
        return if @parser and not @parser.open?
        return if @ready_state >= OPEN

        event = Event.new('open')
        event.init_event('open', false, false)
        dispatch_event(event)

        buffer = @send_buffer || []
        while message = buffer.shift
          send(message)
        end
      end

      def receive_message(data)
        return unless @ready_state == OPEN
        event = Event.new('message')
        event.init_event('message', false, false)
        event.data = data
        dispatch_event(event)
      end

      def finalize(code = nil, reason = nil)
        return if @ready_state == CLOSED
        @ready_state = CLOSED
        EventMachine.cancel_timer(@ping_timer) if @ping_timer
        @stream.close_connection_after_writing
        event = Event.new('close', :code => code || 1000, :reason => reason || '')
        event.init_event('close', false, false)
        dispatch_event(event)
      end

    public

      def write(data)
        @stream.write(data)
      end

      def send(message)
        if @ready_state == CONNECTING
          if @send_buffer
            @send_buffer << message
            return true
          else
            raise IllegalStateError, 'Cannot call send(), socket is not open yet'
          end
        end

        return false if @ready_state == CLOSED

        @parser.frame(message)
        true
      end

      def close
        return finalize if @ready_state == CONNECTING
        return unless @ready_state == OPEN

        @ready_state = CLOSING

        if @parser.respond_to?(:close)
          @parser.close
        else
          finalize
        end
      end
    end

  end
end

