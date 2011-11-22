# encoding=utf-8

require "spec_helper"

WebSocketSteps = EM::RSpec.async_steps do
  def server(port, &callback)
    @server = EchoServer.new
    @server.listen(port)
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
  
  before do
    Thread.new { EM.run }
    sleep(0.1) until EM.reactor_running?

    server 8000
    sync
  end
  
  after { sync ; stop }
  
  it "can open a connection" do
    open_socket "ws://localhost:8000/"
    check_open
  end
  
  it "can close the connection" do
    open_socket "ws://localhost:8000/"
    close_socket
    check_closed
  end
  
  describe "in the OPEN state" do
    before { open_socket "ws://localhost:8000/" }
    
    it "can send and receive messages" do
      listen_for_message
      send_message
      check_response
    end
  end
  
  describe "in the CLOSED state" do
    before do
      open_socket "ws://localhost:8000/"
      close_socket
    end
    
    it "cannot send and receive messages" do
      listen_for_message
      send_message
      check_no_response
    end
  end
end

