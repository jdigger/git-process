# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'git-process/git_lib'
require 'git-process/git_process'
require 'git-process/parked_changes_error'
require 'git-process/uncommitted_changes_error'
require 'git-process/changed_file_helper'


module GitProc

  class Sync < Process

    def initialize(base, opts)
      if !opts[:merge].nil? and opts[:merge] == opts[:rebase]
        raise ArgumentError.new(":merge = #{opts[:merge]} and :rebase = #{opts[:rebase]}")
      end

      @do_rebase = opts[:rebase]
      @force = opts[:force]
      @local = opts[:local]

      super

      @change_file_helper = ChangeFileHelper.new(gitlib)
      self
    end


    #noinspection RubyControlFlowConversionInspection
    def verify_preconditions
      super

      if not gitlib.status.clean?
        @change_file_helper.offer_to_help_uncommitted_changes
      end

      raise ParkedChangesError.new(self) if is_parked?
    end


    def cleanup
      gitlib.stash_pop if @stash_pushed
    end


    def remote_branch_sha
      gitlib.rev_parse(@remote_branch) rescue ''
    end


    def current_branch
      @current_branch ||= gitlib.branches.current
    end


    def runner
      @remote_branch ||= "#{remote.name}/#{current_branch}"

      if do_rebase?
        logger.info 'Doing rebase-based sync'
        @force = true

        # if the remote branch has changed, bring in those changes in
        if remote_has_changed?
          logger.info('There have been changes on the remote branch, so will bring them in.')
          proc_rebase(@remote_branch)
        end

        proc_rebase(config.integration_branch)
      else
        logger.info 'Doing merge-based sync'
        proc_merge(config.integration_branch)
      end

      push_to_server
    end


    private


    def remote_has_changed?
      return false unless (gitlib.has_a_remote? and gitlib.branches.include?(@remote_branch))

      old_sha = remote_branch_sha
      fetch_remote_changes
      new_sha = remote_branch_sha

      if old_sha != new_sha
        logger.info('The remote branch has changed since the last time')
        true
      elsif not current_branch.contains_all_of(@remote_branch)
        logger.info('There are new commits on the remote branch')
        true
      else
        false
      end
    end


    def do_rebase?
      if @do_rebase.nil?
        @do_rebase = config.default_rebase_sync?
      end
      @do_rebase
    end


    def push_to_server
      if @local
        logger.debug('Not pushing to the server because the user selected local-only.')
      elsif not gitlib.has_a_remote?
        logger.debug('Not pushing to the server because there is no remote.')
      elsif @current_branch == config.master_branch
        logger.warn('Not pushing to the server because the current branch is the mainline branch.')
      else
        handle_remote_changed

        gitlib.push(remote.name, @current_branch, @current_branch, :force => @force)
      end
    end


    def handle_remote_changed
      old_sha = remote_branch_sha
      fetch_remote_changes
      new_sha = remote_branch_sha

      if old_sha != new_sha
        logger.warn("'#{@current_branch}' changed on '#{remote.name}'; trying sync again.")
        runner # try again
      end
    end

  end

end
