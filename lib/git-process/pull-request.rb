require 'github-service'
require 'octokit'


module Git

  class PullRequest
    include GitHubService

    attr_reader :lib

    def initialize(lib, opts = {})
      @lib = lib
      @user = opts[:user]
      @password = opts[:password]
    end


    def pull_request(repo, base, head, title, body)
      logger.info { "Creating a pull request asking for '#{head}' to be merged into '#{base}' on #{repo}." }
      begin
        client.create_pull_request(repo, base, head, title, body)
      rescue Octokit::UnprocessableEntity => exp
        pulls = client.pull_requests(repo)
        pull = pulls.find {|p| p[:head][:ref] == head and p[:base][:ref] == base}
        logger.warn { "Pull request already exists. See #{pull[:html_url]}" }
        pull
      end
    end

  end

end
