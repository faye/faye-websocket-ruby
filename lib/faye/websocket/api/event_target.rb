module Faye::WebSocket::API
  module EventTarget

    include ::WebSocket::Protocol::EventEmitter
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
      on(event_type, &listener)
    end

    def remove_event_listener(event_type, listener, use_capture = false)
      remove_listener(event_type, &listener)
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

      emit(event.type, event)
    end

  end
end

