require 'git-process/git_lib'
require 'GitRepoHelper'

describe GitProc::GitLib do

  class GLStub
    include GitProc::GitLib

    def initialize(workdir, log_level)
      @logger = Logger.new(STDOUT)
      @logger.level = log_level || Logger::WARN
      @logger.datetime_format = "%Y-%m-%d %H:%M:%S"
      f = Logger::Formatter.new
      @logger.formatter = proc do |severity, datetime, progname, msg|
        "#{msg}\n"
      end

      @workdir = workdir
      if workdir
        if File.directory?(File.join(workdir, '.git'))
          logger.debug { "Opening existing repository at #{workdir}" }
        else
          logger.info { "Initializing new repository at #{workdir}" }
          command(:init)
        end
      end
    end


    def workdir
      @workdir
    end

    def logger
      @logger
    end
  end


  def gitlib
    gitprocess
  end


  describe "branches" do
    include GitRepoHelper

    it "list all the branches" do
      create_files(['.gitignore'])
      gitlib.commit('initial')

      gitlib.branch('ba', :base_branch => 'master')
      gitlib.branch('bb', :base_branch => 'master')
      gitlib.branch('origin/master', :base_branch => 'master')

      gitlib.branches.names.should == ['ba', 'bb', 'master', 'origin/master']
    end

  end


  describe "branch" do
    attr_reader :lib

    before(:each) do
      @lib = GLStub.new(nil, nil)
    end


    it "should create a branch with default base" do
      lib.stub(:command).with(:branch, ['test_branch', 'master'])
      lib.branch('test_branch')
    end


    it "should create a branch with explicit base" do
      lib.stub(:command).with(:branch, ['test_branch', 'other_branch'])
      lib.branch('test_branch', :base_branch => 'other_branch')
    end


    it "should delete a branch without force" do
      lib.stub(:command).with(:branch, ['-d', 'test_branch'])
      lib.branch('test_branch', :delete => true)
    end


    it "should delete a branch with force" do
      lib.stub(:command).with(:branch, ['-D', 'test_branch'])
      lib.branch('test_branch', :delete => true, :force => true)
    end

  end


  describe "push" do
    attr_reader :lib

    before(:each) do
      @lib = GLStub.new(nil, nil)
    end


    def log_level
      Logger::ERROR
    end


    it "should push local branch to remote" do
      lib.should_receive(:command).with(:push, ['remote', 'local_branch:test_branch'])

      lib.push('remote', 'local_branch', 'test_branch')
    end


    it "should push current branch to remote" do
      lib.stub(:command).with(:branch, ['-a', '--no-color']).and_return("* my_branch\n")
      lib.should_receive(:command).with(:push, ['remote', 'my_branch:my_branch'])

      lib.push('remote', 'my_branch', nil)
    end


    it "should remove named branch on remote" do
      lib.stub(:remote_name).and_return('remote')
      lib.stub(:config).and_return('master')
      lib.should_receive(:command).with(:push, ['remote', '--delete', 'my_branch'])

      lib.push('remote', 'my_branch', nil, :delete => true)
    end


    it "should remove current branch on remote" do
      lib.stub(:remote_name).and_return('remote')
      lib.stub(:config).and_return('master')
      lib.should_receive(:command).with(:push, ['remote', '--delete', 'my_branch'])

      lib.push('remote', nil, nil, :delete => 'my_branch')
    end


    it "should not remove integration branch on remote" do
      lib.stub(:remote_name).and_return('remote')
      lib.stub(:config).and_return('master')

      expect {lib.push('remote', nil, nil, :delete => 'master')}.should raise_error GitProc::GitProcessError
    end

  end


  describe "#remote_name" do
    include GitRepoHelper

    def log_level
      Logger::ERROR
    end


    it "should work with origin" do
      change_file_and_commit('a', '')

      clone('master', 'origin') do |gl|
        gl.remote_name.should == 'origin'
        gl.branches.include?('origin/master').should be_true
      end
    end


    it "should work with a different remote name" do
      change_file_and_commit('a', '')

      clone('master', 'a_remote') do |gl|
        gl.remote_name.should == 'a_remote'
        gl.branches.include?('a_remote/master').should be_true
      end
    end


    it "should work with an overridden remote name" do
      change_file_and_commit('a', '')

      clone('master', 'a_remote') do |gl|
        gl.config('gitProcess.remoteName', 'something_else')

        gl.remote_name.should == 'something_else'
      end
    end

  end

end
