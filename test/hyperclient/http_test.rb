require_relative '../test_helper'
require 'hyperclient/http'

module Hyperclient
  describe HTTP do
    let(:path) do
      '/productions/1'
    end

    let(:config) { {base_uri: 'http://api.example.org'} }

    let(:http) do
      HTTP.new(config)
    end

    describe 'initialize' do
      it 'warns when invalid options given' do
        proc do
          HTTP.new(nil)
        end.must_raise RuntimeError
      end

      it 'sets the default headers' do
        http.headers.wont_be_nil
      end

      it 'sets authentication options' do
        auth_config = config.merge({auth: {type: :basic, user: 'foo', password: 'baz'}})

        http = HTTP.new(auth_config)
        http.connection.headers['Authorization'].wont_be_empty
      end
    end

    describe 'basic_auth' do
      it 'sets the basic authentication options' do
        stub_request(:get, 'http://user:pass@api.example.org/productions/1').
          to_return(body: '{"resource": "This is the resource"}',
           headers: {content_type: 'application/json'})

        http.basic_auth('user', 'pass')
        http.get(path).body.must_equal({'resource' => 'This is the resource'})
      end
    end

    describe 'digest_auth' do
      it 'sets the digest authentication options' do
        stub_request(:post, 'http://api.example.org/productions/1').
          with(body: nil).
          to_return(status: 401, headers: {'www-authenticate' => 'private area'})

        stub_request(:post, 'http://api.example.org/productions/1').
          with(body: "{\"foo\":1}",
               headers: {'Authorization' =>
            %r{Digest username="user", realm="", algorithm=MD5, uri="/productions/1"}}).
          to_return(body: '{"resource": "This is the resource"}',
           headers: {content_type: 'application/json'})

        http.digest_auth('user', 'pass')
        http.post(path, {foo: 1}).body.must_equal({'resource' => 'This is the resource'})
      end
    end

    describe 'headers' do
      it 'sets headers from the given option' do

        stub_request(:get, 'http://api.example.org/productions/1').
          with(headers: {'Accept-Encoding' => 'deflate, gzip'}).
          to_return(body: '{"resource": "This is the resource"}')

        http.headers = {'accept-encoding' => 'deflate, gzip'}
        http.get(path)
      end
    end

    describe 'log!' do
      before(:each) do
        stub_request(:get, 'http://api.example.org/productions/1').
          to_return(body: '{"resource": "This is the resource"}')
      end

      it 'adds a logger to the connection' do
        output = StringIO.new
        logger = Logger.new(output)

        http.log!(logger)
        http.get(path)

        output.string.must_include('get http://api.example.org/productions/1')
      end
    end

    describe 'faraday' do
      describe 'faraday_options' do
        it 'merges with the default options' do
          faraday_config = config.merge(faraday_options: {params: {foo: 1}})
          http = HTTP.new(faraday_config)

          http.faraday_options.must_include(:url)
          http.faraday_options.must_include(:params)
        end
      end

      describe 'faraday_block' do
        it 'uses the given faraday block' do
          custom_block = lambda do |foo|
            foo + 1
          end

          faraday_config = config.merge(faraday_options: {block: custom_block})
          http = HTTP.new(faraday_config)

          http.faraday_block.call(1).must_equal 2
        end

        it 'fallbacks to the default block' do
          http.faraday_block.class.must_equal Proc
        end

        describe 'default block' do
          it 'parses JSON' do
            stub_request(:get, 'http://api.example.org/productions/1').
              to_return(body: '{"some_json": 12345 }', headers: {content_type: 'application/json'})

            response = http.get(path)
            response.body.must_equal({'some_json' => 12345})
          end

          it 'uses Net::HTTP' do
            http.connection.builder.handlers.must_include Faraday::Adapter::NetHttp
          end
        end
      end
    end

    describe 'get' do
      it 'sends a GET request' do
        stub_request(:get, 'http://api.example.org/productions/1')

        http.get(path)
        assert_requested :get, 'http://api.example.org/productions/1'
      end
    end

    describe 'post' do
      it 'sends a POST request' do
        stub_request(:post, 'http://api.example.org/productions/1').
          to_return(body: 'Posting like a big boy huh?', status: 201)

        response = http.post(path, {data: 'foo'})
        response.status.must_equal 201
        assert_requested :post, 'http://api.example.org/productions/1',
                         body: {data: 'foo'}
      end
    end

    describe 'put' do
      it 'sends a PUT request' do
        stub_request(:put, 'http://api.example.org/productions/1').
          to_return(body: 'No changes were made', status: 204)

        response = http.put(path, {attribute: 'changed'})
        response.status.must_equal 204
        assert_requested :put, 'http://api.example.org/productions/1',
                         body: {attribute: 'changed'}
      end
    end

    describe 'options' do
      it 'sends a OPTIONS request' do
        stub_request(:options, 'http://api.example.org/productions/1').
          to_return(status: 200, headers: {allow: 'GET, POST'})

        response = http.options(path)
        response.headers.must_include 'allow'
      end
    end

    describe 'head' do
      it 'sends a HEAD request' do
        stub_request(:head, 'http://api.example.org/productions/1').
          to_return(status: 200, headers: {content_type: 'application/json'})

        response = http.head(path)
        response.headers.must_include 'content-type'
      end
    end

    describe 'delete' do
      it 'sends a DELETE request' do
        stub_request(:delete, 'http://api.example.org/productions/1').
          to_return(body: 'Resource deleted', status: 200)

        response = http.delete(path)
        response.status.must_equal 200
      end
    end
  end
end
