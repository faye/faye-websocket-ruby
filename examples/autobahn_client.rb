require 'rubygems'
require 'bundler/setup'
require 'cgi'
require 'faye/websocket'
require 'permessage_deflate'
require 'progressbar'

EM.run {
  host    = 'ws://localhost:9001'
  ruby    = RUBY_PLATFORM =~ /java/ ? 'jruby' : 'cruby'
  agent   = CGI.escape("#{ruby}-#{RUBY_VERSION}")
  cases   = 0
  options = {:extensions => [PermessageDeflate]}

  socket   = Faye::WebSocket::Client.new("#{host}/getCaseCount")
  progress = nil

  socket.onmessage = lambda do |event|
    puts "Total cases to run: #{event.data}"
    cases = event.data.to_i
    progress = ProgressBar.new('Autobahn', cases)
  end

  run_case = lambda do |n|
    if n > cases
      socket = Faye::WebSocket::Client.new("#{host}/updateReports?agent=#{agent}")
      progress.finish
      socket.onclose = lambda { |e| EM.stop }
      next
    end

    url = "#{host}/runCase?case=#{n}&agent=#{agent}"
    socket = Faye::WebSocket::Client.new(url, nil, options)

    socket.onmessage = lambda do |event|
      socket.send(event.data)
    end

    socket.on :close do |event|
      progress.inc
      run_case[n + 1]
    end
  end

  socket.onclose = lambda do |event|
    run_case[1]
  end
}
