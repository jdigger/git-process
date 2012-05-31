require "rubygems"
require "bundler/setup"
require 'rugged'

module Git

  class Process
    attr_reader :repo

    def initialize(repo)
      @repo = repo
    end
        

    def self.create(dir)
      repo = Rugged::Repository.init_at(dir, false)
      Git::Process.new(repo)
    end


    def self.use(dir)
      repo = Rugged::Repository.new(dir, false)
      Git::Process.new(repo)
    end

  end

end
