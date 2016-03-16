require 'git-process/pull_request'
require 'GitRepoHelper'
require 'github_test_helper'
require 'json'
require 'octokit'
require 'tempfile'

describe GitHub::PullRequest, :git_repo_helper do
  include GitHubTestHelper


  def test_token
    'hfgkdjfgksjhdfkls'
  end


  def pull_request
    @pr ||= GitHub::PullRequest.new(gitlib, 'test_remote', 'tester/test_repo', :user => 'test_user')
  end


  before(:each) do
    gitlib.config['gitProcess.github.authToken'] = test_token
    gitlib.remote.add('test_remote', 'git@github.com:test_repo.git')
  end


  describe '#create' do

    it 'should return a pull request for a good request' do
      stub_post('https://api.github.com/repos/tester/test_repo/pulls', :body => {:number => 1, :state => 'open'})

      pull_request.create('test_base', 'test_head', 'test title', 'test body')[:state].should == 'open'
    end


    it 'should handle asking for a duplicate pull request' do
      # trying to create the request should return "HTTP 422: Unprocessable Entity" because it already exists
      stub_post('https://api.github.com/repos/tester/test_repo/pulls', :status => 422)

      # listing all existing pull requests should contain the current branch
      stub_get('https://api.github.com/repos/tester/test_repo/pulls', :status => 200,
               :body => [{:html_url => 'test_url', :head => {:ref => 'test_head'}, :base => {:ref => 'test_base'}}])

      pull_request.create('test_base', 'test_head', 'test title', 'test body')[:html_url].should == 'test_url'
    end

  end


  describe 'get' do

    it 'should return a pull request for a good request' do
      stub_get('https://api.github.com/repos/tester/test_repo/pulls/1', :body => {:number => 1, :state => 'open'})

      pull_request.pull_request(1)[:state].should == 'open'
    end

  end


  describe '#close' do

    it 'should close a good current pull request' do
      stub_get('https://api.github.com/repos/tester/test_repo/pulls', :body => [
                                                                        {:number => 1, :state => 'open', :html_url => 'test_url', :head => {:ref => 'test_head'},
                                                                         :base => {:ref => 'test_base'}}])
      stub_patch('https://api.github.com/repos/tester/test_repo/pulls/1', :send => JSON({:state => 'closed'}),
                 :body => {:number => 1, :state => 'closed', :html_url => 'test_url', :head => {:ref => 'test_head'},
                           :base => {:ref => 'test_base'}})

      pull_request.close('test_base', 'test_head')[:state].should == 'closed'
    end


    it 'should close a good current pull request using the pull request number' do
      stub_patch('https://api.github.com/repos/tester/test_repo/pulls/1', :send => JSON({:state => 'closed'}),
                 :body => {:number => 1, :state => 'closed', :html_url => 'test_url',
                           :head => {:ref => 'test_head'}, :base => {:ref => 'test_base'}})

      pull_request.close(1)[:state].should == 'closed'
    end


    it 'should retry closing a good current pull request when getting a 422' do
      stub = stub_request(:patch, 'https://api.github.com/repos/tester/test_repo/pulls/1')

      stub.with(:body => JSON({:state => 'closed'}))

      stub.to_raise(Octokit::UnprocessableEntity.new).then.
          to_raise(Octokit::UnprocessableEntity.new).then.
          to_raise(Octokit::UnprocessableEntity.new).then.
          to_raise(Octokit::UnprocessableEntity.new).then.
          to_return(:status => 200, :body => {:number => 1, :state => 'closed', :html_url => 'test_url',
                                              :head => {:ref => 'test_head'}, :base => {:ref => 'test_base'}})

      pull_request.close(1)[:state].should == 'closed'
    end


    it 'should complain about a missing pull request' do
      stub_get('https://api.github.com/repos/tester/test_repo/pulls', :body => [
                                                                        {:number => 1, :state => 'open', :html_url => 'test_url', :head => {:ref => 'test_head'},
                                                                         :base => {:ref => 'test_base'}}])

      expect { pull_request.close('test_base', 'missing_head') }.to raise_error GitHub::PullRequest::NotFoundError
    end


    it 'should complain about wrong number of arguments' do
      expect { pull_request.close() }.to raise_error ::ArgumentError
      expect { pull_request.close('1', '2', '3') }.to raise_error ::ArgumentError
    end

  end

end
