# This file is only loaded and used when on JRuby, to avoid
# depending on a C extension on that platform.

module Faye
  class WebSocket
    module Mask
      def self.mask(payload, mask)
        unmasked = []
        payload.each_with_index do |byte, i|
          byte = byte ^ mask[i % 4] if mask.size > 0
          unmasked << byte
        end
        unmasked
      end
    end
  end
end
