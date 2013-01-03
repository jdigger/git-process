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

require 'highline/import'
require 'octokit'
require 'uri'


#
# Provides utility methods for working with GitHub
#
# Assumes the consuming class has properties called "remote_name", "user", "password"
#
module GitHubService

  def create_client
    auth_token
    logger.debug { "Creating GitHub client for user #{user} using token '#{auth_token}'" }

    handle_ghe

    Octokit::Client.new(:login => user, :oauth_token => auth_token)
  end


  def handle_ghe
    the_site = site
    if /github.com/ !~ the_site
      Octokit.configure do |c|
        c.api_endpoint = "#{the_site}/api/v3"
        c.web_endpoint = the_site
      end
    else
      Octokit.configure do |c|
        c.api_endpoint = Octokit::Configuration::DEFAULT_API_ENDPOINT
        c.web_endpoint = Octokit::Configuration::DEFAULT_WEB_ENDPOINT
      end
    end
  end


  def site
    url = gitlib.remote.expanded_url(remote_name)
    git_url_to_api(url)
  end


  def git_url_to_api(url)
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


  def create_pw_client
    logger.debug { "Creating GitHub client for user #{user} using password #{password}" }

    handle_ghe

    Octokit::Client.new(:login => user, :password => password)
  end


  def ask_for_user
    user = gitlib.config['github.user']
    if user.nil? or user.empty?
      user = ask("Your <%= color('GitHub', [:bold, :blue]) %> username: ") do |q|
        q.validate = /^\w\w+$/
      end
      gitlib.config['github.user'] = user
    end
    user
  end


  def ask_for_password
    ask("Your <%= color('GitHub', [:bold, :blue]) %> password: ") do |q|
      q.validate = /^\S\S+$/
      q.echo = 'x'
    end
  end


  def auth_token
    get_config_auth_token || create_authorization
  end


  def create_authorization
    logger.info("Authorizing #{user} to work with #{remote_name}.")

    auth = pw_client.create_authorization(
        :scopes => %w(repo user gist),
        :note => 'Git-Process',
        :note_url => 'http://jdigger.github.com/git-process')

    config_auth_token = auth['token']
    gitlib.config['gitProcess.github.authToken'] = config_auth_token
    config_auth_token
  end


  def get_config_auth_token
    c_auth_token = gitlib.config['gitProcess.github.authToken']
    (c_auth_token.nil? or c_auth_token.empty?) ? nil : c_auth_token
  end


  def logger
    gitlib.logger
  end


  class GithubServiceError < StandardError
  end


  class NoRemoteRepository < GithubServiceError
  end

end
