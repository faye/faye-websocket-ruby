module Faye
  class WebSocket
    
    module Adapter
      WEBSOCKET_RECEIVE_CALLBACK = 'websocket.receive_callback'.freeze
      
      def websocket?
        @env['HTTP_CONNECTION'] and
        @env['HTTP_CONNECTION'].split(/\s*,\s*/).include?('Upgrade') and
        ['WebSocket', 'websocket'].include?(@env['HTTP_UPGRADE'])
      end
    end
    
  end
end
