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
    require 'sinatra'
    @uid = ENV['BUFFALO_UID']
    @subscribed = false
    @@VERSION = "0.0.0.1"

    def self.initiate_connection
      puts "  connecting!"
      WebSocket::EventMachine::Client.connect(:uri => "ws://#{ENV['HONDOMAIN']}/websocket?uid=#{@uid}")
    end

    def self.login_url
      "#{ENV['HONDOPROTOCOL']}://#{ENV['HONDOMAIN']}/login?uid=#{@uid}"
    end

    def self.logout_url
      "#{ENV['HONDOPROTOCOL']}://#{ENV['HONDOMAIN']}/users/sign_out?uid=#{@uid}"
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
            @ws.send [:identify, { uid: @uid, token: @token, version: @@VERSION } ].to_json
            @ws.send [ 'websocket_rails.subscribe', { data: { channel: 'buffalo', user_id: @uid } } ].to_json
          elsif json.first == 'websocket_rails.channel_token'
            @channel_token ||= json[1]['data']['token']
            @subscribed = true
            @ws.send [ 'websocket_rails.subscribe', { channel: 'buffalo', token: @channel_token, data: { token: @channel_token, user_id: @uid } } ].to_json
          elsif json.first == 'websocket_rails.ping'
            puts " reply: pong"
            @ws.send [ 'websocket_rails.pong', { id: nil } ].to_json
          end
        end

        @ws.onclose do |code, reason|
          puts "Disconnected with status code: #{code}."
          puts "  sleeping..."
          @ws.close
          
          # sleep(2)
          # EM.stop
          # exit
          # Buffalo::Client.run
        end
      end

      EM.next_tick do
        # Fiber.new {
        #   Synchronization.synchronize!
        #   EM.add_shutdown_hook { Synchronization.shutdown! }
        # }.resume
        puts "*** RECONNECT ????"
      end
    end
  end
end
def logged_in?
  !@current_user.nil?
end

# Buffalo::Client.run

get '/' do
  unless logged_in?
    redirect Buffalo::Client.login_url, 303
  else
    @response = Buffalo::Client.run
  end
  slim :index
end

