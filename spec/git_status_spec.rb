require 'git-process/git_status'
require 'GitRepoHelper'
require 'fileutils'

describe GitProc::GitStatus do
  include GitRepoHelper


  def log_level
    Logger::ERROR
  end


  before(:each) do
    create_files(%w(.gitignore))
    gitlib.commit('initial')
  end


  after(:each) do
    rm_rf(gitlib.workdir)
  end


  it 'should handle added files' do
    create_files(['a', 'b file.txt', 'c'])

    gitlib.status.added.should == ['a', 'b file.txt', 'c']
  end


  it 'should handle a modification on both sides' do
    change_file_and_commit('a', '')

    gitlib.checkout('fb', :new_branch => 'master')
    change_file_and_commit('a', 'hello')

    gitlib.checkout('master')
    change_file_and_commit('a', 'goodbye')

    gitlib.merge('fb') rescue ''

    status = gitlib.status
    status.unmerged.should == %w(a)
    status.modified.should == %w(a)
  end


  it "should handle an addition on both sides" do
    gitlib.checkout('fb', :new_branch => 'master')
    change_file_and_commit('a', 'hello')

    gitlib.checkout('master')
    change_file_and_commit('a', 'goodbye')

    gitlib.merge('fb') rescue ''

    status = gitlib.status
    status.unmerged.should == %w(a)
    status.added.should == %w(a)
  end


  it "should handle a merge deletion on fb" do
    change_file_and_commit('a', '')

    gitlib.checkout('fb', :new_branch => 'master')
    gitlib.remove('a', :force => true)
    gitlib.commit('removed a')

    gitlib.checkout('master')
    change_file_and_commit('a', 'goodbye')

    gitlib.merge('fb') rescue ''

    status = gitlib.status
    status.unmerged.should == %w(a)
    status.deleted.should == %w(a)
  end


  it "should handle a merge deletion on master" do
    change_file_and_commit('a', '')

    gitlib.checkout('fb', :new_branch => 'master')
    change_file_and_commit('a', 'hello')

    gitlib.checkout('master')
    gitlib.remove('a', :force => true)
    gitlib.commit('removed a')

    gitlib.merge('fb') rescue ''

    status = gitlib.status
    status.unmerged.should == %w(a)
    status.deleted.should == %w(a)
  end


  it "should handle a move/rename" do
    FileUtils.cp __FILE__, File.join(gitlib.workdir, 'a file.txt')
    gitlib.add('a file.txt')
    gitlib.commit('a with content')

    FileUtils.cp __FILE__, File.join(gitlib.workdir, 'b file.txt')
    gitlib.remove 'a file.txt'
    gitlib.add 'b file.txt'

    status = gitlib.status
    status.deleted.should == ['a file.txt']
    status.added.should == ['b file.txt']
  end


  it "should return an empty result" do
    gitlib.status.added.should == []
    gitlib.status.deleted.should == []
    gitlib.status.modified.should == []
    gitlib.status.unmerged.should == []
  end

end
