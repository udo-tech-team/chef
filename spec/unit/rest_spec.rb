#
# Author:: Adam Jacob (<adam@opscode.com>)
# Author:: Christopher Brown (<cb@opscode.com>)
# Author:: Daniel DeLeo (<dan@opscode.com>)
# Copyright:: Copyright (c) 2008 Opscode, Inc.
# Copyright:: Copyright (c) 2010 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'spec_helper'
require 'uri'
require 'net/https'
require 'stringio'

SIGNING_KEY_DOT_PEM="-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA49TA0y81ps0zxkOpmf5V4/c4IeR5yVyQFpX3JpxO4TquwnRh
8VSUhrw8kkTLmB3cS39Db+3HadvhoqCEbqPE6915kXSuk/cWIcNozujLK7tkuPEy
YVsyTioQAddSdfe+8EhQVf3oHxaKmUd6waXrWqYCnhxgOjxocenREYNhZ/OETIei
PbOku47vB4nJK/0GhKBytL2XnsRgfKgDxf42BqAi1jglIdeq8lAWZNF9TbNBU21A
O1iuT7Pm6LyQujhggPznR5FJhXKRUARXBJZawxpGV4dGtdcahwXNE4601aXPra+x
PcRd2puCNoEDBzgVuTSsLYeKBDMSfs173W1QYwIDAQABAoIBAGF05q7vqOGbMaSD
2Q7YbuE/JTHKTBZIlBI1QC2x+0P5GDxyEFttNMOVzcs7xmNhkpRw8eX1LrInrpMk
WsIBKAFFEfWYlf0RWtRChJjNl+szE9jQxB5FJnWtJH/FHa78tR6PsF24aQyzVcJP
g0FGujBihwgfV0JSCNOBkz8MliQihjQA2i8PGGmo4R4RVzGfxYKTIq9vvRq/+QEa
Q4lpVLoBqnENpnY/9PTl6JMMjW2b0spbLjOPVwDaIzXJ0dChjNXo15K5SHI5mALJ
I5gN7ODGb8PKUf4619ez194FXq+eob5YJdilTFKensIUvt3YhP1ilGMM+Chi5Vi/
/RCTw3ECgYEA9jTw4wv9pCswZ9wbzTaBj9yZS3YXspGg26y6Ohq3ZmvHz4jlT6uR
xK+DDcUiK4072gci8S4Np0fIVS7q6ivqcOdzXPrTF5/j+MufS32UrBbUTPiM1yoO
ECcy+1szl/KoLEV09bghPbvC58PFSXV71evkaTETYnA/F6RK12lEepcCgYEA7OSy
bsMrGDVU/MKJtwqyGP9ubA53BorM4Pp9VVVSCrGGVhb9G/XNsjO5wJC8J30QAo4A
s59ZzCpyNRy046AB8jwRQuSwEQbejSdeNgQGXhZ7aIVUtuDeFFdaIz/zjVgxsfj4
DPOuzieMmJ2MLR4F71ocboxNoDI7xruPSE8dDhUCgYA3vx732cQxgtHwAkeNPJUz
dLiE/JU7CnxIoSB9fYUfPLI+THnXgzp7NV5QJN2qzMzLfigsQcg3oyo6F2h7Yzwv
GkjlualIRRzCPaCw4Btkp7qkPvbs1QngIHALt8fD1N69P3DPHkTwjG4COjKWgnJq
qoHKS6Fe/ZlbigikI6KsuwKBgQCTlSLoyGRHr6oj0hqz01EDK9ciMJzMkZp0Kvn8
OKxlBxYW+jlzut4MQBdgNYtS2qInxUoAnaz2+hauqhSzntK3k955GznpUatCqx0R
b857vWviwPX2/P6+E3GPdl8IVsKXCvGWOBZWTuNTjQtwbDzsUepWoMgXnlQJSn5I
YSlLxQKBgQD16Gw9kajpKlzsPa6XoQeGmZALT6aKWJQlrKtUQIrsIWM0Z6eFtX12
2jjHZ0awuCQ4ldqwl8IfRogWMBkHOXjTPVK0YKWWlxMpD/5+bGPARa5fir8O1Zpo
Y6S6MeZ69Rp89ma4ttMZ+kwi1+XyHqC/dlcVRW42Zl5Dc7BALRlJjQ==
-----END RSA PRIVATE KEY-----"

