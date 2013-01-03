require 'git-process/git_lib'
require 'GitRepoHelper'

describe GitProc::GitBranch do
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


  describe "contains_all_of" do

    it "should handle the trivial case" do
      current = gitlib.branches.current
      current.contains_all_of(current.name).should == true
    end


    it "should handle new branch containing base branch that did not change" do
      base_branch = gitlib.branches.current

      gitlib.checkout('fb', :new_branch => base_branch.name)
      current = gitlib.branches.current

      change_file_and_commit('a', 'hello')

      current.contains_all_of(base_branch.name).should == true
    end


    it "should handle new branch containing base branch that did change" do
      base_branch = gitlib.branches.current

      gitlib.checkout('fb', :new_branch => base_branch.name)
      current = gitlib.branches.current

      gitlib.checkout(base_branch.name)
      change_file_and_commit('a', 'goodbye')

      current.contains_all_of(base_branch.name).should == false
    end


    it "should handle containing in both branches" do
      base_branch = gitlib.branches.current

      gitlib.checkout('fb', :new_branch => base_branch.name)
      current = gitlib.branches.current

      change_file_and_commit('a', 'hello')

      gitlib.checkout(base_branch.name)
      change_file_and_commit('a', 'goodbye')

      current.contains_all_of(base_branch.name).should == false
    end

  end


  describe "is_ahead_of" do

    it "should handle the trivial case" do
      current = gitlib.branches.current
      current.is_ahead_of(current.name).should == false # same is not "ahead of"
    end


    it "should handle new branch containing base branch that did not change" do
      base_branch = gitlib.branches.current

      gitlib.checkout('fb', :new_branch => base_branch.name)
      current = gitlib.branches.current

      change_file_and_commit('a', 'hello')

      current.is_ahead_of(base_branch.name).should == true
    end


    it "should handle new branch containing base branch that did change" do
      base_branch = gitlib.branches.current

      gitlib.checkout('fb', :new_branch => base_branch.name)
      current = gitlib.branches.current

      gitlib.checkout(base_branch.name)
      change_file_and_commit('a', 'goodbye')

      current.is_ahead_of(base_branch.name).should == false
    end


    it "should handle containing in both branches" do
      base_branch = gitlib.branches.current

      gitlib.checkout('fb', :new_branch => base_branch.name)
      current = gitlib.branches.current

      change_file_and_commit('a', 'hello')

      gitlib.checkout(base_branch.name)
      change_file_and_commit('a', 'goodbye')

      current.is_ahead_of(base_branch.name).should == false
    end

  end

end
