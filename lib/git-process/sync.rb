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
# limitations under the License.require 'shellwords'

require 'git-process/git_lib'
require 'git-process/git_process'
require 'git-process/parked_changes_error'
require 'git-process/uncommitted_changes_error'


module GitProc

  class Sync < Process

    def initialize(dir, opts)
      @do_rebase = opts[:rebase]
      @force = opts[:force]
      super
    end


    def runner
      raise UncommittedChangesError.new unless status.clean?
      raise ParkedChangesError.new(self) if is_parked?

      current_branch = branches.current
      remote_branch = "#{server_name}/#{current_branch}"

      fetch(server_name)

      if @do_rebase
        proc_rebase(remote_master_branch)
      else
        proc_merge(remote_master_branch)
      end

      old_sha = command('rev-parse', remote_branch) rescue ''

      unless current_branch == master_branch
        fetch(server_name)
        new_sha = command('rev-parse', remote_branch) rescue ''
        unless old_sha == new_sha
          logger.warn("'#{current_branch}' changed on '#{server_name}'"+
                      " [#{old_sha[0..5]}->#{new_sha[0..5]}]; trying sync again.")
          sync_with_server(@do_rebase, @force)
        end
        push(server_name, current_branch, current_branch, :force => @force)
      else
        logger.warn("Not pushing to the server because the current branch is the master branch.")
      end
    end

  end

end
