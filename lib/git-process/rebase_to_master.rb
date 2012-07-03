require 'git-process/git-lib'
require 'git-process/git-process'
require 'git-process/git-rebase-error'
require 'git-process/git-process-error'
require 'git-process/parked-changes-error'


module GitProc

  class RebaseToMaster < Process
    include GitLib

    def remote_master_branch
      "#{server_name}/#{master_branch}"
    end


    def rebase_to_master
      raise UncommittedChangesError.new unless status.clean?
      raise ParkedChangesError.new(self) if is_parked?

      if has_a_remote?
        fetch(server_name)
        proc_rebase(remote_master_branch)
        push(server_name, branches.current, master_branch)
        remove_feature_branch
      else
        proc_rebase(master_branch)
      end
    end


    def remove_feature_branch
      mybranches = branches

      remote_master = mybranches[remote_master_branch]
      current_branch = mybranches.current

      unless remote_master.contains_all_of(current_branch.name)
        raise GitProcessError.new("Branch '#{current_branch.name}' has not been merged into '#{remote_master_branch}'")
      end

      parking_branch = mybranches['_parking_']
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
      if mybranches["#{server_name}/#{current_branch.name}"]
        push(server_name, nil, nil, :delete => current_branch.name)
      end
    end


    private


    def bad_parking_branch_msg
      hl = HighLine.new
      hl.color("\n***********************************************************************************************\n\n"+
               "There is an old '_parking_' branch with unacounted changes in it.\n"+
               "It has been renamed to '_parking_OLD_'.\n"+
               "Please rename the branch to what the changes are about (`git branch -m _parking_OLD_ my_fb_name`),\n"+
               " or remove it altogher (`git branch -D _parking_OLD_`).\n\n"+
               "***********************************************************************************************\n", :red, :bold)
    end

  end

end
