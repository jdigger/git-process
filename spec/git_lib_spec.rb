require 'git-process/git_lib'
require 'GitRepoHelper'
include GitProc


describe GitLib, :git_repo_helper do

  describe 'workdir' do

    it 'should use the passed in directory when the top level is a git workdir' do
      dir = Dir.mktmpdir
      mkdir_p "#{dir}/.git"
      gitlib = GitLib.new(dir, :log_level => Logger::ERROR)
      gitlib.workdir.should == dir
    end


    it "should find the parent git workdir" do
      topdir = Dir.mktmpdir
      mkdir_p "#{topdir}/.git"
      dir = "#{topdir}/a/b/c/d/e/f/g"
      mkdir_p dir
      gitlib = GitLib.new(dir, :log_level => Logger::ERROR)
      gitlib.workdir.should == topdir
    end

  end


  describe 'branches' do

    it 'list all the branches' do
      gitlib.branch('ba', :base_branch => 'master')
      gitlib.branch('bb', :base_branch => 'master')
      gitlib.branch('origin/master', :base_branch => 'master')

      gitlib.branches.names.should == %w(ba bb master origin/master)
    end

  end


  describe "branch" do

    it "should create a branch with default base" do
      gitlib.stub(:command).with(:branch, %w(test_branch master))
      gitlib.branch('test_branch')
    end


    it "should create a branch with explicit base" do
      gitlib.should_receive(:command).with(:branch, %w(test_branch other_branch))
      gitlib.branch('test_branch', :base_branch => 'other_branch')
    end


    it 'should delete a branch without force' do
      gitlib.should_receive(:command).with(:branch, %w(-d test_branch))
      gitlib.branch('test_branch', :delete => true)
    end


    it 'should delete a branch with force' do
      gitlib.should_receive(:command).with(:branch, %w(-D test_branch))
      gitlib.branch('test_branch', :delete => true, :force => true)
    end


    it "should rename a branch" do
      gitlib.should_receive(:command).with(:branch, %w(-m test_branch new_branch))
      gitlib.branch('test_branch', :rename => 'new_branch')
    end

  end


  describe "push" do

    it "should push local branch to remote" do
      gitlib.should_receive(:command).with(:push, %w(remote local_branch:test_branch))

      gitlib.push('remote', 'local_branch', 'test_branch')
    end


    it "should push current branch to remote" do
      gitlib.stub(:command).with(:branch, %w(-a --no-color)).and_return("* my_branch\n")
      gitlib.should_receive(:command).with(:push, %w(remote my_branch:my_branch))

      gitlib.push('remote', 'my_branch', nil)
    end


    it "should remove named branch on remote" do
      gitlib.remote.stub(:name).and_return('remote_server')
      gitlib.config.stub(:master_branch).and_return('master')
      gitlib.should_receive(:command).with(:push, %w(remote_server --delete my_branch))

      gitlib.push('remote_server', 'my_branch', nil, :delete => true)
    end


    it "should remove current branch on remote" do
      gitlib.remote.stub(:name).and_return('remote_server')
      gitlib.config.stub(:master_branch).and_return('master')
      gitlib.should_receive(:command).with(:push, %w(remote_server --delete my_branch))

      gitlib.push('remote_server', nil, nil, :delete => 'my_branch')
    end


    it "should not remove integration branch on remote" do
      gitlib.remote.stub(:name).and_return('remote_server')
      gitlib.config.stub(:master_branch).and_return('master')

      expect { gitlib.push('remote_server', nil, nil, :delete => 'master') }.to raise_error GitProcessError
    end

  end

end
