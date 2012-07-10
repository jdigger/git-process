require 'git-process/git_process'
require 'GitRepoHelper'
require 'fileutils'

describe GitProc::Process do
  include GitRepoHelper

  before(:each) do
    create_files(['.gitignore'])
    gitprocess.commit('initial')
  end


  after(:each) do
    rm_rf(tmpdir)
  end


  describe "workdir" do

    it "should use the passed in directory when the top level is a git workdir" do
      proc = GitProc::Process.new(tmpdir)
      proc.workdir.should == tmpdir
    end


    it "should find the parent git workdir" do
      dir = "#{tmpdir}/a/b/c/d/e/f/g"
      mkdir_p dir
      proc = GitProc::Process.new(dir)
      proc.workdir.should == tmpdir
    end

  end

end
