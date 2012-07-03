require 'git-process/git_status'
require 'GitRepoHelper'

describe GitProc::GitStatus do
  include GitRepoHelper

  before(:each) do
    create_files(['.gitignore'])
    gitprocess.commit('initial')
  end


  after(:each) do
    rm_rf(@tmpdir)
  end


  it "should handle added files" do
    create_files(['a', 'b', 'c'])

    gitprocess.status.added.should == ['a', 'b', 'c']
  end


  it "should handle a modification on both sides" do
    change_file_and_commit('a', '')

    gitprocess.checkout('fb', :new_branch => 'master')
    change_file_and_commit('a', 'hello')

    gitprocess.checkout('master')
    change_file_and_commit('a', 'goodbye')

    gitprocess.merge('fb') rescue

    status = gitprocess.status
    status.unmerged.should == ['a']
    status.modified.should == ['a']
  end


  it "should handle an addition on both sides" do
    gitprocess.checkout('fb', :new_branch => 'master')
    change_file_and_commit('a', 'hello')

    gitprocess.checkout('master')
    change_file_and_commit('a', 'goodbye')

    gitprocess.merge('fb') rescue

    status = gitprocess.status
    status.unmerged.should == ['a']
    status.added.should == ['a']
  end


  it "should handle a merge deletion on fb" do
    change_file_and_commit('a', '')

    gitprocess.checkout('fb', :new_branch => 'master')
    gitprocess.remove('a', :force => true)
    gitprocess.commit('removed a')

    gitprocess.checkout('master')
    change_file_and_commit('a', 'goodbye')

    gitprocess.merge('fb') rescue

    status = gitprocess.status
    status.unmerged.should == ['a']
    status.deleted.should == ['a']
  end


  it "should handle a merge deletion on master" do
    change_file_and_commit('a', '')

    gitprocess.checkout('fb', :new_branch => 'master')
    change_file_and_commit('a', 'hello')

    gitprocess.checkout('master')
    gitprocess.remove('a', :force => true)
    gitprocess.commit('removed a')

    gitprocess.merge('fb') rescue

    status = gitprocess.status
    status.unmerged.should == ['a']
    status.deleted.should == ['a']
  end


  it "should return an empty result" do
    gitprocess.status.added.should == []
    gitprocess.status.deleted.should == []
    gitprocess.status.modified.should == []
    gitprocess.status.unmerged.should == []
  end

end
