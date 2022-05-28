require "./spec_helper"

require "../src/hot_topic"
require "http"
require "json"

describe HotTopic do
  it "calls the HTTP::Handler" do
    client = HotTopic.new(EchoApp.new)
    response = client.get("/foo", headers: HTTP::Headers{"accept" => "application/json"})
    echo_response = EchoApp::JSONResponse.from_json(response.body)

    response.should be_a HTTP::Client::Response
    response.status.code.should eq 200
    echo_response.path.should eq "/foo"
    echo_response.headers["accept"].should eq ["application/json"]
  end

  # This example makes an affordance for 2 cases:
  # 1. HTTP::Server.new { |context| block content here }
  # 2. A simplified version of your middleware without having to create a class
  it "can receive a block in place of an HTTP::Handler" do
    client = HotTopic.new do |context|
      EchoApp.new.call context
    end

    EchoApp::JSONResponse.from_json(client.get("/json").body).path.should eq "/json"
  end

  it "establishes a websocket" do
    client = HotTopic.new(WebSocketEchoApp.new)
    websocket = client.establish_ws("/echo/websocket")

    result = "failed"
    websocket.on_message do |message|
      result = message
      websocket.close
    end
    websocket.send "hello"
    websocket.run
    result.should eq("hello")
  end
end

class EchoApp
  include HTTP::Handler

  def call(context)
    request = context.request

    body = request.body
    body = body.gets_to_end if body.is_a? IO

    {
      method:  request.method,
      path:    request.path,
      headers: request.headers.to_h,
      body:    body,
    }.to_json context.response
  end

  struct JSONResponse
    include JSON::Serializable

    getter method : String
    getter path : String
    getter headers : Hash(String, Array(String))
    getter body : String?
  end
end

class WebSocketEchoApp
  include HTTP::Handler

  def call(context)
    request = context.request
    response = context.response

    if request.headers.includes_word?("Connection", "Upgrade")
      key = request.headers["Sec-Websocket-Key"]

      accept_code = Base64.strict_encode(OpenSSL::SHA1.hash("#{key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))

      response.status = HTTP::Status::SWITCHING_PROTOCOLS
      response.headers["Upgrade"] = "websocket"
      response.headers["Connection"] = "Upgrade"
      response.headers["Sec-Websocket-Accept"] = accept_code
      response.upgrade do |io|
        begin
          # basic websocket echo server
          socket = HTTP::WebSocket.new(io)
          socket.on_message do |message|
            socket.send(message)
          end
          socket.run
        ensure
          io.close
        end
      end
    else
      response.status = HTTP::Status::UPGRADE_REQUIRED
      response.content_type = "text/plain"
      response << "This service requires use of the WebSocket protocol"
    end
  end
end
