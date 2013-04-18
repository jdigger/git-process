# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'git-process/git_process'

module GitProc

  class NewFeatureBranch < Process

    def initialize(dir, opts)
      @branch_name = opts[:branch_name]
      super
    end


    def runner
      mybranches = gitlib.branches()
      on_parking = (mybranches.parking == mybranches.current)

      if on_parking
        base_branch = if mybranches[config.integration_branch].contains_all_of(mybranches.parking.name)
          config.integration_branch
        else
          '_parking_'
        end

        logger.info { "Creating #{@branch_name} off of #{base_branch}" }
        new_branch = gitlib.checkout(@branch_name, :new_branch => base_branch)

        branches = gitlib.branches()
        branches[@branch_name].upstream(config.integration_branch)
        branches.parking.delete!
        new_branch
      else
        gitlib.checkout(@branch_name, :new_branch => config.integration_branch)
      end
    end

  end

end
