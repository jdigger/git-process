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
require 'git-process/pull_request'
require 'git-process/syncer'


module GitProc

  class RebaseToMaster < Process

    def initialize(dir, opts)
      @keep = opts[:keep]
      @pr_number = opts[:prNumber]
      @user = opts[:user]
      @password = opts[:password]
      super
    end


    def verify_preconditions
      super

      raise UncommittedChangesError.new unless gitlib.status.clean?
      raise ParkedChangesError.new(gitlib) if is_parked?
    end
	
	
    def should_squash_commits		
        if commits_since_master > 1
            if ask_about_squashing_commits
              gitlib.proc_rebase(gitlib.config.integration_branch, :interactive => 'origin/master')
            end
        end
    end

    def runner
      if remote.exists?
        gitlib.fetch(remote.name)

        unless @pr_number.nil? or @pr_number.empty?
          checkout_pull_request
        end
		
        should_squash_commits if squash_commits_config_value.to_boolean
		
        Syncer.rebase_sync(gitlib, true)
        current = gitlib.branches.current.name
        gitlib.push(remote.name, current, config.master_branch)

        unless @keep
          close_pull_request
          remove_feature_branch
          gitlib.delete_sync_control_file!(current) if gitlib.sync_control_file_exists?(current)
        end
      else
        Syncer.rebase_sync(gitlib, true)
      end
    end


    def checkout_pull_request
      PullRequest.checkout_pull_request(gitlib, @pr_number, remote.name, remote.repo_name, @user, @password, logger)
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
          if @pr_number
            pr.close(@pr_number)
          else
            mybranches = gitlib.branches()
            pull = pr.find_pull_request(config.master_branch, mybranches.current.name)
            if pull
              pr.close(pull[:number])
            else
              logger.debug { "There is no pull request for #{mybranches.current.name} against #{config.master_branch}" }
            end
          end
        rescue GitHubService::NoRemoteRepository => exp
          logger.debug exp.to_s
        end
      else
        logger.debug 'There is no GitHub auth token defined, so not trying to close a pull request.'
      end
    end

    #noinspection RubyInstanceMethodNamingConvention
    def squash_commits_config_value
      gitlib.config['gitProcess.squashCommits']
    end
	
    def ask_about_squashing_commits
      resp = ask("You should squash your commits before pushing to master.  Do you need to do this? (Yn) ") do |q|
        q.responses[:not_valid] = 'Please respond with either (y)es or (n)o. Defaults to (y)es.'
        q.case = :down
        q.default = 'Y'
        q.validate = /y|n/i
      end

      if resp == 'n'
        say("(You can turn off this message using \"git config gitProcess.squashCommits false\").")
        false
      else
        true
      end
    end

    private


    def bad_parking_branch_msg
      hl = HighLine.new
      hl.color(
          "\n***********************************************************************************************\n\n"+
              "There is an old '_parking_' branch with unacounted changes in it.\n"+
              "It has been renamed to '_parking_OLD_'.\n"+
              "Please rename the branch to what the changes are about (`git branch -m _parking_OLD_ my_fb_name`),\n"+
              " or remove it altogher (`git branch -D _parking_OLD_`).\n\n"+
              "***********************************************************************************************\n", :red, :bold)
    end

  end

end
