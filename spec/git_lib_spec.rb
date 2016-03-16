require 'git-process/git_lib'
require 'GitRepoHelper'
include GitProc


describe GitLib, :git_repo_helper do


  def log_level
    Logger::ERROR
  end


  describe 'workdir' do

    it 'should use the passed in directory when the top level is a git workdir' do
      dir = Dir.mktmpdir
      mkdir_p "#{dir}/.git"
      gitlib = GitLib.new(dir, :log_level => Logger::ERROR)
      gitlib.workdir.should == dir
    end


    it "should find the parent git workdir" do
      topdir = Dir.mktmpdir
      mkdir_p "#{topdir}/.git"
      dir = "#{topdir}/a/b/c/d/e/f/g"
      mkdir_p dir
      gitlib = GitLib.new(dir, :log_level => Logger::ERROR)
      gitlib.workdir.should == topdir
    end

  end


  describe 'branches' do

    it 'list all the branches' do
      gitlib.branch('ba', :base_branch => 'master')
      gitlib.branch('bb', :base_branch => 'master')
      gitlib.branch('origin/master', :base_branch => 'master')

      gitlib.branches.names.should == %w(ba bb master origin/master)
    end

  end


  describe 'rev_parse' do

    it 'parses a known branch name' do
      expect(gitlib.rev_parse('master')).not_to be_empty
    end


    it 'does not try to parse a file name as a revision name' do
      file = gitlib.workdir + '/fooble.txt'
      FileUtils.touch(file, :verbose => false)
      gitlib.add file
      gitlib.commit 'test'
      expect(gitlib.rev_parse('fooble.txt')).to be_nil
    end


    it 'empty for an unknown branch name' do
      expect(gitlib.rev_parse('skdfklsjhdfklerouwh')).to be_nil
    end

  end


  describe 'set_upstream_branch' do
    include GitRepoHelper

    it 'updates for remote branch' do
      gitlib.branch('ba/bb', :base_branch => 'master')
      clone_repo do |gl|
        gl.checkout('new_branch', :new_branch => 'origin/master')
        gl.set_upstream_branch('new_branch', 'origin/ba/bb')

        gl.config['branch.new_branch.remote'].should == 'origin'
        gl.config['branch.new_branch.merge'].should == 'refs/heads/ba/bb'
      end
    end


    it 'updates for local branch' do
      gitlib.branch('ba', :base_branch => 'master')
      gitlib.checkout('new_branch', :new_branch => 'master')
      gitlib.set_upstream_branch('new_branch', 'ba')

      gitlib.config['branch.new_branch.remote'].should == nil
      gitlib.config['branch.new_branch.merge'].should == 'refs/heads/ba'
    end


    it 'updates for local branch that looks remote' do
      gitlib.branch('other/ba', :base_branch => 'master')
      gitlib.checkout('new_branch', :new_branch => 'master')
      gitlib.set_upstream_branch('new_branch', 'other/ba')

      gitlib.config['branch.new_branch.remote'].should == nil
      gitlib.config['branch.new_branch.merge'].should == 'refs/heads/other/ba'
    end

  end


  describe 'fetch' do

    it 'parse the list of changes' do
      output = '' '
