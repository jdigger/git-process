require "rubygems"
require "bundler/setup"
require 'rugged'

module Git

  module Process

    def self.echo(msg)
      msg
    end
    
    def self.repo(dir)
      Rugged::Repository.new(dir)
    end

  end

end
