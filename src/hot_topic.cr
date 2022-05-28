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

    def establish_ws(uri : URI | String, headers = HTTP::Headers.new) : HTTP::WebSocket
      # build bi-directional io
      local_read, remote_write = IO.pipe
      remote_read, local_write = IO.pipe
      local_io = IO::Stapled.new(local_read, local_write)
      remote_io = IO::Stapled.new(remote_read, remote_write)
  
      # immitate HTTP::WebSocket::Protocol.new
      begin
        random_key = Base64.strict_encode(StaticArray(UInt8, 16).new { rand(256).to_u8 })
  
        headers["Connection"] = "Upgrade"
        headers["Upgrade"] = "websocket"
        headers["Sec-WebSocket-Version"] = HTTP::WebSocket::Protocol::VERSION
        headers["Sec-WebSocket-Key"] = random_key
  
        case uri
        in URI
          if (user = uri.user) && (password = uri.password)
            headers["Authorization"] ||= "Basic #{Base64.strict_encode("#{user}:#{password}")}"
          end
          path = uri.request_target
        in String
          path = uri
        end
  
        handshake = HTTP::Request.new("GET", path, headers)
        response = HTTP::Server::Response.new(remote_io)
        context = HTTP::Server::Context.new(handshake, response)
        context.response.output = remote_io
  
        # emulate the upgrade request processing
        # needs to be in seperate fiber for bidirectional blocking IO
        spawn do
          @app.call(context)
          if upgrade_handler = response.upgrade_handler
            upgrade_handler.call(remote_io)
          end
        end

        # ensure the upgrade was successful
        handshake_response = HTTP::Client::Response.from_io(local_io, ignore_body: true)
        unless handshake_response.status.switching_protocols?
          raise Socket::Error.new("Handshake got denied. Status code was #{handshake_response.status.code}.")
        end
  
        challenge_response = HTTP::WebSocket::Protocol.key_challenge(random_key)
        unless handshake_response.headers["Sec-WebSocket-Accept"]? == challenge_response
          raise Socket::Error.new("Handshake got denied. Server did not verify WebSocket challenge.")
        end
      rescue exc
        local_io.close
        remote_io.close
        raise exc
      end
  
      # return an established websocket
      HTTP::WebSocket.new HTTP::WebSocket::Protocol.new(local_io, masked: true)
    end
  end
end
