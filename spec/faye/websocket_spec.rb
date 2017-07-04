require "spec_helper"
require "socket"

describe Faye::WebSocket do
  it "can start the reactor" do
    expect(EventMachine.reactor_running?).to be(false)

    env = Rack::MockRequest.env_for(
      "/",
      "HTTP_HOST" => "localhost",
      "HTTP_CONNECTION" => "Upgrade",
      "HTTP_UPGRADE" => "websocket"
    )
    ws = Faye::WebSocket.new(env, nil)

    expect(EventMachine.reactor_running?).to be(true)
    expect(ws.rack_response).to eq([ -1, {}, [] ])
  end

  it "can handle the reactor stopping during rack hijack" do
    expect(EventMachine.reactor_running?).to be(false)

    # The "rack.hijack" callback is called from RackStream#hijack_rack_socket,
    # so we'll use it here as a timely hook to cause the next EM run loop to
    # stop the reactor - but not before RackStream#hijack_rack_socket has
    # scheduled its own work for the next EM tick.
    hijack_proc = ->() do
      expect(EventMachine.reactor_running?).to be(true)

      EventMachine.next_tick do
        raise "error"
      end
    end

    env = Rack::MockRequest.env_for(
      "/",
      "HTTP_HOST" => "localhost",
      "HTTP_CONNECTION" => "Upgrade",
      "HTTP_UPGRADE" => "websocket",

      "rack.hijack" => hijack_proc,
      "rack.hijack_io" => Socket.new(:UNIX, :STREAM)
    )

    Timeout.timeout(1, Timeout::Error) do
      Faye::WebSocket.new(env, nil)
    end
  end
end
