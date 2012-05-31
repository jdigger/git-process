require "rubygems"
require "bundler/setup"

require 'rugged'
require 'logger'

module Git

  class Process
    @@logger = Logger.new(STDOUT)
    @@logger.datetime_format = "%Y-%m-%d %H:%M:%S"
    f = Logger::Formatter.new
    @@logger.formatter = proc do |severity, datetime, progname, msg|
      "#{severity[0..0]}: Git::Process #{datetime.strftime(@@logger.datetime_format)}: #{msg}\n"
    end

    attr_reader :repo, :logger

    def initialize(repo)
      @repo = repo
      @logger = @@logger
      @logger.debug {"working dir: #{repo.workdir}"}
    end
        

    def self.create(dir)
      @@logger.debug "git init"
      repo = Rugged::Repository.init_at(dir, false)
      Git::Process.new(repo)
    end


    def self.use(dir)
      repo = Rugged::Repository.new(dir, false)
      Git::Process.new(repo)
    end

  end

end
