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

require File.dirname(__FILE__) + '/git_lib'
require File.dirname(__FILE__) + '/git_logger'
require 'highline/import'
require 'octokit'
require 'octokit/default'
require 'uri'
require 'faraday'
require 'faraday/response/logger'


module GitHubService

  #
  # Provides methods related to GitHub configuration
  #
  class Configuration

    #
    # @param [GitProc::GitConfig] git_config
    # @param [Hash] opts
    # @option opts [String] :remote_name (Configuration#remote_name) The "remote" name to use (e.g., 'origin')
    # @option opts [String] :user the username to authenticate with
    # @option opts [String] :password (Configuration#password) the password to authenticate with
    #
    # @return [String] the OAuth token
    #
    # @todo pass in {GitLib} instead of {GitConfig}
    #
    def initialize(git_config, opts = {})
      @git_config = git_config
      @user = opts[:user]
      @password = opts[:password]
      @remote_name = opts[:remote_name]
    end


    # @return [GitProc::GitConfig]
    def git_config
      @git_config
    end


    # @return [String] the "remote name" (e.g., origin) for GitHub
    #
    # @see GitProc::GitRemote#remote_name
    def remote_name
      unless @remote_name
        @remote_name = gitlib.remote.name
        raise NoRemoteRepository.new('No remote repository is defined') unless @remote_name
      end
      @remote_name
    end


    # @return [String] the user name for GitHub
    def user
      @user ||= Configuration.ask_for_user(gitlib)
    end


    # @return [String] the password for GitHub
    def password
      @password ||= Configuration.ask_for_password
    end


    # @return [Octokit::Client] the client for communicating with GitHub using {Configuration#user} and {Configuration#auth_token}
    def client
      @client ||= create_client
    end


    # @return [GitProc::GitLib]
    def gitlib
      @git_config.gitlib
    end


    #
    # Configures Octokit to use the appropriate URLs for GitHub server.
    #
    # @option opts [String] :base_url The base URL to use for the GitHub server; defaults to {#base_github_api_url_for_remote}
    #
    # @return [void]
    #
    # @todo remove opts and pass in base_url directly
    #
    def configure_octokit(opts = {})
      base_url = opts[:base_url] || base_github_api_url_for_remote
      Octokit.configure do |c|
        c.api_endpoint = api_endpoint(base_url)
        c.web_endpoint = web_endpoint(base_url)
      end
      if logger.level < ::GitProc::GitLogger::INFO
        Octokit.middleware = Faraday::RackBuilder.new do |builder|
          builder.response :logger, logger
          builder.use Octokit::Response::RaiseError
          builder.adapter Faraday.default_adapter
        end
      end
    end


    #
    # Determines the URL used for using the GitHub REST interface based
    # on a "base" URL.
    #
    # If the "base_url" is not provided, then it assumes that this object
    # has a "remote_name" property that it can ask.
    #
    # @param [String] base_url the base GitHub URL
    # @return [String] the GitHub REST API URL
    #
    def api_endpoint(base_url = nil)
      base_url ||= base_github_api_url_for_remote
      if /github.com/ !~ base_url
        "#{base_url}/api/v3"
      else
        Octokit::Default::API_ENDPOINT
      end
    end


    #
    # Determines the URL used for using the GitHub web interface based
    # on a "base" URL.
    #
    # If the "base_url" is not provided, then it assumes that this object
    # has a "remote_name" property that it can ask.
    #
    # @param [String] base_url the base GitHub URL
    # @return [String] the GitHub web URL
    #
    def web_endpoint(base_url = nil)
      base_url ||= base_github_api_url_for_remote
      if /github.com/ !~ base_url
        base_url
      else
        Octokit::Default::WEB_ENDPOINT
      end
    end


    #
    # Determines the base URL for GitHub API calls.
    #
    # @return [String] the base GitHub API URL
    #
    def base_github_api_url_for_remote
      url = gitlib.remote.expanded_url(remote_name)
      Configuration.url_to_base_github_api_url(url)
    end


    #
    # Translate any "git known" URL to the HTTP(S) URL needed for
    # GitHub API calls.
    #
    # @param url [String] the URL to translate
    # @return [String] the base GitHub API URL
    #
    # @example
    #   url_to_base_github_api_url('git@github.com:jdigger/git-process.git') #=> 'https://api.github.com'
    #
    #   url_to_base_github_api_url('http://ghe.myco.com/jdigger/git-process.git') #=> 'http://ghe.myco.com'
    #
    # @todo use Octokit's improved ability to determine this
    #
    def self.url_to_base_github_api_url(url)
      uri = URI.parse(url)
      host = uri.host

      if /github.com$/ =~ host
        return 'https://api.github.com'
      else
        scheme = uri.scheme
        scheme = 'https' unless scheme.start_with?('http')
        host = 'unknown-host' unless host
        return "#{scheme}://#{host}"
      end
    end


    #
    # Create a GitHub client using username and password specifically.
    # Meant to be used to get an OAuth token for "regular" client calls.
    #
    # @param [Hash] opts the options to create a message with
    # @option opts [String] :base_url The base URL to use for the GitHub server
    # @option opts [String] :remote_name (#remote_name) The "remote" name to use (e.g., 'origin')
    # @option opts [String] :user the username to authenticate with
    # @option opts [String] :password (#password) the password to authenticate with
    #
    # @return [Octokit::Client] the Octokit client for communicating with GitHub
    #
    def create_pw_client(opts = {})
      usr = opts[:user] || user()
      pw = opts[:password] || password()
      remote = opts[:remote_name] || self.remote_name

      logger.info("Authorizing #{usr} to work with #{remote}.")

      configure_octokit(opts)

      Octokit::Client.new(:login => usr, :password => pw)
    end


    #
    # Returns to OAuth token. If it's in .git/config, returns that.
    #   Otherwise it connects to GitHub to get the authorization token.
    #
    # @param [Hash] opts
    # @option opts [String] :base_url The base URL to use for the GitHub server
    # @option opts [String] :remote_name (#remote_name) The "remote" name to use (e.g., 'origin')
    # @option opts [String] :user the username to authenticate with
    # @option opts [String] :password (#password) the password to authenticate with
    #
    # @return [String]
    #
    def auth_token(opts = {})
      get_config_auth_token() || create_authorization(opts)
    end


    #
    # Connects to GitHub to get an OAuth token.
    #
    # @option opts [String] :base_url The base URL to use for the GitHub server
    # @option opts [String] :remote_name (Configuration#remote_name) The "remote" name to use (e.g., 'origin')
    # @option opts [String] :user the username to authenticate with
    # @option opts [String] :password (#password) the password to authenticate with
    # @option opts [String] :two_factor (#password) the password to authenticate with
    #
    # @return [String] the OAuth token
    #
    # noinspection RubyStringKeysInHashInspection
    def create_authorization(opts = {})
      client = opts[:client] || create_pw_client(opts)

      return create_authorization_token(client, opts[:two_factor])
    end


    def create_authorization_token(client, two_factor)
      begin
        # noinspection RubyStringKeysInHashInspection
        headers = two_factor ? {'X-GitHub-OTP' => two_factor} : nil
        auth = client.create_authorization(
            :scopes => %w(repo user gist),
            :note => 'Git-Process',
            :note_url => 'http://jdigger.github.com/git-process',
            :headers => headers
        )
      rescue Octokit::OneTimePasswordRequired
        return create_2f_authorization(client)
      rescue Octokit::UnprocessableEntity => exp
        return unprocessable_authorization(exp)
      end

      config_auth_token = auth[:token]

      # remember it for next time
      gitlib.config['gitProcess.github.authToken'] = config_auth_token

      return config_auth_token
    end


    #
    # Connects to GitHub to get an OAuth token.
    #
    # @option opts [String] :base_url The base URL to use for the GitHub server
    # @option opts [String] :remote_name (Configuration#remote_name) The "remote" name to use (e.g., 'origin')
    # @option opts [String] :user the username to authenticate with
    # @option opts [String] :password (#password) the password to authenticate with
    # @option opts [String] :two_factor (#password) the password to authenticate with
    #
    # @return [String] the OAuth token
    #
    # noinspection RubyStringKeysInHashInspection
    def create_2f_authorization(client)
      two_factor = Configuration.ask_for_two_factor

      create_authorization_token(client, two_factor)
    end


    def two_factor_auth(authorization_count, opts)
      return create_authorization(opts.merge(:two_factor => two_factor, :authorization_count => authorization_count + 1))
    end


    # @return [String, nil] the OAuth token, or nil if not found
    def get_config_auth_token
      c_auth_token = gitlib.config['gitProcess.github.authToken']
      (c_auth_token.nil? or c_auth_token.empty?) ? nil : c_auth_token
    end


    def logger
      gitlib.logger
    end


    private


    #
    # Create a client for communicating with GitHub using {Configuration#user} and {Configuration#auth_token}
    #
    # @return [Octokit::Client]
    #
    # @todo have the params passed in explicitly instead of via opts
    #
    def create_client(opts = {})
      logger.debug { "Creating GitHub client for user #{user} using token '#{auth_token}'" }

      base_url = opts[:base_url] || base_github_api_url_for_remote

      configure_octokit(:base_url => base_url)

      Octokit::Client.new(:access_token => auth_token)
    end


    def self.ask_for_user(gitlib)
      user = gitlib.config['github.user']
      if user.nil? or user.empty?
        user = ask("Your <%= color('GitHub', [:bold, :blue]) %> username: ") do |q|
          q.validate = /^\w\w+$/
        end
        gitlib.config['github.user'] = user
      end
      user
    end


    def self.ask_for_password
      ask("Your <%= color('GitHub', [:bold, :blue]) %> password: ") do |q|
        q.validate = /^\S\S+$/
        q.echo = 'x'
      end
    end


    def self.ask_for_two_factor
      ask("Your <%= color('GitHub', [:bold, :blue]) %> two-factor code: ") do |q|
        q.validate = /^\w\w+$/
      end
    end


    # @todo implement https://github.com/jdigger/git-process/issues/142
    def ask_about_resetting_authorization
      raise TokenAlreadyExists.new("The token already exists. Please check your OAuth settings for your account.")
    end


    #
    # Tries to more gracefully handle the token already existing. See
    #
    # @return [String] the OAuth token
    #
    # @raise [TokenAlreadyExists] the token already exists
    # @raise [Octokit::UnprocessableEntity] there was another problem
    def unprocessable_authorization(exp)
      errors = exp.errors
      if not (errors.nil? or errors.empty?)
        error_hash = errors[0]
        if error_hash[:resource] == 'OauthAccess'
          # error_hash[:code]
          return ask_about_resetting_authorization
        else
          raise exp
        end
      else
        raise exp
      end
    end

  end


  class Error < ::StandardError
  end


  class NoRemoteRepository < Error
  end

  class TokenAlreadyExists < Error
  end

end
