module Faye::WebSocket::API
  class Event

    attr_reader   :type, :bubbles, :cancelable
    attr_accessor :target, :current_target, :event_phase, :data, :message

    CAPTURING_PHASE = 1
    AT_TARGET       = 2
    BUBBLING_PHASE  = 3

    def initialize(event_type, options = {})
      @type = event_type
      metaclass = (class << self ; self ; end)
      options.each do |key, value|
        metaclass.__send__(:define_method, key) { value }
      end
    end

    def init_event(event_type, can_bubble, cancelable)
      @type       = event_type
      @bubbles    = can_bubble
      @cancelable = cancelable
    end

    def stop_propagation
    end

    def prevent_default
    end

  end
end

