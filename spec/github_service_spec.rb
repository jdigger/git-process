require 'git-process/github_service'
require 'git-process/git_lib'
require 'webmock/rspec'
require 'json'
require 'octokit'
require 'tempfile'
require 'rspec/mocks/methods'
require 'rspec/mocks/test_double'
require 'rspec/mocks/mock'
require 'github_test_helper'
include GitProc

class GHS
  include GitHubService

  attr_reader :remote_name


  def initialize(user = nil, password = nil, site = 'origin')
    @lib = GitLib.new(Dir.mktmpdir, :log_level => Logger::ERROR)
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


  def client
    @client ||= create_client
  end


  def gitlib
    @lib
  end
end


describe GitHubService do
  include GitHubTestHelper


  def test_token
    'hfgkdjfgksjhdfkls'
  end


  after(:each) do
    rm_rf(ghs.gitlib.workdir)
  end


  def ghs
    @ghs ||= GHS.new
  end


  describe "create_authorization" do

    def ghs
      unless @ghs
        @ghs = GHS.new('tu', 'dfsdf')
        @ghs.gitlib.remote.add('origin', 'git@github.com:jdigger/git-process.git')
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

      expect { ghs.create_authorization() }.to raise_error Octokit::Unauthorized
    end

  end


  describe "auth_token no username or password" do

    it "should get the token from config if it exists" do
      ghs.gitlib.remote.add('origin', 'git@github.com:jdigger/git-process.git')
      ghs.gitlib.config['github.user'] = 'test_user'
      ghs.gitlib.config['gitProcess.github.authToken'] = test_token

      ghs.auth_token.should == test_token
    end

  end


  describe "auth_token with password but no username" do

    def ghs
      @ghs ||= GHS.new(nil, 'dfsdf')
    end


    it "should get the token from the server if it does not exist in config" do
      ghs.gitlib.remote.add('origin', 'git@github.com:jdigger/git-process.git')
      ghs.gitlib.config['github.user'] = 'test_user'
      ghs.gitlib.config['gitProcess.github.authToken'] = ''

      stub_post('https://test_user:dfsdf@api.github.com/authorizations', :send => auth_json,
                :body => {:token => test_token})

      ghs.auth_token.should == test_token
    end

  end


  describe "user" do

    def ghs
      @ghs ||= GHS.new(nil, 'dfsdf')
    end


    it "should get the value from config" do
      ghs.gitlib.config['github.user'] = 'test_user'

      ghs.user.should == 'test_user'
    end


    it "should prompt the user and store it in the config" do
      ghs.gitlib.config['github.user'] = ''

      ghs.stub(:ask_for_user).and_return('test_user')
      ghs.user.should == 'test_user'
    end

  end


  describe "using GHE instead of GitHub.com" do

    def ghs
      @ghs ||= GHS.new('tu', 'dfsdf')
    end


    it "should use the correct server and path for a non-GitHub.com site" do
      ghs.gitlib.remote.add('origin', 'git@myco.com:jdigger/git-process.git')

      stub_post('https://tu:dfsdf@myco.com/api/v3/authorizations',
                :send => auth_json,
                :body => {:token => test_token})

      ghs.create_authorization().should == test_token
    end


    it "site should raise an error if remote.origin.url not set" do
      ghs.gitlib.config['remote.origin.url'] = ''

      expect { ghs.base_github_api_url_for_remote }.to raise_error GitHubService::NoRemoteRepository
    end


    it "site should not work for a garbage url address" do
      ghs.gitlib.remote.add('origin', 'garbage')

      expect { ghs.base_github_api_url_for_remote }.to raise_error URI::InvalidURIError
    end


    it "site should work for an ssh-configured url address" do
      ghs.gitlib.remote.add('origin', 'git@github.myco.com:fooble')

      ghs.base_github_api_url_for_remote.should == 'https://github.myco.com'
    end

  end


  it "#url_to_base_github_api_url" do
    c = GitHubService::Configuration

    c.url_to_base_github_api_url('ssh://git@github.myco.com/fooble').should == 'https://github.myco.com'
    c.url_to_base_github_api_url('git://myco.com/jdigger/git-process.git').should == 'https://myco.com'
    c.url_to_base_github_api_url('http://github.myco.com/fooble').should == 'http://github.myco.com'
    c.url_to_base_github_api_url('http://tu@github.myco.com/fooble').should == 'http://github.myco.com'
    c.url_to_base_github_api_url('https://github.myco.com/fooble').should == 'https://github.myco.com'
    c.url_to_base_github_api_url('https://github.com/fooble').should == 'https://api.github.com'
  end


  def auth_json
    JSON({:note_url => 'http://jdigger.github.com/git-process',
          :scopes => %w(repo user gist), :note => "Git-Process"})
  end

end
