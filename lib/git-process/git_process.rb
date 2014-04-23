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
require 'git-process/git_rebase_error'
require 'git-process/git_merge_error'
require 'highline/import'


module GitProc

  class Process

    # @param [GitLib] gitlib
    def initialize(gitlib, opts = {})
      @gitlib = gitlib
    end


    def gitlib
      @gitlib
    end


    def run
      begin
        verify_preconditions

        runner
      rescue GitProc::GitProcessError => exp
        puts exp.message
        exit(-1)
      ensure
        cleanup
      end
    end


    def runner
      # extension point - does nothing by default
    end


    def workdir
      gitlib.workdir
    end


    def logger
      gitlib.logger
    end


    def config
      gitlib.config
    end


    def master_branch
      gitlib.config.master_branch
    end


    def remote
      gitlib.remote
    end


    def verify_preconditions
      if should_remove_master?
        if ask_about_removing_master
          delete_master_branch!
        end
      end
    end


    def cleanup
      # extension point
    end


    def fetch_remote_changes(remote_name = nil)
      gitlib.fetch_remote_changes(remote_name)
    end


    def is_parked?
      gitlib.is_parked?
    end
	
	
    def commits_since_master
	  Integer(gitlib.rev_list('origin/master','HEAD', :count => []))
    end


    private


    def delete_master_branch!
      gitlib.branches[config.master_branch].delete!
    end


    def should_remove_master?
      my_branches = gitlib.branches()
      gitlib.has_a_remote? and
          my_branches.include?(config.master_branch) and
          my_branches.current.name != config.master_branch and
          !keep_local_integration_branch? and
          my_branches[config.integration_branch].contains_all_of(config.master_branch)
    end


    def keep_local_integration_branch?
      keep_local_integration_branch_config_value.to_boolean
    end


    #noinspection RubyInstanceMethodNamingConvention
    def keep_local_integration_branch_config_value
      gitlib.config['gitProcess.keepLocalIntegrationBranch']
    end


    def ask_about_removing_master
      resp = ask("You should remove your obsolete <%= color('local', [:bold]) %> branch, '#{config.master_branch}'. Should I remove it for you? (Yn) ") do |q|
        q.responses[:not_valid] = 'Please respond with either (y)es or (n)o. Defaults to (y)es.'
        q.case = :down
        q.default = 'Y'
        q.validate = /y|n/i
      end

      if resp == 'n'
        say("(You can turn off this message using \"git config gitProcess.keepLocalIntegrationBranch true\").")
        false
      else
        true
      end
    end


    def proc_rebase(base, opts = {})
      gitlib.proc_rebase(base, opts)
    end


    def proc_merge(base, opts = {})
      gitlib.proc_merge(base, opts)
    end

  end

end
