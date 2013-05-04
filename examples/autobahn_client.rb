require 'rubygems'
require 'bundler/setup'
require 'faye/websocket'
require 'cgi'
require 'progressbar'

EM.run {
  host  = 'ws://localhost:9001'
  ruby  = RUBY_PLATFORM =~ /java/ ? 'JRuby' : 'MRI'
  agent = "#{ruby} #{RUBY_VERSION}"
  cases = 0
  skip  = []

  socket   = Faye::WebSocket::Client.new("#{host}/getCaseCount")
  progress = nil

  socket.onmessage = lambda do |event|
    puts "Total cases to run: #{event.data}"
    cases = event.data.to_i
    progress = ProgressBar.new('Autobahn', cases)
  end

  socket.onclose = lambda do |event|
    run_case = lambda do |n|
      progress.inc

      if n > cases
        socket = Faye::WebSocket::Client.new("#{host}/updateReports?agent=#{CGI.escape agent}")
        progress.finish
        socket.onclose = lambda { |e| EM.stop }

      elsif skip.include?(n)
        EM.next_tick { run_case.call(n+1) }

      else
        socket = Faye::WebSocket::Client.new("#{host}/runCase?case=#{n}&agent=#{CGI.escape agent}")

        socket.onmessage = lambda do |event|
          socket.send(event.data)
        end

        socket.on :close do |event|
          run_case.call(n + 1)
        end
      end
    end

    run_case.call(1)
  end
}

