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
require 'git-process/pull_request_error'
require 'highline/import'


module GitProc

  class PullRequest < Process

    def initialize(dir, opts)
      super
      @base_branch = opts[:base_branch]
      @head_branch = opts[:head_branch]
      @_repo_name = opts[:repo_name]
      @_remote_name = opts[:server]
      @pr_number = opts[:prNumber]
      @title = opts[:title]
      @description = opts[:description]
      @user = opts[:user]
      @password = opts[:password]
    end


    def runner
      if @pr_number.nil? or @pr_number.empty?
        pr = create_pull_request
        logger.info { "Created pull request at #{pr.html_url}" }
      else
        checkout_pull_request
      end
    end


    def create_pull_request_client(remote_name, repo_name)
      PullRequest.create_pull_request_client(self, remote_name, repo_name, @user, @password)
    end


    def create_pull_request
      current_branch = gitlib.branches.current.name
      base_branch = @base_branch || config.master_branch
      head_branch = @head_branch || current_branch
      title = @title || current_branch
      description = @description || ''

      PullRequest.create_pull_request(gitlib, remote.name, remote.name, remote.repo_name, current_branch, base_branch, head_branch, title, description, logger, @user, @password)
    end


    def checkout_pull_request
      PullRequest.checkout_pull_request(gitlib, @pr_number, remote.name, remote.repo_name, @user, @password, logger)
    end


    class << self

      def create_pull_request_client(lib, remote_name, repo_name, username, password)
        GitHub::PullRequest.new(lib, remote_name, repo_name, {:user => username, :password => password})
      end


      def create_pull_request(lib, server_name, remote_name, repo_name, current_branch, base_branch, head_branch, title, description, logger, username, password)
        if base_branch == head_branch
          raise PullRequestError.new("Can not create a pull request where the base branch and head branch are the same: #{base_branch}")
        end

        lib.push(server_name, current_branch, current_branch, :force => false)
        pr = create_pull_request_client(lib, remote_name, repo_name, username, password)
        pr.create(base_branch, head_branch, title, description)
      end


      def checkout_pull_request(lib, pr_number, remote_name, repo_name, username, password, logger)
        logger.info { 'Getting #pr_number' }

        lib.fetch(remote_name)

        pr = create_pull_request_client(lib, remote_name, repo_name, username, password)
        json = pr.pull_request(pr_number)
        head_branch_name = json[:head][:ref]
        base_branch_name = json[:base][:ref]

        remote_head_server_name = match_remote_to_pr_remote(lib, json[:head][:repo][:ssh_url])
        remote_base_server_name = match_remote_to_pr_remote(lib, json[:base][:repo][:ssh_url])
        lib.checkout(head_branch_name, :new_branch => "#{remote_head_server_name}/#{head_branch_name}")
        lib.branch(head_branch_name, :upstream => "#{remote_base_server_name}/#{base_branch_name}")
        #logger.info(json.to_hash)

        lib.fetch(remote_base_server_name) if remote_head_server_name != remote_base_server_name
      end


      def match_remote_to_pr_remote(lib, pr_remote)
        pr_url = lib.remote.expanded_url(nil, pr_remote)
        servers = lib.remote.remote_names
        server_urls = servers.collect { |s| {:server_name => s, :url => lib.remote.expanded_url(s)} }

        pair = server_urls.find do |su|
          url = su[:url]
          uri = URI.parse(url)
          host = uri.host
          path = uri.path

          pr_uri = URI.parse(lib.remote.expanded_url(nil, pr_url))
          pr_host = pr_uri.host
          pr_path = pr_uri.path

          pr_host == host and pr_path == path
        end

        if pair.nil?
          raise GitHubService::NoRemoteRepository.new("Could not match pull request url (#{pr_url}) to any of the registered remote urls: #{server_urls.map {|s| '{' + s[:server_name] + ': ' + s[:url] + '}'}.join(', ')}")
        end

        pair[:server_name]
      end

    end

  end
end
