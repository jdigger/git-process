require 'git-process/github_configuration'
require 'json'
require 'github_test_helper'


describe GitHubService::Configuration, :git_repo_helper do
  include GitHubTestHelper


  def test_token
    'hfgkdjfgksjhdfkls'
  end


  def ghc
    @ghc ||= GitHubService::Configuration.new(gitlib.config, :user => 'tu', :password => 'dfsdf')
  end


  describe "create_authorization" do

    it "should return an auth_token for a good request" do
      gitlib.remote.add('origin', 'git@github.com:jdigger/git-process.git')
      stub_post('https://tu:dfsdf@api.github.com/authorizations', :send => auth_json,
                :body => {:token => test_token})

      ghc.create_authorization().should == test_token
    end


    it "should 401 for bad password" do
      gitlib.remote.add('origin', 'git@github.com:jdigger/git-process.git')
      stub_post('https://tu:dfsdf@api.github.com/authorizations', :send => auth_json,
                :status => 401)

      expect { ghc.create_authorization() }.to raise_error Octokit::Unauthorized
    end

  end


  describe "auth_token no username or password" do

    it "should get the token from config if it exists" do
      gitlib.config['github.user'] = 'test_user'
      gitlib.config['gitProcess.github.authToken'] = test_token

      ghc.auth_token.should == test_token
    end

  end


  describe "auth_token with password but no username" do

    def ghc
      @ghc ||= GitHubService::Configuration.new(gitlib.config, :user => nil, :password => 'dfsdf')
    end


    it "should get the token from the server if it does not exist in config" do
      gitlib.remote.add('origin', 'git@github.com:jdigger/git-process.git')
      gitlib.config['github.user'] = 'test_user'
      gitlib.config['gitProcess.github.authToken'] = ''

      stub_post('https://test_user:dfsdf@api.github.com/authorizations', :send => auth_json,
                :body => {:token => test_token})

      ghc.auth_token.should == test_token
    end

  end


  describe "user" do

    def ghc
      @ghc ||= GitHubService::Configuration.new(gitlib.config, :user => nil, :password => 'dfsdf')
    end


    it "should get the value from config" do
      gitlib.config['github.user'] = 'test_user'

      ghc.user.should == 'test_user'
    end


    it "should prompt the user and store it in the config" do
      gitlib.config['github.user'] = ''

      GitHubService::Configuration.stub(:ask_for_user).and_return('test_user')
      ghc.user.should == 'test_user'
    end

  end


  describe "using GHE instead of GitHub.com" do

    it "should use the correct server and path for a non-GitHub.com site" do
      gitlib.remote.add('origin', 'git@myco.com:jdigger/git-process.git')

      stub_post('https://tu:dfsdf@myco.com/api/v3/authorizations',
                :send => auth_json,
                :body => {:token => test_token})

      ghc.create_authorization().should == test_token
    end


    it "site should raise an error if remote.origin.url not set" do
      gitlib.config['remote.origin.url'] = ''

      expect { ghc.base_github_api_url_for_remote }.to raise_error GitHubService::NoRemoteRepository
    end


    it "site should not work for a garbage url address" do
      gitlib.remote.add('origin', 'garbage')

      expect { ghc.base_github_api_url_for_remote }.to raise_error URI::InvalidURIError
    end


    it "site should work for an ssh-configured url address" do
      gitlib.remote.add('origin', 'git@github.myco.com:fooble')

      ghc.base_github_api_url_for_remote.should == 'https://github.myco.com'
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
