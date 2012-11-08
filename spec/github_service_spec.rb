require 'git-process/github_service'
require 'git-process/git_lib'
require 'webmock/rspec'
require 'json'
require 'octokit'
require 'tempfile'
require 'rspec/mocks/methods'
require 'rspec/mocks/test_double'
require 'rspec/mocks/mock'
require 'git_lib_stub'
require 'github_test_helper'

class GHS
  include GitHubService

  attr_reader :remote_name


  def initialize(user = nil, password = nil, site = 'origin')
    @lib = GitLibStub.new
    @user = user
    @password = password
    @remote_name = site
  end


  def user
    @user ||= ask_for_user
  end


  def password
    @password ||= ask_for_password
  end


  def pw_client
    @pw_client ||= create_pw_client
  end


  def client
    @client ||= create_client
  end


  def lib
    @lib
  end
end


describe GitHubService do
  include GitHubTestHelper


  def test_token
    'hfgkdjfgksjhdfkls'
  end


  describe "create_authorization" do

    def ghs
      unless @ghs
        @ghs = GHS.new('tu', 'dfsdf')
        @ghs.lib.add_remote('origin', 'git@github.com:jdigger/git-process.git')
      end
      @ghs
    end


    it "should return an auth_token for a good request" do
      stub_post('https://tu:dfsdf@api.github.com/authorizations', :send => auth_json,
                :body => {:token => test_token})

      ghs.create_authorization().should == test_token
    end


    it "should 401 for bad password" do
      stub_post('https://tu:dfsdf@api.github.com/authorizations', :send => auth_json,
                :status => 401)

      lambda { ghs.create_authorization() }.should raise_error Octokit::Unauthorized
    end

  end


  describe "auth_token" do

    it "should get the token from config if it exists" do
      ghs = GHS.new
      ghs.lib.add_remote('origin', 'git@github.com:jdigger/git-process.git')
      ghs.lib.config('github.user', 'test_user')
      ghs.lib.config('gitProcess.github.authToken', test_token)

      ghs.auth_token.should == test_token
    end


    it "should get the token from the server if it does not exist in config" do
      ghs = GHS.new(nil, 'dfsdf')
      ghs.lib.add_remote('origin', 'git@github.com:jdigger/git-process.git')
      ghs.lib.config('github.user', 'test_user')
      ghs.lib.config('gitProcess.github.authToken', '')

      stub_post('https://test_user:dfsdf@api.github.com/authorizations', :send => auth_json,
                :body => {:token => test_token})

      ghs.auth_token.should == test_token
    end

  end


  describe "user" do

    it "should get the value from config" do
      ghs = GHS.new(nil, 'dfsdf')
      ghs.lib.config('github.user', 'test_user')

      ghs.user.should == 'test_user'
    end


    it "should prompt the user and store it in the config" do
      ghs = GHS.new(nil, 'dfsdf')
      ghs.lib.config('github.user', '')

      ghs.stub(:ask).with(/username/).and_return('test_user')
      ghs.user.should == 'test_user'
    end

  end


  describe "using GHE instead of GitHub.com" do

    def ghs
      unless @ghs
        @ghs = GHS.new('tu', 'dfsdf')
      end
      @ghs
    end


    it "should use the correct server and path for a non-GitHub.com site" do
      ghs.lib.add_remote('origin', 'git@myco.com:jdigger/git-process.git')

      stub_post('https://tu:dfsdf@myco.com/api/v3/authorizations',
                :send => auth_json,
                :body => {:token => test_token})

      ghs.create_authorization().should == test_token
    end


    it "site should raise an error if remote.origin.url not set" do
      ghs.lib.config('remote.origin.url', '')

      lambda { ghs.site }.should raise_error GitHubService::NoRemoteRepository
    end


    it "site should not work for a garbage url address" do
      ghs.lib.add_remote('origin', 'garbage')

      lambda { ghs.site }.should raise_error URI::InvalidURIError
    end


    it "site should work for an ssh-configured url address" do
      ghs.lib.add_remote('origin', 'git@github.myco.com:fooble')

      ghs.site().should == 'https://github.myco.com'
    end

  end


  it "#git_url_to_api" do
    ghs = GHS.new('tu', 'dfsdf')

    ghs.git_url_to_api('ssh://git@github.myco.com/fooble').should == 'https://github.myco.com'
    ghs.git_url_to_api('git://myco.com/jdigger/git-process.git').should == 'https://myco.com'
    ghs.git_url_to_api('http://github.myco.com/fooble').should == 'http://github.myco.com'
    ghs.git_url_to_api('http://tu@github.myco.com/fooble').should == 'http://github.myco.com'
    ghs.git_url_to_api('https://github.myco.com/fooble').should == 'https://github.myco.com'
    ghs.git_url_to_api('https://github.com/fooble').should == 'https://api.github.com'
  end


  def auth_json
    JSON({:note_url => 'http://jdigger.github.com/git-process',
          :scopes => %w(repo user gist), :note => "Git-Process"})
  end

end
