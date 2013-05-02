require 'git-process/git_remote'
require 'GitRepoHelper'
include GitProc

describe GitRemote do

  def log_level
    Logger::ERROR
  end


  describe '#name' do
    include GitRepoHelper

    it 'should work with origin' do
      change_file_and_commit('a', '')

      clone_repo('master', 'origin') do |gl|
        gl.remote.name.should == 'origin'
        gl.branches.include?('origin/master').should be_true
      end
    end


    it 'should work with a different remote name' do
      change_file_and_commit('a', '')

      clone_repo('master', 'a_remote') do |gl|
        gl.remote.name.should == 'a_remote'
        gl.branches.include?('a_remote/master').should be_true
      end
    end


    it 'should work with an overridden remote name' do
      change_file_and_commit('a', '')

      clone_repo('master', 'a_remote') do |gl|
        gl.config['gitProcess.remoteName'] = 'something_else'

        gl.remote.name.should == 'something_else'
      end
    end

  end


  describe "#expanded_url" do
    include GitRepoHelper

    it "should work for an ssh address" do
      remote.add('torigin', 'tuser@github.myco.com:jdigger/git-process.git')

      remote.expanded_url('torigin').should == 'ssh://tuser@github.myco.com/jdigger/git-process.git'
    end


    it 'should work for an http address' do
      remote.add('torigin', 'http://github.myco.com:8080/jdigger/git-process.git')

      remote.expanded_url('torigin').should == 'http://github.myco.com:8080/jdigger/git-process.git'
    end


    it "should work for an https address" do
      remote.add('torigin', 'https://github.myco.com/jdigger/git-process.git')

      remote.expanded_url('torigin').should == 'https://github.myco.com/jdigger/git-process.git'
    end


    it "should work for an ssh-configured url address" do
      remote.add('origin', 'mygithub:jdigger/git-process.git')

      content = "\nHost mygithub\n"+
          "  User tuser\n"+
          "  HostName github.myco.com\n"

      in_tempfile('ssh_config', content) do |file|
        remote.expanded_url('origin', nil, :ssh_config_file => file.path).should == 'ssh://tuser@github.myco.com/jdigger/git-process.git'
      end
    end

  end


  describe "#repo_name" do
    include GitRepoHelper

    it "should work for an ssh address" do
      remote.add('torigin', 'tuser@github.myco.com:jdigger/git-process.git')

      remote.repo_name.should == 'jdigger/git-process'
    end


    it 'should work for an http address' do
      remote.add('torigin', 'http://github.myco.com:8080/jdigger/git-process.git')

      remote.repo_name.should == 'jdigger/git-process'
    end


    it "should work for an https address" do
      remote.add('torigin', 'https://github.myco.com/jdigger/git-process.git')

      remote.repo_name.should == 'jdigger/git-process'
    end


    it "should work for an ssh-configured url address" do
      remote.add('origin', 'mygithub:jdigger/git-process.git')

      content = "\nHost mygithub\n"+
          "  User tuser\n"+
          "  HostName github.myco.com\n"

      in_tempfile('ssh_config', content) do |file|
        remote.repo_name.should == 'jdigger/git-process'
      end
    end

  end


  describe "#hostname_and_user_from_ssh_config" do
    include GitRepoHelper

    it "should find in a single entry" do
      content = "\nHost mygithub\n"+
          "  User git\n"+
          "  HostName github.myco.com\n"

      in_tempfile('ssh_config', content) do |file|
        GitRemote.hostname_and_user_from_ssh_config('mygithub', file.path).should == %w(github.myco.com git)
      end
    end


    it "should find in multiple entries" do
      content = "\nHost mygithub1\n"+
          "  User gittyw\n"+
          "  HostName github.mycoy.com\n"+
          "Host mygithub2\n"+
          "  User gitty\n"+
          "  HostName github.myco.com\n"+
          "Host mygithub3\n"+
          "  User gittyz\n"+
          "  HostName github.mycoz.com\n"

      in_tempfile('ssh_config', content) do |file|
        GitRemote.hostname_and_user_from_ssh_config('mygithub2', file.path).should == %w(github.myco.com gitty)
      end
    end


    it "should return nil when no file" do
      GitRemote.hostname_and_user_from_ssh_config('mygithub', '/bogus_file').should == nil
    end


    it "should return nil when given an unknown host" do
      content = "\nHost mygithub1\n"+
          "  User gittyw\n"+
          "  HostName github.mycoy.com\n"+
          "Host mygithub2\n"+
          "  User gitty\n"+
          "  HostName github.myco.com\n"+
          "Host mygithub3\n"+
          "  User gittyz\n"+
          "  HostName github.mycoz.com\n"

      in_tempfile('ssh_config', content) do |file|
        GitRemote.hostname_and_user_from_ssh_config('UNKNOWNZ', file.path).should == nil
      end
    end


    it "should return nil when no hostname for an existing host" do
      content = "\nHost mygithub1\n"+
          "  User gittyw\n"+
          "  HostName github.mycoy.com\n"+
          "Host mygithub2\n"+
          "  User gitty\n"+
          "Host mygithub3\n"+
          "  User gittyz\n"+
          "  HostName github.mycoz.com\n"

      in_tempfile('ssh_config', content) do |file|
        GitRemote.hostname_and_user_from_ssh_config('mygithub2', file.path).should == nil
      end
    end


    it "should return hostname but no username when no user for an existing host" do
      content = "\nHost mygithub1\n"+
          "  User gittyw\n"+
          "  HostName github.mycoy.com\n"+
          "Host mygithub2\n"+
          "  HostName github.myco.com\n"+
          "Host mygithub3\n"+
          "  User gittyz\n"+
          "  HostName github.mycoz.com\n"

      in_tempfile('ssh_config', content) do |file|
        GitRemote.hostname_and_user_from_ssh_config('mygithub2', file.path).should == ['github.myco.com', nil]
      end
    end

  end

end


def in_tempfile(filename, content, &block)
  file = Tempfile.new(filename)
  file.puts content
  file.flush

  begin
    block.call(file)
  ensure
    file.close
    file.unlink
  end
end

