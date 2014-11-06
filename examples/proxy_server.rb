require 'rubygems'
require 'bundler/setup'
require 'eventmachine'
require 'websocket/driver'

require File.expand_path('../../spec/proxy_server', __FILE__)

port   = ARGV[0]
secure = ARGV[1] == 'tls'

EM.run {
  proxy = ProxyServer.new(:debug => true)
  proxy.listen(port, secure)
}
