require "rubygems"
require "bundler/setup"

require 'rugged'
require 'logger'

module Git

  class Process
    attr_reader :repo, :logger

    def initialize(repo)
      @repo = repo

      @logger = Logger.new(STDOUT)
      @logger.datetime_format = "%Y-%m-%d %H:%M:%S"
      f = Logger::Formatter.new
      @logger.formatter = proc do |severity, datetime, progname, msg|
        "#{severity[0..0]}: Git::Process #{datetime.strftime(@logger.datetime_format)}: #{msg}\n"
      end
    end
        

    def self.create(dir)
      repo = Rugged::Repository.init_at(dir, false)
      gp = Git::Process.new(repo)
      gp.logger.debug {"git init #{dir}"}
      gp
    end


    def self.use(dir)
      repo = Rugged::Repository.new(dir, false)
      Git::Process.new(repo)
    end

  end

end