describe Chef::REST do
  before(:each) do
    @log_stringio = StringIO.new
    Chef::Log.init(@log_stringio)

    Chef::REST::CookieJar.stub(:instance).and_return({})
    @base_url   = "http://chef.example.com:4000"
    @monkey_uri = URI.parse("http://chef.example.com:4000/monkey")
    @rest = Chef::REST.new(@base_url, nil, nil)

    Chef::REST::CookieJar.instance.clear
  end


  describe "calling an HTTP verb on a path or absolute URL" do
    it "adds a relative URL to the base url it was initialized with" do
      @rest.create_url("foo/bar/baz").should == URI.parse(@base_url + "/foo/bar/baz")
    end

    it "replaces the base URL when given an absolute URL" do
      @rest.create_url("http://chef-rulez.example.com:9000").should == URI.parse("http://chef-rulez.example.com:9000")
    end

    it "makes a :GET request with the composed url object" do
      @rest.should_receive(:send_http_request).
        with(:GET, @monkey_uri, STANDARD_READ_HEADERS, false).
        and_return([1,2,3])
      @rest.should_receive(:apply_response_middleware).with(1,2,3).and_return([1,2,3])
      @rest.should_receive('success_response?'.to_sym).with(1).and_return(true)
      @rest.get_rest("monkey")
    end

    it "makes a :GET reqest for a streaming download with the composed url" do
      @rest.should_receive(:streaming_request).with('monkey', {})
      @rest.get_rest("monkey", true)
    end

    STANDARD_READ_HEADERS = {"Accept"=>"application/json", "Accept"=>"application/json", "Accept-Encoding"=>"gzip;q=1.0,deflate;q=0.6,identity;q=0.3"}
    STANDARD_WRITE_HEADERS = {"Accept"=>"application/json", "Content-Type"=>"application/json", "Accept"=>"application/json", "Accept-Encoding"=>"gzip;q=1.0,deflate;q=0.6,identity;q=0.3"}

    it "makes a :DELETE request with the composed url object" do
      @rest.should_receive(:send_http_request).
        with(:DELETE, @monkey_uri, STANDARD_READ_HEADERS, false).
        and_return([1,2,3])
      @rest.should_receive(:apply_response_middleware).with(1,2,3).and_return([1,2,3])
      @rest.should_receive('success_response?'.to_sym).with(1).and_return(true)
      @rest.delete_rest("monkey")
    end

    it "makes a :POST request with the composed url object and data" do
      @rest.should_receive(:send_http_request).
        with(:POST, @monkey_uri, STANDARD_WRITE_HEADERS, "\"data\"").
        and_return([1,2,3])
      @rest.should_receive(:apply_response_middleware).with(1,2,3).and_return([1,2,3])
      @rest.should_receive('success_response?'.to_sym).with(1).and_return(true)
      @rest.post_rest("monkey", "data")
    end

    it "makes a :PUT request with the composed url object and data" do
      @rest.should_receive(:send_http_request).
        with(:PUT, @monkey_uri, STANDARD_WRITE_HEADERS, "\"data\"").
        and_return([1,2,3])
      @rest.should_receive(:apply_response_middleware).with(1,2,3).and_return([1,2,3])
      @rest.should_receive('success_response?'.to_sym).with(1).and_return(true)
      @rest.put_rest("monkey", "data")
    end
  end

  describe "legacy API" do
    before(:each) do
      Chef::Config[:node_name]  = "webmonkey.example.com"
      Chef::Config[:client_key] = CHEF_SPEC_DATA + "/ssl/private_key.pem"
      @rest = Chef::REST.new(@base_url)
    end

    it 'responds to raw_http_request as a public method' do
      @rest.public_methods.map(&:to_s).should include("raw_http_request")
    end

    it 'calls the authn middleware' do
      data = "\"secure data\""

      auth_headers = STANDARD_WRITE_HEADERS.merge({"auth_done"=>"yep"})

      @rest.authenticator.should_receive(:handle_request).
        with(:POST, @monkey_uri, STANDARD_WRITE_HEADERS, data).
        and_return([:POST, @monkey_uri, auth_headers, data])
      @rest.should_receive(:send_http_request).
        with(:POST, @monkey_uri, auth_headers, data).
        and_return([1,2,3])
      @rest.should_receive('success_response?'.to_sym).with(1).and_return(true)
      @rest.raw_http_request(:POST, @monkey_uri, STANDARD_WRITE_HEADERS, data)
    end

    it 'sets correct authn headers' do
      data = "\"secure data\""
      method, uri, auth_headers, d = @rest.authenticator.handle_request(:POST, @monkey_uri, STANDARD_WRITE_HEADERS, data)

      @rest.should_receive(:send_http_request).
        with(:POST, @monkey_uri, auth_headers, data).
        and_return([1,2,3])
      @rest.should_receive('success_response?'.to_sym).with(1).and_return(true)
      @rest.raw_http_request(:POST, @monkey_uri, STANDARD_WRITE_HEADERS, data)
    end
  end


  describe "when configured to authenticate to the Chef server" do
    before do
      @url = URI.parse("http://chef.example.com:4000")
      Chef::Config[:node_name]  = "webmonkey.example.com"
      Chef::Config[:client_key] = CHEF_SPEC_DATA + "/ssl/private_key.pem"
      @rest = Chef::REST.new(@url)
    end

    it "configures itself to use the node_name and client_key in the config by default" do
      @rest.client_name.should == "webmonkey.example.com"
      @rest.signing_key_filename.should == CHEF_SPEC_DATA + "/ssl/private_key.pem"
    end

    it "provides access to the raw key data" do
      @rest.signing_key.should == SIGNING_KEY_DOT_PEM
    end

    it "does not error out when initialized without credentials" do
      @rest = Chef::REST.new(@url, nil, nil) #should_not raise_error hides the bt from you, so screw it.
      @rest.client_name.should be_nil
      @rest.signing_key.should be_nil
    end

    it "indicates that requests should not be signed when it has no credentials" do
      @rest = Chef::REST.new(@url, nil, nil)
      @rest.sign_requests?.should be_false
    end

    it "raises PrivateKeyMissing when the key file doesn't exist" do
      lambda {Chef::REST.new(@url, "client-name", "/dev/null/nothing_here")}.should raise_error(Chef::Exceptions::PrivateKeyMissing)
    end

    it "raises InvalidPrivateKey when the key file doesnt' look like a key" do
      invalid_key_file = CHEF_SPEC_DATA + "/bad-config.rb"
      lambda {Chef::REST.new(@url, "client-name", invalid_key_file)}.should raise_error(Chef::Exceptions::InvalidPrivateKey)
    end

    it "can take private key as a sting :raw_key in options during initializaton" do
      Chef::REST.new(@url, "client-name", nil, :raw_key => SIGNING_KEY_DOT_PEM).signing_key.should == SIGNING_KEY_DOT_PEM
    end

    it "raises InvalidPrivateKey when the key passed as string :raw_key in options doesnt' look like a key" do
      lambda {Chef::REST.new(@url, "client-name", nil, :raw_key => "bad key string")}.should raise_error(Chef::Exceptions::InvalidPrivateKey)
    end

  end

  context "when making REST requests" do
    let(:body) { "ninja" }

    let(:http_response) do
      http_response = Net::HTTPSuccess.new("1.1", "200", "successful rest req")
      http_response.stub(:read_body)
      http_response.stub(:body).and_return(body)
      http_response.add_field("Content-Length", body.bytesize)
      http_response
    end

    let(:host_header) { "one:80" }

    let(:url) { URI.parse("https://one:80/?foo=bar") }

    let(:base_url) { "http://chef.example.com:4000" }

    let(:http_client) do
      http_client = Net::HTTP.new(url.host, url.port)
      http_client.stub(:request).and_yield(http_response).and_return(http_response)
      http_client
    end

    def stub_net_http_new
      http_client_mock = http_client
      Net::HTTP.stub(:new).and_return(http_client_mock)
    end

    let(:rest) do
      stub_net_http_new
      Chef::REST.new(base_url, nil, nil)
    end

    let(:base_headers) do
      {
        'Accept' => 'application/json',
        'X-Chef-Version' => Chef::VERSION,
        'Accept-Encoding' => Chef::REST::RESTRequest::ENCODING_GZIP_DEFLATE,
      }
    end

    let (:req_with_body_headers) do
      base_headers.merge("Content-Type" => "application/json", "Content-Length" => '13')
    end

    before(:each) do
      Chef::Config[:ssl_client_cert] = nil
      Chef::Config[:ssl_client_key]  = nil
    end

    describe "streaming downloads to a tempfile" do
      let(:tempfile) do
        tempfile = StringIO.new
        tempfile.stub(:close!)
        tempfile.stub(:path).and_return("/a-temporary-file")
        tempfile
      end

      let(:request_mock) { {} }

      before do
        Tempfile.stub(:new).with("chef-rest").and_return(tempfile)
        Tempfile.stub(:open).and_return(tempfile)

        Net::HTTP::Get.stub(:new).and_return(request_mock)
      end

      it "should build a new HTTP GET request without the application/json accept header" do
        expected_headers = {'Accept' => "*/*",
                            'X-Chef-Version' => Chef::VERSION,
                            'Accept-Encoding' => Chef::REST::RESTRequest::ENCODING_GZIP_DEFLATE,
                            'Host' => host_header}
        Net::HTTP::Get.should_receive(:new).with("/?foo=bar", expected_headers).and_return(request_mock)
        rest.streaming_request(url, {})
      end

      it "should create a tempfile for the output of a raw request" do
        rest.streaming_request(url, {}).should equal(tempfile)
      end

      it "should read the body of the response in chunks on a raw request" do
        http_response.should_receive(:read_body).and_return(true)
        rest.streaming_request(url, {})
      end

      it "should populate the tempfile with the value of the raw request" do
        http_response.should_receive(:read_body).and_yield("ninja")
        rest.streaming_request(url, {})
        tempfile.string.should include("ninja")
      end

      it "should close the tempfile if we're doing a raw request" do
        tempfile.should_receive(:close).once.and_return(true)
        rest.streaming_request(url, {})
      end

      it "should not raise a divide by zero exception if the size is 0" do
        http_response.stub(:header).and_return({ 'Content-Length' => "5" })
        http_response.stub(:read_body).and_yield('')
        lambda { rest.streaming_request(url, {}) }.should_not raise_error
      end

      it "should not raise a divide by zero exception if the Content-Length is 0" do
        http_response.stub(:header).and_return({ 'Content-Length' => "0" })
        http_response.stub(:read_body).and_yield("ninja")
        lambda { rest.streaming_request(url, {}) }.should_not raise_error
      end

    end

    describe "as JSON API requests" do
      let(:request_mock) { {} }

      let(:base_headers) do  #FIXME: huh?
        {
          'Accept' => 'application/json',
          'X-Chef-Version' => Chef::VERSION,
          'Accept-Encoding' => Chef::REST::RESTRequest::ENCODING_GZIP_DEFLATE,
          'Host' => host_header,
        }
      end

      before do
        Net::HTTP::Get.stub(:new).and_return(request_mock)
      end

      it "should always include the X-Chef-Version header" do
        Net::HTTP::Get.should_receive(:new).with("/?foo=bar", base_headers).and_return(request_mock)
        rest.request(:GET, url, {})
      end

      it "sets the user agent to chef-client" do
        # XXX: must reset to default b/c knife changes the UA
        Chef::REST::RESTRequest.user_agent = Chef::REST::RESTRequest::DEFAULT_UA
        rest.request(:GET, url, {})
        request_mock['User-Agent'].should match(/^Chef Client\/#{Chef::VERSION}/)
      end

      # CHEF-3140
      context "when configured to disable compression" do
        let(:rest) do
          stub_net_http_new
          Chef::REST.new(base_url, nil, nil,  :disable_gzip => true)
        end

        it "does not accept encoding gzip" do
          rest.send(:build_headers, :GET, url, {}).should_not have_key("Accept-Encoding")
        end

        it "does not decompress a response encoded as gzip" do
          http_response.add_field("content-encoding", "gzip")
          request = Net::HTTP::Get.new(url.path)
          Net::HTTP::Get.should_receive(:new).and_return(request)
          # will raise a Zlib error if incorrect
          rest.request(:GET, url, {}).should == "ninja"
        end
      end

      context "when configured with custom http headers" do
        let(:custom_headers) do
          {
            'X-Custom-ChefSecret' => 'sharpknives',
            'X-Custom-RequestPriority' => 'extremely low'
          }
        end

        before(:each) do
          Chef::Config[:custom_http_headers] = custom_headers
        end

        after(:each) do
          Chef::Config[:custom_http_headers] = nil
        end

        it "should set them on the http request" do
          url_string = an_instance_of(String)
          header_hash = hash_including(custom_headers)
          Net::HTTP::Get.should_receive(:new).with(url_string, header_hash)
          rest.request(:GET, url, {})
        end
      end

      it "should set the cookie for this request if one exists for the given host:port" do
        Chef::REST::CookieJar.instance["#{url.host}:#{url.port}"] = "cookie monster"
        Net::HTTP::Get.should_receive(:new).with("/?foo=bar", base_headers.merge('Cookie' => "cookie monster")).and_return(request_mock)
        rest.request(:GET, url, {})
      end

      it "should build a new HTTP GET request" do
        Net::HTTP::Get.should_receive(:new).with("/?foo=bar", base_headers).and_return(request_mock)
        rest.request(:GET, url, {})
      end

      it "should build a new HTTP POST request" do
        request = Net::HTTP::Post.new(url.path)
        expected_headers = base_headers.merge("Content-Type" => 'application/json', 'Content-Length' => '13')

        Net::HTTP::Post.should_receive(:new).with("/?foo=bar", expected_headers).and_return(request)
        rest.request(:POST, url, {}, {:one=>:two})
        request.body.should == '{"one":"two"}'
      end

      it "should build a new HTTP PUT request" do
        request = Net::HTTP::Put.new(url.path)
        expected_headers = base_headers.merge("Content-Type" => 'application/json', 'Content-Length' => '13')
        Net::HTTP::Put.should_receive(:new).with("/?foo=bar",expected_headers).and_return(request)
        rest.request(:PUT, url, {}, {:one=>:two})
        request.body.should == '{"one":"two"}'
      end

      it "should build a new HTTP DELETE request" do
        Net::HTTP::Delete.should_receive(:new).with("/?foo=bar", base_headers).and_return(request_mock)
        rest.request(:DELETE, url)
      end

      it "should raise an error if the method is not GET/PUT/POST/DELETE" do
        lambda { rest.request(:MONKEY, url) }.should raise_error(ArgumentError)
      end

      it "returns nil when the response is successful but content-type is not JSON" do
        rest.request(:GET, url).should == "ninja"
      end

      context "when JSON is returned" do
        let(:body) { '{"ohai2u":"json_api"}' }
        it "should inflate the body as to an object" do
          http_response.add_field('content-type', "application/json")
          rest.request(:GET, url, {}).should == {"ohai2u"=>"json_api"}
        end
      end

      %w[ HTTPFound HTTPMovedPermanently HTTPSeeOther HTTPUseProxy HTTPTemporaryRedirect HTTPMultipleChoice ].each do |resp_name|
        describe "when encountering a #{resp_name} redirect" do
          let(:http_response) do
            resp_cls  = Net.const_get(resp_name)
            resp_code = Net::HTTPResponse::CODE_TO_OBJ.keys.detect { |k| Net::HTTPResponse::CODE_TO_OBJ[k] == resp_cls }
            http_response = Net::HTTPFound.new("1.1", resp_code, "bob is somewhere else again")
            http_response.add_field("location", url.path)
            http_response.stub(:read_body)
            http_response
          end
          it "should call request again" do

            lambda { rest.request(:GET, url) }.should raise_error(Chef::Exceptions::RedirectLimitExceeded)

            [:PUT, :POST, :DELETE].each do |method|
              lambda { rest.request(method, url) }.should raise_error(Chef::Exceptions::InvalidRedirect)
            end
          end
        end
      end

      context "when the response is 304 NotModified" do
        let (:http_response) do
          http_response = Net::HTTPNotModified.new("1.1", "304", "it's the same as when you asked 5 minutes ago")
          http_response.stub(:read_body)
          http_response
        end

        it "should return `false`" do
          rest.request(:GET, url).should be_false
        end
      end

      describe "when the request fails" do
        before do
          @original_log_level = Chef::Log.level
          Chef::Log.level = :info
        end

        after do
          Chef::Log.level = @original_log_level
        end

        context "on an unsuccessful response with a JSON error" do
          let(:http_response) do
            http_response = Net::HTTPServerError.new("1.1", "500", "drooling from inside of mouth")
            http_response.add_field("content-type", "application/json")
            http_response.stub(:body).and_return('{ "error":[ "Ears get sore!", "Not even four" ] }')
            http_response.stub(:read_body)
            http_response
          end

          it "should show the JSON error message" do
            rest.stub(:sleep)

            lambda {rest.request(:GET, url)}.should raise_error(Net::HTTPFatalError)
            @log_stringio.string.should match(Regexp.escape('INFO: HTTP Request Returned 500 drooling from inside of mouth: Ears get sore!, Not even four'))
          end
        end

        context "on an unsuccessful response with a JSON error that is compressed" do
          let(:http_response) do
            http_response = Net::HTTPServerError.new("1.1", "500", "drooling from inside of mouth")
            http_response.add_field("content-type", "application/json")
            http_response.add_field("content-encoding", "deflate")
            unzipped_body = '{ "error":[ "Ears get sore!", "Not even four" ] }'
            gzipped_body = Zlib::Deflate.deflate(unzipped_body)
            gzipped_body.force_encoding(Encoding::BINARY) if "strings".respond_to?(:force_encoding)

            http_response.stub(:body).and_return gzipped_body
            http_response.stub(:read_body)
            http_response
          end
          it "decompresses the JSON error message" do
            rest.stub(:sleep)
            rest.stub(:http_retry_count).and_return(0)

            lambda {rest.request(:GET, url)}.should raise_error(Net::HTTPFatalError)
            @log_stringio.string.should match(Regexp.escape('INFO: HTTP Request Returned 500 drooling from inside of mouth: Ears get sore!, Not even four'))
          end
        end

        context "on a generic unsuccessful request" do
          let(:http_response) do
            http_response = Net::HTTPServerError.new("1.1", "500", "drooling from inside of mouth")
            http_response.stub(:body)
            http_response.stub(:read_body)
            http_response
          end
          it "throws an exception" do
            rest.stub(:sleep)
            lambda {rest.request(:GET, url)}.should raise_error(Net::HTTPFatalError)
          end
        end
      end
    end

    context "when streaming downloads to a tempfile" do
      let(:tempfile) {  Tempfile.open("chef-rspec-rest_spec-line-@{__LINE__}--") }

      let(:request_mock) { {} }

      let(:http_response) do
        http_response = Net::HTTPSuccess.new("1.1",200, "it-works")

        http_response.stub(:read_body)
        http_response.should_not_receive(:body)
        http_response.add_field("Content-Length", body.bytesize)
        http_response
      end

      before do
        tempfile_mock = tempfile
        Tempfile.stub(:new).with("chef-rest").and_return(tempfile_mock)
        Net::HTTP::Get.stub(:new).and_return(request_mock)
      end

      after do
        tempfile.close!
      end

      it " build a new HTTP GET request without the application/json accept header" do
        expected_headers = {'Accept' => "*/*",
                            'X-Chef-Version' => Chef::VERSION,
                            'Accept-Encoding' => Chef::REST::RESTRequest::ENCODING_GZIP_DEFLATE,
                            'Host' => host_header}
        Net::HTTP::Get.should_receive(:new).with("/?foo=bar", expected_headers).and_return(request_mock)
        rest.streaming_request(url, {})
      end

      it "returns a tempfile containing the streamed response body" do
        rest.streaming_request(@url, {}).should equal(tempfile)
      end

      it "writes the response body to a tempfile" do
        http_response.stub(:read_body).and_yield("real").and_yield("ultimate").and_yield("power")
        rest.streaming_request(url, {})
        IO.read(tempfile.path).chomp.should == "realultimatepower"
      end

      it "closes the tempfile" do
        rest.streaming_request(url, {})
        tempfile.should be_closed
      end

      it "yields the tempfile containing the streamed response body and then unlinks it when given a block" do
        http_response.stub(:read_body).and_yield("real").and_yield("ultimate").and_yield("power")
        tempfile_path = nil
        rest.streaming_request(url, {}) do |tempfile|
          tempfile_path = tempfile.path
          File.exist?(tempfile.path).should be_true
          IO.read(tempfile.path).chomp.should == "realultimatepower"
        end
        File.exist?(tempfile_path).should be_false
      end

      it "does not raise a divide by zero exception if the content's actual size is 0" do
        http_response.add_field('Content-Length', "5")
        http_response.stub(:read_body).and_yield('')
        lambda { rest.streaming_request(@url, {}) }.should_not raise_error
      end

      it "does not raise a divide by zero exception when the Content-Length is 0" do
        http_response.add_field('Content-Length', "0")
        http_response.stub(:read_body).and_yield("ninja")
        lambda { rest.streaming_request(url, {}) }.should_not raise_error
      end

      it "fetches a file and yields the tempfile it is streamed to" do
        http_response.stub(:read_body).and_yield("real").and_yield("ultimate").and_yield("power")
        tempfile_path = nil
        rest.fetch("cookbooks/a_cookbook") do |tempfile|
          tempfile_path = tempfile.path
          IO.read(tempfile.path).chomp.should == "realultimatepower"
        end
        File.exist?(tempfile_path).should be_false
      end

      it "closes and unlinks the tempfile if there is an error while streaming the content to the tempfile" do
        path = tempfile.path
        path.should_not be_nil
        tempfile.stub(:write).and_raise(IOError)
        rest.fetch("cookbooks/a_cookbook") {|tmpfile| "shouldn't get here"}
        File.exists?(path).should be_false
      end

      it "closes and unlinks the tempfile when the response is a redirect" do
        tempfile = double("A tempfile", :path => "/tmp/ragefist", :close => true, :binmode => true)
        tempfile.should_receive(:close!).at_least(1).times
        Tempfile.stub(:new).with("chef-rest").and_return(tempfile)

        redirect = Net::HTTPFound.new("1.1", "302", "bob is taking care of that one for me today")
        redirect.add_field("location", url.path)
        redirect.stub(:read_body)

        http_client.should_receive(:request).and_yield(redirect).and_return(redirect)
        http_client.should_receive(:request).and_yield(http_response).and_return(http_response)
        rest.fetch("cookbooks/a_cookbook") {|tmpfile| "shouldn't get here"}
      end

      it "passes the original block to the redirected request" do
        http_redirect = Net::HTTPFound.new("1.1", "302", "bob is taking care of that one for me today")
        http_redirect.add_field("location","/that-thing-is-here-now")
        http_redirect.stub(:read_body)

        block_called = false
        http_client.stub(:request).and_yield(http_response).and_return(http_redirect, http_response)
        rest.fetch("cookbooks/a_cookbook") do |tmpfile|
          block_called = true
        end
        block_called.should be_true
      end
    end
  end

  context "when following redirects" do
    before do
      Chef::Config[:node_name]  = "webmonkey.example.com"
      Chef::Config[:client_key] = CHEF_SPEC_DATA + "/ssl/private_key.pem"
      @rest = Chef::REST.new(@url)
    end

    it "raises a RedirectLimitExceeded when redirected more than 10 times" do
      redirected = lambda {@rest.follow_redirect { redirected.call }}
      lambda {redirected.call}.should raise_error(Chef::Exceptions::RedirectLimitExceeded)
    end

    it "does not count redirects from previous calls against the redirect limit" do
      total_redirects = 0
      redirected = lambda do
        @rest.follow_redirect do
          total_redirects += 1
          redirected.call unless total_redirects >= 9
        end
      end
      lambda {redirected.call}.should_not raise_error
      total_redirects = 0
      lambda {redirected.call}.should_not raise_error
    end

    it "does not sign the redirected request when sign_on_redirect is false" do
      @rest.sign_on_redirect = false
      @rest.follow_redirect { @rest.sign_requests?.should be_false }
    end

    it "resets sign_requests to the original value after following an unsigned redirect" do
      @rest.sign_on_redirect = false
      @rest.sign_requests?.should be_true

      @rest.follow_redirect { @rest.sign_requests?.should be_false }
      @rest.sign_requests?.should be_true
    end

    it "configures the redirect limit" do
      total_redirects = 0
      redirected = lambda do
        @rest.follow_redirect do
          total_redirects += 1
          redirected.call unless total_redirects >= 9
        end
      end
      lambda {redirected.call}.should_not raise_error

      total_redirects = 0
      @rest.redirect_limit = 3
      lambda {redirected.call}.should raise_error(Chef::Exceptions::RedirectLimitExceeded)
    end

  end
end
