module Faye::WebSocket::API
  module EventTarget

    attr_accessor :onopen, :onmessage, :onerror, :onclose

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

      callback = __send__("on#{ event.type }")
      callback.call(event) if callback

      return unless @listeners and @listeners[event.type]
      @listeners[event.type].each do |listener|
        listener.call(event)
      end
    end

  end
end

