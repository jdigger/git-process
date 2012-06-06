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


    def fetch
      command('fetch', '-p')
    end


    def push(remote_name, remote_branch)
      git.push(git.remote(remote_name), remote_branch)
    end


    def rebase_continue
      command('rebase', '--continue')
    end


    def clean_status?
      command('status', '-s') == ''
    end


    def log_count
      command('log', '--oneline').split(/\n/).length
    end


    private

    def command(cmd, opts = [], chdir = true, redirect = '')
      git.lib.send(:command, cmd, opts, chdir, redirect)
    end

  end

end
