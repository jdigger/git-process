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

require 'logger'
require 'git-process/git_branch'
require 'git-process/git_branches'
require 'git-process/git_status'
require 'git-process/git_process_error'


class String

  def to_boolean
    return false if self == false || self.nil? || self =~ (/(false|f|no|n|0)$/i)
    return true if self == true || self =~ (/(true|t|yes|y|1)$/i)
    raise ArgumentError.new("invalid value for Boolean: \"#{self}\"")
  end

end


class NilClass
  def to_boolean
    false
  end
end


module GitProc

  class GitExecuteError < GitProcessError
  end


  #
  # Provides Git commands
  #
  # = Assumes =
  # log_level
  # workdir
  #
  module GitLib

    def logger
      if @logger.nil?
        @logger = Logger.new(STDOUT)
        @logger.level = log_level || Logger::WARN
        @logger.datetime_format = "%Y-%m-%d %H:%M:%S"
        f = Logger::Formatter.new
        @logger.formatter = proc do |severity, datetime, progname, msg|
          "#{msg}\n"
        end
      end
      @logger
    end


    def server_name
      @server_name ||= remote_name
    end


    def master_branch
      @master_branch ||= config('gitProcess.integrationBranch') || 'master'
    end


    # @return [Boolean] does this have a remote defined?
    def has_a_remote?
      if @has_remote == nil
        @has_remote = (command(:remote) != '')
      end
      @has_remote
    end


    def add(file)
      logger.info { "Adding #{[*file].join(', ')}" }
      command(:add, ['--', file])
    end


    def commit(msg)
      logger.info "Committing changes"
      command(:commit, ['-m', msg])
    end


    def rebase(base)
      logger.info { "Rebasing #{branches.current.name} against #{base}" }
      command('rebase', base)
    end


    def merge(base)
      logger.info { "Merging #{branches.current.name} with #{base}" }
      command(:merge, [base])
    end


    def fetch(name = remote_name)
      logger.info "Fetching the latest changes from the server"
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
    # @option opts [String]  :base_branch the branch to base the new branch off of;
    #   defaults to 'master'
    #
    # @return [String] the output of running the git command
    def branch(branch_name, opts = {})
      args = []
      if opts[:delete]
        logger.info { "Deleting local branch '#{branch_name}'."} unless branch_name == '_parking_'

        args << (opts[:force] ? '-D' : '-d')
        args << branch_name
      elsif opts[:rename]
        logger.info { "Renaming branch '#{branch_name}' to '#{opts[:rename]}'."}

        args << '-m' << branch_name << opts[:rename]
      elsif branch_name
        if opts[:force]
          raise ArgumentError.new("Need :base_branch when using :force for a branch.") unless opts[:base_branch]
          logger.info { "Changing branch '#{branch_name}' to point to '#{opts[:base_branch]}'."}

          args << '-f' << branch_name << opts[:base_branch]
        else
          logger.info { "Creating new branch '#{branch_name}' based on '#{opts[:base_branch]}'."}

          args << branch_name
          args << (opts[:base_branch] ? opts[:base_branch] : 'master')
        end
      else
        args << '-a' if opts[:all]
        args << '--no-color' if opts[:no_color]
      end
      command(:branch, args)
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
          raise ArgumentError.new("Need a branch name to delete.")
        end

        int_branch = master_branch
        if rb == int_branch
          raise GitProc::GitProcessError.new("Can not delete the integration branch '#{int_branch}'")
        end

        logger.info { "Deleting remote branch '#{rb}' on '#{remote_name}'."}
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


    def checkout(branch_name, opts = {}, &block)
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


    def remove(file, opts = {})
      args = []
      args << '-f' if opts[:force]
      args << file
      command(:rm, args)
    end


    def config_hash
      @config_hash ||= {}
    end


    private :config_hash


    def config(key = nil, value = nil, global = false)
      if key and value
        args = global ? ['--global'] : []
        args << key << value
        command(:config, args)
        config_hash[key] = value unless config_hash.empty?
        value
      elsif key
        value = config_hash[key]
        unless value
          value = command(:config, ['--get', key])
          value = nil if value.empty?
          config_hash[key] = value unless config_hash.empty?
        end
        value
      else
        if config_hash.empty?
          str = command(:config, '--list')
          lines = str.split("\n")
          lines.each do |line|
            (key, *values) = line.split('=')
            config_hash[key] = values.join('=')
          end
        end
        config_hash
      end
    end


    def repo_name
      unless @repo_name
        origin_url = config("remote.#{remote_name}.url")
        raise GitProc::Process::GitProcessError.new("There is no #{remote_name} url set up.") if origin_url.empty?
        @repo_name = origin_url.sub(/^.*:(.*?)(.git)?$/, '\1')
      end
      @repo_name
    end


    def remote_name
      unless @remote_name
        remote_str = command(:remote)
        unless remote_str == nil or remote_str.empty?
          @remote_name = remote_str.split(/\n/)[0]
          raise "!@remote_name.is_a? String" unless @remote_name.is_a? String
        end
        logger.debug {"Using remote name of '#{@remote_name}'"}
      end
      @remote_name
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


    def rerere_enabled?
      re = config('rerere.enabled')
      re && re.to_boolean
    end


    def rerere_enabled(re, global = true)
      config('rerere.enabled', re, global)
    end


    def rerere_autoupdate?
      re = config('rerere.autoupdate')
      re && re.to_boolean
    end


    def rerere_autoupdate(re, global = true)
      config('rerere.autoupdate', re, global)
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


    def add_remote(remote_name, url)
      command(:remote, ['add', remote_name, url])
    end


    private


    def command(cmd, opts = [], chdir = true, redirect = '', &block)
      ENV['GIT_DIR'] = File.join(workdir, '.git')
      ENV['GIT_INDEX_FILE'] = File.join(workdir, '.git', 'index')
      ENV['GIT_WORK_TREE'] = workdir
      path = workdir

      opts = [opts].flatten.map {|s| escape(s) }.join(' ')
      git_cmd = "git #{cmd} #{opts} #{redirect} 2>&1"

      out = nil
      if chdir and (Dir.getwd != path)
        Dir.chdir(path) { out = run_command(git_cmd, &block) } 
      else
        out = run_command(git_cmd, &block)
      end
      
      if logger
        logger.debug(git_cmd)
        logger.debug(out)
      end
            
      if $?.exitstatus > 0
        if $?.exitstatus == 1 && out == ''
          return ''
        end
        raise GitProc::GitExecuteError.new(git_cmd + ':' + out.to_s) 
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

  end

end
