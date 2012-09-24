require 'git-process/git_status'
require 'GitRepoHelper'
require 'fileutils'

describe GitProc::GitStatus do
  include GitRepoHelper


  def log_level
    Logger::ERROR
  end


  before(:each) do
    create_files(['.gitignore'])
    gitprocess.commit('initial')
  end


  after(:each) do
    rm_rf(@tmpdir)
  end


  it "should handle added files" do
    create_files(['a', 'b file.txt', 'c'])

    gitprocess.status.added.should == ['a', 'b file.txt', 'c']
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


  it "should handle a move/rename" do
    FileUtils.cp __FILE__, File.join(gitprocess.workdir, 'a file.txt')
    gitprocess.add('a file.txt')
    gitprocess.commit('a with content')

    FileUtils.cp __FILE__, File.join(gitprocess.workdir, 'b file.txt')
    gitprocess.remove 'a file.txt'
    gitprocess.add 'b file.txt'

    status = gitprocess.status
    status.deleted.should == ['a file.txt']
    status.added.should == ['b file.txt']
  end


  it "should return an empty result" do
    gitprocess.status.added.should == []
    gitprocess.status.deleted.should == []
    gitprocess.status.modified.should == []
    gitprocess.status.unmerged.should == []
  end

end
