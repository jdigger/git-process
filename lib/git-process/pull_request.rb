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
require 'git-process/github_pull_request'
require 'highline/import'


module GitProc

  class PullRequest < Process
    include GitLib


    def initialize(dir, opts)
      super
      @title = opts[:title]
      @base_branch = opts[:base_branch] || master_branch
      @head_branch = opts[:head_branch] || branches.current
      @repo_name = opts[:repo_name] || repo_name()
      @title = opts[:title] || ask_for_pull_title()
      @description = opts[:description] || ask_for_pull_description()
      @user = opts[:user]
      @password = opts[:password]
    end


    def runner
      current_branch = branches.current
      push(server_name, current_branch, current_branch, :force => false)
      pr = GitHub::PullRequest.new(self, @repo_name, {:user => @user, :password => @password})
      pr.create(@base_branch, @head_branch, @title, @description)
    end


    private


    def ask_for_pull_title
      ask("What <%= color('title', [:bold]) %> do you want to give the pull request? ") do |q|
        q.validate = /^\w+.*/
      end
    end


    def ask_for_pull_description
      ask("What <%= color('description', [:bold]) %> do you want to give the pull request? ")
    end

  end

end
