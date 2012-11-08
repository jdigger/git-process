require 'FileHelpers'
require 'git-process/git_process'
require 'webmock/rspec'

module GitHubTestHelper


  def stub_get(url, opts = {})
    stub = stub_request(:get, url)

    if opts[:token]
      stub.with(:Authorization => "token #{opts[:token]}")
    end

    stub.to_return(:status => opts[:status] ? opts[:status] : 200, :body => opts[:body] ? opts[:body] : '')
    stub
  end


  def stub_post(url, opts = {})
    stub = stub_request(:post, url)

    if opts[:token]
      stub.with(:Authorization => "token #{opts[:token]}")
    end

    stub.to_return(:status => opts[:status] ? opts[:status] : 200, :body => opts[:body] ? opts[:body] : '')

    stub
  end


  def stub_patch(url, opts = {})
    stub = stub_request(:patch, url)

    if opts[:token]
      stub.with(:Authorization => "token #{opts[:token]}")
    end

    if opts[:send]
      stub.with(:body => opts[:send])
    end

    stub.to_return(:status => opts[:status] ? opts[:status] : 200, :body => opts[:body] ? opts[:body] : '')

    stub
  end

end
