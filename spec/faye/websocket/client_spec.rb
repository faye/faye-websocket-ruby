# encoding=utf-8

require "spec_helper"

WebSocketSteps = EM::RSpec.async_steps do
  def server(port, backend, secure, &callback)
    @server = EchoServer.new
    @server.listen(port, backend, secure)
    @port = port
    EM.add_timer(0.1, &callback)
  end

  def stop(&callback)
    @server.stop
    EM.next_tick(&callback)
  end

  def open_socket(url, protocols, &callback)
    done = false

    resume = lambda do |open|
      unless done
        done = true
        @open = open
        callback.call
      end
    end

    @ws = Faye::WebSocket::Client.new(url, protocols)

    @ws.onopen  = lambda { |e| resume.call(true) }
    @ws.onclose = lambda { |e| resume.call(false) }
  end

  def close_socket(&callback)
    @ws.onclose = lambda do |e|
      @open = false
      callback.call
    end
    @ws.close
  end

  def check_open(&callback)
    @open.should == true
    callback.call
  end

  def check_closed(&callback)
    @open.should == false
    callback.call
  end

  def check_protocol(protocol, &callback)
    @ws.protocol.should == protocol
    callback.call
  end

  def listen_for_message(&callback)
    @ws.add_event_listener('message', lambda { |e| @message = e.data })
    callback.call
  end

  def send_message(message, &callback)
    @ws.send(message)
    EM.add_timer(0.1, &callback)
  end

  def check_response(message, &callback)
    @message.should == message
    callback.call
  end

  def check_no_response(&callback)
    @message.should == nil
    callback.call
  end
end

describe Faye::WebSocket::Client do
  next if Faye::WebSocket.jruby?
  include WebSocketSteps

  let(:protocols)      { ["foo", "echo"]       }
  let(:plain_text_url) { "ws://0.0.0.0:8000/"  }
  let(:secure_url)     { "wss://0.0.0.0:8000/" }

  shared_examples_for "socket client" do
    it "can open a connection" do
      open_socket(socket_url, protocols)
      check_open
      check_protocol("echo")
    end

    it "cannot open a connection to the wrong host" do
      open_socket(blocked_url, protocols)
      check_closed
    end

    it "cannot open a connection with unacceptable protocols" do
      open_socket(socket_url, ["foo"])
      check_closed
    end

    it "can close the connection" do
      open_socket(socket_url, protocols)
      close_socket
      check_closed
    end

    describe "in the OPEN state" do
      before { open_socket(socket_url, protocols) }

      it "can send and receive messages" do
        listen_for_message
        send_message "I expect this to be echoed"
        check_response "I expect this to be echoed"
      end

      it "sends numbers as strings" do
        listen_for_message
        send_message 13
        check_response "13"
      end
    end

    describe "in the CLOSED state" do
      before do
        open_socket(socket_url, protocols)
        close_socket
      end

      it "cannot send and receive messages" do
        listen_for_message
        send_message "I expect this to be echoed"
        check_no_response
      end
    end
  end

  describe "with a plain-text Thin server" do
    let(:socket_url)  { plain_text_url }
    let(:blocked_url) { secure_url }

    before { server 8000, :thin, false }
    after  { stop }

    it_should_behave_like "socket client"
  end

  describe "with a secure Thin server" do
    next if Faye::WebSocket.rbx?

    let(:socket_url)  { secure_url }
    let(:blocked_url) { plain_text_url }

    before { server 8000, :thin, true }
    after  { stop }

    it_should_behave_like "socket client"
  end
end

