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

end
