require File.expand_path('../git-lib', __FILE__)
require File.expand_path('../uncommitted-changes-error', __FILE__)
require File.expand_path('../git-rebase-error', __FILE__)
require 'shellwords'

module Git

  class Process
    attr_reader :lib

    def initialize(dir, options = {})
      @lib = Git::GitLib.new(dir, options)
    end


    def rebase_to_master
      unless lib.status.clean?
        raise UncommittedChangesError.new
      end

      lib.fetch if lib.has_a_remote?

      rebase(lib.has_a_remote? ? "origin/master" : "master")

      lib.push("origin", "master") if lib.has_a_remote?
    end


    def sync_with_server
      if !lib.status.clean?
        raise UncommittedChangesError.new
      end

      lib.fetch
      rebase("origin/master")
      if lib.current_branch != 'master'
        lib.push("origin", lib.current_branch)
      else
        logger.warn("Not pushing to the server because the current branch is the master branch.")
      end
    end


    def rebase(base)
      begin
        lib.rebase(base)
      rescue Git::GitExecuteError => rebase_error
        raise RebaseError.new(rebase_error.message, lib)
      end
    end


    def git
      lib.git
    end


    def logger
      @lib.logger
    end

  end

end