remote: Counting objects: 1028, done.
remote: Compressing objects: 100% (301/301), done.
remote: Total 699 (delta 306), reused 654 (delta 273)
Receiving objects: 100% (699/699), 600.68 KiB | 686 KiB/s, done.
Resolving deltas: 100% (306/306), completed with 84 local objects.
From remote.system.com:tuser/test-proj
   8e667e0..19ecc91  SITE_TOUR_MODAL -> origin/SITE_TOUR_MODAL
 + cea75d7...d656188 WEBCMS-2014 -> origin/WEBCMS-2014  (forced update)
 * [new branch]      WEBCMS-2047 -> origin/WEBCMS-2047
   ca9e80e..d383005  WEBCMS-2157 -> origin/WEBCMS-2157
   77b5d5c..f485c7f  WEBCMS-2159 -> origin/WEBCMS-2159
 * [new branch]      WEBCMS-2166 -> origin/WEBCMS-2166
   c648f2a..86ee15e  WEBCMS-2167 -> origin/WEBCMS-2167
 * [new tag]         RELEASE_1.0.1.53 -> RELEASE_1.0.1.53
 * [new tag]         RELEASE_1.0.1.54 -> RELEASE_1.0.1.54
 x [deleted]         (none)     -> origin/WEBCMS-4650-resi-breadcrumbs
 * [new branch]      WEBCMS-2169 -> origin/WEBCMS-2169
 * [new branch]      base-carousel -> origin/base-carousel
   1de9c437..7546667 develop    -> origin/develop
   90e8d75..23ae7d1  new-ui-smoketest -> origin/new-ui-smoketest
 * [new branch]      webcms-2023 -> origin/webcms-2023
   b9797f8..dd24a9f  webcms-2135 -> origin/webcms-2135
 * [new branch]      webcms-831-faq-web-service -> origin/webcms-831-faq-web-service
 x [deleted]         (none)     -> origin/webcms-1315-masthead
' ''
      changes = gitlib.fetch_changes(output)

      changes[:new_branch].size().should == 6
      changes[:new_tag].size().should == 2
      changes[:deleted].size().should == 2
      changes[:force_updated].size().should == 1
      changes[:updated].size().should == 7

      empty_changes = gitlib.fetch_changes('')

      empty_changes[:new_branch].size().should == 0
      empty_changes[:new_tag].size().should == 0
      empty_changes[:deleted].size().should == 0
      empty_changes[:force_updated].size().should == 0
      empty_changes[:updated].size().should == 0
    end

  end


  describe "branch" do

    it "should create a branch with default base" do
      gitlib.stub(:command).with(:branch, %w(test_branch master))
      gitlib.branch('test_branch')
    end


    it "should create a branch with explicit base" do
      gitlib.should_receive(:command).with(:branch, %w(test_branch other_branch))
      gitlib.branch('test_branch', :base_branch => 'other_branch')
    end


    it 'should delete a branch without force' do
      gitlib.should_receive(:command).with(:branch, %w(-d test_branch))
      gitlib.branch('test_branch', :delete => true)
    end


    it 'should delete a branch with force' do
      gitlib.should_receive(:command).with(:branch, %w(-D test_branch))
      gitlib.branch('test_branch', :delete => true, :force => true)
    end


    it "should rename a branch" do
      gitlib.should_receive(:command).with(:branch, %w(-m test_branch new_branch))
      gitlib.branch('test_branch', :rename => 'new_branch')
    end

  end


  describe "push" do

    it "should push local branch to remote" do
      gitlib.should_receive(:command).with(:push, %w(remote local_branch:test_branch))

      gitlib.push('remote', 'local_branch', 'test_branch')
    end


    it "should push current branch to remote" do
      gitlib.stub(:command).with(:branch, %w(-a --no-color)).and_return("* my_branch\n")
      gitlib.should_receive(:command).with(:push, %w(remote my_branch:my_branch))

      gitlib.push('remote', 'my_branch', nil)
    end


    it "should remove named branch on remote" do
      gitlib.remote.stub(:name).and_return('remote_server')
      gitlib.config.stub(:master_branch).and_return('master')
      gitlib.should_receive(:command).with(:push, %w(remote_server --delete my_branch))

      gitlib.push('remote_server', 'my_branch', nil, :delete => true)
    end


    it "should remove current branch on remote" do
      gitlib.remote.stub(:name).and_return('remote_server')
      gitlib.config.stub(:master_branch).and_return('master')
      gitlib.should_receive(:command).with(:push, %w(remote_server --delete my_branch))

      gitlib.push('remote_server', nil, nil, :delete => 'my_branch')
    end


    it "should not remove integration branch on remote" do
      gitlib.remote.stub(:name).and_return('remote_server')
      gitlib.config.stub(:master_branch).and_return('master')

      expect { gitlib.push('remote_server', nil, nil, :delete => 'master') }.to raise_error GitProcessError
    end

  end

end
