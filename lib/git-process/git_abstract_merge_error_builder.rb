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

require 'git-process/abstract_error_builder'
require 'shellwords'

module GitProc

  #noinspection RubyTooManyInstanceVariablesInspection
  class AbstractMergeErrorBuilder
    include GitProc::AbstractErrorBuilder

    attr_reader :gitlib, :error_message, :continue_command


    def initialize(gitlib, error_message, continue_command)
      @gitlib = gitlib
      @error_message = error_message
      @continue_command = continue_command
    end


    def resolved_files
      @resolved_files ||= find_resolved_files
    end


    def unresolved_files
      @unresolved_files ||= (unmerged - resolved_files)
    end


    def find_resolved_files
      resolved_files = []

      unmerged.each do |file|
        resolved_file = (/Resolved '#{file}' using previous resolution./m =~ error_message)
        resolved_files << file if resolved_file
      end

      resolved_files.sort
    end


    def human_message
      msg = 'There was a problem merging.'

      unresolved_files.each do |file|
        if modified.include? file
          msg << "\n'#{file}' was modified in both branches."
        end
      end

      msg
    end


    def build_commands
      commands = []

      unless resolved_files.empty?
        escaped_files = shell_escaped_files(resolved_files)
        commands << "git add #{escaped_files}"
      end

      unless unresolved_files.empty?
        mergeable = unresolved_files & modified
        commands << "git mergetool #{shell_escaped_files(mergeable)}" unless mergeable.empty?
        mergeable.each do |f|
          commands << "# Verify '#{f}' merged correctly."
        end
        (unresolved_files & added).each do |f|
          commands << "# '#{f}' was added in both branches; Fix the conflict."
        end
        commands << "git add #{shell_escaped_files(unresolved_files)}"
      end

      commands << continue_command if continue_command

      commands
    end


    attr_writer :unmerged, :added, :deleted, :modified


    def unmerged
      @unmerged ||= status.unmerged
    end


    def added
      @added ||= status.added
    end


    def deleted
      @deleted ||= status.deleted
    end


    def modified
      @modified ||= status.modified
    end


    private


    def config
      gitlib.config
    end


    def status
      @status ||= gitlib.status
    end

  end

end
