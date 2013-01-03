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

require 'shellwords'

module GitProc

  module AbstractErrorBuilder

    def commands
      @commands ||= build_commands
    end


    def build_message
      msg = human_message

      msg << append_commands
    end


    def append_commands
      commands.empty? ? '' : "\n\nCommands:\n\n  #{commands.join("\n  ")}"
    end


    def human_message
      ''
    end


    def build_commands
      []
    end


    def shell_escaped_files(files)
      shell_escaped_files = files.map { |f| f.shellescape }
      shell_escaped_files.join(' ')
    end

  end

end
