require "rubygems"
require "bundler/setup"

require 'git'
require 'logger'

module Git

  class Process
    attr_reader :logger, :git

    def initialize(dir, logger = nil)
      if logger == nil
        Logger.new(STDOUT)
        logger.level = Logger::INFO
      end
      @logger = logger
      workdir = File.expand_path(dir)
      if File.directory?(File.join(dir, '.git'))
        @git = Git.open(workdir, :log => logger)
      else
        @git = Git.init(workdir, :log => logger)
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


    def clone(source_repo, clone_dir)
      cr = Git.clone(source_repo, 'temprepo', :path => clone_dir, :log => logger)
      Git::Process.new(cr.dir.to_s, logger)
    end


    def rebase_to_master(remote = true)
      command('fetch', '-p') if remote
      rebase(if remote then "origin/master" else "master" end)
    end
    

    def rebase(base)
      command('rebase', base)
    end
    

    private
    
    def command(cmd, opts = [], chdir = true, redirect = '')
      git.lib.send(:command, cmd, opts, chdir, redirect)
    end

  end

end
