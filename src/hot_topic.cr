require "http/client"
require "log"

module HotTopic
  VERSION = "0.1.0"

  def self.new(app)
    Client.new(app)
  end

  def self.new(&block : HTTP::Server::Context -> Nil)
    Client.new(block)
  end

  class Client(T) < HTTP::Client
    getter app : T
    getter app_name : String
    @log : ::Log

    # These ivars are required by HTTP::Client but we don't need them so we set
    # them to whatever.
    @host = ""
    @port = -1

    def initialize(@app, @app_name = app.class.name, *, @log = ::Log.for(HotTopic))
    end

    protected def around_exec(request, &)
      @log.debug &.emit "request",
        app: app_name,
        method: request.method,
        resource: request.resource

      yield
    end

    private def exec_internal(request : HTTP::Request) : HTTP::Client::Response
      buffer = IO::Memory.new
      response = HTTP::Server::Response.new(buffer)
      context = HTTP::Server::Context.new(request, response)

      @app.call(context)
      response.close

      HTTP::Client::Response.from_io(buffer.rewind)
    end

    private def exec_internal(request : HTTP::Request, & : HTTP::Client::Response -> T) : T forall T
      buffer = IO::Memory.new
      response = HTTP::Server::Response.new(buffer)
      context = HTTP::Server::Context.new(request, response)

      @app.call(context)
      response.close

      if r = HTTP::Client::Response.from_io(buffer.rewind) { |response| yield response }
        r
      else
        yield HTTP::Client::Response.new(
          status: response.status,
          status_message: response.status_message,
          headers: response.headers,
          version: response.version,
          body_io: response.output.as(HTTP::Server::Response::Output).@io,
        )
      end
    end
  end
end
