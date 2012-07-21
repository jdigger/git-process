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
require 'git-process/git_rebase_error'
require 'git-process/git_merge_error'
require 'highline/import'


module GitProc

  class Process
    include GitLib

    def initialize(dir, opts = {})
      @log_level = Process.log_level(opts)

      set_workdir(dir)
    end


    def run
      begin
        verify_state

        runner
      rescue GitProc::GitProcessError => exp
        puts exp.message
        exit(-1)
      end
    end


    def runner
      # extension point - does nothing by default
    end


    def set_workdir(dir)
      if !dir.nil?
        @workdir = find_workdir(dir)
        if @workdir.nil?
          @workdir = dir
          logger.info { "Initializing new repository at #{workdir}" }
          command(:init)
        else
          logger.debug { "Opening existing repository at #{workdir}" }
        end
      else
        logger.debug "Process dir is nil"
      end
    end


    def workdir
      @workdir
    end


    def log_level
      @log_level
    end


    def log_level=(ll)
      @log_level = ll
    end


    def remote_master_branch
      "#{server_name}/#{master_branch}"
    end


    def integration_branch
      has_a_remote? ? remote_master_branch : master_branch
    end


    def verify_state
      if should_remove_master
        if ask_about_removing_master
          branches[master_branch].delete!
        end
      end
    end


    def should_remove_master
      my_branches = branches()
      has_a_remote? and
      my_branches.include?(master_branch) and
      my_branches.current.name != master_branch and
      !keep_local_integration_branch? and
      my_branches[integration_branch].contains_all_of(master_branch)
    end


    def keep_local_integration_branch?
      keep_local_integration_branch_config_value.to_boolean
    end


    def Process.log_level(opts)
      if opts[:log_level]
        opts[:log_level]
      elsif opts[:quiet]
        Logger::ERROR
      elsif opts[:verbose]
        Logger::DEBUG
      else
        Logger::INFO
      end
    end


    def is_parked?
      mybranches = branches
      mybranches.parking == mybranches.current
    end


    private


    def keep_local_integration_branch_config_value
      config('gitProcess.keepLocalIntegrationBranch')
    end


    def ask_about_removing_master
      resp = ask("You should remove your obsolete <%= color('local', [:bold]) %> branch, '#{master_branch}'. Should I remove it for you? (Yn) ") do |q|
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


    def find_workdir(dir)
      if dir == File::SEPARATOR
        nil
      elsif File.directory?(File.join(dir, '.git'))
        dir
      else
        find_workdir(File.expand_path("#{dir}/.."))
      end
    end


    def proc_rebase(base)
      begin
        rebase(base)
      rescue GitExecuteError => rebase_error
        raise RebaseError.new(rebase_error.message, self)
      end
    end


    def proc_merge(base)
      begin
        merge(base)
      rescue GitExecuteError => merge_error
        raise MergeError.new(merge_error.message, self)
      end
    end

  end

end
