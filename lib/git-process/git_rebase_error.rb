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

require 'git-process/git_abstract_merge_error_builder'

module GitProc

  class RebaseError < GitProcessError
    include GitProc::AbstractMergeErrorBuilder

    attr_reader :error_message, :lib

    def initialize(rebase_error_message, lib)
      @lib = lib
      @error_message = rebase_error_message

      msg = build_message

      super(msg)
    end


    def continue_command
      'git rebase --continue'
    end

  end

end
