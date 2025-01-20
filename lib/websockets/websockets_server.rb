require 'faye/websocket'
require 'json'

class WebSocketServer

  def initialize(app)
    @app = app
    @clients = Hash.new { |h, k| h[k] = [] }
  end

  def subscribe(channel, env)
    if Faye::WebSocket.websocket?(env)
      ws = Faye::WebSocket.new(env)

      ws.on :open do |event|
        puts 'WebSocket connection opened'
        @clients[channel] ||= []
        @clients[channel] << ws
      end

      ws.on :message do |event|
      end

      ws.on :close do |event|
        puts 'WebSocket connection closed'
        @clients.delete(channel)
        ws = nil
      end

      ws.rack_response
    else
      @app.call(env)
    end
  end

  def unsubscribe(channel)
    @clients[channel].each { |socket| socket.close}
  end

  def broadcast(channel, message)
    @clients[channel].each { |socket| socket.send(message)}
  end

end
