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

module GitProc

  class GitBranch
    include Comparable

    attr_reader :name

    def initialize(name, current, lib)
      if (/^remotes\// =~ name)
        @name = name[8..-1]
        @remote = true
      else
        @name = name
        @remote = false
      end
      @current = Grit::Head.current.name == name
      @lib = lib
    end


    def current?
      @current
    end


    def remote?
      @remote
    end


    def local?
      !@remote
    end


    def to_s
      name
    end


    def logger
      @lib.logger
    end


    def sha
      @sha ||= @lib.sha(name)
    end


    def <=>(other)
      self.name <=> other.name
    end


    def is_ahead_of(base_branch_name)
      @lib.rev_list(base_branch_name, @name, :oneline => true, :num_revs => 1) != ''
    end


    def delete(force = false)
      if local?
        @lib.branch(@name, :force => force, :delete => true)
      else
        @lib.push(Process.server_name, nil, nil, :delete => @name)
      end
    end


    def rename(new_name)
      @lib.branch(@name, :rename => new_name)
    end


    def contains_all_of(branch_name)
      @lib.rev_list(@name, branch_name, :oneline => true, :num_revs => 1) == ''
    end


    def checkout_to_new(new_branch, opts = {})
      @lib.checkout(new_branch, :new_branch => @name, :no_track => opts[:no_track])
    end

  end

end
