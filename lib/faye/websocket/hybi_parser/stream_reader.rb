module Faye
  class WebSocket
    class HybiParser

      class StreamReader
        def initialize
          @queue = []
        end

        def read(length)
          read_bytes(length)
        end

        def put(bytes)
          return unless bytes and bytes.size > 0
          @queue.concat(bytes)
        end

      private

        def read_bytes(length)
          return nil if length > @queue.size
          @queue.shift(length)
        end
      end

    end
  end
end
