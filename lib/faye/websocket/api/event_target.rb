module Faye::WebSocket::API
  module EventTarget

    include ::WebSocket::Driver::EventEmitter
    events = %w[open message error close]

    events.each do |event_type|
      define_method "on#{event_type}=" do |handler|
        EventMachine.next_tick do
          flush(event_type, &handler)
          instance_variable_set("@on#{event_type}", handler)
        end
      end
    end

    def add_event_listener(event_type, listener, use_capture = false)
      add_listener(event_type, &listener)
    end

    def add_listener(event_type, &listener)
      EventMachine.next_tick do
        flush(event_type, &listener)
        super(event_type, &listener)
      end
    end

    def remove_event_listener(event_type, listener, use_capture = false)
      remove_listener(event_type, &listener)
    end

    def dispatch_event(event)
      event.target = event.current_target = self
      event.event_phase = Event::AT_TARGET

      callback = instance_variable_get("@on#{ event.type }")
      count    = listener_count(event.type)

      unless callback or count > 0
        @buffers ||= Hash.new { |k,v| k[v] = [] }
        @buffers[event.type].push(event)
      end

      callback.call(event) if callback
      emit(event.type, event)
    end

  private

    def flush(event_type, &callback)
      if buffer = @buffers && @buffers.delete(event_type.to_s)
        buffer.each { |event| callback.call(event) }
      end
    end

  end
end
