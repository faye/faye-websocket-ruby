# encoding=utf-8

require "spec_helper"
require "socket"

IS_JRUBY = (defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby')

WebSocketSteps = RSpec::EM.async_steps do
  def server(port, backend, secure, &callback)
    @echo_server = EchoServer.new
    @echo_server.listen(port, backend, secure)
    EM.add_timer(0.1, &callback)
  end

  def stop(&callback)
    @echo_server.stop
    EM.next_tick(&callback)
  end

  def proxy(port, &callback)
    @proxy_server = ProxyServer.new
    @proxy_server.listen(port)
    EM.add_timer(0.1, &callback)
  end

  def stop_proxy(&callback)
    @proxy_server.stop
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

    @ws = Faye::WebSocket::Client.new(url, protocols, :proxy => { :origin => proxy_url }, :tls => tls_options)

    @ws.on(:open) { |e| resume.call(true) }
    @ws.onclose = lambda { |e| resume.call(false) }
  end

  def open_socket_and_close_it_fast(url, protocols, &callback)
    @ws = Faye::WebSocket::Client.new(url, protocols, :tls => tls_options)

    @ws.on(:open) { |e| @open = @ever_opened = true }
    @ws.onclose = lambda { |e| @open = false }

    @ws.close

    callback.call
  end

  def close_socket(&callback)
    @ws.onclose = lambda do |e|
      @open = false
      callback.call
    end
    @ws.close
  end

  def check_open(status, headers, &callback)
    expect(@open).to be(true)
    expect(@ws.status).to eq(status)
    headers.each do |name, value|
      expect(@ws.headers[name]).to eq(value)
    end
    callback.call
  end

  def check_closed(&callback)
    expect(@open).to be(false)
    callback.call
  end

  def check_never_opened(&callback)
    expect(!!@ever_opened).to be(false)
    callback.call
  end

  def check_protocol(protocol, &callback)
    expect(@ws.protocol).to eq(protocol)
    callback.call
  end

  def listen_for_message(&callback)
    @ws.add_event_listener('message', lambda { |e| @message = e.data })
    start = Time.now
    timer = EM.add_periodic_timer 0.1 do
      if @message or Time.now.to_i - start.to_i > 5
        EM.cancel_timer(timer)
        callback.call
      end
    end
  end

  def send_message(message, &callback)
    EM.add_timer(0.5) { @ws.send(message) }
    EM.next_tick(&callback)
  end

  def check_response(message, &callback)
    expect(@message).to eq(message)
    callback.call
  end

  def check_no_response(&callback)
    expect(@message).to eq(nil)
    callback.call
  end

  def wait(seconds, &callback)
    EM.add_timer(seconds, &callback)
  end
end

describe Faye::WebSocket::Client do
  include WebSocketSteps

  let(:protocols)      { ["foo", "echo"] }

  let(:localhost)      { "localhost" }
  let(:port)           { 4180 }
  let(:plain_text_url) { "ws://#{ localhost }:#{ port }/" }
  let(:wrong_url)      { "ws://#{ localhost }:9999/" }
  let(:secure_url)     { "wss://#{ localhost }:#{ port }/" }

  let :tls_options do
    { :root_cert_file => File.expand_path('../../../server.crt', __FILE__) }
  end

  shared_examples_for "socket client" do
    before do
      @ever_opened = @message = nil
    end

    it "can open a connection" do
      open_socket(socket_url, protocols)
      check_open(101, { "Upgrade" => "websocket" })
      check_protocol("echo")
    end

    it "cannot open a connection to the wrong host" do
      open_socket(blocked_url, protocols)
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
        send_message "I expect this to be echoed"
        listen_for_message
        check_response "I expect this to be echoed"
      end

      it "sends numbers as strings" do
        send_message 13
        listen_for_message
        check_response "13"
      end
    end

    describe "in the CLOSED state" do
      before do
        open_socket(socket_url, protocols)
        close_socket
      end

      it "cannot send and receive messages" do
        send_message "I expect this to be echoed"
        listen_for_message
        check_no_response
      end
    end

    it "can be closed before connecting" do
      open_socket_and_close_it_fast(socket_url, protocols)
      wait 0.01
      check_closed
      check_never_opened
    end
  end

  shared_examples_for "socket server" do
    describe "with a Puma server" do
      let(:localhost)   { "0.0.0.0" }
      let(:socket_url)  { plain_text_url }
      let(:blocked_url) { wrong_url }

      before { server port, :puma, false }
      after  { stop }

      it_should_behave_like "socket client"
    end

    describe "with a plain-text Thin server" do
      next if IS_JRUBY

      let(:socket_url)  { plain_text_url }
      let(:blocked_url) { secure_url }

      before { server port, :thin, false }
      after  { stop }

      it_should_behave_like "socket client"
    end

    describe "with a secure Thin server" do
      next if IS_JRUBY

      let(:socket_url)  { secure_url }
      let(:blocked_url) { plain_text_url }

      before { server port, :thin, true }
      after  { stop }

      it_should_behave_like "socket client"
    end
  end

  describe "with no proxy" do
    let(:proxy_url) { nil }
    it_should_behave_like "socket server"
  end

  describe "with a proxy" do
    let(:proxy_port) { 4181 }
    let(:proxy_url)  { "http://localhost:#{ proxy_port }" }

    next if IS_JRUBY

    before { proxy proxy_port }
    after  { stop_proxy }

    it_should_behave_like "socket server"
  end
end
