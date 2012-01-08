class Goliath::Connection
  attr_accessor :web_socket
  alias :goliath_receive_data :receive_data
  
  def receive_data(data)
    if @serving == :websocket
      web_socket.receive(data) if web_socket
    else
      goliath_receive_data(data)
      web_socket.receive(@parser.upgrade_data) if web_socket
      @serving = :websocket if @api.websocket?
    end
  end
  
  def unbind
    super
  ensure
    web_socket.fail if web_socket
  end
end

class Goliath::API
  include Faye::WebSocket::Adapter
end

class Goliath::Request
  alias :goliath_process :process
  
  def process
    env['em.connection'] = conn
    goliath_process
  end
end

class Goliath::Response
  alias :goliath_head :head
  alias :goliath_headers_output :headers_output
  
  def head
    (status == 101) ? '' : goliath_head
  end
  
  def headers_output
    (status == 101) ? '' : goliath_headers_output
  end
end

