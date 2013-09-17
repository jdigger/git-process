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
require 'git-process/parked_changes_error'
require 'git-process/syncer'
require 'git-process/changed_file_helper'


module GitProc

  class Sync < Process

    def initialize(base, opts)
      super

      @opts = opts

      self
    end


    #noinspection RubyControlFlowConversionInspection
    def verify_preconditions
      super

      if not gitlib.status.clean?
        GitProc::ChangeFileHelper.new(gitlib).offer_to_help_uncommitted_changes
      end

      raise ParkedChangesError.new(self) if gitlib.is_parked?
    end


    def cleanup
      gitlib.stash_pop if @stash_pushed
    end


    def runner
      GitProc::Syncer.do_sync(gitlib, @opts)
    end

  end

end
