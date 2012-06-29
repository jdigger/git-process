require "rubygems"
require "bundler/setup"

require 'git'
require 'logger'
require 'git-branch'
require 'git-branches'


class String

  def to_boolean
    return false if self == false || self.nil? || self =~ (/(false|f|no|n|0)$/i)
    return true if self == true || self =~ (/(true|t|yes|y|1)$/i)
    raise ArgumentError.new("invalid value for Boolean: \"#{self}\"")
  end

end


module Git

  # @!attribute [r] logger
  #   @return [Logger] a logger
  # @!attribute [r] git
  #   @return [Git] an instance of the Git library
  class GitLib
    attr_reader :logger, :git

    def initialize(dir, options = {})
      initialize_logger(options[:logger], options[:log_level])
      initialize_git(dir, options[:git])
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


    def initialize_git(dir, git)
      if git
        @git = git
      else
        workdir = File.expand_path(dir)
        @git = if File.directory?(File.join(workdir, '.git'))
          logger.info { "Opening existing repository at #{workdir}" }
          Git.open(workdir, :log => logger)
        else
          logger.info { "Initializing new repository at #{workdir}" }
          Git.init(workdir, :log => logger)
        end
      end
    end


    private :initialize_logger, :initialize_git


    def workdir
      git.dir.to_s
    end


    def has_a_remote?
      if @remote == nil
        @remote = (command('remote') != '')
      end
      @remote
    end


    def add(file)
      git.add(file)
    end


    def commit(msg)
      git.commit(msg)
    end


    def rebase(base)
      command('rebase', base)
    end


    def merge(base)
      git.merge(base, nil)
    end


    def fetch
      command('fetch', '-p')
    end


    def branch_sha(branch_name)
      command('rev-parse', branch_name)
    end


    def branches
      GitBranches.new(self)
    end


    def branch_names
      branches.map { |b| b.name }
    end


    #
    # Does branch manipulation.
    #
    # @param [String] branch_name the name of the branch
    #
    # @option opts [Boolean] :delete delete the remote branch
    # @option opts [Boolean] :force force the update, even if not a fast-forward
    # @option opts [String] :base_branch the branch to base the new branch off of;
    #   defaults to 'master'
    #
    # @return [void]
    def branch(branch_name, opts = {})
      args = []
      args << '-D' if opts[:delete] and opts[:force]
      args << '-d' if opts[:delete] and !opts[:force]
      args << branch_name
      args << (opts[:base_branch] ? opts[:base_branch] : 'master') unless opts[:delete]
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
        args << '--delete' << opts[:delete]
      else
        local_branch ||= branches.current
        remote_branch ||= local_branch
        args << '-f' if opts[:force]
        args << "#{local_branch}:#{remote_branch}"
      end
      command(:push, args)
    end


    def rebase_continue
      command(:rebase, '--continue')
    end


    def checkout(branch_name, opts = {}, &block)
      args = []
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
      command('log', '--oneline').split(/\n/).length
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


    class Status
      attr_reader :unmerged, :modified, :deleted, :added

      def initialize(lib)
        unmerged = []
        modified = []
        deleted = []
        added = []
        unknown = []

        stats = lib.command('status', '--porcelain').split("\n")

        stats.each do |s|
          stat = s[0..1]
          file = s[3..-1]
          #puts "stat #{stat} - #{file}"
          case stat
          when 'U ', ' U'
            unmerged << file
          when 'UU'
            unmerged << file
            modified << file
          when 'M ', ' M'
            modified << file
          when 'D ', ' D'
            deleted << file
          when 'DU', 'UD'
            deleted << file
            unmerged << file
          when 'A ', ' A'
            added << file
          when 'AA'
            added << file
            unmerged << file
          when '??'
            unknown << file
          else
            raise "Do not know what to do with status #{stat} - #{file}"
          end
        end

        @unmerged = unmerged.sort.uniq
        @modified = modified.sort.uniq
        @deleted = deleted.sort.uniq
        @added = added.sort.uniq
        @unknown = unknown.sort.uniq
      end

      def clean?
        @unmerged.empty? and @modified.empty? and @deleted.empty? and @added.empty? and @unknown.empty?
      end

    end


    def status
      Status.new(self)
    end


    def rerere_enabled?
      re = command('config', ['--get', 'rerere.enabled'])
      re && re.to_boolean
    end


    def rerere_enabled=(re, global = true)
      args = []
      args << '--global' if global
      args << 'rerere.enabled' << re
      command('config', args)
    end


    def rerere_autoupdate?
      re = command('config', ['--get', 'rerere.autoupdate'])
      re && re.to_boolean
    end


    def rerere_autoupdate=(re, global = true)
      args = []
      args << '--global' if global
      args << 'rerere.autoupdate' << re
      command('config', args)
    end


    def command(cmd, opts = [], chdir = true, redirect = '')
      git.lib.send(:command, cmd, opts, chdir, redirect)
    end

  end

end
