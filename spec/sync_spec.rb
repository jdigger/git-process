require 'git-process/sync'
require 'GitRepoHelper'

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


  describe 'when forcing the push' do

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

        expect {
          GitProc::Sync.new(gl, :rebase => false, :force => true, :log_level => log_level).runner
        }.to_not raise_error
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


    it 'should complain if remote feature branch conflicts' do
      change_file_and_commit('a', '')

      gitlib.checkout('fb', :new_branch => 'master')

      clone_repo do |gl|
        gl.checkout('fb', :new_branch => 'origin/master')

        change_file_and_commit('a', 'hello!', gitlib)
        change_file_and_commit('a', 'conflict!!', gl)
        gitlib.checkout('master')

        expect { create_process(gl).runner }.to raise_error RebaseError
      end
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

        change_file_and_commit('a', 'A')
        @a_sha = @origin.sha('HEAD')

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
          parent(@c_sha).should == @a_sha
          parent(@b_sha).should == @a_sha
        end


        #         i
        #        /
        # - A - C - B1
        #           /
        #         l,r
        it 'should work if no conflict' do
          Given do
            origin 'fb', :new_branch => 'master'
            create_commit :b

            origin 'master'
            create_commit :c

            local 'fb', :new_branch => 'origin/fb'
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
        it 'should do ???? if there is a conflict' do
          Given do
            origin 'fb', :new_branch => 'master'
            create_commit :b, :file => 'a'

            origin 'master'
            create_commit :c, :file => 'a'

            local 'fb', :new_branch => 'origin/fb'
          end

          pending 'undefined' do
            when_sync_is_run

            Then do
              local_and_remote_are_same
              parent(l_sha).should == @c_sha
              check_file_content :b
            end
          end
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
          parent(@c_sha).should == @a_sha
          parent(@b_sha).should == @a_sha
          parent(@d_sha).should == @b_sha
        end


        #         i
        #        /
        # - A - C - B1 - D1
        #                /
        #              l,r
        it 'should work if no conflict' do
          Given do
            origin 'fb', :new_branch => 'master'
            create_commit :b

            local 'fb', :new_branch => 'origin/fb'
            create_commit :d

            origin 'master'
            create_commit :c
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
        it 'should do ??? if there is a conflict' do
          Given do
            origin 'fb', :new_branch => 'master'
            create_commit :b, :file => 'a'

            local 'fb', :new_branch => 'origin/fb'
            create_commit :d

            origin 'master'
            create_commit :c, :file => 'a'
          end

          pending 'undefined' do
            when_sync_is_run

            Then do
              local_and_remote_are_same
              @local.sha("#{l_sha}~2").should == @c_sha
              check_file_content :b
              check_file_content :d
            end
          end
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
          parent(@c_sha).should == @a_sha
          parent(@b_sha).should == @a_sha
          parent(@b1_sha).should == @c_sha
          parent(@d_sha).should == @b1_sha
        end


        #     i
        #    /
        # - A - C - B2 - D1
        #               /
        #             l,r
        #
        # 'B2' would have the same content, but different SHA from 'B1' because it comes
        # from 'B' on the remote. When 'B1' is then applied it's a no-op, but 'D' becomes 'D1'
        # because it is based on 'B2' instead of 'B1'.
        it 'should work' do
          Given do
            origin 'fb', :new_branch => 'master'
            create_commit :b

            origin 'master'
            create_commit :c

            local 'fb', :new_branch => 'origin/fb'

            @local.rebase('origin/master', :oldbase => @a_sha)
            @b1_sha = @local.sha('HEAD')

            create_commit :d
          end

          when_sync_is_run

          Then do
            local_and_remote_are_same
            @local.sha("#{l_sha}~2").should == @c_sha
            check_file_content :b
            check_file_content :d
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
          parent(@c_sha).should == @a_sha
          parent(@b_sha).should == @a_sha
          parent(@b1_sha).should == @c_sha
          parent(@d_sha).should == @b_sha
        end


        #     i
        #    /
        # - A - C - B1 - D1
        #               /
        #             l,r
        it 'should work' do
          Given do
            origin 'fb', :new_branch => 'master'
            create_commit :b

            origin 'master'
            create_commit :c

            local 'fb', :new_branch => 'origin/fb'
            create_commit :d

            origin 'fb'
            @origin.rebase('master', :oldbase => @a_sha)
            @b1_sha = @origin.sha('HEAD')
          end

          when_sync_is_run

          Then do
            local_and_remote_are_same
            parent(l_sha).should == @b1_sha
            check_file_content :b
            check_file_content :d
          end
        end


        #         i   r
        #        /   /
        # - A - C - B1 - XX
        #   \            /
        #   B - D       l
        #       \
        #       ??
        it 'should do ?? if there is a conflict' do
          Given do
            origin 'fb', :new_branch => 'master'
            create_commit :b

            origin 'master'
            create_commit :c, :file => 'a'

            local 'fb', :new_branch => 'origin/fb'
            create_commit :d, :file => 'a'

            origin 'fb'
            @origin.rebase('master', :oldbase => @a_sha)
            @b1_sha = @origin.sha('HEAD')
          end

          pending 'unknown' do
            when_sync_is_run

            Then do
              local_and_remote_are_same
              parent(l_sha).should == @b1_sha
              check_file_content :b
              check_file_content :d
            end
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
          parent(@b_sha).should == @a_sha
          parent(@c_sha).should == @a_sha
          parent(@d_sha).should == @b_sha
          parent(@e_sha).should == @b_sha
        end


        #         i          l,r
        #        /            \
        # - A - C - B1 - E1 - D1
        it 'should work if no conflict' do
          Given do
            origin 'fb', :new_branch => 'master'
            create_commit :b

            origin 'master'
            create_commit :c

            local 'fb', :new_branch => 'origin/fb'

            origin 'fb'
            create_commit :e

            local 'fb'
            create_commit :d
          end

          when_sync_is_run

          Then do
            local_and_remote_are_same
            @local.sha("#{l_sha}~3").should == @c_sha
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
        it 'should do ??? if conflict applying B' do
          Given do
            origin 'fb', :new_branch => 'master'
            create_commit :b, :file => 'a'

            origin 'master'
            create_commit :c, :file => 'a'

            local 'fb', :new_branch => 'origin/fb'

            origin 'fb'
            create_commit :e

            local 'fb'
            create_commit :d
          end

          pending 'undefined' do
            when_sync_is_run

            Then do
              local_and_remote_are_same
              @local.sha("#{l_sha}~3").should == @c_sha
              check_file_content :b
              check_file_content :d
            end
          end
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
        it 'should do ??? if conflict applying remote' do
          Given do
            origin 'fb', :new_branch => 'master'
            create_commit :b

            origin 'master'
            create_commit :c, :file => 'a'

            local 'fb', :new_branch => 'origin/fb'

            origin 'fb'
            create_commit :e, :file => 'a'

            local 'fb'
            create_commit :d
          end

          pending 'undefined' do
            when_sync_is_run

            Then do
              local_and_remote_are_same
              @local.sha("#{l_sha}~3").should == @c_sha
              check_file_content :b
              check_file_content :d
            end
          end
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
        it 'should do ??? if conflict applying local' do
          Given do
            origin 'fb', :new_branch => 'master'
            create_commit :b

            origin 'master'
            create_commit :c, :file => 'a'

            local 'fb', :new_branch => 'origin/fb'

            origin 'fb'
            create_commit :e

            local 'fb'
            create_commit :d, :file => 'a'
          end

          pending 'undefined' do
            when_sync_is_run

            Then do
              local_and_remote_are_same
              @local.sha("#{l_sha}~3").should == @c_sha
              check_file_content :b
              check_file_content :d
            end
          end
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
      #   2. Work has happened locally on the feature branch, but it is no longer a "simple" addition to the remote
      #
      describe 'if local is based on integration but not a "simple" version of remote' do

        def verify_start_state
          l_sha.should == @d_sha
          r_sha.should == @b_sha
          i_sha.should == @c_sha
          parent(@b_sha).should == @a_sha
          parent(@c_sha).should == @a_sha
          parent(@d_sha).should == @c_sha
        end


        #         i
        #        /
        # - A - C - B1 - D1
        #               /
        #             l,r
        it 'should work if no conflict' do
          Given do
            origin 'fb', :new_branch => 'master'
            create_commit :b

            origin 'master'
            create_commit :c

            local 'fb', :new_branch => 'origin/fb'
            @local.reset('origin/master', :hard => true)
            create_commit :d
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
        # - A - C - D
        #   \   \   \
        #   B   XX  ??
        #   \    \
        #   r    l
        it 'should do ??? if there is a conflict' do
          Given do
            origin 'fb', :new_branch => 'master'
            create_commit :b, :file => 'a'

            origin 'master'
            create_commit :c, :file => 'a'

            local 'fb', :new_branch => 'origin/fb'
            @local.reset('origin/master', :hard => true)
            create_commit :d
          end

          pending 'undefined' do
            when_sync_is_run

            Then do
              local_and_remote_are_same
              @local.sha("#{l_sha}~2").should == @c_sha
              check_file_content :b
              check_file_content :d
            end
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
      #   2. Work has happened locally based on a newer version of integration, and it is no longer
      #      a "simple" addition to the remote
      #
      describe 'if local is not based on integration and not a "simple" version of remote' do

        def verify_start_state
          l_sha.should == @d_sha
          r_sha.should == @b_sha
          i_sha.should == @e_sha
          parent(@b_sha).should == @a_sha
          parent(@c_sha).should == @a_sha
          parent(@d_sha).should == @c_sha
          parent(@e_sha).should == @c_sha
        end


        # - A - C - E - B1 - D1
        #          /         /
        #         i        l,r
        it 'should work if no conflict' do
          Given do
            origin 'fb', :new_branch => 'master'
            create_commit :b

            origin 'master'
            create_commit :c

            local 'fb', :new_branch => 'origin/fb'
            @local.reset('origin/master', :hard => true)
            create_commit :d

            origin 'master'
            create_commit :e
          end

          when_sync_is_run

          Then do
            local_and_remote_are_same
            @local.sha("#{l_sha}~2").should == @e_sha
            check_file_content :b
            check_file_content :d
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
        it 'should do ??? with conflict on remote content' do
          Given do
            origin 'fb', :new_branch => 'master'
            create_commit :b, :file => 'a'

            origin 'master'
            create_commit :c

            local 'fb', :new_branch => 'origin/fb'
            @local.reset('origin/master', :hard => true)
            create_commit :d

            origin 'master'
            create_commit :e, :file => 'a'
          end

          pending 'undefined' do
            when_sync_is_run

            Then do
              local_and_remote_are_same
              @local.sha("#{l_sha}~2").should == @e_sha
              check_file_content :b
              check_file_content :d
            end
          end
        end


        #           ??
        #          /
        #         D
        #        /
        # - A - C - E - B1 - XX
        #   \      /         /
        #   B     i         l
        #   \
        #   r
        it 'should do ??? with conflict on local content' do
          Given do
            origin 'fb', :new_branch => 'master'
            create_commit :b

            origin 'master'
            create_commit :c

            local 'fb', :new_branch => 'origin/fb'
            @local.reset('origin/master', :hard => true)
            create_commit :d, :file => 'a'

            origin 'master'
            create_commit :e, :file => 'a'
          end

          pending 'undefined' do
            when_sync_is_run

            Then do
              local_and_remote_are_same
              @local.sha("#{l_sha}~2").should == @e_sha
              check_file_content :b
              check_file_content :d
            end
          end
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
          parent(@b_sha).should == @a_sha
          parent(@b1_sha).should == @c_sha
          parent(@c_sha).should == @a_sha
          parent(@d_sha).should == @b_sha
          parent(@e_sha).should == @b1_sha
        end


        # - A - C - B1 - E1 - D1
        #      /              /
        #     i             l,r
        it 'should work if no conflict' do
          Given do
            origin 'fb', :new_branch => 'master'
            create_commit :b

            origin 'master'
            create_commit :c

            local 'fb', :new_branch => 'origin/fb'

            origin 'fb'
            @origin.rebase('master', :oldbase => @a_sha)
            @b1_sha = @origin.sha('HEAD')
            create_commit :e

            local 'fb'
            create_commit :d
          end

          when_sync_is_run

          Then do
            local_and_remote_are_same
            @local.sha("#{l_sha}~2").should == @b1_sha
            @local.sha("#{l_sha}~3").should == @c_sha
            check_file_content :d
          end
        end


        #         i      r   l
        #        /       \   \
        # - A - C - B1 - E - XX
        #   \
        #   B - D
        #       \
        #       ??
        it 'should do ??? if there is a conflict' do
          Given do
            origin 'fb', :new_branch => 'master'
            create_commit :b

            origin 'master'
            create_commit :c

            local 'fb', :new_branch => 'origin/fb'

            origin 'fb'
            @origin.rebase('master', :oldbase => @a_sha)
            @b1_sha = @origin.sha('HEAD')
            create_commit :e, :file => 'a'

            local 'fb'
            create_commit :d, :file => 'a'
          end

          pending 'undefined' do
            when_sync_is_run

            Then do
              local_and_remote_are_same
              @local.sha("#{l_sha}~2").should == @b1_sha
              @local.sha("#{l_sha}~3").should == @c_sha
              check_file_content :d
            end
          end
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
          parent(@b_sha).should == @a_sha
          parent(@b1_sha).should == @c_sha
          parent(@c_sha).should == @a_sha
          parent(@d_sha).should == @b_sha
          parent(@e_sha).should == @b1_sha
          parent(@f_sha).should == @c_sha
        end


        # - A - C - F - B2 - E1 - D1
        #          /              /
        #         i             l,r
        it 'should work if no conflict' do
          Given do
            origin 'fb', :new_branch => 'master'
            create_commit :b

            origin 'master'
            create_commit :c

            local 'fb', :new_branch => 'origin/fb'
            create_commit :d

            origin 'fb'
            @origin.rebase('master', :oldbase => @a_sha)
            @b1_sha = @origin.sha('HEAD')
            create_commit :e

            origin 'master'
            create_commit :f
          end

          when_sync_is_run

          Then do
            local_and_remote_are_same
            @local.sha("#{l_sha}~3").should == @f_sha
            check_file_content :b
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
        it 'should do ?? if conflict applying remote' do
          Given do
            origin 'fb', :new_branch => 'master'
            create_commit :b, :file => 'a'

            origin 'master'
            create_commit :c

            local 'fb', :new_branch => 'origin/fb'
            create_commit :d

            origin 'fb'
            @origin.rebase('master', :oldbase => @a_sha)
            @b1_sha = @origin.sha('HEAD')
            create_commit :e

            origin 'master'
            create_commit :f, :file => 'a'
          end

          pending 'undefined' do
            when_sync_is_run

            Then do
              local_and_remote_are_same
              @local.sha("#{l_sha}~3").should == @f_sha
              check_file_content :b
            end
          end
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
        it 'should do ?? if conflict applying local' do
          Given do
            origin 'fb', :new_branch => 'master'
            create_commit :b

            origin 'master'
            create_commit :c

            local 'fb', :new_branch => 'origin/fb'
            create_commit :d, :file => 'a'

            origin 'fb'
            @origin.rebase('master', :oldbase => @a_sha)
            @b1_sha = @origin.sha('HEAD')
            create_commit :e, :file => 'a'

            origin 'master'
            create_commit :f
          end

          pending 'undefined' do
            when_sync_is_run

            Then do
              local_and_remote_are_same
              @local.sha("#{l_sha}~3").should == @f_sha
              check_file_content :b
            end
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
          gl.should_receive(:fetch) # want to get remote changes
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


  def when_sync_is_run
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


  def l_sha
    @local.sha('fb')
  end


  def i_sha
    @origin.sha('master')
  end


  def r_sha
    @origin.sha('fb')
  end


  def local_and_remote_are_same
    l_sha.should == r_sha
  end

end
