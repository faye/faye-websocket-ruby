module Faye::WebSocket::API
  module EventTarget

    events = %w[open message error close]

    events.each do |event_type|
      define_method "on#{event_type}=" do |handler|
        EventMachine.next_tick do
          if buffer = @buffers && @buffers.delete(event_type)
            buffer.each { |event| handler.call(event) }
          end
          instance_variable_set("@on#{event_type}", handler)
        end
      end
    end

    def add_event_listener(event_type, listener, use_capture = false)
      @listeners ||= {}
      list = @listeners[event_type] ||= []
      list << listener
    end

    def remove_event_listener(event_type, listener, use_capture = false)
      return unless @listeners and @listeners[event_type]
      return @listeners.delete(event_type) unless listener

      @listeners[event_type].delete_if(&listener.method(:==))
    end

    def dispatch_event(event)
      event.target = event.current_target = self
      event.event_phase = Event::AT_TARGET

      callback = instance_variable_get("@on#{ event.type }")
      if callback
        callback.call(event)
      else
        @buffers ||= Hash.new { |k,v| k[v] = [] }
        @buffers[event.type].push(event)
      end

      return unless @listeners and @listeners[event.type]
      @listeners[event.type].each do |listener|
        listener.call(event)
      end
    end

  end
end

