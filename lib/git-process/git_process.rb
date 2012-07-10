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


module GitProc

  class Process
    include GitLib

    def initialize(dir, opts = {})
      @log_level = Process.log_level(opts)

      if dir
        @workdir = find_workdir(dir)
        if @workdir.nil?
          @workdir = dir
          logger.info { "Initializing new repository at #{workdir}" }
          command(:init)
        else
          logger.debug { "Opening existing repository at #{workdir}" }
        end
      end
    end


    def run
      begin
        runner
      rescue GitProc::GitProcessError => exp
        puts exp.message
        exit(-1)
      end
    end


    def runner
      # extension point - does nothing by default
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


    def Process.log_level(opts)
      if opts[:quiet]
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
