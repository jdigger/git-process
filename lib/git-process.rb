require "rubygems"
require "bundler/setup"

require 'rugged'
require 'git'
require 'logger'

module Git

  class Process
    @@logger = Logger.new(STDOUT)
    @@logger.datetime_format = "%Y-%m-%d %H:%M:%S"
    f = Logger::Formatter.new
    @@logger.formatter = proc do |severity, datetime, progname, msg|
      "#{severity[0..0]}: Git::Process #{datetime.strftime(@@logger.datetime_format)}: #{msg}\n"
    end

    attr_reader :rugged, :logger, :git

    def initialize(rugged)
      @rugged = rugged
      @logger = @@logger
      logger.level = Logger::INFO
      @git = Git.open(rugged.workdir, :log => logger)
    end


    def self.create(dir)
      rugged = Rugged::Repository.init_at(File.expand_path(dir), false)
      Git::Process.new(rugged)
    end


    def self.use(dir)
      rugged = Rugged::Repository.new(File.expand_path(dir), false)
      Git::Process.new(rugged)
    end


    def workdir
      rugged.workdir
    end


    def add(file)
      git.add(file)
    end
    
    def commit(msg)
      git.commit(msg)
    end

  end

end
