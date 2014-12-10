require 'sinatra'
require 'websocket'
require 'dotenv'
require 'slim'
require 'websocket-eventmachine-client'
require 'json'

require 'pry'
require 'pry-nav'
Dotenv.load

module Buffalo
  module Client
    @uid = ENV['UID']
    @subscribed = false
    def self.initiate_connection
      puts "  connecting!"
      WebSocket::EventMachine::Client.connect(:uri => "ws://#{ENV['HONDOMAIN']}/websocket?uid=#{@uid}")
    end

    def self.run
      EM.run do
        @ws = Buffalo::Client.initiate_connection

        @ws.onopen do
          puts "  * client connected."
        end

        @ws.onmessage do |msg, type|
          puts "Received message: #{msg}"
          json = JSON.parse(msg.to_s).first
          if json.first == 'authorization_token'
            @token = json[1]['data']['value']
            @ws.send [:identify, { uid: @uid, token: @token } ].to_json
            @ws.send [ 'websocket_rails.subscribe', { data: { channel: 'buffalo', user_id: @uid } } ].to_json
          elsif json.first == 'websocket_rails.channel_token'
            @channel_token ||= json[1]['data']['token']
            @subscribed = true
            @ws.send [ 'websocket_rails.subscribe', { channel: 'buffalo', data: { token: @channel_token, user_id: @uid } } ].to_json
          elsif json.first == 'websocket_rails.ping'
            @ws.send [ 'websocket_rails.pong', { id: nil } ].to_json
          end
        end

        @ws.onclose do |code, reason|
          puts "Disconnected with status code: #{code}."
          puts "  sleeping..."
          @ws.close
          
          sleep(2)
          EM.stop
          exit
          Buffalo::Client.run
        end
      end
    end
  end
end




get '/' do
  @handshake = nil
  # @handshake.to_s
  slim :index
end

Buffalo::Client.run