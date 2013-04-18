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

require 'logger'
require 'git-process/git_branch'
require 'git-process/git_branches'
require 'git-process/git_remote'
require 'git-process/git_status'
require 'git-process/git_process_error'


module GitProc

  class GitExecuteError < GitProcessError
  end


  #
  # Provides Git commands
  #
  #noinspection RubyTooManyMethodsInspection
  class GitLib

    # @param [Dir] dir
    def initialize(dir, opts)
      self.log_level = GitLib.log_level(opts)
      self.workdir = dir
    end


    def logger
      if @logger.nil?
        @logger = GitLogger.new(log_level)
      end
      @logger
    end


    def self.log_level(opts)
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


    def log_level
      @log_level || Logger::WARN
    end


    def log_level=(lvl)
      @log_level = lvl
    end


    def workdir
      @workdir
    end


    def workdir=(dir)
      workdir = GitLib.find_workdir(dir)
      if workdir.nil?
        @workdir = dir
        logger.info { "Initializing new repository at #{dir}" }
        command(:init)
      else
        @workdir = workdir
        logger.debug { "Opening existing repository at #{dir}" }
      end
    end


    def self.find_workdir(dir)
      if dir == File::SEPARATOR
        nil
      elsif File.directory?(File.join(dir, '.git'))
        dir
      else
        find_workdir(File.expand_path("#{dir}#{File::SEPARATOR}.."))
      end
    end


    def config
      if @config.nil?
        @config = GitConfig.new(self)
      end
      @config
    end


    def remote
      if @remote.nil?
        @remote = GitProc::GitRemote.new(config)
      end
      @remote
    end


    # @return [Boolean] does this have a remote defined?
    def has_a_remote?
      remote.exists?
    end


    def add(file)
      logger.info { "Adding #{[*file].join(', ')}" }
      command(:add, ['--', file])
    end


    def commit(msg = nil)
      logger.info 'Committing changes'
      command(:commit, msg.nil? ? nil : ['-m', msg])
    end


    def rebase(base, opts = {})
      args = []
      if opts[:interactive]
        logger.info { "Interactively rebasing #{branches.current.name} against #{base}" }
        args << '-i'
      else
        logger.info { "Rebasing #{branches.current.name} against #{base}" }
      end
      args << base
      command('rebase', args)
    end


    def merge(base)
      logger.info { "Merging #{branches.current.name} with #{base}" }
      command(:merge, [base])
    end


    def fetch(name = remote.name)
      logger.info 'Fetching the latest changes from the server'
      command(:fetch, ['-p', name])
    end


    def branches
      GitProc::GitBranches.new(self)
    end


    #
    # Does branch manipulation.
    #
    # @param [String] branch_name the name of the branch
    #
    # @option opts [Boolean] :delete delete the remote branch
    # @option opts [Boolean] :force force the update
    # @option opts [Boolean] :all list all branches, local and remote
    # @option opts [Boolean] :no_color force not using any ANSI color codes
    # @option opts [String]  :rename the new name for the branch
    # @option opts [String]  :upstream the new branch to track
    # @option opts [String]  :base_branch the branch to base the new branch off of;
    #   defaults to 'master'
    #
    # @return [String] the output of running the git command
    def branch(branch_name, opts = {})
      if opts[:delete]
        delete_branch(branch_name, opts[:force])
      elsif opts[:rename]
        rename_branch(branch_name, opts[:rename])
      elsif opts[:upstream]
        set_upstream_branch(branch_name, opts[:upstream])
      elsif branch_name
        if opts[:force]
          change_branch(branch_name, opts[:base_branch])
        else
          create_branch(branch_name, opts[:base_branch])
        end
      else
        list_branches(opts[:all], opts[:no_color])
      end
    end


    #
    # Pushes the given branch to the server.
    #
    # @param [String] remote_name the repository name; nil -> 'origin'
    # @param [String] local_branch the local branch to push; nil -> the current branch
    # @param [String] remote_branch the name of the branch to push to; nil -> same as local_branch
    #
    # @option opts [Boolean, String] :delete delete the remote branch
    # @option opts [Boolean] :force force the update, even if not a fast-forward
    #
    # @return [void]
    #
    # @raise [ArgumentError] if :delete is true, but no branch name is given
    def push(remote_name, local_branch, remote_branch, opts = {})
      remote_name ||= 'origin'

      args = [remote_name]

      if opts[:delete]
        if remote_branch
          rb = remote_branch
        elsif local_branch
          rb = local_branch
        elsif !(opts[:delete].is_a? TrueClass)
          rb = opts[:delete]
        else
          raise ArgumentError.new('Need a branch name to delete.')
        end

        int_branch = config.master_branch
        if rb == int_branch
          raise GitProc::GitProcessError.new("Can not delete the integration branch '#{int_branch}'")
        end

        logger.info { "Deleting remote branch '#{rb}' on '#{remote_name}'." }
        args << '--delete' << rb
      else
        local_branch ||= branches.current
        remote_branch ||= local_branch
        args << '-f' if opts[:force]

        logger.info do
          if local_branch == remote_branch
            "Pushing to '#{remote_branch}' on '#{remote_name}'."
          else
            "Pushing #{local_branch} to '#{remote_branch}' on '#{remote_name}'."
          end
        end

        args << "#{local_branch}:#{remote_branch}"
      end
      command(:push, args)
    end


    def rebase_continue
      command(:rebase, '--continue')
    end


    def stash_save
      command(:stash, %w(save))
    end


    def stash_pop
      command(:stash, %w(pop))
    end


    def show(refspec)
      command(:show, refspec)
    end


    def checkout(branch_name, opts = {})
      args = []
      args << '--no-track' if opts[:no_track]
      args << '-b' if opts[:new_branch]
      args << branch_name
      args << opts[:new_branch] if opts[:new_branch]
      branches = branches()
      command(:checkout, args)

      branches << GitBranch.new(branch_name, opts[:new_branch] != nil, self)

      if block_given?
        yield
        command(:checkout, branches.current.name)
        branches.current
      else
        branches[branch_name]
      end
    end


    def log_count
      command(:log, '--oneline').split(/\n/).length
    end


    def remove(files, opts = {})
      args = []
      args << '-f' if opts[:force]
      args << [*files]
      command(:rm, args)
    end


    #
    # Returns the status of the git repository.
    #
    # @return [Status]
    def status
      GitStatus.new(self)
    end


    # @return [String] the raw porcelain status string
    def porcelain_status
      command(:status, '--porcelain')
    end


    def reset(rev_name, opts = {})
      args = []
      args << '--hard' if opts[:hard]
      args << rev_name

      logger.info { "Resetting #{opts[:hard] ? '(hard)' : ''} to #{rev_name}" }

      command(:reset, args)
    end


    def rev_list(start_revision, end_revision, opts ={})
      args = []
      args << "-#{opts[:num_revs]}" if opts[:num_revs]
      args << '--oneline' if opts[:oneline]
      args << "#{start_revision}..#{end_revision}"
      command('rev-list', args)
    end


    def rev_parse(name)
      command('rev-parse', name)
    end


    alias sha rev_parse


    def command(cmd, opts = [], chdir = true, redirect = '', &block)
      ENV['GIT_INDEX_FILE'] = File.join(workdir, '.git', 'index')
      ENV['GIT_DIR'] = File.join(workdir, '.git')
      ENV['GIT_WORK_TREE'] = workdir
      path = workdir

      git_cmd = create_git_command(cmd, opts, redirect)

      out = command_git_cmd(path, git_cmd, chdir, block)

      if logger
        logger.debug(git_cmd)
        logger.debug(out)
      end

      handle_exitstatus($?, git_cmd, out)
    end


    private


    def create_git_command(cmd, opts, redirect)
      opts = [opts].flatten.map { |s| escape(s) }.join(' ')
      "git #{cmd} #{opts} #{redirect} 2>&1"
    end


    def command_git_cmd(path, git_cmd, chdir, block)
      out = nil
      if chdir and (Dir.getwd != path)
        Dir.chdir(path) { out = run_command(git_cmd, &block) }
      else
        out = run_command(git_cmd, &block)
      end
      out
    end


    # @return [void]
    def handle_exitstatus(proc_status, git_cmd, out)
      if proc_status.exitstatus > 0
        unless proc_status.exitstatus == 1 && out == ''
          raise GitProc::GitExecuteError.new(git_cmd + ':' + out.to_s)
        end
      end
      out
    end


    def run_command(git_cmd, &block)
      if block_given?
        IO.popen(git_cmd, &block)
      else
        `#{git_cmd}`.chomp
      end
    end


    def escape(s)
      escaped = s.to_s.gsub('\'', '\'\\\'\'')
      %Q{"#{escaped}"}
    end


    def change_branch(branch_name, base_branch)
      raise ArgumentError.new('Need :base_branch when using :force for a branch.') unless base_branch
      logger.info { "Changing branch '#{branch_name}' to point to '#{base_branch}'." }

      command(:branch, ['-f', branch_name, base_branch])
    end


    def create_branch(branch_name, base_branch)
      logger.info { "Creating new branch '#{branch_name}' based on '#{base_branch}'." }

      command(:branch, [branch_name, (base_branch || 'master')])
    end


    def list_branches(all_branches, no_color)
      args = []
      args << '-a' if all_branches
      args << '--no-color' if no_color
      command(:branch, args)
    end


    def delete_branch(branch_name, force)
      logger.info { "Deleting local branch '#{branch_name}'." } unless branch_name == '_parking_'

      command(:branch, [force ? '-D' : '-d', branch_name])
    end


    def rename_branch(branch_name, new_name)
      logger.info { "Renaming branch '#{branch_name}' to '#{new_name}'." }

      command(:branch, ['-m', branch_name, new_name])
    end


    def set_upstream_branch(branch_name, upstream)
      logger.info { "Setting upstream/tracking for branch '#{branch_name}' to '#{upstream}'." }

      command(:branch, ['--set-upstream-to', upstream, branch_name])
    end

  end

end
