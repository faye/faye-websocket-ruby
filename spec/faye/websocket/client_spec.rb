# encoding=utf-8

require "spec_helper"

WebSocketSteps = EM::RSpec.async_steps do
  def server(port, secure, &callback)
    @server = EchoServer.new
    @server.listen(port, secure)
    @port = port
    EM.add_timer(0.1, &callback)
  end
  
  def stop(&callback)
    @server.stop
    EM.next_tick(&callback)
  end
  
  def open_socket(url, &callback)
    done = false
    
    resume = lambda do |open|
      unless done
        done = true
        @open = open
        callback.call
      end
    end
    
    @ws = Faye::WebSocket::Client.new(url)
    
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
  
  def listen_for_message(&callback)
    @ws.onmessage = lambda { |e| @message = e.data }
    callback.call
  end
  
  def send_message(&callback)
    @ws.send("I expect this to be echoed")
    EM.add_timer(0.1, &callback)
  end
  
  def check_response(&callback)
    @message.should == "I expect this to be echoed"
    callback.call
  end
  
  def check_no_response(&callback)
    @message.should == nil
    callback.call
  end
end

describe Faye::WebSocket::Client do
  include WebSocketSteps
  
  let(:plain_text_url) { "ws://0.0.0.0:8000/"  }
  let(:secure_url)     { "wss://0.0.0.0:8000/" }
  
  before do
    Thread.new { EM.run }
    sleep(0.1) until EM.reactor_running?
  end
  
  shared_examples_for "socket client" do
    it "can open a connection" do
      open_socket(socket_url)
      check_open
    end
    
    it "cannot open a connection to the wrong host" do
      open_socket(blocked_url)
      check_closed
    end
    
    it "can close the connection" do
      open_socket(socket_url)
      close_socket
      check_closed
    end
    
    describe "in the OPEN state" do
      before { open_socket(socket_url) }
      
      it "can send and receive messages" do
        listen_for_message
        send_message
        check_response
      end
    end
    
    describe "in the CLOSED state" do
      before do
        open_socket(socket_url)
        close_socket
      end
      
      it "cannot send and receive messages" do
        listen_for_message
        send_message
        check_no_response
      end
    end
  end
  
  describe "with a plain-text server" do
    let(:socket_url)  { plain_text_url }
    let(:blocked_url) { secure_url }
    
    before { server 8000, false }
    after  { sync ; stop }
    
    it_should_behave_like "socket client"
  end
  
  describe "with a secure server" do
    let(:socket_url)  { secure_url }
    let(:blocked_url) { plain_text_url }
    
    before { server 8000, true }
    after  { sync ; stop }
    
    it_should_behave_like "socket client"
  end
end

