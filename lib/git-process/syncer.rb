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

  class Syncer

    class << self

      def do_sync(gitlib, opts)
        if !opts[:merge].nil? and opts[:merge] == opts[:rebase]
          raise ArgumentError.new(":merge = #{opts[:merge]} and :rebase = #{opts[:rebase]}")
        end

        local = opts[:local]

        branch_name = opts[:branch_name]
        checkout_branch(gitlib, branch_name) unless branch_name.nil?

        if do_rebase?(gitlib, opts)
          rebase_sync(gitlib, local)
        else
          merge_sync(gitlib, opts[:force], local)
        end
      end


      def merge_sync(gitlib, force, local)
        gitlib.logger.info 'Doing merge-based sync'
        gitlib.proc_merge(gitlib.config.integration_branch)

        current_branch = gitlib.branches.current
        remote_branch = "#{gitlib.remote.name}/#{current_branch}"

        runner = lambda { merge_sync(gitlib, force, local) }
        push_to_server(gitlib, current_branch, remote_branch, force, local, runner)
      end


      def rebase_sync(gitlib, stay_local)
        gitlib.logger.info 'Doing rebase-based sync'

        current_branch = gitlib.branches.current
        remote_branch = "#{gitlib.remote.name}/#{current_branch}"

        runner = lambda { rebase_sync(gitlib, stay_local) }

        # if the remote branch has changed, bring in those changes in
        remote_sha = gitlib.previous_remote_sha(current_branch, remote_branch)
        if remote_sha.nil?
          gitlib.logger.debug 'There were no changes on the remote branch.'
        else
          handle_remote_rebase_changes(current_branch, gitlib, remote_branch, remote_sha, runner, stay_local)
        end

        gitlib.proc_rebase(gitlib.config.integration_branch)

        push_to_server(gitlib, current_branch, remote_branch, true, stay_local, runner)
      end


      private


      def checkout_branch(gitlib, branch_name)
        unless gitlib.remote.exists?
          raise GitProc::GitProcessError.new("Specifying '#{branch_name}' does not make sense without a remote")
        end

        gitlib.fetch_remote_changes

        remote_branch = "#{gitlib.remote.name}/#{branch_name}"

        unless gitlib.branches.include?(remote_branch)
          raise GitProc::GitProcessError.new("There is not a remote branch for '#{branch_name}'")
        end

        if gitlib.branches.include?(branch_name)
          handle_existing_branch(gitlib, branch_name, remote_branch)
        else
          gitlib.logger.debug { "There is not already a local branch named #{branch_name}" }
          gitlib.checkout(branch_name, :new_branch => remote_branch, :no_track => true)
        end

        gitlib.branches[branch_name].upstream(gitlib.config.integration_branch)
      end


      def handle_existing_branch(gitlib, branch_name, remote_branch)
        if gitlib.branches[remote_branch].contains_all_of(branch_name)
          gitlib.logger.info "There is already a local branch named #{branch_name} and it is fully subsumed by #{remote_branch}"
          gitlib.checkout(branch_name)
        else
          raise GitProc::GitProcessError.new("There is already a local branch named #{branch_name} that is not fully subsumed by #{remote_branch}")
        end
      end


      def handle_remote_rebase_changes(current_branch, gitlib, remote_branch, remote_sha, runner, stay_local)
        gitlib.logger.info 'There have been changes on the remote branch, so will bring them in.'
        gitlib.proc_rebase(remote_branch, :oldbase => remote_sha)

        push_to_server(gitlib, current_branch, remote_branch, true, stay_local, runner)
      end


      def do_rebase?(gitlib, opts)
        if opts[:rebase].nil?
          gitlib.config.default_rebase_sync?
        else
          opts[:rebase]
        end
      end


      def push_to_server(gitlib, current_branch, remote_branch, force, local, runner)
        gitlib.push_to_server(current_branch, current_branch,
                              :local => local,
                              :force => force,
                              :prepush => lambda { handle_remote_changed(gitlib, current_branch, remote_branch, runner) },
                              :postpush => lambda { gitlib.write_sync_control_file(current_branch) }
        )
      end


      def handle_remote_changed(gitlib, current_branch, remote_branch, runner)
        old_sha = gitlib.remote_branch_sha(remote_branch)
        gitlib.fetch_remote_changes
        new_sha = gitlib.remote_branch_sha(remote_branch)

        if old_sha != new_sha
          gitlib.logger.warn("'#{current_branch}' changed on '#{gitlib.remote.name}'; trying sync again.")
          runner.call # try again
        end
      end

    end

  end

end
