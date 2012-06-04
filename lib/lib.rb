require "rubygems"
require "bundler/setup"

require 'git'
require 'logger'

module Git

  class PLib
    attr_reader :logger, :git

    def initialize(dir, logger = nil)
      if logger == nil
        logger = Logger.new(STDOUT)
        logger.level = Logger::INFO
      end
      @logger = logger
      workdir = File.expand_path(dir)
      @git = if File.directory?(File.join(workdir, '.git'))
        Git.open(workdir, :log => logger)
      else
        Git.init(workdir, :log => logger)
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
      git.status.all? {|status| !status.type }
    end


    private

    def command(cmd, opts = [], chdir = true, redirect = '')
      git.lib.send(:command, cmd, opts, chdir, redirect)
    end

  end

end
