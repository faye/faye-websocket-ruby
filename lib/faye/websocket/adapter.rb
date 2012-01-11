module Faye
  class WebSocket
    
    module Adapter
      def websocket?
        e = defined?(@env) ? @env : env
        WebSocket.web_socket?(e)
      end
      
      def eventsource?
        e = defined?(@env) ? @env : env
        EventSource.event_source?(e)
      end
    end
    
  end
end
