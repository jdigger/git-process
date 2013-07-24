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

      raise ArgumentError.new(':rebase is not set') if opts[:rebase].nil?

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

      # if the remote branch has changed, merge those changes in before
      #   doing anything with the integration branch
      if remote_has_changed?
        logger.info('There have been changes on this remote branch, so will merge them in.')
        proc_merge(@remote_branch, :merge_strategy => 'recursive')
      end

      if do_rebase?
        @force = true
        proc_rebase(config.integration_branch)
      else
        proc_merge(config.integration_branch)
      end

      push_to_server
    end


    private


    def remote_has_changed?
      old_sha = remote_branch_sha
      fetch_remote_changes
      new_sha = remote_branch_sha

      old_sha != new_sha
    end


    def do_rebase?
      @do_rebase ||= config['gitProcess.defaultRebaseSync'].to_boolean
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

      unless old_sha == new_sha
        logger.warn("'#{@current_branch}' changed on '#{config.server_name}'"+
                        " [#{old_sha[0..5]}->#{new_sha[0..5]}]; trying sync again.")
        runner # try again
      end
    end

  end

end
