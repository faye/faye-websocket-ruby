require "spec_helper"

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
end
