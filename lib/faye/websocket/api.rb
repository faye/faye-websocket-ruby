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
        @ready_state = OPEN

        buffer = @send_buffer || []
        while message = buffer.shift
          send(*message)
        end

        event = Event.new('open')
        event.init_event('open', false, false)
        dispatch_event(event)
      end

    public

      def receive(data)
        return false unless @ready_state == OPEN
        event = Event.new('message')
        event.init_event('message', false, false)
        event.data = data
        dispatch_event(event)
      end

      def send(data, type = nil, error_type = nil)
        if @ready_state == CONNECTING
          if @send_buffer
            @send_buffer << [data, type, error_type]
            return true
          else
            raise IllegalStateError, 'Cannot call send(), socket is not open yet'
          end
        end

        return false if @ready_state == CLOSED

        data = data.to_s unless Array === data

        data = WebSocket.encode(data) if String === data
        frame = @parser.frame(data, type, error_type)
        @stream.write(frame) if frame
      end

      def close(code = nil, reason = nil, ack = true)
        return if @ready_state == CLOSED
        return if @ready_state == CLOSING && ack

        finalize = lambda do
          @ready_state = CLOSED
          EventMachine.cancel_timer(@ping_timer) if @ping_timer
          @stream.close_connection_after_writing
          event = Event.new('close', :code => code || 1000, :reason => reason || '')
          event.init_event('close', false, false)
          dispatch_event(event)
        end

        return finalize.call if @ready_state == CONNECTING

        @ready_state = CLOSING

        if ack
          if @parser.respond_to?(:close)
            @parser.close(code, reason, &finalize)
          else
            finalize.call
          end
        else
          @parser.close(code, reason) if @parser.respond_to?(:close)
          finalize.call
        end
      end
    end

  end
end

