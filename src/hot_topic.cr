require "http"

module HotTopic
  VERSION = "0.1.0"

  def self.new(app)
    Client.new(app)
  end

  def self.new(&block : HTTP::Server::Context -> Nil)
    Client.new(block)
  end

  class Client(T) < HTTP::Client
    # These ivars are required by HTTP::Client but we don't need them so we set
    # them to whatever.
    @host = ""
    @port = -1

    def initialize(@app : T)
    end

    def exec_internal(request : HTTP::Request) : HTTP::Client::Response
      buffer = IO::Memory.new
      response = HTTP::Server::Response.new(buffer)
      context = HTTP::Server::Context.new(request, response)

      @app.call(context)
      response.close

      HTTP::Client::Response.from_io(buffer.rewind)
    end

    def exec_internal(request : HTTP::Request)
      buffer = IO::Memory.new
      response = HTTP::Server::Response.new(buffer)
      context = HTTP::Server::Context.new(request, response)

      @app.call(context)
      response.close

      yield HTTP::Client::Response.from_io(buffer.rewind)
    end
  end
end
