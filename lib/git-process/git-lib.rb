require "rubygems"
require "bundler/setup"

require 'logger'
require 'git-branch'
require 'git-branches'
require 'git-status'


class String

  def to_boolean
    return false if self == false || self.nil? || self =~ (/(false|f|no|n|0)$/i)
    return true if self == true || self =~ (/(true|t|yes|y|1)$/i)
    raise ArgumentError.new("invalid value for Boolean: \"#{self}\"")
  end

end


module Git

  class GitExecuteError < StandardError
  end


  # @!attribute [r] logger
  #   @return [Logger] a logger
  # @!attribute [r] git
  #   @return [Git] an instance of the Git library
  class GitLib
    attr_reader :logger

    def initialize(dir, options = {})
      initialize_logger(options[:logger], options[:log_level])
      initialize_git(dir)
    end


    def initialize_logger(logger, log_level)
      if logger
        @logger = logger
      else
        @logger = Logger.new(STDOUT)
        @logger.level = log_level || Logger::WARN
        @logger.datetime_format = "%Y-%m-%d %H:%M:%S"
        f = Logger::Formatter.new
        @logger.formatter = proc do |severity, datetime, progname, msg|
          "#{msg}\n"
          # "#{severity[0..0]}: #{datetime.strftime(@logger.datetime_format)}: #{msg}\n"
        end
      end
    end


    def initialize_git(dir, git = nil)
      if dir
        @workdir = File.expand_path(dir)
        unless File.directory?(File.join(workdir, '.git'))
          logger.info { "Initializing new repository at #{workdir}" }
          command(:init)
        else
          logger.info { "Opening existing repository at #{workdir}" }
        end
      end
    end


    private :initialize_logger, :initialize_git


    def workdir
      @workdir
    end


    def has_a_remote?
      if @remote == nil
        @remote = (command('remote') != '')
      end
      @remote
    end


    def add(file)
      command(:add, ['--', file])
    end


    def commit(msg)
      command(:commit, ['-m', msg])
    end


    def rebase(base)
      command('rebase', base)
    end


    def merge(base)
      command(:merge, [base])
    end


    def fetch
      command(:fetch, ['-p', Process.server_name])
    end


    def branches
      GitBranches.new(self)
    end


    #
    # Does branch manipulation.
    #
    # @param [String] branch_name the name of the branch
    #
    # @option opts [Boolean] :delete delete the remote branch
    # @option opts [Boolean] :force force the update, even if not a fast-forward
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
        logger.info { "Deleting local branch '#{branch_name}'."}

        args << (opts[:force] ? '-D' : '-d')
        args << branch_name
      elsif opts[:rename]
        logger.info { "Renaming branch '#{branch_name}' to '#{opts[:rename]}'."}

        args << '-m' << branch_name << opts[:rename]
      elsif branch_name
        logger.info { "Creating new branch '#{branch_name}' based on '#{opts[:base_branch]}'."}

        args << branch_name
        args << (opts[:base_branch] ? opts[:base_branch] : 'master')
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
          opts[:delete] = remote_branch
        elsif local_branch
          opts[:delete] = local_branch
        else
          raise ArgumentError.new("Need a branch name to delete.") if opts[:delete].is_a? TrueClass
        end
        logger.info { "Deleting remote branch '#{opts[:delete]}' on '#{remote_name}'."}
        args << '--delete' << opts[:delete]
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
      command('rm', args)
    end


    def config_hash
      @config_hash ||= {}
    end


    def config(key = nil, value = nil)
      if key and value
        command('config', [key, value])
        config_hash[key] = value
        value
      elsif key
        value = config_hash[key]
        unless value
          value = command('config', ['--get', key])
          config_hash[key] = value
        end
        value
      else
        if config_hash.empty?
          str = command('config', '--list')
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
        origin_url = config['remote.origin.url']
        raise Git::Process::GitProcessError.new("There is not origin url set up.") if origin_url.empty?
        @repo_name = origin_url.sub(/^.*:(.*?)(.git)?$/, '\1')
      end
      @repo_name
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
      re = command('config', ['--get', 'rerere.enabled'])
      re && re.to_boolean
    end


    def rerere_enabled(re, global = true)
      args = []
      args << '--global' if global
      args << 'rerere.enabled' << re
      command(:config, args)
    end


    def rerere_autoupdate?
      re = command('config', ['--get', 'rerere.autoupdate'])
      re && re.to_boolean
    end


    def rerere_autoupdate(re, global = true)
      args = []
      args << '--global' if global
      args << 'rerere.autoupdate' << re
      command(:config, args)
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
        logger.info(git_cmd)
        logger.debug(out)
      end
            
      if $?.exitstatus > 0
        if $?.exitstatus == 1 && out == ''
          return ''
        end
        raise Git::GitExecuteError.new(git_cmd + ':' + out.to_s) 
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
