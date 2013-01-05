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

require 'git-process/github_configuration'
require 'octokit'
require 'octokit/repository'


module GitHub

  class PullRequest
    attr_reader :gitlib, :repo, :remote_name, :client, :configuration


    def initialize(lib, remote_name, repo, opts = {})
      @gitlib = lib
      @repo = repo
      @remote_name = remote_name
      @configuration = GitHubService::Configuration.new(gitlib.config, :user => opts[:user], :password => opts[:password])
    end


    def client
      @client ||= @configuration.create_client
    end


    def pull_requests
      @pull_requests ||= client.pull_requests(repo)
    end


    def create(base, head, title, body)
      logger.info { "Creating a pull request asking for '#{head}' to be merged into '#{base}' on #{repo}." }
      begin
        client.create_pull_request(repo, base, head, title, body)
      rescue Octokit::UnprocessableEntity
        pull = pull_requests.find { |p| p[:head][:ref] == head and p[:base][:ref] == base }
        logger.warn { "Pull request already exists. See #{pull[:html_url]}" }
        pull
      end
    end


    def logger
      @gitlib.logger
    end


    def pull_request(pr_number)
      client.pull_request(repo, pr_number)
    end


    def find_pull_request(base, head)
      json = pull_requests
      json.find { |p| p[:head][:ref] == head and p[:base][:ref] == base }
    end


    def close(*args)
      pull_number = nil

      if args.size == 2
        base = args[0]
        head = args[1]
        logger.info { "Closing a pull request asking for '#{head}' to be merged into '#{base}' on #{repo}." }

        json = pull_requests
        pull = json.find { |p| p[:head][:ref] == head and p[:base][:ref] == base }

        raise NotFoundError.new(base, head, repo, json) if pull.nil?

        pull_number = pull[:number]
      elsif args.size == 1
        pull_number = args[0]
        logger.info { "Closing a pull request \##{pull_number} on #{repo}." }
      end

      client.patch("repos/#{Octokit::Repository.new(repo)}/pulls/#{pull_number}", {:state => 'closed'})
    end


    class NotFoundError < StandardError
      attr_reader :base, :head, :repo


      def initialize(base, head, repo, pull_requests_json)
        @base = base
        @head = head
        @repo = repo

        @pull_requests = pull_requests_json.map do |p|
          {:head => p[:head][:ref], :base => p[:base][:ref]}
        end

        msg = "Could not find a pull request for '#{head}' to be merged with '#{base}' on #{repo}."
        msg += "\n\nExisting Pull Requests:"
        msg = pull_requests.inject(msg) { |a, v| "#{a}\n  #{v[:head]} -> #{v[:base]}" }

        super(msg)
      end


      def pull_requests
        @pull_requests
      end

    end

  end

end
