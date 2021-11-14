require "./spec_helper"

require "../src/hot_topic"
require "http"
require "json"

describe HotTopic do
  it "calls the HTTP::Handler" do
    client = HotTopic.new(EchoApp.new)
    response = client.get("/foo", headers: HTTP::Headers { "accept" => "application/json" })
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
end

class EchoApp
  include HTTP::Handler

  def call(context)
    request = context.request

    body = request.body
    body = body.gets_to_end if body.is_a? IO

    {
      method: request.method,
      path: request.path,
      headers: request.headers.to_h,
      body: body,
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
