require "http2client/version"
require 'socket'
require 'http/2'
require 'openssl'
require 'uri'
require 'timeout'
require 'zlib'

module Http2client

  class RequestError < RuntimeError 
  end

  class Request
    attr_reader :uri, :sock, :conn, :stream, :response, :headers, :payload, :stream_closed, :options

    DRAFT = 'h2'.freeze
    DEFAULT_TIMEOUT = 60

    def initialize url, args
      # puts "init Request #{url}, #{args.reject{|k, _v| k == :body}}"
      @stream_closed = false
      @uri = URI.parse(url)
      @options = {}
      @options[:timeout] = args[:timeout] || DEFAULT_TIMEOUT
      @options[:proxy] = args[:proxy]
      begin
        ::Timeout::timeout(@options[:timeout]){
          if args[:proxy]
            proxy = URI.parse(args[:proxy])
            create_socket(proxy_tcp_socket(@uri, {proxy_addr: args[:proxy]}), 
              {proxy_host: proxy.host, connect_timeout: @options[:timeout]}
            )
          else
            tcp = tcp_socket(@uri, {connect_timeout: @options[:timeout]})
            # tcp = TCPSocket.new(@uri.host, @uri.port)
            create_socket(tcp, {})
          end
          create_connection
          create_stream
        }
      rescue Exception => e
        close
        raise e
      end
      merge_headers(args[:method], args[:headers])
      @payload = args[:body]
      @response = {headers: nil, data: '', status_code: 0}
    end

    def execute
      # puts 'Sending HTTP 2.0 request'
      begin
        ::Timeout::timeout(@options[:timeout]){
          if @headers[':method'] == 'GET'
            @stream.headers(@headers, end_stream: true)
          else
            compressed = false
            if (@headers['content-encoding'].downcase.include?('gzip')) && !@payload.nil?
              compressed = true
            end
            # compressed = @payload.nil? ? nil : gzip(@payload)
            if compressed
              @stream.headers(@headers, end_stream: false)
              @stream.data(gzip(@payload))
            else
              @stream.headers(@headers, end_stream: true)
            end
          end

          while !@stream_closed
            if !@sock.closed? && !@sock.eof?
              data = @sock.read_nonblock(1024)
              # puts "Received bytes: #{data.unpack("H*").first}"

              begin
                @conn << data
              rescue => e
                close
                raise e
              end
            else
              @stream_closed = true
            end
          end
          close
          if response_ok?
            body = if @response[:headers]["content-encoding"] && @response[:headers]["content-encoding"] == "gzip"
              inflate(@response[:data])
            else
              @response[:data]
            end
            {headers: @response[:headers], body: body, status_code: @response[:headers][':status']}
          else
            # TODO
            raise RequestError.new "#{response_status}, #{@response[:data].to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')}"
          end
        }
      rescue Exception => e
        close
        raise e
      end
    end

    def close
      @sock.close if @sock
    end

    private

    def response_status
      @response[:headers] ? @response[:headers][':status'] : nil
    end

    def response_ok?
      response_status == '200'
    end

    def merge_headers method, h = {}
      @headers = {
        ':method' => method == :post ? 'POST' : 'GET',
        ':scheme' => @uri.scheme,
        ':path' => @uri.path,
        ':authority' => [@uri.host, @uri.port].join(':')
      }.merge(h || {})
    end

    def proxy_tcp_socket(uri, options)
      proxy_addr = options[:proxy_addr]
      proxy_user = options[:proxy_user]
      proxy_pass = options[:proxy_pass]

      proxy_socket = tcp_socket(URI.parse(proxy_addr), options)
      http_version = '1.1'

      buf = "CONNECT #{uri.host}:#{uri.port} HTTP/#{http_version}\r\n"
      buf << "Host: #{uri.host}:#{uri.port}\r\n"
      if proxy_user
        credential = ["#{proxy_user}:#{proxy_pass}"].pack('m')
        credential.delete!("\r\n")
        buf << "Proxy-Authorization: Basic #{credential}\r\n"
      end
      buf << "\r\n"
      proxy_socket.write(buf)
      validate_proxy_response!(proxy_socket)

      proxy_socket

    end

    def tcp_socket(uri, options)
      family   = ::Socket::AF_INET
      address  = ::Socket.getaddrinfo(uri.host, nil, family).first[3]
      sockaddr = ::Socket.pack_sockaddr_in(uri.port, address)

      socket = ::Socket.new(family, ::Socket::SOCK_STREAM, 0)
      socket.setsockopt(::Socket::IPPROTO_TCP, ::Socket::TCP_NODELAY, 1)

      begin
        socket.connect_nonblock(sockaddr)
      rescue IO::WaitWritable
        if IO.select(nil, [socket], nil, options[:connect_timeout])
          begin
            socket.connect_nonblock(sockaddr)
          rescue Errno::EISCONN
            # socket is connected
          rescue
            socket.close
            raise
          end
        else
          socket.close
          raise Errno::ETIMEDOUT
        end
      end

      socket
    end

    def validate_proxy_response!(socket)
      result = ''
      loop do
        line = socket.gets
        break if !line || line.strip.empty?

        result << line
      end
      return if result =~ /HTTP\/\d(?:\.\d)?\s+2\d\d\s/

      raise(StandardError, "Proxy connection failure:\n#{result}")
    end

    def create_socket(tcp, options)
      if @uri.scheme == 'https'
        ctx = OpenSSL::SSL::SSLContext.new
        ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE

        # For ALPN support, Ruby >= 2.3 and OpenSSL >= 1.0.2 are required

        ctx.alpn_protocols = [DRAFT]
        ctx.alpn_select_cb = lambda do |protocols|
          # puts "ALPN protocols supported by server: #{protocols}"
          DRAFT if protocols.include? DRAFT
        end

        @sock = OpenSSL::SSL::SSLSocket.new(tcp, ctx)
        @sock.sync_close = true
        @sock.hostname = options[:proxy_host] || @uri.hostname
        @sock.connect

        if @sock.alpn_protocol != DRAFT
          # puts "Failed to negotiate #{DRAFT} via ALPN"
          raise StandardError, "Failed to negotiate #{DRAFT} via ALPN"
        end
      else
        @sock = tcp
      end
    end

    def create_connection
      @conn = HTTP2::Client.new
      @conn.on(:frame) do |bytes|
        @sock.print bytes
        @sock.flush
      end
    end

    def headers_to_hash array
      h = {}
      array.each{|a| h[a[0]] = a[1]}
      h
    end

    def create_stream
      @stream = @conn.new_stream
      @stream.on(:headers) do |h|
        @response[:headers] = headers_to_hash(h)
      end
      @stream.on(:data) do |d|
        @response[:data] << d
      end
      @stream.on(:close) do
        @stream_closed = true
      end
    end

    def gzip(string)
      wio = StringIO.new("w")
      w_gz = ::Zlib::GzipWriter.new(wio)
      w_gz.write(string)
      w_gz.close
      wio.string
    end

    def inflate(data)
      gz = ::Zlib::GzipReader.new(StringIO.new(data))
      gz.read
    end

  end
end
