module Faye::WebSocket::API
  module EventTarget

    include ::WebSocket::Driver::EventEmitter
    attr_accessor :onopen, :onmessage, :onerror, :onclose

    def add_event_listener(event_type, listener, use_capture = false)
      add_listener(event_type, &listener)
    end

    def remove_event_listener(event_type, listener, use_capture = false)
      remove_listener(event_type, &listener)
    end

    def dispatch_event(event)
      event.target = event.current_target = self
      event.event_phase = Event::AT_TARGET

      callback = instance_variable_get("@on#{ event.type }")

      callback.call(event) if callback
      emit(event.type, event)
    end

  end
end

