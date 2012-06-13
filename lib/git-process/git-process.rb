require 'backports'
require_relative 'git-lib'
require_relative 'uncommitted-changes-error'
require_relative 'git-rebase-error'
require_relative 'pull-request'
require 'shellwords'
require 'oauth2'
require 'launchy'
require 'webrick'
include WEBrick


module Git

  class Process
    attr_reader :lib

    @@server_name = 'origin'
    @@master_branch = 'master'

    def initialize(dir, options = {})
      @lib = Git::GitLib.new(dir, options)
    end


    def Process.remote_master_branch
      "#{@@server_name}/#{@@master_branch}"
    end


    def Process.server_name
      @@server_name
    end


    def Process.master_branch
      @@master_branch
    end


    def rebase_to_master
      unless lib.status.clean?
        raise UncommittedChangesError.new
      end

      if lib.has_a_remote?
        lib.fetch
        rebase(Process::remote_master_branch)
        lib.push(Process::server_name, lib.current_branch, Process::master_branch)
      else
        rebase("master")
      end
    end


    def sync_with_server(rebase)
      unless lib.status.clean?
        raise UncommittedChangesError.new
      end

      lib.fetch

      current_branch = lib.current_branch
      remote_branch = "origin/#{current_branch}"
      old_sha = lib.command('rev-parse', remote_branch)

      rebase(remote_branch)
      rebase(Process::remote_master_branch)

      unless current_branch == Process::master_branch
        lib.fetch
        new_sha = lib.command('rev-parse', remote_branch)
        unless old_sha == new_sha
          logger.warn("'#{current_branch}' changed on '#{Process::server_name}'"+
            " [#{old_sha[0..5]}->#{new_sha[0..5]}]; trying sync again.")
          sync_with_server
        end
        lib.push(Process::server_name, current_branch, current_branch, :force => true)
      else
        merge(remote_branch)
        merge(Process::remote_master_branch)
      end

      unless current_branch == Process::master_branch
        lib.fetch
        if rebase
          new_sha = lib.command('rev-parse', remote_branch)
          unless old_sha == new_sha
            logger.warn("'#{current_branch}' changed on '#{Process::server_name}'"+
                        " [#{old_sha[0..5]}->#{new_sha[0..5]}]; trying sync again.")
            sync_with_server
          end
        end
        lib.push(Process::server_name, current_branch, current_branch, :force => rebase)
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


    def merge(base)
      begin
        lib.merge(base)
      rescue Git::GitExecuteError => merge_error
        raise MergeError.new(merge_error.message, lib)
      end
    end


    def pull_request
      Git::PullRequest.new(lib).pull_request
    end


    def logger
      @lib.logger
    end

  end

end
