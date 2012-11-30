require 'git-process/git_lib'
require 'GitRepoHelper'
require 'git_lib_stub'

describe GitProc::GitLib do

  def gitlib
    gitprocess
  end


  describe "branches" do
    include GitRepoHelper

    it "list all the branches" do
      create_files(%w(.gitignore))
      gitlib.commit('initial')

      gitlib.branch('ba', :base_branch => 'master')
      gitlib.branch('bb', :base_branch => 'master')
      gitlib.branch('origin/master', :base_branch => 'master')

      gitlib.branches.names.should == %w(ba bb master origin/master)
    end

  end


  describe "branch" do
    attr_reader :lib

    before(:each) do
      @lib = GitLibStub.new
    end


    it "should create a branch with default base" do
      lib.stub(:command).with(:branch, %w(test_branch master))
      lib.branch('test_branch')
    end


    it "should create a branch with explicit base" do
      lib.stub(:command).with(:branch, %w(test_branch other_branch))
      lib.branch('test_branch', :base_branch => 'other_branch')
    end


    it "should delete a branch without force" do
      lib.stub(:command).with(:branch, %w(-d test_branch))
      lib.branch('test_branch', :delete => true)
    end


    it "should delete a branch with force" do
      lib.stub(:command).with(:branch, %w(-D test_branch))
      lib.branch('test_branch', :delete => true, :force => true)
    end

  end


  describe "push" do
    attr_reader :lib

    before(:each) do
      @lib = GitLibStub.new
    end


    def log_level
      Logger::ERROR
    end


    it "should push local branch to remote" do
      lib.should_receive(:command).with(:push, %w(remote local_branch:test_branch))

      lib.push('remote', 'local_branch', 'test_branch')
    end


    it "should push current branch to remote" do
      lib.stub(:command).with(:branch, %w(-a --no-color)).and_return("* my_branch\n")
      lib.should_receive(:command).with(:push, %w(remote my_branch:my_branch))

      lib.push('remote', 'my_branch', nil)
    end


    it "should remove named branch on remote" do
      lib.stub(:remote_name).and_return('remote')
      lib.stub(:config).and_return('master')
      lib.should_receive(:command).with(:push, %w(remote --delete my_branch))

      lib.push('remote', 'my_branch', nil, :delete => true)
    end


    it "should remove current branch on remote" do
      lib.stub(:remote_name).and_return('remote')
      lib.stub(:config).and_return('master')
      lib.should_receive(:command).with(:push, %w(remote --delete my_branch))

      lib.push('remote', nil, nil, :delete => 'my_branch')
    end


    it "should not remove integration branch on remote" do
      lib.stub(:remote_name).and_return('remote')
      lib.stub(:config).and_return('master')

      expect { lib.push('remote', nil, nil, :delete => 'master') }.should raise_error GitProc::GitProcessError
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


  describe "#expanded_url" do
    include GitRepoHelper

    it "should work for an ssh address" do
      gitlib.add_remote('torigin', 'tuser@github.myco.com:jdigger/git-process.git')

      gitlib.expanded_url('torigin').should == 'tuser@github.myco.com:jdigger/git-process.git'
    end


    it "should work for an http address" do
      gitlib.add_remote('torigin', 'http://github.myco.com:8080/jdigger/git-process.git')

      gitlib.expanded_url('torigin').should == 'http://github.myco.com:8080/jdigger/git-process.git'
    end


    it "should work for an https address" do
      gitlib.add_remote('torigin', 'https://github.myco.com/jdigger/git-process.git')

      gitlib.expanded_url('torigin').should == 'https://github.myco.com/jdigger/git-process.git'
    end


    it "should work for an ssh-configged url address" do
      gitlib.add_remote('origin', 'mygithub:jdigger/git-process.git')

      content = "\nHost mygithub\n"+
          "  User tuser\n"+
          "  HostName github.myco.com\n"

      in_tempfile('ssh_config', content) do |file|
        gitlib.expanded_url('origin', :ssh_config_file => file.path).should == 'tuser@github.myco.com:jdigger/git-process.git'
      end
    end

  end


  describe "#hostname_and_user_from_ssh_config" do
    include GitRepoHelper

    it "should find in a single entry" do
      content = "\nHost mygithub\n"+
          "  User git\n"+
          "  HostName github.myco.com\n"

      in_tempfile('ssh_config', content) do |file|
        gitlib.hostname_and_user_from_ssh_config('mygithub', file.path).should == %w(github.myco.com git)
      end
    end


    it "should find in multiple entries" do
      content = "\nHost mygithub1\n"+
          "  User gittyw\n"+
          "  HostName github.mycoy.com\n"+
          "Host mygithub2\n"+
          "  User gitty\n"+
          "  HostName github.myco.com\n"+
          "Host mygithub3\n"+
          "  User gittyz\n"+
          "  HostName github.mycoz.com\n"

      in_tempfile('ssh_config', content) do |file|
        gitlib.hostname_and_user_from_ssh_config('mygithub2', file.path).should == %w(github.myco.com gitty)
      end
    end


    it "should return nil when no file" do
      gitlib.hostname_and_user_from_ssh_config('mygithub', '/bogus_file').should == nil
    end


    it "should return nil when given an unknown host" do
      content = "\nHost mygithub1\n"+
          "  User gittyw\n"+
          "  HostName github.mycoy.com\n"+
          "Host mygithub2\n"+
          "  User gitty\n"+
          "  HostName github.myco.com\n"+
          "Host mygithub3\n"+
          "  User gittyz\n"+
          "  HostName github.mycoz.com\n"

      in_tempfile('ssh_config', content) do |file|
        gitlib.hostname_and_user_from_ssh_config('UNKNOWNZ', file.path).should == nil
      end
    end


    it "should return nil when no hostname for an existing host" do
      content = "\nHost mygithub1\n"+
          "  User gittyw\n"+
          "  HostName github.mycoy.com\n"+
          "Host mygithub2\n"+
          "  User gitty\n"+
          "Host mygithub3\n"+
          "  User gittyz\n"+
          "  HostName github.mycoz.com\n"

      in_tempfile('ssh_config', content) do |file|
        gitlib.hostname_and_user_from_ssh_config('mygithub2', file.path).should == nil
      end
    end


    it "should return hostname but no username when no user for an existing host" do
      content = "\nHost mygithub1\n"+
          "  User gittyw\n"+
          "  HostName github.mycoy.com\n"+
          "Host mygithub2\n"+
          "  HostName github.myco.com\n"+
          "Host mygithub3\n"+
          "  User gittyz\n"+
          "  HostName github.mycoz.com\n"

      in_tempfile('ssh_config', content) do |file|
        gitlib.hostname_and_user_from_ssh_config('mygithub2', file.path).should == ['github.myco.com', nil]
      end
    end

  end

end


def in_tempfile(filename, content, &block)
  file = Tempfile.new(filename)
  file.puts content
  file.flush

  begin
    block.call(file)
  ensure
    file.close
    file.unlink
  end
end

