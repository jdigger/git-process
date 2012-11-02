require 'git-process/sync'
require 'GitRepoHelper'

describe GitProc::Sync do
  include GitRepoHelper

  before(:each) do
    create_files(%w(.gitignore))
    gitprocess.commit('initial')
  end


  after(:each) do
    rm_rf(tmpdir)
  end


  def log_level
    Logger::ERROR
  end


  def create_process(dir, opts)
    GitProc::Sync.new(dir, opts.merge({:rebase => false, :force => false}))
  end


  it "should work when pushing with fast-forward" do
    change_file_and_commit('a', '')

    gitprocess.branch('fb', :base_branch => 'master')

    gp = clone('fb')
    change_file_and_commit('a', 'hello', gp)
    gp.branches.include?('origin/fb').should be_true
    GitProc::Sync.new(gp.workdir, {:rebase => false, :force => false, :log_level => log_level}).runner
    gp.branches.include?('origin/fb').should be_true
    gitprocess.branches.include?('fb').should be_true
  end


  it "should work with a different remote server name" do
    change_file_and_commit('a', '')

    gitprocess.branch('fb', :base_branch => 'master')

    gp = clone('fb', 'a_remote')
    change_file_and_commit('a', 'hello', gp)
    gp.branches.include?('a_remote/fb').should be_true
    GitProc::Sync.new(gp.workdir, {:rebase => false, :force => false, :log_level => log_level}).runner
    gp.branches.include?('a_remote/fb').should be_true
    gitprocess.branches.include?('fb').should be_true
  end


  describe "when forcing the push" do

    def create_process(dir, opts)
      GitProc::Sync.new(dir, opts.merge({:rebase => false, :force => true}))
    end


    it "should work when pushing with non-fast-forward" do
      change_file_and_commit('a', '')

      gitprocess.branch('fb', :base_branch => 'master')

      clone('fb') do |gp|
        gitprocess.checkout('fb') do
          change_file_and_commit('a', 'hello', gitprocess)
        end

        expect {
          GitProc::Sync.new(gp.workdir, {:rebase => false, :force => true, :log_level => log_level}).runner
        }.to_not raise_error GitProc::GitExecuteError
      end
    end

  end


  describe "when changes are made upstream" do

    def create_process(dir, opts)
      GitProc::Sync.new(dir, opts.merge({:rebase => false, :force => false}))
    end


    it "should work when pushing with non-fast-forward by merging" do
      change_file_and_commit('a', '')

      gitprocess.branch('fb', :base_branch => 'master')

      clone('fb') do |gp|

        gitprocess.checkout('fb') do
          change_file_and_commit('a', 'hello', gitprocess)
        end

        expect {
          gp.runner
        }.to_not raise_error GitProc::GitExecuteError
      end
    end

  end


  describe "when rebasing" do

    def create_process(dir, opts)
      GitProc::Sync.new(dir, opts.merge({:rebase => true, :force => false}))
    end


    it "should work when pushing (non-fast-forward)" do
      change_file_and_commit('a', '')

      gp = clone
      gp.checkout('fb', :new_branch => 'master')

      expect { gp.runner }.to_not raise_error GitProc::GitExecuteError

      change_file_and_commit('a', 'hello', gitprocess)

      expect { gp.runner }.to_not raise_error GitProc::GitExecuteError
    end


    it "should merge and then rebase if remote feature branch changed" do
      change_file_and_commit('a', '')

      gitprocess.checkout('fb', :new_branch => 'master')

      gp = clone
      gp.checkout('fb', :new_branch => 'origin/master')

      change_file_and_commit('b', 'hello', gp)
      change_file_and_commit('a', 'hello', gitprocess)
      change_file_and_commit('b', 'goodbye', gp)
      change_file_and_commit('a', 'goodbye', gitprocess)
      gitprocess.checkout('master')

      expect { gp.runner }.to_not raise_error GitProc::GitExecuteError
    end

  end


  describe "when forcing local-only" do

    def create_process(dir, opts)
      GitProc::Sync.new(dir, opts.merge({:rebase => true, :force => false, :local => true}))
    end


    it "should not try to push" do
      change_file_and_commit('a', '')

      gitprocess.branch('fb', :base_branch => 'master')

      gp = clone('fb')
      gitprocess.checkout('fb') do
        change_file_and_commit('a', 'hello', gitprocess)
      end

      sp = GitProc::Sync.new(gp.workdir, {:rebase => true, :force => false, :local => true, :log_level => log_level})
      sp.should_receive(:fetch) # want to get remote changes
      sp.should_not_receive(:push) # ...but not push any

      sp.runner
    end

  end


  describe "when there is no remote" do

    def create_process(dir, opts)
      GitProc::Sync.new(dir, opts.merge({:rebase => true, :force => false, :local => false}))
    end


    it "should not try to fetch or push" do
      change_file_and_commit('a', '')

      gitprocess.branch('fb', :base_branch => 'master')

      sp = GitProc::Sync.new(gitprocess.workdir, {:rebase => true, :force => false, :local => true, :log_level => log_level})
      sp.should_not_receive(:fetch)
      sp.should_not_receive(:push)

      sp.runner
    end

  end


  describe "when default rebase flag is used" do

    def create_process(dir, opts)
      GitProc::Sync.new(dir, opts.merge({:rebase => false, :force => false, :local => false}))
    end


    it "should try to rebase by flag" do
      change_file_and_commit('a', '', gitprocess)

      gitprocess.branch('fb', :base_branch => 'master')

      sp = GitProc::Sync.new(gitprocess.workdir, {:rebase => true, :force => false, :local => true, :log_level => log_level})
      sp.should_receive(:rebase)
      sp.should_not_receive(:merge)

      sp.runner
    end


    it "should try to rebase by config" do
      change_file_and_commit('a', '', gitprocess)

      gitprocess.branch('fb', :base_branch => 'master')
      gitprocess.config('gitProcess.defaultRebaseSync', 'true')

      sp = GitProc::Sync.new(gitprocess.workdir, {:rebase => false, :force => false, :local => true, :log_level => log_level})
      sp.should_receive(:rebase)
      sp.should_not_receive(:merge)

      sp.runner
    end


    it "should not try to rebase by false config" do
      change_file_and_commit('a', '', gitprocess)

      gitprocess.branch('fb', :base_branch => 'master')
      gitprocess.config('gitProcess.defaultRebaseSync', 'false')

      sp = GitProc::Sync.new(gitprocess.workdir, {:rebase => false, :force => false, :local => true, :log_level => log_level})
      sp.should_not_receive(:rebase)
      sp.should_receive(:merge)

      sp.runner
    end


    it "should not try to rebase by false config" do
      change_file_and_commit('a', '', gitprocess)

      gitprocess.branch('fb', :base_branch => 'master')
      gitprocess.config('gitProcess.defaultRebaseSync', 'false')

      sp = GitProc::Sync.new(gitprocess.workdir, {:rebase => false, :force => false, :local => true, :log_level => log_level})
      sp.should_not_receive(:rebase)
      sp.should_receive(:merge)

      sp.runner
    end


    it "should try to rebase by true config" do
      change_file_and_commit('a', '', gitprocess)

      gitprocess.branch('fb', :base_branch => 'master')
      gitprocess.config('gitProcess.defaultRebaseSync', 'true')

      sp = GitProc::Sync.new(gitprocess.workdir, {:rebase => false, :force => false, :local => true, :log_level => log_level})
      sp.should_receive(:rebase)
      sp.should_not_receive(:merge)

      sp.runner
    end

  end


  it "should work with a different remote server name than 'origin'" do
    change_file_and_commit('a', '')

    gitprocess.branch('fb', :base_branch => 'master')

    gp = clone('fb', 'a_remote')
    change_file_and_commit('a', 'hello', gp)
    gp.branches.include?('a_remote/fb').should be_true
    GitProc::Sync.new(gp.workdir, {:rebase => false, :force => false, :log_level => log_level}).runner
    gp.branches.include?('a_remote/fb').should be_true
    gitprocess.branches.include?('fb').should be_true
  end


  it 'should fail when removing current feature while on _parking_' do
    gitprocess.checkout('_parking_', :new_branch => 'master')
    change_file_and_commit('a', '')

    expect { gitprocess.verify_preconditions }.to raise_error GitProc::ParkedChangesError
  end

end
