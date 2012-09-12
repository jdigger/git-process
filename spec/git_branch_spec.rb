require 'git-process/new_fb'
require 'GitRepoHelper'

describe GitProc::GitBranch do
  include GitRepoHelper

  before(:each) do
    create_files(['.gitignore'])
    gitprocess.commit('initial')
  end


  after(:each) do
    rm_rf(tmpdir)
  end


  def create_process(dir, opts)
    opts[:branch_name] = 'test_branch'
    GitProc::NewFeatureBranch.new(dir, opts)
  end


  describe "#new_feature_branch" do

    def log_level
      Logger::ERROR
    end


    it "should create the named branch against origin/master" do
      clone do |gp|
        new_branch = gp.runner

        new_branch.name.should == 'test_branch'
        new_branch.sha.should == gp.branches['origin/master'].sha
      end
    end


    it "should bring committed changes on _parking_ over to the new branch" do
      gitprocess.branch('origin/master', :base_branch => 'master')
      gitprocess.checkout('_parking_', :new_branch => 'master')
      change_file_and_commit('a', '')
      change_file_and_commit('b', '')

      new_branch = gitprocess.runner

      new_branch.name.should == 'test_branch'
      Dir.chdir(gitprocess.workdir) do |dir|
        File.exists?('a').should be_true
        File.exists?('b').should be_true
      end

      gitprocess.branches.parking.should be_nil
    end


    it "should use 'integration_branch' instead of 'remote_master_branch'" do
      change_file_and_commit('a', '')

      new_branch = gitprocess.runner

      new_branch.name.should == 'test_branch'
    end


    it "should bring new/uncommitted changes on _parking_ over to the new branch" do
      gitprocess.branch('origin/master', :base_branch => 'master')
      gitprocess.checkout('_parking_', :new_branch => 'master')
      change_file_and_commit('a', '')
      change_file_and_add('b', '')
      change_file('c', '')

      new_branch = gitprocess.runner

      new_branch.name.should == 'test_branch'
      Dir.chdir(gitprocess.workdir) do |dir|
        File.exists?('a').should be_true
        File.exists?('b').should be_true
        File.exists?('c').should be_true
      end

      gitprocess.branches.parking.should be_nil
    end

  end

end
