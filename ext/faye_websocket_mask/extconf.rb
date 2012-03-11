return if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby'

require 'mkmf'
extension_name = 'faye_websocket_mask'
dir_config(extension_name)
create_makefile(extension_name)
