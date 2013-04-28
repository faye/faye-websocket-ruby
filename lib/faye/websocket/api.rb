module Faye
  class WebSocket

    module API
      CONNECTING = 0
      OPEN       = 1
      CLOSING    = 2
      CLOSED     = 3

      require File.expand_path('../api/event_target', __FILE__)
      require File.expand_path('../api/event', __FILE__)
      include EventTarget

      attr_reader :url, :ready_state, :buffered_amount

    private

      def open
        return unless @ready_state == CONNECTING
        @ready_state = OPEN
        event = Event.new('open')
        event.init_event('open', false, false)
        dispatch_event(event)
      end

      def receive_message(data)
        return unless @ready_state == OPEN
        event = Event.new('message')
        event.init_event('message', false, false)
        event.data = data
        dispatch_event(event)
      end

      def finalize(reason = nil, code = nil)
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
        return false if @ready_state > OPEN
        case message
          when Numeric then @parser.text(message.to_s)
          when String  then @parser.text(message)
          when Array   then @parser.binary(message)
          else false
        end
      end

      def ping(message = '', &callback)
        return false if @ready_state > OPEN
        @parser.ping(message, &callback)
      end

      def protocol
        @parser.protocol || ''
      end

      def close
        @ready_state = CLOSING if @ready_state == OPEN
        @parser.close
      end
    end

  end
end

