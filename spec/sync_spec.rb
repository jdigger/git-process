require 'git-process/sync_process'
require 'GitRepoHelper'
require 'rugged'


describe Sync do
  include GitRepoHelper

  before(:each) do
    create_files(%w(.gitignore))
    gitlib.commit('initial')
  end


  after(:each) do
    rm_rf(gitlib.workdir)
  end


  def log_level
    Logger::ERROR
  end


  def create_process(base = gitlib, opts = {})
    GitProc::Sync.new(base, opts.merge({:rebase => false, :force => false}))
  end


  def verify_start_state
    # meant to overridden
  end


  it 'should work when pushing with fast-forward' do
    Given do
      origin 'fb', :new_branch => 'master'
      create_commit :b
      local 'fb', :new_branch => 'origin/fb'
      create_commit :c
    end

    when_sync_is_run

    Then do
      local_and_remote_are_same
      l_sha.should == @local.sha('origin/fb')
    end
  end


  it 'should work with a different remote server name' do
    Given do
      origin 'fb', :new_branch => 'master'
      create_commit :b
      local 'fb', :new_branch => 'a_remote/fb', :remote_name => 'a_remote'
      create_commit :c
    end

    when_sync_is_run

    Then do
      local_and_remote_are_same
      l_sha.should == @local.sha('a_remote/fb')
    end
  end

  it 'should work when the branch name contins a slash' do
    Given do
      origin 'user/fb', :new_branch => 'master'
      create_commit :b
      local 'user/fb', :new_branch => 'origin/user/fb'
      create_commit :c
    end

    @local.checkout('user/fb')
    create_process(@local).runner

    Then do
      branch_tip(local_repo, 'user/fb').should == branch_tip(origin_repo, 'user/fb')
      branch_tip(local_repo, 'user/fb').should == @local.sha('origin/user/fb')
    end
  end


  describe 'when forcing the push with a merge' do

    def create_process(gitlib, opts)
      GitProc::Sync.new(gitlib, opts.merge({:rebase => false, :force => true}))
    end


    it 'should work when pushing with non-fast-forward' do
      change_file_and_commit('a', '')

      gitlib.branch('fb', :base_branch => 'master')

      clone_repo('fb') do |gl|
        gitlib.checkout('fb') do
          change_file_and_commit('a', 'hello', gitlib)
        end

        GitProc::Sync.new(gl, :rebase => false, :force => true, :log_level => log_level).runner
      end
    end

  end


  describe 'when merging' do

    def create_process(gitlib, opts = {})
      GitProc::Sync.new(gitlib, opts.merge({:rebase => true, :force => false}))
    end


    context 'piece by piece' do
      it 'should do the same as rebase, but with merge - HOLDER'
    end

  end


  describe 'when rebasing' do

    def create_process(gitlib, opts = {})
      GitProc::Sync.new(gitlib, opts.merge({:rebase => true, :force => false}))
    end


    context 'piece by piece' do

      #
      # Legend for the symbols below:
      #   i - integration branch (i.e., 'origin/master')
      #   l - local/working feature branch (i.e., 'fb')
      #   r - remote feature branch (i.e., 'origin/fb')
      #

      before(:each) do
        @origin = gitlib
        @origin.config['receive.denyCurrentBranch'] = 'ignore'

        @a_sha = rcreate_commit :origin, 'HEAD', :a

        @local = clone_repo('master', 'origin')
      end


      after(:each) do
        rm_rf(@origin.workdir)
        rm_rf(@local.workdir)
      end


      #         i
      #        /
      # - A - C
      #   \
      #   B
      #   \
      #   l,r
      #
      # Steps to get to this state:
      #   1. Changes have been applied to the integration branch
      #   2. No work has happened on the feature branch since the last `sync`
      #
      describe 'if local/remote match' do

        def verify_start_state
          l_sha.should == @b_sha
          r_sha.should == @b_sha
          i_sha.should == @c_sha
          treeish(origin_repo, "#{@c_sha}~1").should == @a_sha
          treeish(origin_repo, "#{@b_sha}~1").should == @a_sha
        end


        #         i
        #        /
        # - A - C - B1
        #           /
        #         l,r
        it 'should work if no conflict' do
          Given do
            rcreate_commit_on_new_branch :origin, 'fb', 'master', :b
            rfetch local_repo, 'origin'
            local_repo.create_branch('fb', 'origin/fb')
            @local.write_sync_control_file('fb')
            rcreate_commit :origin, 'master', :c
          end

          when_sync_is_run

          Then do
            local_and_remote_are_same
            parent(l_sha).should == @c_sha
            check_file_content :b
          end
        end


        #         i
        #        /
        # - A - C - XX
        #   \      /
        #   B     l
        #   \
        #   r
        it 'should raise an error if there is a conflict' do
          Given do
            rcreate_commit_on_new_branch :origin, 'fb', 'master', :b, :file => 'a'
            rfetch local_repo, 'origin'
            local_repo.create_branch('fb', 'origin/fb')
            @local.write_sync_control_file('fb')
            rcreate_commit :origin, 'master', :c, :file => 'a'
          end

          expect { when_sync_is_run }.to raise_error(RebaseError, /'a' was modified in both branches/)
        end

      end

      #         i
      #        /
      # - A - C
      #   \
      #   B - D
      #   \   \
      #   r   l
      #
      # Steps to get to this state:
      #   1. Changes have been applied to the integration branch
      #   2. Work has happened locally only on the feature branch since the last `sync`
      #
      describe 'if local is a fast-forward of remote' do

        def verify_start_state
          l_sha.should == @d_sha
          r_sha.should == @b_sha
          i_sha.should == @c_sha
          treeish(origin_repo, "#{@c_sha}~1").should == @a_sha
          treeish(origin_repo, "#{@b_sha}~1").should == @a_sha
          treeish(local_repo, "#{@d_sha}~1").should == @b_sha
        end


        #         i
        #        /
        # - A - C - B1 - D1
        #                /
        #              l,r
        it 'should work if no conflict' do
          Given do
            rcreate_commit_on_new_branch :origin, 'fb', 'master', :b
            rfetch local_repo, 'origin'
            local_repo.create_branch('fb', 'origin/fb')
            @local.write_sync_control_file('fb')
            rcreate_commit :local, 'fb', :d
            rcreate_commit :origin, 'master', :c
          end

          when_sync_is_run

          Then do
            local_and_remote_are_same
            @local.sha("#{l_sha}~2").should == @c_sha
            check_file_content :b
            check_file_content :d
          end
        end


        #         i
        #        /
        # - A - C - XX
        #   \       \
        #   B - D   l
        #   \   \
        #   r   ??
        it 'should raise an error if there is a conflict' do
          Given do
            rcreate_commit_on_new_branch :origin, 'fb', 'master', :b, :file => 'a'
            rfetch local_repo, 'origin'
            local_repo.create_branch('fb', 'origin/fb')
            @local.write_sync_control_file('fb')
            rcreate_commit :local, 'fb', :d
            rcreate_commit :origin, 'master', :c, :file => 'a'
          end

          expect { when_sync_is_run }.to raise_error(RebaseError, /'a' was modified in both branches/)
        end

      end


      #         i     l
      #        /       \
      # - A - C - B1 - D
      #   \
      #   B
      #   \
      #   r
      #
      # Steps to get to this state:
      #   1. Changes have been applied to the integration branch
      #   2. The local feature branch is manually rebased with integration
      #   2. Work has happened locally only on the feature branch since the last `sync`
      #
      describe 'if local has already been rebased onto integration' do

        def verify_start_state
          l_sha.should == @d_sha
          r_sha.should == @b_sha
          i_sha.should == @c_sha
          treeish(origin_repo, "#{@c_sha}~1").should == @a_sha
          treeish(origin_repo, "#{@b_sha}~1").should == @a_sha
          treeish(local_repo, "#{@b1_sha}~1").should == @c_sha
          treeish(local_repo, "#{@d_sha}~2").should == @c_sha
        end


        #         i
        #        /
        # - A - C - B1 - D
        #               /
        #             l,r
        it 'should work' do
          Given do
            rcreate_commit_on_new_branch :origin, 'fb', 'master', :b
            rcreate_commit :origin, 'master', :c
            rfetch local_repo, 'origin'
            rcreate_commit_on_new_branch :local, 'fb', 'origin/master', :b1, :file => 'b'
            rcreate_commit :local, 'fb', :d
          end

          when_sync_is_run

          Then do
            local_and_remote_are_same
            treeish(local_repo, "#{l_sha}~2").should == @c_sha
          end
        end

      end


      #         i   r
      #        /   /
      # - A - C - B1
      #   \
      #   B - D
      #       \
      #       l
      #
      # Steps to get to this state:
      #   1. Changes have been applied to the integration branch
      #   2. The remote feature branch is rebased with integration, but no new work
      #   2. Work has happened locally on the feature branch
      #
      describe 'if remote has already been rebased onto integration' do

        def verify_start_state
          l_sha.should == @d_sha
          r_sha.should == @b1_sha
          i_sha.should == @c_sha
          treeish(origin_repo, "#{@c_sha}~1").should == @a_sha
          treeish(local_repo, "#{@b_sha}~1").should == @a_sha
          treeish(origin_repo, "#{@b1_sha}~1").should == @c_sha
          treeish(local_repo, "#{@d_sha}~1").should == @b_sha
        end


        #     i
        #    /
        # - A - C - B1 - D1
        #               /
        #             l,r
        it 'should work' do
          Given do
            rcreate_commit_on_new_branch :local, 'fb', 'origin/master', :b
            @local.write_sync_control_file('fb')
            rcreate_commit :local, 'fb', :d
            rcreate_commit :origin, 'master', :c
            rcreate_commit_on_new_branch :origin, 'fb', 'master', :b1, :file => 'b'
          end

          when_sync_is_run

          Then do
            local_and_remote_are_same
            l_sha.should_not == @d_sha
            treeish(local_repo, "#{l_sha}~1").should == @b1_sha
            treeish(local_repo, "#{l_sha}~2").should == @c_sha
          end
        end


        #         i   r
        #        /   /
        # - A - C - B1 - XX
        #   \            /
        #   B - D       l
        #       \
        #       ??
        it 'should raise an error if there is a conflict' do
          Given do
            rcreate_commit_on_new_branch :local, 'fb', 'origin/master', :b
            rcreate_commit :local, 'fb', :d, :file => 'a'
            rcreate_commit :origin, 'master', :c, :file => 'a'
            rcreate_commit_on_new_branch :origin, 'fb', 'master', :b1, :file => 'b'
          end

          expect { when_sync_is_run }.to raise_error(RebaseError, /'a' was modified in both branches/)
        end

      end


      #         i      r
      #        /       \
      # - A - C - B1 - D
      #   \
      #   B
      #   \
      #   l
      #
      # Steps to get to this state:
      #   1. Changes have been applied to the integration branch
      #   2. The remote feature branch is rebased with integration, but with new work
      #   2. Work has not happened locally on the feature branch
      #
      describe 'if remote is ahead of local' do

        def verify_start_state
          l_sha.should == @b_sha
          r_sha.should == @d_sha
          i_sha.should == @c_sha
          treeish(origin_repo, "#{@c_sha}~1").should == @a_sha
          treeish(local_repo, "#{@b_sha}~1").should == @a_sha
          treeish(origin_repo, "#{@b1_sha}~1").should == @c_sha
          treeish(origin_repo, "#{@d_sha}~1").should == @b1_sha
        end


        #     i
        #    /
        # - A - C - B1 - D
        #               /
        #             l,r
        it 'should work' do
          Given do
            rcreate_commit_on_new_branch :origin, 'fb', 'master', :b
            rfetch local_repo, 'origin'
            local_repo.create_branch('fb', 'origin/fb')
            @local.write_sync_control_file('fb')
            rcreate_commit :origin, 'master', :c
            rcreate_commit :origin, 'fb', :b1, :file => 'b', :parents => [@c_sha]
            rcreate_commit :origin, 'fb', :d
          end

          when_sync_is_run

          Then do
            local_and_remote_are_same
            l_sha.should == @d_sha
          end
        end


        #     i
        #    /
        # - A - C - B1 - D
        #               /
        #             l,r
        it 'should work without a control file' do
          Given do
            rcreate_commit_on_new_branch :origin, 'fb', 'master', :b
            rfetch local_repo, 'origin'
            local_repo.create_branch('fb', 'origin/fb')
            rcreate_commit :origin, 'master', :c
            rcreate_commit :origin, 'fb', :b1, :file => 'b', :parents => [@c_sha]
            rcreate_commit :origin, 'fb', :d
          end

          when_sync_is_run

          Then do
            local_and_remote_are_same
            l_sha.should == @d_sha
          end
        end

      end


      #         i
      #        /
      # - A - C
      #   \
      #   B - D
      #   \   \
      #   \   l
      #   E
      #    \
      #    r
      #
      # Steps to get to this state:
      #   1. Changes have been applied to the integration branch
      #   2. Work has happened locally
      #   3. Work has happened remotely
      #
      describe 'if local and remote both have work done on them, and remote has not been rebased' do

        def verify_start_state
          l_sha.should == @d_sha
          r_sha.should == @e_sha
          i_sha.should == @c_sha
          treeish(origin_repo, "#{@c_sha}~1").should == @a_sha
          treeish(origin_repo, "#{@b_sha}~1").should == @a_sha
          treeish(local_repo, "#{@d_sha}~1").should == @b_sha
          treeish(origin_repo, "#{@e_sha}~1").should == @b_sha
        end


        #         i          l,r
        #        /            \
        # - A - C - B1 - E1 - D1
        it 'should work if no conflict' do
          Given do
            rcreate_commit_on_new_branch :origin, 'fb', 'master', :b
            rfetch local_repo, 'origin'
            local_repo.create_branch('fb', 'origin/fb')
            @local.write_sync_control_file('fb')
            rcreate_commit :local, 'fb', :d
            rcreate_commit :origin, 'master', :c
            rcreate_commit :origin, 'fb', :e
          end

          when_sync_is_run

          Then do
            local_and_remote_are_same
            treeish(origin_repo, "#{l_sha}~3").should == @c_sha
            check_file_content :b
            check_file_content :d
          end
        end


        #         i   l
        #        /   /
        # - A - C - XX
        #   \
        #   B - D
        #   \   \
        #   \   ??
        #   E
        #    \
        #    r
        it 'should raise an error if conflict applying B' do
          Given do
            rcreate_commit_on_new_branch :origin, 'fb', 'master', :b, :file => 'a'
            rfetch local_repo, 'origin'
            local_repo.create_branch('fb', 'origin/fb')
            @local.write_sync_control_file('fb')
            rcreate_commit :local, 'fb', :d
            rcreate_commit :origin, 'master', :c, :file => 'a'
            rcreate_commit :origin, 'fb', :e
          end

          expect { when_sync_is_run }.to raise_error(RebaseError, /'a' was modified in both branches/)
        end


        #         i      l
        #        /       \
        # - A - C - B1 - XX
        #   \
        #   B - D
        #   \   \
        #   \   ??
        #   E
        #    \
        #    r
        it 'should raise an error if there is a conflict applying remote' do
          Given do
            rcreate_commit_on_new_branch :origin, 'fb', 'master', :b
            rfetch local_repo, 'origin'
            local_repo.create_branch('fb', 'origin/fb')
            @local.write_sync_control_file('fb')
            rcreate_commit :local, 'fb', :d
            rcreate_commit :origin, 'master', :c, :file => 'a'
            rcreate_commit :origin, 'fb', :e, :file => 'a'
          end

          expect { when_sync_is_run }.to raise_error(RebaseError, /'a' was modified in both branches/)
        end


        #         i           l
        #        /            \
        # - A - C - B1 - E1 - XX
        #   \
        #   B - D
        #   \   \
        #   \   ??
        #   E
        #    \
        #    r
        it 'should raise an error if conflict applying local' do
          Given do
            rcreate_commit_on_new_branch :origin, 'fb', 'master', :b
            rfetch local_repo, 'origin'
            local_repo.create_branch('fb', 'origin/fb')
            @local.write_sync_control_file('fb')
            rcreate_commit :local, 'fb', :d, :file => 'a'
            rcreate_commit :origin, 'master', :c, :file => 'a'
            rcreate_commit :origin, 'fb', :e
          end

          expect { when_sync_is_run }.to raise_error(RebaseError, /'a' was modified in both branches/)
        end

      end


      #         i   l
      #        /   /
      # - A - C - D
      #   \
      #   B
      #   \
      #   r
      #
      # Steps to get to this state:
      #   1. Changes have been applied to the integration branch
      #   2. Nothing has changed on the remote since the last sync
      #   3. Work has happened locally on the feature branch, and it is no longer a "simple" addition to the remote
      #
      describe 'if local is based on integration but not a "simple" version of remote' do

        def verify_start_state
          l_sha.should == @d_sha
          r_sha.should == @b_sha
          i_sha.should == @c_sha
          treeish(origin_repo, "#{@b_sha}~1").should == @a_sha
          treeish(origin_repo, "#{@c_sha}~1").should == @a_sha
          treeish(local_repo, "#{@d_sha}~1").should == @c_sha
        end


        #         i
        #        /
        # - A - C - D
        #          /
        #         l,r
        it 'should override remote branch' do
          Given do
            rcreate_commit_on_new_branch :origin, 'fb', 'master', :b
            rcreate_commit :origin, 'master', :c
            rfetch local_repo, 'origin'
            local_repo.create_branch('fb', 'origin/fb')
            @local.write_sync_control_file('fb')
            rcreate_commit :local, 'fb', :d, :parents => [@c_sha]
          end

          when_sync_is_run

          Then do
            local_and_remote_are_same
            l_sha.should == @d_sha
          end
        end

      end


      #           l
      #          /
      #         D
      #        /
      # - A - C - E
      #   \      /
      #   B     i
      #   \
      #   r
      #
      # Steps to get to this state:
      #   1. Changes have been applied to the integration branch
      #   2. Nothing has changed on the remote since the last sync
      #   2. Work has happened locally based on a newer version of integration, and it is no longer
      #      a "simple" addition to the remote
      #
      describe 'if local is not based on integration and not a "simple" version of remote' do

        def verify_start_state
          l_sha.should == @d_sha
          r_sha.should == @b_sha
          i_sha.should == @e_sha
          treeish(origin_repo, "#{@b_sha}~1").should == @a_sha
          treeish(origin_repo, "#{@c_sha}~1").should == @a_sha
          treeish(local_repo, "#{@d_sha}~1").should == @c_sha
          treeish(origin_repo, "#{@e_sha}~1").should == @c_sha
        end


        # - A - C - E - D1
        #          /    /
        #         i   l,r
        it 'should override remote branch' do
          Given do
            rcreate_commit_on_new_branch :origin, 'fb', 'master', :b
            rcreate_commit :origin, 'master', :c
            rfetch local_repo, 'origin'
            local_repo.create_branch('fb', 'origin/fb')
            @local.write_sync_control_file('fb')
            rcreate_commit :local, 'fb', :d, :parents => [@c_sha]
            rcreate_commit :origin, 'master', :e
          end

          when_sync_is_run

          Then do
            local_and_remote_are_same
            treeish(origin_repo, "#{l_sha}~1").should == @e_sha
          end
        end


        #           ??
        #          /
        #         D
        #        /
        # - A - C - E - XX
        #   \      /    /
        #   B     i    l
        #   \
        #   r
        it 'should raise an error with conflict on local content' do
          Given do
            rcreate_commit_on_new_branch :origin, 'fb', 'master', :b
            rcreate_commit :origin, 'master', :c
            rfetch local_repo, 'origin'
            local_repo.create_branch('fb', 'origin/fb')
            @local.write_sync_control_file('fb')
            rcreate_commit :local, 'fb', :d, :parents => [@c_sha], :file => 'a'
            rcreate_commit :origin, 'master', :e, :file => 'a'
          end

          expect { when_sync_is_run }.to raise_error(RebaseError, /'a' was modified in both branches/)
        end

      end


      #         i      r
      #        /       \
      # - A - C - B1 - E
      #   \
      #   B - D
      #       \
      #       l
      #
      # Steps to get to this state:
      #   1. Changes have been applied to the integration branch
      #   2. Work has happened locally based on an older version of integration
      #   3. Work has happened remotely based on rebasing against integration
      #
      describe 'if local and remote both have work done on them, and remote has been rebased with integration' do

        def verify_start_state
          l_sha.should == @d_sha
          r_sha.should == @e_sha
          i_sha.should == @c_sha
          treeish(local_repo, "#{@b_sha}~1").should == @a_sha
          treeish(origin_repo, "#{@b1_sha}~1").should == @c_sha
          treeish(origin_repo, "#{@c_sha}~1").should == @a_sha
          treeish(local_repo, "#{@d_sha}~1").should == @b_sha
          treeish(origin_repo, "#{@e_sha}~1").should == @b1_sha
        end


        # - A - C - B1 - E - D1
        #      /             /
        #     i            l,r
        it 'should work if no conflict' do
          Given do
            rcreate_commit_on_new_branch :origin, 'fb', 'master', :b
            rcreate_commit :origin, 'master', :c
            rfetch local_repo, 'origin'
            local_repo.create_branch('fb', 'origin/fb')
            @local.write_sync_control_file('fb')
            rcreate_commit :local, 'fb', :d
            rcreate_commit :origin, 'fb', :b1, :parents => [@c_sha], :file => 'b'
            rcreate_commit :origin, 'fb', :e
          end

          when_sync_is_run

          Then do
            local_and_remote_are_same
            treeish(origin_repo, "#{l_sha}~1").should == @e_sha
          end
        end


        #         i      r   l
        #        /       \   \
        # - A - C - B1 - E - XX
        #   \
        #   B - D
        #       \
        #       ??
        it 'should raise an error if there is a conflict' do
          Given do
            rcreate_commit_on_new_branch :origin, 'fb', 'master', :b
            rcreate_commit :origin, 'master', :c
            rfetch local_repo, 'origin'
            local_repo.create_branch('fb', 'origin/fb')
            @local.write_sync_control_file('fb')
            rcreate_commit :local, 'fb', :d, :file => 'a'
            rcreate_commit :origin, 'fb', :b1, :parents => [@c_sha], :file => 'b'
            rcreate_commit :origin, 'fb', :e, :file => 'a'
          end

          expect { when_sync_is_run }.to raise_error(RebaseError, /'a' was modified in both branches/)
        end

      end


      #              r
      #              \
      #         B1 - E
      #        /
      # - A - C - F
      #   \       \
      #   B - D   i
      #       \
      #       l
      #
      # Steps to get to this state:
      #   1. Changes have been applied to the integration branch
      #   2. Work has happened locally based on an older version of integration
      #   3. Work has happened remotely based on rebasing against integration
      #   4. More work happened on integration
      #
      describe 'if local and remote both have work done on them, remote has been rebased with integration, and more work has been done on integration' do

        def verify_start_state
          l_sha.should == @d_sha
          r_sha.should == @e_sha
          i_sha.should == @f_sha
          treeish(local_repo, "#{@b_sha}~1").should == @a_sha
          treeish(origin_repo, "#{@b1_sha}~1").should == @c_sha
          treeish(origin_repo, "#{@c_sha}~1").should == @a_sha
          treeish(local_repo, "#{@d_sha}~1").should == @b_sha
          treeish(origin_repo, "#{@e_sha}~1").should == @b1_sha
          treeish(origin_repo, "#{@f_sha}~1").should == @c_sha
        end


        # - A - C - F - B2 - E1 - D1
        #          /              /
        #         i             l,r
        it 'should work if no conflict' do
          Given do
            rcreate_commit_on_new_branch :origin, 'fb', 'master', :b
            rcreate_commit :origin, 'master', :c
            rfetch local_repo, 'origin'
            local_repo.create_branch('fb', 'origin/fb')
            @local.write_sync_control_file('fb')
            rcreate_commit :local, 'fb', :d
            rcreate_commit :origin, 'fb', :b1, :parents => [@c_sha], :file => 'b'
            rcreate_commit :origin, 'fb', :e
            rcreate_commit :origin, 'master', :f
          end

          when_sync_is_run

          Then do
            local_and_remote_are_same
            treeish(local_repo, "#{l_sha}~3").should == @f_sha
          end
        end


        #              r
        #              \
        #         B1 - E
        #        /
        # - A - C - F - XX
        #   \       \    \
        #   B - D   i    l
        #       \
        #       ??
        it 'should raise an error if conflict applying remote' do
          Given do
            rcreate_commit_on_new_branch :origin, 'fb', 'master', :b
            rcreate_commit :origin, 'master', :c
            rfetch local_repo, 'origin'
            local_repo.create_branch('fb', 'origin/fb')
            @local.write_sync_control_file('fb')
            rcreate_commit :local, 'fb', :d
            rcreate_commit :origin, 'fb', :b1, :parents => [@c_sha], :file => 'a'
            rcreate_commit :origin, 'fb', :e
            rcreate_commit :origin, 'master', :f, :file => 'a'
          end

          expect { when_sync_is_run }.to raise_error(RebaseError, /'a' was modified in both branches/)
        end


        #              r
        #              \
        #         B1 - E
        #        /
        # - A - C - F - B2 - E1 - XX
        #   \       \             /
        #   B - D   i            l
        #       \
        #       ??
        it 'should raise an error if conflict applying local' do
          Given do
            rcreate_commit_on_new_branch :origin, 'fb', 'master', :b
            rcreate_commit :origin, 'master', :c
            rfetch local_repo, 'origin'
            local_repo.create_branch('fb', 'origin/fb')
            @local.write_sync_control_file('fb')
            rcreate_commit :local, 'fb', :d, :file => 'a'
            rcreate_commit :origin, 'fb', :b1, :parents => [@c_sha], :file => 'b'
            rcreate_commit :origin, 'fb', :e, :file => 'a'
            rcreate_commit :origin, 'master', :f
          end

          expect { when_sync_is_run }.to raise_error(RebaseError, /'a' was modified in both branches/)
        end

      end


      describe 'with branch name' do

        def create_process(gitlib, opts = {})
          GitProc::Sync.new(gitlib, opts.merge({:branch_name => 'fb', :rebase => true, :force => false}))
        end


        #         i
        #        /
        # - A - C
        #   \
        #   B
        #   \
        #   r
        #
        # Steps to get to this state:
        #   1. There is a remote feature branch ("fb")
        #   2. The local repo does not have a feature branch by the same name
        #   3. The integration branch has moved on since the remote branch was last synced
        describe 'no local branch by the same name' do

          def verify_start_state
            Rugged::Branch.lookup(local_repo, 'fb').should be_nil
            r_sha.should == @b_sha
            i_sha.should == @c_sha
            treeish(origin_repo, "#{@c_sha}~1").should == @a_sha
            treeish(origin_repo, "#{@b_sha}~1").should == @a_sha
          end


          #         i  l,r
          #        /   /
          # - A - C - B1
          #
          it 'creates a local branch and rebases with integration' do
            Given do
              rcreate_commit_on_new_branch :origin, 'fb', 'master', :b
              rfetch local_repo, 'origin'
              rcreate_commit_on_new_branch :local, 'random', 'master', :z, :parents => []
              rcreate_commit :origin, 'master', :c
            end

            when_sync_is_run(false)

            Then do
              local_and_remote_are_same
              @local.config['branch.fb.remote'].should == 'origin'
              @local.config['branch.fb.merge'].should == 'refs/heads/master'
              parent(l_sha).should == @c_sha
            end
          end

        end


        #         i
        #        /
        # - A - C
        #   \
        #   B - l
        #   \
        #   D - r
        #
        # Steps to get to this state:
        #   1. There is a remote feature branch ("fb")
        #   2. The local repo has a feature branch by the same name that is fully within the remote's history
        #   3. The integration branch has moved on since the feature branches were last synced
        describe 'has local branch by same name subsumed by remote' do

          def verify_start_state
            Rugged::Branch.lookup(local_repo, 'fb').should_not be_nil
            l_sha.should == @b_sha
            r_sha.should == @d_sha
            i_sha.should == @c_sha
            treeish(origin_repo, "#{@c_sha}~1").should == @a_sha
            treeish(origin_repo, "#{@b_sha}~1").should == @a_sha
            treeish(origin_repo, "#{@d_sha}~1").should == @b_sha
          end


          #         i  l,r
          #        /   /
          # - A - C - B1
          #
          it 'change to the remote and rebases with integration if it is subsumed by the remote' do
            Given do
              rcreate_commit_on_new_branch :origin, 'fb', 'master', :b
              rfetch local_repo, 'origin'
              local_repo.create_branch('fb', 'origin/fb')
              rcreate_commit :origin, 'fb', :d
              rcreate_commit :origin, 'master', :c
            end

            when_sync_is_run(false)

            Then do
              local_and_remote_are_same
              @local.config['branch.fb.remote'].should == 'origin'
              @local.config['branch.fb.merge'].should == 'refs/heads/master'
              parent(l_sha).should == @c_sha
            end
          end

        end


        #         i
        #        /
        # - A - C
        #   \
        #   B
        #   \
        #   r
        #
        # Steps to get to this state:
        #   1. There is a remote feature branch ("fb")
        #   2. The local repo has a feature branch by the same name not fully in the remote's history
        #   3. The integration branch has moved on since the remote branch was last synced
        describe 'has local branch by same name not subsumed by remote' do

          def verify_start_state
            Rugged::Branch.lookup(local_repo, 'fb').should_not be_nil
            r_sha.should == @b_sha
            i_sha.should == @c_sha
            treeish(origin_repo, "#{@c_sha}~1").should == @a_sha
            treeish(origin_repo, "#{@b_sha}~1").should == @a_sha
          end


          #         i  l,r
          #        /   /
          # - A - C - B1
          #
          it 'should fail if it is not subsumed by the remote' do
            Given do
              rcreate_commit_on_new_branch :origin, 'fb', 'master', :b
              rcreate_commit_on_new_branch :local, 'fb', 'master', :z, :parents => []
              rcreate_commit :origin, 'master', :c
            end

            expect { when_sync_is_run(false) }.to raise_error(GitProcessError, /is not fully subsumed by origin\/fb/)
          end

        end


        describe 'unknown branch name' do

          def create_process(gitlib, opts = {})
            GitProc::Sync.new(gitlib, opts.merge({:branch_name => 'unknown', :rebase => true, :force => false}))
          end


          def verify_start_state
            Rugged::Branch.lookup(origin_repo, 'fb').should_not be_nil
            Rugged::Branch.lookup(local_repo, 'unknown').should be_nil
            Rugged::Branch.lookup(origin_repo, 'unknown').should be_nil
          end


          it 'should fail if it is not subsumed by the remote' do
            Given do
              rcreate_commit_on_new_branch :origin, 'fb', 'master', :b
            end

            expect { when_sync_is_run(false) }.to raise_error(GitProcessError, /There is not a remote branch for 'unknown'/)
          end

        end


        describe 'no remote' do

          def create_process(gitlib, opts = {})
            GitProc::Sync.new(gitlib, opts.merge({:branch_name => 'no_remote', :rebase => true, :force => false}))
          end


          def verify_start_state
            Rugged::Branch.lookup(local_repo, 'no_remote').should be_nil
          end


          it 'should fail if it is not subsumed by the remote' do
            Given do
              @local.command(:remote, ['rm', 'origin'])
            end

            expect { when_sync_is_run(false) }.to raise_error(GitProcessError, /Specifying 'no_remote' does not make sense without a remote/)
          end

        end

      end

    end


    describe 'when forcing local-only' do

      def create_process(dir, opts)
        GitProc::Sync.new(dir, opts.merge({:rebase => true, :force => false, :local => true}))
      end


      it 'should not try to push' do
        change_file_and_commit('a', '')

        gitlib.branch('fb', :base_branch => 'master')

        clone_repo('fb') do |gl|
          gitlib.checkout('fb')
          change_file_and_commit('a', 'hello', gitlib)

          sp = GitProc::Sync.new(gl, :rebase => true, :force => false, :local => true, :log_level => log_level)
          gl.should_receive(:fetch).at_least(1) # want to get remote changes
          gl.should_not_receive(:push) # ...but not push any

          sp.runner
        end
      end

    end
  end


  describe 'when there is no remote' do

    def create_process(base, opts)
      GitProc::Sync.new(base, opts.merge({:rebase => true, :force => false, :local => false}))
    end


    it 'should not try to fetch or push' do
      change_file_and_commit('a', '')

      gitlib.branch('fb', :base_branch => 'master')

      sp = GitProc::Sync.new(gitlib, :rebase => true, :force => false, :local => true, :log_level => log_level)
      gitlib.should_not_receive(:fetch)
      gitlib.should_not_receive(:push)

      sp.runner
    end

  end


  describe 'when default rebase flag is used' do

    def create_process(base = gitlib, opts = {})
      GitProc::Sync.new(base, opts.merge({:rebase => false, :force => false, :local => false}))
    end


    it 'should try to rebase by flag' do
      change_file_and_commit('a', '', gitlib)

      gitlib.branch('fb', :base_branch => 'master')

      sp = GitProc::Sync.new(gitlib, :rebase => true, :force => false, :local => true, :log_level => log_level)
      gitlib.should_receive(:rebase)
      gitlib.should_not_receive(:merge)

      sp.runner
    end


    it 'should try to rebase by config' do
      change_file_and_commit('a', '', gitlib)

      gitlib.branch('fb', :base_branch => 'master')
      gitlib.config.default_rebase_sync = true

      sp = GitProc::Sync.new(gitlib, :force => false, :local => true, :log_level => log_level)
      gitlib.should_receive(:rebase)
      gitlib.should_not_receive(:merge)

      sp.runner
    end


    it 'should not try to rebase by false config' do
      change_file_and_commit('a', '', gitlib)

      gitlib.branch('fb', :base_branch => 'master')
      gitlib.config.default_rebase_sync = false

      sp = GitProc::Sync.new(gitlib, :rebase => false, :force => false, :local => true, :log_level => log_level)
      gitlib.should_not_receive(:rebase)
      gitlib.should_receive(:merge)

      sp.runner
    end


    it 'should try to rebase by true flag config' do
      change_file_and_commit('a', '', gitlib)

      gitlib.branch('fb', :base_branch => 'master')
      gitlib.config.default_rebase_sync = false

      sp = GitProc::Sync.new(gitlib, :rebase => true, :force => false, :local => true, :log_level => log_level)
      gitlib.should_receive(:rebase)
      gitlib.should_not_receive(:merge)

      sp.runner
    end


    it 'should not try to rebase by false flag config' do
      change_file_and_commit('a', '', gitlib)

      gitlib.branch('fb', :base_branch => 'master')
      gitlib.config.default_rebase_sync = true

      sp = GitProc::Sync.new(gitlib, :rebase => false, :force => false, :local => true, :log_level => log_level)
      gitlib.should_not_receive(:rebase)
      gitlib.should_receive(:merge)

      sp.runner
    end

  end


  it "should work with a different remote server name than 'origin'" do
    change_file_and_commit('a', '')

    gitlib.branch('fb', :base_branch => 'master')

    clone_repo('fb', 'a_remote') do |gl|
      change_file_and_commit('a', 'hello', gl)
      gl.branches.include?('a_remote/fb').should be_true

      GitProc::Sync.new(gl, :rebase => false, :force => false, :log_level => log_level).runner

      gl.branches.include?('a_remote/fb').should be_true
      gitlib.branches.include?('fb').should be_true
    end
  end


  it 'should fail when removing current feature while on _parking_' do
    gitlib.checkout('_parking_', :new_branch => 'master')
    change_file_and_commit('a', '')

    expect { gitprocess.verify_preconditions }.to raise_error ParkedChangesError
  end


  ###########################################################################
  #
  # HELPER METHODS
  #
  ###########################################################################


  #noinspection RubyInstanceMethodNamingConvention
  def Given
    if block_given?
      yield
      verify_start_state
    else
      raise ArgumentError, 'No block given'
    end
  end


  def when_sync_is_run(do_checkout = true)
    @local.checkout('fb') if do_checkout
    create_process(@local).runner
  end


  #noinspection RubyInstanceMethodNamingConvention
  def Then
    if block_given?
      yield
    else
      raise ArgumentError, 'No block given'
    end
  end


  def origin(branchname = nil, opts={})
    unless @origin
      @origin = gitlib
      @origin.config['receive.denyCurrentBranch'] = 'ignore'
    end
    @current_lib = @origin
    @origin.checkout(branchname, opts) if branchname
    @origin
  end


  def local(branchname = nil, opts={})
    if @local.nil?
      remote_name = opts[:remote_name] || 'origin'
      @local ||= clone_repo('master', remote_name)
    end
    @current_lib = @local
    @local.fetch
    @local.checkout(branchname, opts) if branchname
    @local
  end


  def parent(sha, lib = @local)
    lib.fetch
    @local.sha("#{sha}~1")
  end


  def create_commit(commit_name, opts={})
    lib = opts[:lib] || @current_lib
    raise ArgumentError, 'missing lib' unless lib

    filename = opts[:file] || commit_name.to_s
    change_file_and_commit(filename, "#{commit_name} contents", lib)
    instance_variable_set("@#{commit_name}_sha", lib.sha('HEAD'))
  end


  def check_file_content(commit_name, opts={})
    lib = opts[:lib] || @local

    filename = opts[:file] || commit_name.to_s
    File.open(File.join(lib.workdir, filename)).read.should == "#{commit_name} contents\n"
  end


  #noinspection RubyInstanceMethodNamingConvention
  def create_feature_branch_on_origin
    @origin.checkout('fb', :new_branch => 'master')
  end


  def local_repo
    @local_repo ||= Rugged::Repository.new(@local.workdir)
  end


  def origin_repo
    @origin_repo ||= Rugged::Repository.new(@origin.workdir)
  end


  def l_sha
    branch_tip(local_repo, 'fb')
  end


  def i_sha
    branch_tip(origin_repo, 'master')
  end


  def r_sha
    branch_tip(origin_repo, 'fb')
  end


  def local_and_remote_are_same
    l_sha.should == r_sha
  end


  def branch_tip(repo, branch_name)
    Rugged::Branch.lookup(repo, branch_name).tip.oid
  end


  def rchange_file_and_commit(repo_name, branch, filename, contents, opts = {})
    repo = self.method("#{repo_name.to_s}_repo").call

    content_oid = repo.write(contents, :blob)
    logger.debug { "\nwrote content '#{contents}' to #{content_oid}" }

    if branch.nil?
      tree = Rugged::Tree::Builder.new
      tree.insert(:name => filename, :oid => content_oid, :filemode => 0100644)
      tree_oid = tree.write(repo)
      parents = opts[:parents] || []
      branch_name = 'HEAD'
    else
      tree = Rugged::Tree::Builder.new(branch.tip.tree)
      tree.insert(:name => filename, :oid => content_oid, :filemode => 0100644)
      tree_oid = tree.write(repo)
      parents = opts[:parents] || [branch.tip.oid]
      branch_name = branch.canonical_name
    end

    tree = repo.lookup(tree_oid)
    logger.debug "tree:"
    tree.each { |entry| logger.debug "  #{entry.inspect}" }

    person = {:name => 'test user', :email => 'test.user@test.com', :time => Time.now, :time_offset => 3600}
    oid = Rugged::Commit.create(repo,
                                :message => "#{filename} - #{contents}",
                                :committer => person,
                                :author => person,
                                :parents => parents,
                                :update_ref => branch_name,
                                :tree => tree_oid)

    new_branch = Rugged::Branch.lookup(repo, branch.nil? ? 'HEAD' : branch.name)
    new_tip = new_branch.nil? ? 'BUG' : new_branch.tip.oid
    logger.debug { "wrote commit #{oid} on #{repo_name} - #{branch_name} with #{parents} as the parent, making new branch tip #{new_tip}" }
    oid
  end


  def rcreate_commit(repo_name, branch_name, commit_name, opts={})
    repo = self.method("#{repo_name.to_s}_repo").call
    branch = Rugged::Branch.lookup(repo, branch_name)
    _create_commit(repo_name, branch, commit_name, opts)
  end


  def _create_commit(repo_name, branch, commit_name, opts)
    filename = opts[:file] || commit_name.to_s
    oid = rchange_file_and_commit(repo_name, branch, filename, "#{commit_name} contents\n", opts)
    instance_variable_set("@#{commit_name}_sha", oid)
    oid
  end


  def rcreate_commit_on_new_branch(repo_name, branch_name, base_branch_name, commit_name, opts={})
    repo = self.method("#{repo_name.to_s}_repo").call
    branch = repo.create_branch(branch_name, base_branch_name)
    _create_commit(repo_name, branch, commit_name, opts)
  end


  def rfetch(repo, remote_name)
    remote = Rugged::Remote.lookup(repo, remote_name)
    remote.connect(:fetch) do |r|
      r.download()
      r.update_tips!
    end
  end


  def treeish(repo, treeish)
    Rugged::Object.rev_parse(repo, treeish).oid
  end

end
