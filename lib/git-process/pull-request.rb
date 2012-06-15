require 'git-lib'
require 'uncommitted-changes-error'
require 'git-rebase-error'
require 'git-process-error'
require 'highline/import'
require 'github-client'
require 'uri'


module Git

  class PullRequest
    attr_reader :lib, :site

    def initialize(lib, opts = {})
      @lib = lib
      @user = opts[:user]
      @password = opts[:password]
      # @site = opts[:site]
    end


    def client
      unless @client
        auth_token
        logger.debug { "Creating GitHub client for user #{user} using token '#{auth_token}'" }
        @client = GitHubClient.new(:login => user, :oauth_token=> auth_token)
        @client.site = site
      end
      @client
    end


    def site
      @site ||= compute_site
    end


    class NoRemoteRepository < Git::Process::GitProcessError
    end


    def compute_site
      origin_url = lib.config('remote.origin.url')
      
      raise NoRemoteRepository.new("There is no value set for 'remote.origin.url'") if origin_url.empty?

      begin
        uri = URI.parse(origin_url)
        host = uri.host
      rescue URI::InvalidURIError => uri_error
        host = origin_url.sub(/^git\@(.*?):.*$/, '\1')
      end
      site = host_to_site(host)
    end


    def host_to_site(host)
      if /github.com$/ =~ host
        'https://api.github.com'
      else
        "http://#{host}"
      end
    end


    private :host_to_site, :compute_site


    def pw_client
      unless @pw_client
        logger.debug { "Creating GitHub client for user #{user} using password #{password}" }
        @pw_client = GitHubClient.new(:login => user, :password => password)
        @pw_client.site = site
      end
      @pw_client
    end


    def user
      unless @user
        user = lib.config('github.user')
        if user.empty?
          user = ask("Your <%= color('GitHub', [:bold, :blue]) %> username: ") do |q|
            q.validate = /^\w\w+$/
          end
          lib.config('github.user', user)
        end
        @user = user
      end
      @user
    end


    def password
      unless @password
        @password = ask("Your <%= color('GitHub', [:bold, :blue]) %> password: ") do |q|
          q.validate = /^\w\w+$/
          q.echo = 'x'
        end
      end
      @password
    end


    def auth_token
      @auth_token ||= config_auth_token || create_authorization
    end


    def create_authorization
      logger.info("Authorizing this to work with your repos.")
      auth = pw_client.create_authorization(:scopes => ['repo', 'user', 'gist'],
                                            :note => 'Git-Process',
                                            :note_url => 'http://jdigger.github.com/git-process')
      config_auth_token = auth['token']
      lib.config('gitProcess.github.authToken', config_auth_token)
      config_auth_token
    end


    def config_auth_token
      unless @auth_token
        c_auth_token = lib.config('gitProcess.github.authToken')
        @auth_token = c_auth_token.empty? ? nil : c_auth_token
      end
      @auth_token
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


    def logger
      @lib.logger
    end

  end

end
