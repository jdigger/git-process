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

module GitProc

  #
  # A Git Branch
  #
  # @attr_reader [String] name the name of the branch
  #
  class GitBranch
    include Comparable

    attr_reader :name


    # @param [String] name the name of the branch; if it starts with "remotes/" that part is stripped
    #                       and {#remote?} will return {true}
    # @param [Boolean] current is this the current branch?
    # @param [GitLib] lib the {GitLib} to use for operations
    #
    # @todo instead of passing in _current_, detect it dynamically (e.g., look at HEAD)
    def initialize(name, current, lib)
      if /^remotes\// =~ name
        @name = name[8..-1]
        @remote = true
      else
        @name = name
        @remote = false
      end
      @current = current
      @lib = lib
    end


    # @return [Boolean] is this the current branch?
    def current?
      @current
    end


    # @return [Boolean] does this represent a remote branch?
    def remote?
      @remote
    end


    # @return [Boolean] does this represent a local branch?
    def local?
      !@remote
    end


    # @return [String] the name of the branch
    def to_s
      name
    end


    # @return [GitLogger] the logger to use
    def logger
      @lib.logger
    end


    # @return [String] the SHA-1 of the tip of this branch
    def sha
      @lib.sha(name)
    end


    #
    # Implements {Comparable} based on the branch name
    #
    # @param [String, #name] other the item to compare to this; if a {String} then it is compared to _self.name_,
    #                              otherwise the names are compared
    # @return [int, nil] -1, 0, 1 or nil per {Object#<=>}
    def <=>(other)
      if other.nil?
        return nil
      elsif other.is_a? String
        return self.name <=> other
      elsif other.respond_to? :name
        return self.name <=> other.name
      else
        return nil
      end
    end


    # @param [String] base_branch_name the branch to compare to
    # @return [Boolean] does this branch contain every commit in _base_branch_name_ as well as at least one more?
    def is_ahead_of(base_branch_name)
      contains_all_of(base_branch_name) and
          (@lib.rev_list(base_branch_name, @name, :oneline => true, :num_revs => 1) != '')
    end


    #
    # Delete this branch
    #
    # @param [Boolean] force should this force removal even if the branch has not been fully merged?
    #
    # @return [String] the output of running the git command
    def delete!(force = false)
      if local?
        @lib.branch(@name, :force => force, :delete => true)
      else
        @lib.push(Process.server_name, nil, nil, :delete => @name)
      end
    end


    def rename(new_name)
      @lib.branch(@name, :rename => new_name)
    end


    def upstream(upstream_name)
      @lib.branch(@name, :upstream => upstream_name)
    end


    def contains_all_of(branch_name)
      @lib.rev_list(@name, branch_name, :oneline => true, :num_revs => 1) == ''
    end


    def checkout_to_new(new_branch, opts = {})
      @lib.checkout(new_branch, :new_branch => @name, :no_track => opts[:no_track])
    end

  end

end
