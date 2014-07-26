require 'sinatra'
require 'websocket'
require 'dotenv'
Dotenv.load

get '/' do
  @handshake = WebSocket::Handshake::Client.new(url: "ws://#{ENV['HONDOMAIN']}/websocket", headers: { 'Cookie' => 'BUFFALOID=1' })

  # Create request
	@handshake.to_s

	@handshake.inspect
end
