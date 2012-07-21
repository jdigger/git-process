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
# limitations under the License.require 'shellwords'

require 'git-process/git_process'

module GitProc

  class NewFeatureBranch < Process

    def initialize(dir, opts)
      @branch_name = opts[:branch_name]
      super
    end


    def runner
      mybranches = branches()
      on_parking = (mybranches.parking == mybranches.current)

      if on_parking
        new_branch = checkout(@branch_name, :new_branch => '_parking_')
        mybranches.parking.delete!
        new_branch
      else
        checkout(@branch_name, :new_branch => integration_branch)
      end
    end

  end

end
