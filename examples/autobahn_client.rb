require 'bundler/setup'
require 'cgi'
require 'faye/websocket'
require 'permessage_deflate'
require 'progressbar'

EM.run {
  ruby    = RUBY_PLATFORM =~ /java/ ? 'jruby' : 'mri-ruby'
  version = defined?(RUBY_ENGINE_VERSION) ? RUBY_ENGINE_VERSION : RUBY_VERSION
  version += " (#{ RUBY_VERSION })" if ruby == 'jruby'

  host    = 'ws://0.0.0.0:9001'
  agent   = CGI.escape("#{ ruby }-#{ version }")
  cases   = 0
  options = { :extensions => [PermessageDeflate] }

  socket   = Faye::WebSocket::Client.new("#{ host }/getCaseCount")
  progress = nil

  socket.onmessage = lambda do |event|
    puts "Total cases to run: #{ event.data }"
    cases = event.data.to_i
    progress = ProgressBar.create(:title => 'Autobahn', :total => cases)
  end

  run_case = lambda do |n|
    if n > cases
      socket = Faye::WebSocket::Client.new("#{ host }/updateReports?agent=#{ agent }")
      socket.onclose = lambda { |e| EM.stop }
      next
    end

    url = "#{ host }/runCase?case=#{ n }&agent=#{ agent }"
    socket = Faye::WebSocket::Client.new(url, [], options)

    socket.onmessage = lambda do |event|
      socket.send(event.data)
    end

    socket.on :close do |event|
      progress.increment
      run_case[n + 1]
    end
  end

  socket.onclose = lambda do |event|
    run_case[1]
  end
}
