# Http2client

ruby [http-2](https://github.com/igrigorik/http-2) gem wrapper

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'http2client', git: 'https://github.com/mvalitov/http2client'
```

And then execute:

    $ bundle


## Usage

```ruby
2.3.1 :002 > Http2client::Request.new("https://nghttp2.org/httpbin/headers", {method: :get}).execute
init Request https://nghttp2.org/httpbin/headers, {:method=>:get}
Sending HTTP 2.0 request
 => {:headers=>{":status"=>"200", "date"=>"Mon, 16 Apr 2018 08:32:14 GMT", "content-type"=>"application/json", "content-length"=>"77", "access-control-allow-origin"=>"*", "access-control-allow-credentials"=>"true", "x-backend-header-rtt"=>"0.003416", "strict-transport-security"=>"max-age=31536000", "server"=>"nghttpx", "via"=>"1.1 nghttpx", "x-frame-options"=>"SAMEORIGIN", "x-xss-protection"=>"1; mode=block", "x-content-type-options"=>"nosniff"}, :body=>"{\n  \"headers\": {\n    \"Host\": \"nghttp2.org:443\",\n    \"Via\": \"2 nghttpx\"\n  }\n}\n"}

2.3.1 :002 > Http2client::Request.new("https://nghttp2.org/httpbin/headers", {method: :get, headers: {'custom' => 'custom value'}}).execute
init Request https://nghttp2.org/httpbin/headers, {:method=>:get, :headers=>{"custom"=>"custom value"}}
Sending HTTP 2.0 request
 => {:headers=>{":status"=>"200", "date"=>"Mon, 16 Apr 2018 08:49:43 GMT", "content-type"=>"application/json", "content-length"=>"107", "access-control-allow-origin"=>"*", "access-control-allow-credentials"=>"true", "x-backend-header-rtt"=>"0.003247", "strict-transport-security"=>"max-age=31536000", "server"=>"nghttpx", "via"=>"1.1 nghttpx", "x-frame-options"=>"SAMEORIGIN", "x-xss-protection"=>"1; mode=block", "x-content-type-options"=>"nosniff"}, :body=>"{\n  \"headers\": {\n    \"Custom\": \"custom value\",\n    \"Host\": \"nghttp2.org:443\",\n    \"Via\": \"2 nghttpx\"\n  }\n}\n"}

2.3.1 :002 > Http2client::Request.new("https://nghttp2.org/httpbin/post", {proxy: "http://127.0.0.1:8080", method: :post, body: "id=1"}).execute
init Request https://nghttp2.org/httpbin/post, {:proxy=>"http://127.0.0.1:8080", :method=>:post}
Sending HTTP 2.0 request
 => {:headers=>{":status"=>"200", "date"=>"Mon, 16 Apr 2018 08:34:40 GMT", "content-type"=>"application/json", "content-length"=>"264", "access-control-allow-origin"=>"*", "access-control-allow-credentials"=>"true", "x-backend-header-rtt"=>"0.004909", "strict-transport-security"=>"max-age=31536000", "server"=>"nghttpx", "via"=>"1.1 nghttpx", "x-frame-options"=>"SAMEORIGIN", "x-xss-protection"=>"1; mode=block", "x-content-type-options"=>"nosniff"}, :body=>"{\n  \"args\": {},\n  \"data\": \"\",\n  \"files\": {},\n  \"form\": {},\n  \"headers\": {\n    \"Host\": \"nghttp2.org:443\",\n    \"Transfer-Encoding\": \"chunked\",\n    \"Via\": \"2 nghttpx\"\n  },\n  \"json\": null,\n  \"origin\": \"131.127.48.11\",\n  \"url\": \"https://nghttp2.org:443/httpbin/post\"\n}\n"}
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/mvalitov/http2client.
