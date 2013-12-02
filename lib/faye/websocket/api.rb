require File.expand_path('../api/event_target', __FILE__)
require File.expand_path('../api/event', __FILE__)

module Faye
  class WebSocket

    module API
      CONNECTING = 0
      OPEN       = 1
      CLOSING    = 2
      CLOSED     = 3

      include EventTarget

      extend Forwardable
      def_delegators :@driver, :version

      attr_reader :url, :ready_state, :buffered_amount

      def initialize(options = {})
        super()

        if headers = options[:headers]
          headers.each { |name, value| @driver.set_header(name, value) }
        end

        @ping            = options[:ping]
        @ping_id         = 0
        @ready_state     = CONNECTING
        @buffered_amount = 0

        @driver.on(:open)    { |e| open }
        @driver.on(:message) { |e| receive_message(e.data) }
        @driver.on(:close)   { |e| finalize(e.reason, e.code) }

        @driver.on(:error) do |error|
          event = Event.new('error', :message => error.message)
          event.init_event('error', false, false)
          dispatch_event(event)
        end

        if @ping
          @ping_timer = EventMachine.add_periodic_timer(@ping) do
            @ping_id += 1
            ping(@ping_id.to_s)
          end
        end
      end

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
        @stream.close_connection_after_writing if @stream
        event = Event.new('close', :code => code || 1000, :reason => reason || '')
        event.init_event('close', false, false)
        dispatch_event(event)
      end

      def parse(data)
        @driver.parse(data)
      end

    public

      def write(data)
        @stream.write(data)
      end

      def send(message)
        return false if @ready_state > OPEN
        case message
          when Numeric then @driver.text(message.to_s)
          when String  then @driver.text(message)
          when Array   then @driver.binary(message)
          else false
        end
      end

      def ping(message = '', &callback)
        return false if @ready_state > OPEN
        @driver.ping(message, &callback)
      end

      def close
        @ready_state = CLOSING if @ready_state == OPEN
        @driver.close
      end

      def protocol
        @driver.protocol || ''
      end
    end

  end
end

