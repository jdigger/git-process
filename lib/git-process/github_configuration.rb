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

require 'git-process/git_lib'
require 'highline/import'
require 'octokit'
require 'uri'


#
# Provides utility methods for working with GitHub
#
# @abstract Override {#remote_name}, {#lib}, {#user} and {#password} to implement.
#
module GitHubService

  class Configuration

    attr_reader :git_config


    # @param [GitProc::GitLib] git_config
    def initialize(git_config)
      @git_config = git_config
    end


    # @abstract The default remote name (e.g., 'origin')
    # @return [String]
    def remote_name
      raise NotImplementedError
    end


    # @abstract The default user to use to connect to GitHub
    # @return [String]
    def user
      raise NotImplementedError
    end


    # @abstract The default password to use to connect to GitHub
    # @return [String]
    def password
      raise NotImplementedError
    end


    # @return [Octokit::Client]
    def client
      create_client
    end


    # @abstract the GitLib to use
    # @return [GitProc::GitLib]
    def gitlib
      raise NotImplementedError
    end


    # @return [Octokit::Client]
    def create_client(opts = {})
      logger.debug { "Creating GitHub client for user #{user} using token '#{auth_token}'" }

      base_url = opts[:base_url] || base_github_api_url_for_remote(opts[:remote_name] || remote_name)

      configure_octokit(:base_url => base_url)

      Octokit::Client.new(:login => user, :oauth_token => auth_token)
    end


    #
    # Configures Octokit to use the appropriate URLs for GitHub server.
    #
    # @param [Hash] opts the options to create a message with
    # @option opts [String] :base_url The base URL to use for the GitHub server
    # @option opts [String] :remote_name (#remote_name) The "remote" name to use (e.g., 'origin')
    #
    # @return [void]
    #
    def configure_octokit(opts = {})
      base_url = opts[:base_url] || base_github_api_url_for_remote(opts[:remote_name] || remote_name)
      Octokit.configure do |c|
        c.api_endpoint = api_endpoint(base_url)
        c.web_endpoint = web_endpoint(base_url)
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
        Octokit::Configuration::DEFAULT_API_ENDPOINT
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
        Octokit::Configuration::DEFAULT_WEB_ENDPOINT
      end
    end


    #
    # Determines the base URL for GitHub API calls based on the given remote name.
    #
    # If the "remote" is not provided, then it assumes that this object
    # has a "remote_name" property that it can ask.
    #
    # @param remote [String] the remote name (e.g., 'origin')
    # @return [String] the base GitHub API URL
    #
    def base_github_api_url_for_remote(remote = nil)
      remote ||= remote_name
      url = lib.expanded_url(remote)
      url_to_base_github_api_url(url)
    end


    #
    # Translate any "git known" URL to the HTTP(S) URL needed for
    # GitHub API calls.
    #
    # @param url [String] the URL to translate
    # @return [String] the base GitHub API URL
    #
    def self.url_to_base_github_api_url(url)
      uri = URI.parse(url)
      host = uri.host

      if /github.com$/ =~ host
        'https://api.github.com'
      else
        scheme = uri.scheme
        scheme = 'https' unless scheme.start_with?('http')
        "#{scheme}://#{host}"
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
    def create_pw_client(opts = {})
      usr = opts[:user] || user()
      pw = opts[:password] || password()

      logger.debug { "Creating GitHub client for user #{usr} using BasicAuth w/ password" }

      configure_octokit(opts)

      Octokit::Client.new(:login => usr, :password => pw)
    end


    def ask_for_user
      GitHubService.ask_for_user(lib)
    end


    def self.ask_for_user(lib)
      user = lib.config('github.user')
      if user.nil? or user.empty?
        user = ask("Your <%= color('GitHub', [:bold, :blue]) %> username: ") do |q|
          q.validate = /^\w\w+$/
        end
        lib.config('github.user', user)
      end
      user
    end


    def self.ask_for_password
      ask("Your <%= color('GitHub', [:bold, :blue]) %> password: ") do |q|
        q.validate = /^\S\S+$/
        q.echo = 'x'
      end
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
    # @param [Hash] opts
    # @option opts [String] :base_url The base URL to use for the GitHub server
    # @option opts [String] :remote_name (#remote_name) The "remote" name to use (e.g., 'origin')
    # @option opts [String] :user the username to authenticate with
    # @option opts [String] :password (#password) the password to authenticate with
    #
    # @return [String] the OAuth token
    #
    def create_authorization(opts = {})
      username = opts[:user] || self.user
      remote = opts[:remote_name] || self.remote_name
      logger.info("Authorizing #{username} to work with #{remote}.")

      auth = create_pw_client(opts).create_authorization(
          :scopes => %w(repo user gist),
          :note => 'Git-Process',
          :note_url => 'http://jdigger.github.com/git-process')

      config_auth_token = auth['token']

      # remember it for next time
      lib.config('gitProcess.github.authToken', config_auth_token)

      self.config_auth_token
    end


    # @return [String]
    def get_config_auth_token
      c_auth_token = lib.config('gitProcess.github.authToken')
      (c_auth_token.nil? or c_auth_token.empty?) ? nil : c_auth_token
    end


    def logger
      lib.logger
    end


    class GithubServiceError < StandardError
    end


    class NoRemoteRepository < GithubServiceError
    end

  end

end
