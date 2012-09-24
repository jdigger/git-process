require 'git-process/sync'
require 'GitRepoHelper'

module GitProc

  class CFHStub < Process
    include ChangeFileHelper


    def cleanup
      stash_pop if @stash_pushed
    end

  end

end


describe GitProc::ChangeFileHelper do
  include GitRepoHelper

  before(:each) do
    create_files(%w(.gitignore))
    gitprocess.commit('initial')
  end


  after(:each) do
    rm_rf(tmpdir)
  end


  def log_level
    Logger::ERROR
  end


  def create_process(dir, opts)
    GitProc::CFHStub.new(dir, opts)
  end


  describe "uncommitted changes" do

    it 'should fail when there are unmerged files' do
      change_file_and_commit('modified file.txt', 'start')

      gp = clone
      change_file_and_commit('modified file.txt', 'changed', gp)
      change_file_and_commit('modified file.txt', 'conflict', gitprocess)
      gp.fetch

      gp.merge('origin/master') rescue ''

      expect { gp.offer_to_help_uncommitted_changes }.should raise_error GitProc::UncommittedChangesError
    end


    describe "using 'unknown' file" do

      before(:each) do
        change_file('unknown file.txt', '')
        gitprocess.stub(:say)
      end


      it 'should then add it' do
        gitprocess.stub(:ask).and_return('a')
        gitprocess.should_receive(:add).with(['unknown file.txt'])

        gitprocess.offer_to_help_uncommitted_changes
      end


      it 'should ignore the file' do
        gitprocess.stub(:ask).and_return('i')
        gitprocess.should_not_receive(:add)

        gitprocess.offer_to_help_uncommitted_changes
      end

    end


    describe "using changed files" do

      before(:each) do
        change_file_and_commit('modified file.txt', 'start')
        change_file_and_commit('modified file2.txt', 'start')
        change_file_and_commit('modified file3.txt', 'start')
        change_file_and_commit('modified file4.txt', 'start')
        change_file_and_commit('removed file.txt', 'content')
        change_file_and_add('added file.txt', '')
        change_file('modified file.txt', 'modified')
        change_file_and_add('modified file2.txt', 'modified')
        change_file_and_add('modified file3.txt', 'modified')
        change_file('modified file2.txt', 'modified again')
        change_file_and_add('removed file2.txt', 'content')
        change_file_and_add('modified file4.txt', 'content')
        File.delete(File.join(gitprocess.workdir, 'removed file.txt'))
        File.delete(File.join(gitprocess.workdir, 'removed file2.txt'))
        File.delete(File.join(gitprocess.workdir, 'modified file3.txt'))

        # End state of the above is:
        # A  "added file.txt"
        #  M "modified file.txt"
        # MM "modified file2.txt"
        # MD "modified file3.txt"
        # M  "modified file4.txt"
        #  D "removed file.txt"
        # AD "removed file2.txt"

        gitprocess.stub(:say)
      end


      it 'should ask about modified files, then commit them' do
        gitprocess.stub(:ask).and_return('c')
        gitprocess.should_receive(:add).with(["added file.txt", "modified file.txt", "modified file2.txt", "modified file4.txt"])
        gitprocess.should_receive(:remove).with(["modified file3.txt", "removed file.txt", "removed file2.txt"])
        gitprocess.should_receive(:commit).with(nil)

        gitprocess.offer_to_help_uncommitted_changes
      end


      it 'should ask about modified files, then stash them' do
        gitprocess.stub(:ask).and_return('s')

        gitprocess.offer_to_help_uncommitted_changes

        gitprocess.status.clean?.should be_true

        gitprocess.cleanup

        stat = gitprocess.status
        stat.added.should == ["added file.txt", "removed file2.txt"]
        stat.modified.should == ["modified file.txt", "modified file2.txt", "modified file4.txt"]
        stat.deleted.should == ["modified file3.txt", "removed file.txt"]
      end

    end

  end

end
