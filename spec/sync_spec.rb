require 'git-process/sync'
require 'GitRepoHelper'

describe GitProc::Sync do
  include GitRepoHelper

  before(:each) do
    create_files(['.gitignore'])
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


  it "should fail when pushing with non-fast-forward and no force" do
    change_file_and_commit('a', '')

    gitprocess.branch('fb', :base_branch => 'master')

    gp = clone('fb')
    gitprocess.checkout('fb') do
      change_file_and_commit('a', 'hello', gitprocess)
    end

    expect {
      GitProc::Sync.new(gp.workdir, {:rebase => false, :force => false, :log_level => log_level}).runner
    }.to raise_error GitProc::GitExecuteError
  end


  describe "when forcing the push" do

    def create_process(dir, opts)
      GitProc::Sync.new(dir, opts.merge({:rebase => false, :force => true}))
    end


    it "should work when pushing with non-fast-forward" do
      change_file_and_commit('a', '')

      gitprocess.branch('fb', :base_branch => 'master')

      gp = clone('fb')
      gitprocess.checkout('fb') do
        change_file_and_commit('a', 'hello', gitprocess)
      end

      expect {
        GitProc::Sync.new(dir, opts.merge({:rebase => false, :force => true, :log_level => log_level})).runner
      }.to_not raise_error GitProc::GitExecuteError
    end

  end


  describe "when rebasing" do

    def create_process(dir, opts)
      GitProc::Sync.new(dir, opts.merge({:rebase => true, :force => false}))
    end


    it "should work when pushing (non-fast-forward)" do
      change_file_and_commit('a', '')

      gitprocess.branch('fb', :base_branch => 'master')

      clone('fb') do |gp|
        gitprocess.checkout('fb') do
          change_file_and_commit('a', 'hello', gitprocess)
        end

        expect {gp.runner}.to_not raise_error GitProc::GitExecuteError
      end
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

    expect {gitprocess.verify_preconditions}.to raise_error GitProc::ParkedChangesError
  end

end
