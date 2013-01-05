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

require 'git-process/git_process'
require 'git-process/git_rebase_error'
require 'git-process/git_process_error'
require 'git-process/parked_changes_error'
require 'git-process/uncommitted_changes_error'
require 'git-process/github_pull_request'


module GitProc

  class RebaseToMaster < Process

    def initialize(dir, opts)
      @keep = opts[:keep]
      @interactive = opts[:interactive]
      super
    end


    def verify_preconditions
      super

      raise UncommittedChangesError.new unless gitlib.status.clean?
      raise ParkedChangesError.new(gitlib) if is_parked?
    end


    def runner
      if remote.exists?
        gitlib.fetch(remote.name)
        proc_rebase(config.integration_branch)
        proc_rebase(config.integration_branch, :interactive => true) if @interactive
        gitlib.push(remote.name, gitlib.branches.current, config.master_branch)

        unless @keep
          close_pull_request
          remove_feature_branch
        end
      else
        proc_rebase(config.integration_branch)
      end
    end


    def remove_feature_branch
      mybranches = gitlib.branches

      remote_master = mybranches[remote.master_branch_name]
      current_branch = mybranches.current
      logger.debug { "Removing feature branch (#{current_branch})" }

      unless remote_master.contains_all_of(current_branch.name)
        raise GitProcessError.new("Branch '#{current_branch.name}' has not been merged into '#{remote.master_branch_name}'")
      end

      parking_branch = mybranches['_parking_']
      if parking_branch
        if parking_branch.is_ahead_of(remote_master.name) and
            !current_branch.contains_all_of(parking_branch.name)

          parking_branch.rename('_parking_OLD_')

          logger.warn { bad_parking_branch_msg }
        else
          parking_branch.delete!
        end
      end
      remote_master.checkout_to_new('_parking_', :no_track => true)

      current_branch.delete!(true)
      if mybranches["#{remote.name}/#{current_branch.name}"]
        gitlib.push(remote.name, nil, nil, :delete => current_branch.name)
      end
    end


    def close_pull_request
      pr = GitHub::PullRequest.new(gitlib, remote.name, remote.repo_name)

      # Assume that if we haven't done something that would create the
      # GitHub auth token, then this likely isn't a GitHub-based repo.
      # (Or at least the user isn't using pull requests)
      if pr.configuration.get_config_auth_token
        begin
          mybranches = gitlib.branches()
          pull = pr.find_pull_request(config.master_branch, mybranches.current.name)
          if pull
            pr.close(pull[:number])
          else
            logger.debug { "There is no pull request for #{mybranches.current.name} against #{config.master_branch}" }
          end
        rescue GitHubService::NoRemoteRepository => exp
          logger.debug exp.to_s
        end
      else
        logger.debug "There is no GitHub auth token defined, so not trying to close a pull request."
      end
    end


    private


    def bad_parking_branch_msg
      hl = HighLine.new
      hl.color("\n***********************************************************************************************\n\n"+
                   "There is an old '_parking_' branch with unacounted changes in it.\n"+
                   "It has been renamed to '_parking_OLD_'.\n"+
                   "Please rename the branch to what the changes are about (`git branch -m _parking_OLD_ my_fb_name`),\n"+
                   " or remove it altogher (`git branch -D _parking_OLD_`).\n\n"+
                   "***********************************************************************************************\n", :red, :bold)
    end

  end

end
