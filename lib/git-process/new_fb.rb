require 'git-process/git-process'

module GitProc

  class NewFeatureBranch < Process

    def new_feature_branch(branch_name)
      mybranches = branches
      on_parking = (mybranches.parking == mybranches.current)

      if on_parking
        new_branch = checkout(branch_name, :new_branch => '_parking_')
        mybranches.parking.delete
        new_branch
      else
        checkout(branch_name, :new_branch => remote_master_branch)
      end
    end

  end

end
