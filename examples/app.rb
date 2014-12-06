require 'faye/websocket'
require 'permessage_deflate'
require 'rack'

static  = Rack::File.new(File.dirname(__FILE__))
options = {:extensions => [PermessageDeflate], :ping => 5}

App = lambda do |env|
  if Faye::WebSocket.websocket?(env)
    ws = Faye::WebSocket.new(env, ['irc', 'xmpp'], options)
    p [:open, ws.url, ws.version, ws.protocol]

    ws.onmessage = lambda do |event|
      ws.send(event.data)
    end

    ws.onclose = lambda do |event|
      p [:close, event.code, event.reason]
      ws = nil
    end

    ws.rack_response

  elsif Faye::EventSource.eventsource?(env)
    es   = Faye::EventSource.new(env)
    time = es.last_event_id.to_i

    p [:open, es.url, es.last_event_id]

    loop = EM.add_periodic_timer(2) do
      time += 1
      es.send("Time: #{time}")
      EM.add_timer(1) do
        es.send('Update!!', :event => 'update', :id => time) if es
      end
    end

    es.send("Welcome!\n\nThis is an EventSource server.")

    es.onclose = lambda do |event|
      EM.cancel_timer(loop)
      p [:close, es.url]
      es = nil
    end

    es.rack_response

  else
    static.call(env)
  end
end

def App.log(message)
end
