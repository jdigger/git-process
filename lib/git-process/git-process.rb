require 'git-process/git-lib'
require 'git-process/git-rebase-error'
require 'git-process/git-merge-error'


module GitProc

  class Process
    include GitLib

    def initialize(dir, log_level)
      @log_level ||= log_level || Logger::WARN

      @workdir = dir
      if workdir
        unless File.directory?(File.join(workdir, '.git'))
          logger.info { "Initializing new repository at #{workdir}" }
          command(:init)
        else
          logger.debug { "Opening existing repository at #{workdir}" }
        end
      end
    end


    def workdir
      @workdir
    end


    def log_level
      @log_level
    end


    def remote_master_branch
      "#{server_name}/#{master_branch}"
    end


    def is_parked?
      mybranches = branches
      mybranches.parking == mybranches.current
    end


    private


    def proc_rebase(base)
      begin
        rebase(base)
      rescue GitExecuteError => rebase_error
        raise RebaseError.new(rebase_error.message, self)
      end
    end


    def proc_merge(base)
      begin
        merge(base)
      rescue GitExecuteError => merge_error
        raise MergeError.new(merge_error.message, self)
      end
    end

  end

end
