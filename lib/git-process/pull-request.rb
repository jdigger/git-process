require 'backports'
require_relative 'git-lib'
require_relative 'uncommitted-changes-error'
require_relative 'git-rebase-error'
require 'octokit'
require 'highline/import'


module Git

  class PullRequest
    attr_reader :lib

    def initialize(lib, opts = {})
      @lib = lib
      @user = opts[:user]
      @password = opts[:password]
    end


    def client
      unless @client
        auth_token
        logger.debug { "Creating GitHub client for user #{user} using token '#{auth_token}'" }
        @client = Octokit::Client.new(:login => user, :oauth_token=> auth_token)
        # end
      end
      @client
    end


    def pw_client
      unless @pw_client
        logger.debug { "Creating GitHub client for user #{user} using password #{password}" }
        @pw_client = Octokit::Client.new(:login => user, :password => password)
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
      unless config_auth_token
        logger.info("Authorizing this to work with your repos.")
        auth = pw_client.create_authorization(:scopes => ['repo', 'user', 'gist'],
                                              :note => 'Git-Process',
                                              :note_url => 'http://jdigger.github.com/git-process')
        logger.info("auth: #{auth}")
        config_auth_token = auth['token']
        lib.config('gitProcess.github.authToken', config_auth_token)
        @auth_token = config_auth_token
      end
      @auth_token
    end


    def config_auth_token
      unless @auth_token
        auth_token = lib.config('gitProcess.github.authToken')
        @auth_token = auth_token.empty? ? nil : auth_token
      end
      @auth_token
    end


    def pull_request(repo, base, head, title, body)
      logger.info { "Creating a pull request asking for '#{head}' to be merged into '#{base}' on #{repo}." }
      client.create_pull_request(repo, base, head, title, body)
    end


    def logger
      @lib.logger
    end

  end

end
