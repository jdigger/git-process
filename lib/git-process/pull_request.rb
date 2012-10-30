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
      current_branch = branches.current.name
      @title = opts[:title]
      @base_branch = opts[:base_branch] || master_branch
      @head_branch = opts[:head_branch] || current_branch
      @repo_name = opts[:repo_name] || repo_name()
      @title = opts[:title] || current_branch
      @description = opts[:description] || ''
      @user = opts[:user]
      @password = opts[:password]
    end


    def runner
      current_branch = branches.current
      push(server_name, current_branch, current_branch, :force => false)
      pr = GitHub::PullRequest.new(self, @repo_name, {:user => @user, :password => @password})
      pr.create(@base_branch, @head_branch, @title, @description)
    end

  end

end
