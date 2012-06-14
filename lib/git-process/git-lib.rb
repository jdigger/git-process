require "rubygems"
require "bundler/setup"

require 'git'
require 'logger'

module Git

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
          "#{severity[0..0]}: #{datetime.strftime(@logger.datetime_format)}: #{msg}\n"
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


    def current_branch
      git.current_branch
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


    def push(remote_name, local_branch, remote_branch, opts = {})
      branch = "#{opts[:force] ? '+' : ''}#{local_branch}:#{remote_branch}"
      command('push', [remote_name, branch])
    end


    def rebase_continue
      command('rebase', '--continue')
    end


    def checkout(branch, opts = {})
      git.checkout(branch, opts)
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
          end
        end

        @unmerged = unmerged.sort.uniq
        @modified = modified.sort.uniq
        @deleted = deleted.sort.uniq
        @added = added.sort.uniq
      end

      def clean?
        @unmerged.empty? and @modified.empty? and @deleted.empty? and @added.empty?
      end

    end


    def status
      Status.new(self)
    end


    def rerere_enabled?
      re = command('config', ['--get', 'rerere.enabled'])
      re && re != ''
    end


    def rerere_enabled=(re, global = true)
      args = []
      args << '--global' if global
      args << 'rerere.enabled' << re
      command('config', args)
    end


    def rerere_autoupdate?
      re = command('config', ['--get', 'rerere.autoupdate'])
      re && re != ''
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
