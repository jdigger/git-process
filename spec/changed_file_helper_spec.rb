require 'git-process/sync_process'
include GitProc

describe ChangeFileHelper, :git_repo_helper do

  def log_level
    Logger::ERROR
  end


  #noinspection RubyUnusedLocalVariable
  def create_process(dir, opts)
    nil
  end


  describe 'uncommitted changes' do

    it 'should fail when there are unmerged files' do
      change_file_and_commit('modified file.txt', 'start')

      clone_repo do |gl|
        change_file_and_commit('modified file.txt', 'changed', gl)
        change_file_and_commit('modified file.txt', 'conflict', gitlib)
        gl.fetch

        gl.merge('origin/master') rescue ''

        change_file_helper = ChangeFileHelper.new(gl)
        expect { change_file_helper.offer_to_help_uncommitted_changes }.to raise_error GitProc::UncommittedChangesError
      end
    end


    def change_file_helper
      @change_file_helper ||= ChangeFileHelper.new(gitlib)
    end


    describe "using 'unknown' file" do

      before(:each) do
        change_file('unknown file.txt', '')
        change_file_helper.stub(:say)
      end


      it 'should then add it' do
        ChangeFileHelper.stub(:ask_how_to_handle_unknown_files).and_return(:add)
        change_file_helper.gitlib.should_receive(:add).with(['unknown file.txt'])

        change_file_helper.offer_to_help_uncommitted_changes
      end


      it 'should ignore the file' do
        ChangeFileHelper.stub(:ask_how_to_handle_unknown_files).and_return(:ignore)
        change_file_helper.should_not_receive(:add)

        change_file_helper.offer_to_help_uncommitted_changes
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
        File.delete(File.join(gitlib.workdir, 'removed file.txt'))
        File.delete(File.join(gitlib.workdir, 'removed file2.txt'))
        File.delete(File.join(gitlib.workdir, 'modified file3.txt'))

        # End state of the above is:
        # A  "added file.txt"
        #  M "modified file.txt"
        # MM "modified file2.txt"
        # MD "modified file3.txt"
        # M  "modified file4.txt"
        #  D "removed file.txt"
        # AD "removed file2.txt"

        change_file_helper.stub(:say)
      end


      it 'should ask about modified files, then commit them' do
        ChangeFileHelper.stub(:ask_how_to_handle_changed_files).and_return(:commit)
        gitlib.should_receive(:add).with(["added file.txt", "modified file.txt", "modified file2.txt", "modified file4.txt"])
        gitlib.should_receive(:remove).with(["modified file3.txt", "removed file.txt", "removed file2.txt"])
        gitlib.should_receive(:commit).with(nil)

        change_file_helper.offer_to_help_uncommitted_changes
      end


      it 'should ask about modified files, then stash them' do
        ChangeFileHelper.stub(:ask_how_to_handle_changed_files).and_return(:stash)

        change_file_helper.offer_to_help_uncommitted_changes

        gitlib.status.clean?.should be_true

        gitlib.stash_pop

        stat = gitlib.status
        stat.added.should == ["added file.txt", "removed file2.txt"]
        stat.modified.should == ["modified file.txt", "modified file2.txt", "modified file4.txt"]
        stat.deleted.should == ["modified file3.txt", "removed file.txt"]
      end

    end

  end

end
