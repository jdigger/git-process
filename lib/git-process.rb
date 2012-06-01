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
    end

    
    end

  end

end
