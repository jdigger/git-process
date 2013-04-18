require 'git-process/new_fb'
require 'GitRepoHelper'
include GitProc


describe NewFeatureBranch do
  include GitRepoHelper

  before(:each) do
    create_files(%w(.gitignore))
    gitlib.commit('initial')
  end


  after(:each) do
    rm_rf(gitlib.workdir)
  end


  def create_process(dir, opts = {})
    opts[:branch_name] = 'test_branch'
    NewFeatureBranch.new(dir, opts)
  end


  describe '#new_feature_branch' do

    def log_level
      Logger::ERROR
    end


    it 'should create the named branch against origin/master' do
      clone_repo do |gl|
        gp = create_process(gl)
        gl.checkout('other_branch', :new_branch => 'master')
        change_file_and_commit('a', '', gl)
        change_file_and_commit('b', '', gl)
        new_branch = gp.runner

        new_branch.name.should == 'test_branch'
        new_branch.sha.should == gl.branches['origin/master'].sha
      end
    end


    it "should bring committed changes on _parking_ over to the new branch" do
      clone_repo do |gl|
        gl.checkout('_parking_', :new_branch => 'master')
        change_file_and_commit('a', '', gl)
        change_file_and_commit('b', '', gl)

        gp = create_process(gl)
        new_branch = gp.runner

        new_branch.name.should == 'test_branch'
        Dir.chdir(gl.workdir) do |_|
          File.exists?('a').should be_true
          File.exists?('b').should be_true
        end

        gl.config["branch.test_branch.remote"].should == 'origin'
        gl.config["branch.test_branch.merge"].should == 'refs/heads/master'

        gl.fetch
        gl.branches.parking.should be_nil
        new_branch.sha.should_not == gl.branches['origin/master'].sha
      end

    end


    it "should move new branch over to the integration branch" do
      clone_repo do |gl|
        gl.checkout('_parking_', :new_branch => 'master')
        change_file_and_commit('a', '', gitlib)
        change_file_and_commit('b', '', gitlib)

        gl.fetch
        gp = create_process(gl)
        new_branch = gp.runner

        new_branch.name.should == 'test_branch'
        Dir.chdir(gitlib.workdir) do |_|
          File.exists?('a').should be_true
          File.exists?('b').should be_true
        end

        gl.config["branch.test_branch.remote"].should == 'origin'
        gl.config["branch.test_branch.merge"].should == 'refs/heads/master'

        gl.fetch
        gl.branches.parking.should be_nil
        new_branch.sha.should == gl.branches['origin/master'].sha
      end

    end


    it "should use 'integration_branch' instead of 'remote_master_branch'" do
      change_file_and_commit('a', '')

      new_branch = gitprocess.runner

      new_branch.name.should == 'test_branch'
    end


    it "should bring new/uncommitted changes on _parking_ over to the new branch" do
      gitlib.branch('origin/master', :base_branch => 'master')
      gitlib.checkout('_parking_', :new_branch => 'master')
      change_file_and_commit('a', '')
      change_file_and_add('b', '')
      change_file('c', '')

      new_branch = gitprocess.runner

      new_branch.name.should == 'test_branch'
      Dir.chdir(gitlib.workdir) do |_|
        File.exists?('a').should be_true
        File.exists?('b').should be_true
        File.exists?('c').should be_true
      end

      gitlib.branches.parking.should be_nil
    end

  end

end
