# WebSocket extensions for Rainbows
# Based on code from the Cramp project
# http://github.com/lifo/cramp

# Copyright (c) 2009-2011 Pratik Naik
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

module Faye
  class WebSocket
    
    class RainbowsClient < Rainbows::EventMachine::Client
      include Faye::WebSocket::Adapter
      attr_accessor :web_socket
      
      def receive_data(data)
        case @state
        when :websocket
          callback = @env[WEBSOCKET_RECEIVE_CALLBACK]
          callback.call(data) if callback
        else
          super
        end
      end
      
      def on_read(data)
        if @state == :headers
          @hp.add_parse(data) or return want_more
          @state = :body
          if 0 == @hp.content_length && !websocket?
            app_call NULL_IO # common case
          else # nil or len > 0
            prepare_request_body
          end
        elsif @state == :body && websocket? && @hp.body_eof?
          @state = :websocket
          @input.rewind
          @env['em.connection'] = self
          app_call StringIO.new(@buf)
        else
          super
        end
      rescue => e
        handle_error(e)
      end
      
      def unbind
        super
      ensure
        web_socket.fail if web_socket
      end
      
      def write_response(status, headers, body, alive)
        write_headers(status, headers, alive) unless websocket?
        write_body_each(body)
      ensure
        body.close if body.respond_to?(:close)
      end
    end
    
  end
end
