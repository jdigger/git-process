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

require 'git-process/git_lib'
require 'highline/import'


module GitProc

  #
  # Provides support for prompting the user when the dir/index is dirty.
  #
  #noinspection RubyControlFlowConversionInspection,RubyClassMethodNamingConvention,RubyInstanceMethodNamingConvention
  class ChangeFileHelper

    attr_reader :gitlib

    # @param [GitLib] gitlib
    def initialize(gitlib)
      @gitlib = gitlib
    end


    def offer_to_help_uncommitted_changes
      stat = gitlib.status

      if stat.unmerged.empty?
        handle_unknown_files(stat)
        handle_changed_files(gitlib.status) # refresh status in case it changed earlier
      else
        gitlib.logger.info { "Can not offer to auto-add unmerged files: #{stat.unmerged.inspect}" }
        raise UncommittedChangesError.new
      end
    end


    #noinspection RubyControlFlowConversionInspection
    def handle_unknown_files(stat)
      if not stat.unknown.empty?
        resp = ChangeFileHelper.ask_how_to_handle_unknown_files(stat)
        if resp == :add
          gitlib.add(stat.unknown)
        end
      end
    end


    def handle_changed_files(stat)
      if not stat.modified.empty? or not stat.added.empty? or not stat.deleted.empty?
        resp = ChangeFileHelper.ask_how_to_handle_changed_files(stat)
        if resp == :commit
          changed_files = (stat.added + stat.modified - stat.deleted).sort.uniq

          gitlib.add(changed_files) unless changed_files.empty?
          gitlib.remove(stat.deleted) unless stat.deleted.empty?

          gitlib.commit(nil)
        else
          gitlib.stash_save
        end
      end
    end


    def self.ask_how_to_handle_unknown_files(stat)
      show_changes(:unknown, stat)
      resp = ask('Would you like to (a)dd them or (i)gnore them? ') do |q|
        q.responses[:not_valid] = 'Please respond with either (a)dd or (i)gnore. (Ctl-C to abort.) '
        q.case = :down
        q.validate = /a|i/i
      end

      resp == 'a' ? :add : :ignore
    end


    def self.show_changes(type, stat)
      files = stat.send(type)

      if type != :deleted
        files -= stat.deleted
      end

      if not files.empty?
        say("You have <%= color('#{type}', [:underline]) %> files:\n  <%= color('#{files.join("\n  ")}', [:bold]) %>")
      end
    end


    def self.ask_how_to_handle_changed_files(stat)
      [:added, :modified, :deleted].each { |t| show_changes(t, stat) }
      resp = ask('Would you like to (c)ommit them or (s)tash them? ') do |q|
        q.responses[:not_valid] = 'Please respond with either (c)ommit or (s)tash. (Ctl-C to abort.) '
        q.case = :down
        q.validate = /c|s/i
      end

      resp == 'c' ? :commit : :stash
    end

  end

end
