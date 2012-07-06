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


  def create_process(dir, opts)
    opts[:rebase] = false
    opts[:force] = false
    GitProc::Sync.new(dir, opts)
  end


  describe "#run" do

    def log_level
      Logger::ERROR
    end


    it "should work when pushing with fast-forward" do
      change_file_and_commit('a', '')

      gitprocess.branch('fb', :base_branch => 'master')

      clone('fb') do |gp|
        change_file_and_commit('a', 'hello', gp)
        gp.branches.include?('origin/fb').should be_true
        gp.run
        gp.branches.include?('origin/fb').should be_true
        gitprocess.branches.include?('fb').should be_true
      end
    end


    it "should work with a different remote server name" do
      change_file_and_commit('a', '')

      gitprocess.branch('fb', :base_branch => 'master')

      clone('fb', 'a_remote') do |gp|
        change_file_and_commit('a', 'hello', gp)
        gp.branches.include?('a_remote/fb').should be_true
        gp.run
        gp.branches.include?('a_remote/fb').should be_true
        gitprocess.branches.include?('fb').should be_true
      end
    end


    it "should fail when pushing with non-fast-forward and no force" do
      change_file_and_commit('a', '')

      gitprocess.branch('fb', :base_branch => 'master')

      clone('fb') do |gp|
        gitprocess.checkout('fb') do
          change_file_and_commit('a', 'hello', gitprocess)
        end

        expect {gp.run}.should raise_error GitProc::GitExecuteError
      end
    end

  end


  describe "when forcing the push" do

    def create_process(dir, opts)
      opts[:force] = false
      opts[:force] = true
      GitProc::Sync.new(dir, opts)
    end


    it "should work when pushing with non-fast-forward" do
      change_file_and_commit('a', '')

      gitprocess.branch('fb', :base_branch => 'master')

      clone('fb') do |gp|
        gitprocess.checkout('fb') do
          change_file_and_commit('a', 'hello', gp)
        end

        expect {gp.run}.should_not raise_error GitProc::GitExecuteError
      end
    end

  end


  describe "sync_with_server with different remote name" do

    def log_level
      Logger::ERROR
    end


    def create_process(dir, opts)
      opts[:force] = false
      opts[:force] = true
      gp = GitProc::Sync.new(dir, opts)
      gp.instance_variable_set('@server_name', 'a_remote')
      gp
    end


    it "should work with a different remote server name" do
      change_file_and_commit('a', '')

      gitprocess.branch('fb', :base_branch => 'master')

      clone('fb', 'a_remote') do |gp|
        change_file_and_commit('a', 'hello', gp)
        gp.branches.include?('a_remote/fb').should be_true
        gp.run
        gp.branches.include?('a_remote/fb').should be_true
        gitprocess.branches.include?('fb').should be_true
      end
    end

  end


  describe "remove current feature branch when used while on _parking_" do

    it 'should fail #sync_with_server' do
      gitprocess.checkout('_parking_', :new_branch => 'master')
      change_file_and_commit('a', '')

      expect {gitprocess.run}.should raise_error GitProc::ParkedChangesError
    end

  end

end
