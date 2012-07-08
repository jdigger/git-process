require 'git-process/github-service'
require 'octokit'


module GitHub

  class PullRequest
    include GitHubService

    attr_reader :lib, :repo

    def initialize(lib, repo, opts = {})
      @lib = lib
      @repo = repo
      @user = opts[:user]
      @password = opts[:password]
    end


    def pull_requests
      @pull_requests ||= client.pull_requests(repo)
    end


    def create(base, head, title, body)
      logger.info { "Creating a pull request asking for '#{head}' to be merged into '#{base}' on #{repo}." }
      begin
        client.create_pull_request(repo, base, head, title, body)
      rescue Octokit::UnprocessableEntity => exp
        pull = pull_requests.find {|p| p[:head][:ref] == head and p[:base][:ref] == base}
        logger.warn { "Pull request already exists. See #{pull[:html_url]}" }
        pull
      end
    end

  end

end
