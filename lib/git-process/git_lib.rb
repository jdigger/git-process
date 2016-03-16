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

    # @param [Dir] dir the work dir
    # @param [Hash] logging_opts see {log_level}
    def initialize(dir, logging_opts)
      self.log_level = GitLib.log_level(logging_opts)
      self.workdir = dir
    end


    # @return [GitLogger] the logger to use
    def logger
      if @logger.nil?
        @logger = GitLogger.new(log_level)
      end
      return @logger
    end


    #
    # Decodes the [Hash] to determine what logging level to use
    #
    # @option opts [Fixnum] :log_level the log level from {Logger}
    # @option opts :quiet {Logger::ERROR}
    # @option opts :verbose {Logger::DEBUG}
    #
    # @return [Fixnum] the log level from Logger; defaults to {Logger::INFO}
    #
    def self.log_level(opts)
      if opts[:log_level]
        return opts[:log_level]
      elsif opts[:quiet]
        return Logger::ERROR
      elsif opts[:verbose]
        return Logger::DEBUG
      else
        return Logger::INFO
      end
    end


    # @return [Fixnum] the logging level to use; defaults to {Logger::WARN}
    def log_level
      @log_level || Logger::WARN
    end


    # @param [Fixnum] lvl the logging level to use. See {Logger}
    # @return [void]
    def log_level=(lvl)
      @log_level = lvl
    end


    # @return [Dir] the working directory
    def workdir
      @workdir
    end


    #
    # Sets the working directory to use for the (non-bare) repository.
    #
    # If the directory is *not* part of an existing repository, a new repository is created. (i.e., "git init")
    #
    # @param [Dir] dir the working directory
    # @return [void]
    def workdir=(dir)
      workdir = GitLib.find_workdir(dir)
      if workdir.nil?
        @workdir = dir
        logger.info { "Initializing new repository at #{dir}" }
        return command(:init)
      else
        @workdir = workdir
        logger.debug { "Opening existing repository at #{dir}" }
      end
    end


    def self.find_workdir(dir)
      if dir == File::SEPARATOR
        return nil
      elsif File.directory?(File.join(dir, '.git'))
        return dir
      else
        return find_workdir(File.expand_path("#{dir}#{File::SEPARATOR}.."))
      end
    end


    # @return [void]
    def fetch_remote_changes(remote_name = nil)
      if remote.exists?
        fetch(remote_name || remote.name)
      else
        logger.debug 'Can not fetch latest changes because there is no remote defined'
      end
    end


    #
    # Executes a rebase, but translates any {GitExecuteError} to a {RebaseError}
    #
    # @param (see #rebase)
    # @option (see #rebase)
    # @raise [RebaseError] if there is a problem executing the rebase
    def proc_rebase(base, opts = {})
      begin
        return rebase(base, opts)
      rescue GitExecuteError => rebase_error
        raise RebaseError.new(rebase_error.message, self)
      end
    end


    #
    # Executes a merge, but translates any {GitExecuteError} to a {MergeError}
    #
    # @param (see #merge)
    # @option (see #merge)
    # @raise [MergeError] if there is a problem executing the merge
    def proc_merge(base, opts = {})
      begin
        return merge(base, opts)
      rescue GitExecuteError => merge_error
        raise MergeError.new(merge_error.message, self)
      end
    end


    # @return [String, nil] the previous remote sha ONLY IF it is not the same as the new remote sha; otherwise nil
    def previous_remote_sha(current_branch, remote_branch)
      return nil unless has_a_remote?
      return nil unless remote_branches.include?(remote_branch)

      control_file_sha = read_sync_control_file(current_branch)
      old_sha = control_file_sha || remote_branch_sha(remote_branch)
      fetch_remote_changes
      new_sha = remote_branch_sha(remote_branch)

      if old_sha != new_sha
        logger.info('The remote branch has changed since the last time')
        return old_sha
      else
        logger.debug 'The remote branch has not changed since the last time'
        return nil
      end
    end


    def remote_branch_sha(remote_branch)
      logger.debug { "getting sha for remotes/#{remote_branch}" }
      return rev_parse("remotes/#{remote_branch}") rescue ''
    end


    # @return [Boolean] is the current branch the "_parked_" branch?
    def is_parked?
      mybranches = self.branches()
      return mybranches.parking == mybranches.current
    end

    # Push the repository to the server.
    #
    # @param local_branch [String] the name of the local branch to push from
    # @param remote_branch [String] the name of the remote branch to push to
    #
    # @option opts [Boolean] :local should this do nothing because it is in local-only mode?
    # @option opts [Boolean] :force should it force the push even if it can not fast-forward?
    # @option opts [Proc] :prepush a block to call before doing the push
    # @option opts [Proc] :postpush a block to call after doing the push
    #
    # @return [void]
    #
    def push_to_server(local_branch, remote_branch, opts = {})
      if opts[:local]
        logger.debug('Not pushing to the server because the user selected local-only.')
      elsif not has_a_remote?
        logger.debug('Not pushing to the server because there is no remote.')
      elsif local_branch == config.master_branch
        logger.warn('Not pushing to the server because the current branch is the mainline branch.')
      else
        opts[:prepush].call if opts[:prepush]

        push(remote.name, local_branch, remote_branch, :force => opts[:force])

        opts[:postpush].call if opts[:postpush]
      end
    end


    # @return [GitConfig] the git configuration
    def config
      if @config.nil?
        @config = GitConfig.new(self)
      end
      return @config
    end


    # @return [GitRemote] the git remote configuration
    def remote
      if @remote.nil?
        @remote = GitProc::GitRemote.new(config)
      end
      return @remote
    end


    # @return [Boolean] does this have a remote defined?
    def has_a_remote?
      remote.exists?
    end


    #
    # `git add`
    #
    # @param [String] file the name of the file to add to the index
    # @return [String] the output of 'git add'
    def add(file)
      logger.info { "Adding #{[*file].join(', ')}" }
      return command(:add, ['--', file])
    end


    #
    # `git commit`
    #
    # @param [String] msg the commit message
    # @return [String] the output of 'git commit'
    def commit(msg = nil)
      logger.info 'Committing changes'
      return command(:commit, msg.nil? ? nil : ['-m', msg])
    end


    #
    # `git rebase`
    #
    # @param [String] upstream the commit-ish to rebase against
    # @option opts :interactive do an interactive rebase
    # @option opts [String] :oldbase the old base to rebase from
    #
    # @return [String] the output of 'git rebase'
    def rebase(upstream, opts = {})
      args = []
      if opts[:interactive]
        logger.info { "Interactively rebasing #{branches.current.name} against #{upstream}" }
        args << '-i'
        args << upstream
      elsif opts[:oldbase]
        logger.info { "Doing rebase from #{opts[:oldbase]} against #{upstream} on #{branches.current.name}" }
        args << '--onto' << upstream << opts[:oldbase] << branches.current.name
      else
        logger.info { "Rebasing #{branches.current.name} against #{upstream}" }
        args << upstream
      end
      return command('rebase', args)
    end


    #
    # `git merge`
    #
    # @return [String] the output of 'git merge'
    def merge(base, opts= {})
      logger.info { "Merging #{branches.current.name} with #{base}" }
      args = []
      args << '-s' << opts[:merge_strategy] if opts[:merge_strategy]
      args << base
      return command(:merge, args)
    end


    #
    # `git fetch`
    #
    # @return [String] the output of 'git fetch'
    def fetch(name = remote.name)
      logger.info 'Fetching the latest changes from the server'
      output = self.command(:fetch, ['-p', name])

      log_fetch_changes(fetch_changes(output))

      return output
    end


    # @return [Hash] with lists for each of :new_branch, :new_tag, :force_updated, :deleted, :updated
    def fetch_changes(output)
      changed = output.split("\n")

      changes = {:new_branch => [], :new_tag => [], :force_updated => [], :deleted => [], :updated => []}

      line = changed.shift

      until line.nil? do
        case line
          when /^\s\s\s/
            m = /^\s\s\s(\S+)\s+(\S+)\s/.match(line)
            changes[:updated] << "#{m[2]} (#{m[1]})"
          when /^\s\*\s\[new branch\]/
            m = /^\s\*\s\[new branch\]\s+(\S+)\s/.match(line)
            changes[:new_branch] << m[1]
          when /^\s\*\s\[new tag\]/
            m = /^\s\*\s\[new tag\]\s+(\S+)\s/.match(line)
            changes[:new_tag] << m[1]
          when /^\sx\s/
            m = /^\sx\s\[deleted\]\s+\(none\)\s+->\s+[^\/]+\/(\S+)/.match(line)
            changes[:deleted] << m[1]
          when /^\s\+\s/
            m = /^\s\+\s(\S+)\s+(\S+)\s/.match(line)
            changes[:force_updated] << "#{m[2]} (#{m[1]})"
          else
            # ignore the line
        end
        line = changed.shift
      end

      changes
    end


    # @return [GitBranches]
    def branches
      GitProc::GitBranches.new(self)
    end


    # @return [GitBranches]
    def remote_branches
      GitProc::GitBranches.new(self, :remote => true)
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
    # @option opts [String]  :base_branch ('master') the branch to base the new branch off of
    #
    # @return [String] the output of running the git command
    def branch(branch_name, opts = {})
      if branch_name
        if opts[:delete]
          return delete_branch(branch_name, opts[:force])
        elsif opts[:rename]
          return rename_branch(branch_name, opts[:rename])
        elsif opts[:upstream]
          return set_upstream_branch(branch_name, opts[:upstream])
        else
          base_branch = opts[:base_branch] || 'master'
          if opts[:force]
            return change_branch(branch_name, base_branch)
          else
            return create_branch(branch_name, base_branch)
          end
        end
      else
        #list_branches(opts)
        return list_branches(opts[:all], opts[:remote], opts[:no_color])
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
    # @option opts [Boolean] :force force the update, even if not a fast-forward?
    #
    # @return [String] the output of the push command
    #
    # @raise [ArgumentError] if :delete is true, but no branch name is given
    #
    def push(remote_name, local_branch, remote_branch, opts = {})
      if opts[:delete]
        return push_delete(remote_branch || local_branch, remote_name, opts)
      else
        return push_to_remote(local_branch, remote_branch, remote_name, opts)
      end
    end


    #
    # Pushes the given branch to the server.
    #
    # @param [String] remote_name the repository name; nil -> 'origin'
    # @param [String] local_branch the local branch to push; nil -> the current branch
    # @param [String] remote_branch the name of the branch to push to; nil -> same as local_branch
    #
    # @option opts [Boolean] :force force the update, even if not a fast-forward?
    #
    # @return [String] the output of the push command
    #
    def push_to_remote(local_branch, remote_branch, remote_name, opts)
      remote_name ||= 'origin'

      args = [remote_name]

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
      return command(:push, args)
    end


    #
    # Pushes the given branch to the server.
    #
    # @param [String] remote_name the repository name; nil -> 'origin'
    # @param [String] branch_name the name of the branch to push to
    #
    # @option opts [Boolean, String] :delete if a String it is the branch name
    #
    # @return [String] the output of the push command
    #
    # @raise [ArgumentError] no branch name is given
    # @raise [raise GitProc::GitProcessError] trying to delete the integration branch
    #
    # @todo remove the opts param
    #
    def push_delete(branch_name, remote_name, opts)
      remote_name ||= 'origin'

      args = [remote_name]

      if branch_name
        rb = branch_name
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
      return command(:push, args)
    end


    # `git rebase --continue`
    #
    # @return [String] the output of the git command
    def rebase_continue
      command(:rebase, '--continue')
    end


    # `git stash --save`
    #
    # @return [String] the output of the git command
    def stash_save
      command(:stash, %w(save))
    end


    # `git stash --pop`
    #
    # @return [String] the output of the git command
    def stash_pop
      command(:stash, %w(pop))
    end


    # `git show`
    #
    # @return [String] the output of the git command
    def show(refspec)
      command(:show, refspec)
    end


    # @param [String] branch_name the name of the branch to checkout/create
    # @option opts [Boolean] :no_track do not track the base branch
    # @option opts [String] :new_branch the name of the base branch
    #
    # @return [void]
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


    # @return [int] the number of commits that exist in the current branch
    def log_count
      command(:log, '--oneline').split(/\n/).length
    end


    # Remove the files from the Index
    #
    # @param [Array<String>] files the file names to remove from the Index
    #
    # @option opts :force if exists and not false, will force the removal of the files
    #
    # @return [String] the output of the git command
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


    #
    # Resets the Index/Working Directory to the given revision
    #
    # @param [String] rev_name the revision name (commit-ish) to go back to
    #
    # @option opts :hard should the working directory be changed? If {false} or missing, will only update the Index
    #
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


    #
    # Translate the commit-ish name to the SHA-1 hash value
    #
    # @return [String, nil] the SHA-1 value, or nil if the revision name is unknown
    #
    def rev_parse(name)
      sha = command('rev-parse', ['--revs-only', name])
      return sha.empty? ? nil : sha
    end


    alias :sha :rev_parse


    #
    # Executes the given git command
    #
    # @param [Symbol, String] cmd the command to run (e.g., :commit)
    # @param [Array<String, Symbol>] opts the arguments to pass to the command
    # @param [Boolean] chdir should the shell change to the top of the working dir before executing the command?
    # @param [String] redirect ???????
    # @yield the block to run in the context of running the command
    #
    # @return [String] the output of the git command
    #
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


    #
    # Writes the current SHA-1 for the tip of the branch to the "sync control file"
    #
    # @return [void]
    # @see GitLib#read_sync_control_file
    def write_sync_control_file(branch_name)
      latest_sha = rev_parse(branch_name)
      filename = sync_control_filename(branch_name)
      logger.debug { "Writing sync control file, #{filename}, with #{latest_sha}" }
      File.open(filename, 'w') { |f| f.puts latest_sha }
    end


    # @return [String, nil] the SHA-1 of the latest sync performed for the branch, or nil if none is recorded
    # @see GitLib#write_sync_control_file
    def read_sync_control_file(branch_name)
      filename = sync_control_filename(branch_name)
      if File.exists?(filename)
        sha = File.open(filename) do |file|
          file.readline.chop
        end
        logger.debug "Read sync control file, #{filename}: #{sha}"
        sha
      else
        logger.debug "Sync control file, #{filename}, was not found"
        nil
      end
    end


    #
    # Delete the sync control file for the branch
    #
    # @return [void]
    # @see GitLib#write_sync_control_file
    def delete_sync_control_file!(branch_name)
      filename = sync_control_filename(branch_name)
      logger.debug { "Deleting sync control file, #{filename}" }

      # on some systems, especially Windows, the file may be locked. wait for it to unlock
      counter = 10
      while counter > 0
        begin
          File.delete(filename)
          counter = 0
        rescue
          counter = counter - 1
          sleep(0.25)
        end
      end
    end


    # @return [Boolean] does the sync control file exist?
    # @see GitLib#write_sync_control_file
    def sync_control_file_exists?(branch_name)
      filename = sync_control_filename(branch_name)
      File.exist?(filename)
    end


    def set_upstream_branch(branch_name, upstream)
      logger.info { "Setting upstream/tracking for branch '#{branch_name}' to '#{upstream}'." }

      if has_a_remote?
        parts = upstream.split(/\//)
        if parts.length() > 1
          potential_remote = parts.shift
          if remote.remote_names.include?(potential_remote)
            config["branch.#{branch_name}.remote"] = potential_remote
            config["branch.#{branch_name}.merge"] = "refs/heads/#{parts.join('/')}"
          end
        else
          config["branch.#{branch_name}.merge"] = "refs/heads/#{upstream}"
        end
      else
        config["branch.#{branch_name}.merge"] = "refs/heads/#{upstream}"
      end

      # The preferred way assuming using git 1.8 cli
      #command(:branch, ['--set-upstream-to', upstream, branch_name])
    end


    private


    #
    # Create the CLI for the git command
    #
    # @param [Symbol, String] cmd the command to run (e.g., :commit)
    # @param [Array<String, Symbol>] opts the arguments to pass to the command
    # @param [String] redirect ???????
    #
    # @return [String] the command line to run
    #
    def create_git_command(cmd, opts, redirect)
      opts = [opts].flatten.map { |s| escape(s) }.join(' ')
      return "git #{cmd} #{opts} #{redirect} 2>&1"
    end


    #
    # Executes the given git command
    #
    # @param [String] path the directory to run the command in
    # @param [String] git_cmd the CLI command to execute
    # @param [Boolean] chdir should the shell change to the top of the working dir before executing the command?
    # @param [Proc] block the block to run in the context of running the command
    #
    # @return [String] the output of the git command
    #
    def command_git_cmd(path, git_cmd, chdir, block)
      out = nil
      if chdir and (Dir.getwd != path)
        Dir.chdir(path) { out = run_command(git_cmd, &block) }
      else
        out = run_command(git_cmd, &block)
      end
      return out
    end


    # @return [String]
    def handle_exitstatus(proc_status, git_cmd, out)
      if proc_status.exitstatus > 0
        unless proc_status.exitstatus == 1 && out == ''
          raise GitProc::GitExecuteError.new(git_cmd + ':' + out.to_s)
        end
      end
      return out
    end


    #
    # Executes the given git command
    #
    # @param [String] git_cmd the CLI command to execute
    # @yield the block to run in the context of running the command. See {IO#popen}
    #
    # @return [String] the output of the git command
    #
    def run_command(git_cmd, &block)
      if block_given?
        return IO.popen(git_cmd, &block)
      else
        return `#{git_cmd}`.chomp
      end
    end


    # @return [String]
    def escape(s)
      escaped = s.to_s.gsub('\'', '\'\\\'\'')
      %Q{"#{escaped}"}
    end


    # @return [String]
    def change_branch(branch_name, base_branch)
      raise ArgumentError.new('Need :base_branch when using :force for a branch.') unless base_branch
      logger.info { "Changing branch '#{branch_name}' to point to '#{base_branch}'." }

      command(:branch, ['-f', branch_name, base_branch])
    end


    # @return [String]
    def create_branch(branch_name, base_branch)
      logger.info { "Creating new branch '#{branch_name}' based on '#{base_branch}'." }

      command(:branch, [branch_name, (base_branch || 'master')])
    end


    # @return [String]
    def list_branches(all_branches, remote_branches, no_color)
      args = []
      args << '-a' if all_branches
      args << '-r' if remote_branches
      args << '--no-color' if no_color
      command(:branch, args)
    end


    # @return [String]
    def delete_branch(branch_name, force)
      logger.info { "Deleting local branch '#{branch_name}'." } unless branch_name == '_parking_'

      command(:branch, [force ? '-D' : '-d', branch_name])
    end


    # @return [String]
    def rename_branch(branch_name, new_name)
      logger.info { "Renaming branch '#{branch_name}' to '#{new_name}'." }

      command(:branch, ['-m', branch_name, new_name])
    end


    # @return [String]
    def sync_control_filename(branch_name)
      normalized_branch_name = branch_name.to_s.gsub(/[\/]/, "-")

      return File.join(File.join(workdir, '.git'), "gitprocess-sync-#{remote.name}--#{normalized_branch_name}")
    end


    # @param [Hash] changes a hash of the changes that were made
    #
    # @return [void]
    def log_fetch_changes(changes)
      changes.each do |key, v|
        unless v.empty?
          logger.info { "  #{key.to_s.sub(/_/, ' ')}: #{v.join(', ')}" }
        end
      end
    end

  end

end
