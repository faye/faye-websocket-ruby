# Run using your favourite async server:
#
#     thin start -R examples/config.ru -p 7000
#     rainbows -c spec/rainbows.conf -E production examples/config.ru -p 7000
#
# If you run using one of these commands, the webserver is loaded before this
# file, so Faye::WebSocket can figure out which adapter to load. If instead you
# run using `rackup`, you need the `load_adapter` line below.
#
#     rackup -E production -s thin examples/config.ru -p 7000

require 'rubygems'
require File.expand_path('../app', __FILE__)
# Faye::WebSocket.load_adapter('thin')

run App

