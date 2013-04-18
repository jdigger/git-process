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

require 'git-process/git_process_error'

module GitProc

  class ParkedChangesError < GitProcessError
    include GitProc::AbstractErrorBuilder

    attr_reader :error_message, :lib


    def initialize(lib)
      @lib = lib
      msg = build_message
      super(msg)
    end


    def human_message
      "You made your changes on the the '_parking_' branch instead of a feature branch.\n"+'Please rename the branch to be a feature branch.'
    end


    def build_commands
      ['git branch -m _parking_ my_feature_branch']
    end

  end

end
