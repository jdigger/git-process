require 'git-process'
require 'GitRepoHelper'

describe Git::Process do
  include GitRepoHelper

  before(:each) do
    create_files(['.gitignore'])
    gitlib.commit('initial')
  end


  after(:each) do
    rm_rf(tmpdir)
  end


  describe "rebase to master" do

    it "should work easily for a simple rebase" do
      gitlib.checkout('master', :new_branch => 'fb')
      change_file_and_commit('a', '')

      commit_count.should == 2

      gitlib.checkout('master')
      change_file_and_commit('b', '')

      gitlib.checkout('fb')

      gitprocess.rebase_to_master

      commit_count.should == 3
    end


    it "should work for a rebase after a rerere merge" do
      tgz_file = File.expand_path('../files/merge-conflict-rerere.tgz', __FILE__)
      Dir.chdir(tmpdir) { `tar xfz #{tgz_file}` }

      begin
        gitprocess.rebase_to_master
        raise "Should have raised RebaseError"
      rescue Git::Process::RebaseError => exp
        exp.resolved_files.should == ['a']
        exp.unresolved_files.should == []

        exp.commands.length.should == 3
        exp.commands[0].should match /^# Verify/
        exp.commands[1].should == 'git add a'
        exp.commands[2].should == 'git rebase --continue'
      end
    end

  end


  describe "remove current feature branch" do

    def log_level
      Logger::ERROR
    end


    describe "when handling the parking branch" do

      it "should create it based on origin/master" do
        gitlib.command(:branch, 'origin/master')

        gitprocess.remove_feature_branch
        gitlib.branches.current.name.should == '_parking_'
      end


      it "should move it to the new origin/master if it already exists and is clean" do
        gitlib.command(:branch, ['origin/master', 'master'])
        gitlib.command(:branch, ['_parking_', 'origin/master'])
        change_file_and_commit('a', '')  # still on 'master'

        gitlib.command(:checkout, ['-b', 'fb', 'origin/master'])
        gitprocess.remove_feature_branch
        gitlib.branches.current.name.should == '_parking_'
      end


      it "should move it to the new origin/master if it already exists and changes are part of the current branch" do
        gitlib.command(:branch, ['origin/master', 'master'])
        gitlib.command(:checkout, ['-b', '_parking_', 'origin/master'])
        change_file_and_commit('a', '')
        gitlib.command(:checkout, ['-b', 'fb', '_parking_'])
        gitlib.command(:checkout, 'origin/master')
        gitlib.command(:merge, 'fb')
        gitlib.command(:checkout, 'fb')

        gitprocess.remove_feature_branch
        gitlib.branches.current.name.should == '_parking_'
      end


      it "should move it out of the way if it has unaccounted changes on it" do
        gitlib.command(:branch, ['origin/master', 'master'])
        gitlib.command(:checkout, ['-b', '_parking_', 'origin/master'])
        change_file_and_commit('a', '')
        gitlib.command(:checkout, ['-b', 'fb', 'origin/master'])

        gitlib.branches.include?('_parking_OLD_').should be_false
        gitprocess.remove_feature_branch
        gitlib.branches.include?('_parking_OLD_').should be_true
        gitlib.branches.current.name.should == '_parking_'
      end

    end


    it "should delete the old local branch when it has been merged into origin/master" do
      gitlib.command(:branch, ['origin/master', 'master'])
      change_file_and_commit('a', '')  # still on 'master'

      gitlib.command(:checkout, ['-b', 'fb', 'origin/master'])
      gitlib.branches.include?('fb').should be_true
      gitprocess.remove_feature_branch
      gitlib.branches.include?('fb').should be_false
      gitlib.branches.current.name.should == '_parking_'
    end


    it "should raise an error when the local branch has not been merged into origin/master" do
      gitlib.command(:branch, ['origin/master', 'master'])
      gitlib.command(:checkout, ['-b', 'fb', 'origin/master'])
      change_file_and_commit('a', '')  # on 'fb'

      gitlib.branches.include?('fb').should be_true
      expect {gitprocess.remove_feature_branch}.should raise_error Git::Process::GitProcessError
    end


    it "should delete the old remote branch" do
      change_file_and_commit('a', '')

      gitlib.command(:branch, ['fb', 'master'])

      td = Dir.mktmpdir
      gl = Git::GitLib.new(td, :log_level => log_level)
      gl.command(:remote, ['add', 'origin', "file://#{tmpdir}"])
      gl.fetch
      gl.checkout('fb')

      begin
        gl.branches.include?('origin/fb').should be_true
        Git::Process.new(nil, gl).remove_feature_branch
        gl.branches.include?('origin/fb').should be_false
        gitlib.branches.include?('fb').should be_false
        gl.branches.current.name.should == '_parking_'
      ensure
        rm_rf(td)
      end
    end


    describe "when used while on _parking_" do

      it 'should fail #rebase_to_master' do
        gitlib.checkout('master', :new_branch => '_parking_')
        change_file_and_commit('a', '')

        expect {gitprocess.rebase_to_master}.should raise_error Git::Process::ParkedChangesError
      end


      it 'should fail #sync_with_server' do
        gitlib.checkout('master', :new_branch => '_parking_')
        change_file_and_commit('a', '')

        expect {gitprocess.sync_with_server(false)}.should raise_error Git::Process::ParkedChangesError
      end

    end

  end

end
