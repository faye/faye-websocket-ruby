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
        ::WebSocket::Driver.validate_options(options, [:headers, :extensions, :max_length, :ping, :proxy, :tls])

        if headers = options[:headers]
          headers.each { |name, value| @driver.set_header(name, value) }
        end

        [*options[:extensions]].each do |extension|
          @driver.add_extension(extension)
        end

        @ping            = options[:ping]
        @ping_id         = 0
        @ready_state     = CONNECTING
        @buffered_amount = 0

        @driver.on(:open)    { |e| open }
        @driver.on(:message) { |e| receive_message(e.data) }
        @driver.on(:close)   { |e| begin_close(e.reason, e.code) }

        @driver.on(:error) do |error|
          emit_error(error.message)
        end

        if @ping
          @ping_timer = EventMachine.add_periodic_timer(@ping) do
            @ping_id += 1
            ping(@ping_id.to_s)
          end
        end
      end

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
        @ready_state = CLOSING unless @ready_state == CLOSED
        @driver.close
      end

      def protocol
        @driver.protocol || ''
      end

    private

      def open
        return unless @ready_state == CONNECTING
        @ready_state = OPEN
        event = Event.create('open')
        event.init_event('open', false, false)
        dispatch_event(event)
      end

      def receive_message(data)
        return unless @ready_state == OPEN
        event = Event.create('message', :data => data)
        event.init_event('message', false, false)
        dispatch_event(event)
      end

      def emit_error(message)
        return if @ready_state >= CLOSING

        event = Event.create('error', :message => message)
        event.init_event('error', false, false)
        dispatch_event(event)
      end

      def begin_close(reason, code)
        return if @ready_state == CLOSED
        @ready_state = CLOSING

        if @stream
          @stream.close_connection_after_writing
        else
          finalize_close
        end
        @close_params = [reason, code]
      end

      def finalize_close
        return if @ready_state == CLOSED
        @ready_state = CLOSED

        EventMachine.cancel_timer(@ping_timer) if @ping_timer

        reason = @close_params ? @close_params[0] : ''
        code   = @close_params ? @close_params[1] : 1006

        event = Event.create('close', :code => code, :reason => reason)
        event.init_event('close', false, false)
        dispatch_event(event)
      end

      def parse(data)
        worker = @proxy || @driver
        worker.parse(data)
      end
    end

  end
end
