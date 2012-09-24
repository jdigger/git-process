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
    include ChangeFileHelper


    def initialize(dir, opts)
      opts[:force] = true if opts[:rebase]

      if !opts[:merge].nil? and opts[:merge] == opts[:rebase]
        raise ArgumentError.new(":merge = #{opts[:merge]} and :rebase = #{opts[:rebase]}")
      end

      raise ArgumentError.new(":rebase is not set") if opts[:rebase].nil?

      @do_rebase = opts[:rebase]
      @force = opts[:force]
      @local = opts[:local]
      super
    end


    #noinspection RubyControlFlowConversionInspection
    def verify_preconditions
      super

      if not status.clean?
        offer_to_help_uncommitted_changes
      end

      raise ParkedChangesError.new(self) if is_parked?
    end


    def cleanup
      stash_pop if @stash_pushed
    end


    def runner
      @current_branch ||= branches.current
      @remote_branch ||= "#{server_name}/#@current_branch"

      # if the remote branch has changed, merge those changes in before
      #   doing anything with the integration branch
      old_sha = rev_parse(@remote_branch) rescue ''
      fetch(server_name) if has_a_remote?
      new_sha = rev_parse(@remote_branch) rescue ''
      unless old_sha == new_sha
        logger.info('There have been changes on this remote branch, so will merge them in.')
        proc_merge(@remote_branch)
      end

      if @do_rebase
        proc_rebase(integration_branch)
      else
        proc_merge(integration_branch)
      end

      if @local
        logger.debug("Not pushing to the server because the user selected local-only.")
      elsif not has_a_remote?
        logger.debug("Not pushing to the server because there is no remote.")
      elsif @current_branch == master_branch
        logger.warn("Not pushing to the server because the current branch is the mainline branch.")
      else
        old_sha = rev_parse(@remote_branch) rescue ''

        handle_remote_changed(old_sha)

        push(server_name, @current_branch, @current_branch, :force => @force)
      end
    end


    private


    def handle_remote_changed(old_sha)
      fetch(server_name)
      new_sha = rev_parse(@remote_branch) rescue ''
      unless old_sha == new_sha
        logger.warn("'#@current_branch' changed on '#{server_name}'"+
                        " [#{old_sha[0..5]}->#{new_sha[0..5]}]; trying sync again.")
        runner # try again
      end
    end

  end

end
