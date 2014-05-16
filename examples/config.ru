# Run using your favourite server:
#
#     thin start -R examples/config.ru -p 7000
#     rainbows -c examples/rainbows.conf -E production examples/config.ru -p 7000

require 'rubygems'
require 'bundler/setup'
require File.expand_path('../app', __FILE__)

Faye::WebSocket.load_adapter('thin')
Faye::WebSocket.load_adapter('rainbows')

run App
