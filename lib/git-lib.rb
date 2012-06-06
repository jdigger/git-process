require "rubygems"
require "bundler/setup"

require 'git'
require 'logger'

module Git

  class GitLib
    attr_reader :logger, :git

    def initialize(dir, options = {})
      if options[:logger]
        @logger = options[:logger]
      else
        @logger = Logger.new(STDOUT)
        @logger.level = options[:log_level] || Logger::WARN
        @logger.datetime_format = "%Y-%m-%d %H:%M:%S"
        f = Logger::Formatter.new
        @logger.formatter = proc do |severity, datetime, progname, msg|
          "#{severity[0..0]}: #{datetime.strftime(@logger.datetime_format)}: #{msg}\n"
        end
      end

      if options[:git]
        @git = options[:git]
      else
        workdir = File.expand_path(dir)
        logger.info { "Using '#{workdir}' as the working directory" }
        @git = if File.directory?(File.join(workdir, '.git'))
          Git.open(workdir, :log => logger)
        else
          Git.init(workdir, :log => logger)
        end
      end
    end


    def workdir
      git.dir.to_s
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


    def push(remote_name, remote_branch)
      git.push(git.remote(remote_name), remote_branch)
    end


    def rebase_continue
      command('rebase', '--continue')
    end


    def checkout(branch, opts = {})
      git.checkout(branch, opts)
    end


    def clean_status?
      command('status', '-s') == ''
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
          when 'U '
            unmerged << file
          when 'UU'
            unmerged << file
            modified << file
          when 'M '
            modified << file
          when 'D '
            deleted << file
          when 'DU', 'UD'
            deleted << file
            unmerged << file
          when 'A '
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
    end


    def status
      Status.new(self)
    end


    def command(cmd, opts = [], chdir = true, redirect = '')
      git.lib.send(:command, cmd, opts, chdir, redirect)
    end

  end

end
