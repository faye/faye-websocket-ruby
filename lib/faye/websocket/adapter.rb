module Faye
  class WebSocket
    
    module Adapter
      def websocket?
        e = defined?(@env) ? @env : env
        
        e['HTTP_CONNECTION'] and
        e['HTTP_CONNECTION'].split(/\s*,\s*/).include?('Upgrade') and
        ['WebSocket', 'websocket'].include?(e['HTTP_UPGRADE'])
      end
    end
    
  end
end
