require 'backports'
require_relative '../../lib/git-process/git-process'
require_relative '../FileHelpers'

describe Git::Process do

  before(:each) do
    @tmpdir = Dir.mktmpdir
    @gp = Git::Process.new(@tmpdir, :log_level => Logger::ERROR)
    create_files(['.gitignore'])
    @gp.lib.commit('initial')
  end


  after(:each) do
    rm_rf(@tmpdir)
  end


  def commit_count(gp)
    gp.lib.log_count
  end



  def create_files(file_names)
    Dir.chdir(@gp.lib.workdir) do |dir|
      file_names.each do |fn|
        @gp.lib.logger.debug {"Creating #{dir}/#{fn}"}
        FileUtils.touch fn
      end
    end
    @gp.lib.add(file_names)
  end



  def change_file_and_commit(filename, contents)
    Dir.chdir(@gp.lib.workdir) do
      File.open(filename, 'w') {|f| f.puts contents}
    end
    @gp.lib.add(filename)
    @gp.lib.commit("#{filename} - #{contents}")
  end


  describe "rebase to master" do

    it "should work easily for a simple rebase" do
      @gp.lib.checkout('master', :new_branch => 'fb')
      change_file_and_commit('a', '')

      commit_count(@gp).should == 2

      @gp.lib.checkout('master')
      change_file_and_commit('b', '')

      @gp.lib.checkout('fb')

      @gp.rebase_to_master

      commit_count(@gp).should == 3
    end


    it "should work for a rebase after a rerere merge" do
      tgz_file = File.expand_path('../../files/merge-conflict-rerere.tgz', __FILE__)
      Dir.chdir(@tmpdir) { `tar xfz #{tgz_file}` }
      gp = Git::Process.new(@tmpdir, :log_level => Logger::ERROR)

      begin
        gp.rebase_to_master
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
