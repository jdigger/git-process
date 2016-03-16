require 'FileHelpers'
require 'git-process/git_process'
require 'webmock/rspec'

################
#
# Monkey-patch WebMock to stop screwing with the capitalization of resource headers
#
################
module WebMock
  module Util
    class Headers
      def self.normalize_headers(headers)
        headers
      end
    end
  end
end

module Net::HTTPHeader
  def add_field(key, val)
    if @header.key?(key)
      @header[key].push val
    else
      @header[key] = [val]
    end
  end
end


module GitHubTestHelper


  def stub_get(url, opts = {})
    stub = stub_request(:get, url)

    if opts[:token]
      stub.with(:Authorization => "token #{opts[:token]}")
    end

    stub.to_return(:status => opts[:status] ? opts[:status] : 200, :body => to_body(opts[:body]))
    stub
  end


  def stub_post(url, opts = {})
    stub = stub_request(:post, url)

    with_headers = opts[:headers] || {}

    if opts[:token]
      stub.with(:Authorization => "token #{opts[:token]}")
    end

    if opts[:send]
      stub.with(:body => to_body(opts[:send]))
    end

    if opts[:two_factor]
      # noinspection RubyStringKeysInHashInspection
      with_headers.merge!({'X-GitHub-OTP'.downcase => [opts[:two_factor]]})
    end

    if opts[:body]
      # noinspection RubyStringKeysInHashInspection
      opts[:response_headers] = {'Content-Type' => 'application/json'}.merge(opts[:response_headers] || {})
    end

    stub.with(:headers => with_headers) unless with_headers.empty?
    stub.to_return(:status => opts[:status] ? opts[:status] : 200, :body => to_body(opts[:body]), :headers => opts[:response_headers] ? opts[:response_headers] : {})

    return stub
  end


  def stub_patch(url, opts = {})
    stub = stub_request(:patch, url)

    if opts[:token]
      stub.with(:Authorization => "token #{opts[:token]}")
    end

    if opts[:send]
      stub.with(:body => to_body(opts[:send]))
    end

    stub.to_return(:status => opts[:status] ? opts[:status] : 200, :body => to_body(opts[:body]))

    stub
  end

  def to_body(body)
    return '' if body.nil?

    return body if body.is_a? String

    if body.is_a? Hash or body.is_a? Array
      return JSON(body).to_s
    end
    raise "Do not know what to do with #{body.class} #{body}"
  end

end
