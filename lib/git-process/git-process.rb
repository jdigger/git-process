require 'git-lib'
require 'uncommitted-changes-error'
require 'git-rebase-error'
require 'git-merge-error'
require 'parked-changes-error'
require 'pull-request'
require 'shellwords'
require 'highline/import'


module Git

  class Process
    attr_reader :lib

    @@server_name = 'origin'
    @@master_branch = 'master'

    def initialize(dir = nil, gitlib = nil, options = {})
      @lib = gitlib || Git::GitLib.new(dir, options)
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
      raise UncommittedChangesError.new unless lib.status.clean?
      raise ParkedChangesError.new(lib) if is_parked?

      if lib.has_a_remote?
        lib.fetch
        rebase(Process::remote_master_branch)
        lib.push(Process::server_name, lib.branches.current, Process::master_branch)
        remove_feature_branch
      else
        rebase("master")
      end
    end


    def sync_with_server(rebase, force)
      raise UncommittedChangesError.new unless lib.status.clean?
      raise ParkedChangesError.new(lib) if is_parked?

      current_branch = lib.branches.current
      remote_branch = "#{Process::server_name}/#{current_branch}"

      lib.fetch

      if rebase
        rebase(Process::remote_master_branch)
      else
        merge(Process::remote_master_branch)
      end

      old_sha = lib.command('rev-parse', remote_branch) rescue ''

      unless current_branch == Process::master_branch
        lib.fetch
        new_sha = lib.command('rev-parse', remote_branch) rescue ''
        unless old_sha == new_sha
          logger.warn("'#{current_branch}' changed on '#{Process::server_name}'"+
                      " [#{old_sha[0..5]}->#{new_sha[0..5]}]; trying sync again.")
          sync_with_server(rebase, force)
        end
        lib.push(Process::server_name, current_branch, current_branch, :force => rebase || force)
      else
        logger.warn("Not pushing to the server because the current branch is the master branch.")
      end
    end


    def new_feature_branch(branch_name)
      branches = lib.branches
      on_parking = (branches.parking == branches.current)

      if on_parking
        lib.checkout(branch_name, :new_branch => '_parking_')
        lib.checkout('_parking_')
        lib.command(:reset, ['--hard', 'origin/master'])
        lib.checkout(branch_name)
      else
        lib.checkout(branch_name, :new_branch => 'origin/master')
      end
    end


    def bad_parking_branch_msg
      hl = HighLine.new
      hl.color("\n***********************************************************************************************\n\n"+
               "There is an old '_parking_' branch with unacounted changes in it.\n"+
               "It has been renamed to '_parking_OLD_'.\n"+
               "Please rename the branch to what the changes are about (`git branch -m _parking_OLD_ my_fb_name`),\n"+
               " or remove it altogher (`git branch -D _parking_OLD_`).\n\n"+
               "***********************************************************************************************\n", :red, :bold)
    end


    def remove_feature_branch
      branches = lib.branches

      remote_master = branches[Process::remote_master_branch]
      current_branch = branches.current

      unless remote_master.contains_all_of(current_branch.name)
        raise GitProcessError.new("Branch '#{current_branch.name}' has not been merged into '#{Process::remote_master_branch}'")
      end

      parking_branch = branches['_parking_']
      if parking_branch
        if (parking_branch.is_ahead_of(remote_master.name) and
            !current_branch.contains_all_of(parking_branch.name))

          parking_branch.rename('_parking_OLD_')

          logger.warn {bad_parking_branch_msg}
        else
          parking_branch.delete
        end
      end
      remote_master.checkout_to_new('_parking_', :no_track => true)

      current_branch.delete(true)
      lib.command(:push, [Process.server_name, ":#{current_branch.name}"]) if lib.has_a_remote?
    end


    def is_parked?
      branches = lib.branches
      branches.parking == branches.current
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


    def pull_request(repo_name, base, head, title, body, opts = {})
      repo_name ||= lib.repo_name
      base ||= @@master_branch
      head ||= lib.branches.current
      title ||= ask_for_pull_title
      body ||= ask_for_pull_body
      GitHub::PullRequest.new(lib, repo_name, opts).pull_request(base, head, title, body)
    end


    def ask_for_pull_title
      ask("What <%= color('title', [:bold]) %> do you want to give the pull request? ") do |q|
        q.validate = /^\w+.*/
      end
    end


    def ask_for_pull_body
      ask("What <%= color('description', [:bold]) %> do you want to give the pull request? ")
    end


    def logger
      @lib.logger
    end

  end

end
