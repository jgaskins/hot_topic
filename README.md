# HotTopic

Stubbing HTTP operations

## Srsly why did you name it this?

Hotmail is HTML with extra letters, and HotTopic is HTTP with extra letters. Also, it makes me laugh.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     hot_topic:
       github: jgaskins/hot_topic
   ```

2. Run `shards install`

## Usage

In your test, instantiate a `HotTopic` client with an `HTTP::Handler` entrypoint (could be middleware or the specific route handler), call [any `HTTP::Client` method](https://crystal-lang.org/api/1.2.2/HTTP/Client.html) on it to get a response back as if you had made the request over HTTP.

Let's say you have an `HTTP::Handler` called `MyApp`:

```crystal
require "http"

class MyApp
  include HTTP::Handler

  def call(context)
    # ...
  end
end
```

In your test, you can instantiate `HotTopic` with an instance of `MyApp`:

```crystal
require "hot_topic"
client = HotTopic.new(MyApp.new)
```

Then you can operate on `client` as if it were a real HTTP client as if it were an `HTTP::Client` request to a remote server. It even returns an actual [`HTTP::Client::Response`](https://crystal-lang.org/api/1.2.2/HTTP/Client/Response.html):

```crystal
response = client.get("/")

# do things with the response
```

## Contributing

1. Fork it (<https://github.com/jgaskins/hot_topic/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Jamie Gaskins](https://github.com/jgaskins) - creator and maintainer
