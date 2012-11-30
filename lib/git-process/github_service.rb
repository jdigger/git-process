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
require 'git-process/github_client'
require 'uri'


module GitHubService

  def client
    if @client.nil?
      auth_token
      logger.debug { "Creating GitHub client for user #{user} using token '#{auth_token}'" }
      @client = GitHubClient.new(:login => user, :oauth_token => auth_token)
      @client.site = site
    end
    @client
  end


  def site(opts = {})
    @site ||= compute_site(opts)
  end


  def compute_site(opts = {})
    url = lib.expanded_url('origin')
    git_url_to_api(url)
  end


  def git_url_to_api(url)
    if /^git@/ =~ url
      host = url.sub(/^git@(.*?):.*$/, '\1')

      if /github.com$/ =~ host
        'https://api.github.com'
      else
        "http://#{host}"
      end
    else
      uri = URI.parse(url)
      host = uri.host

      if /github.com$/ =~ host
        'https://api.github.com'
      else
        scheme = uri.scheme
        scheme = 'https' if scheme == 'git'
        "#{scheme}://#{host}"
      end
    end
  end


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
      if user.nil? or user.empty?
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
        q.validate = /^\S\S+$/
        q.echo = 'x'
      end
    end
    @password
  end


  def auth_token
    @auth_token ||= config_auth_token || create_authorization
  end


  def create_authorization
    logger.info("Authorizing #{user} to work with #{site}.")
    auth = pw_client.create_authorization(:scopes => %w(repo user gist),
                                          :note => 'Git-Process',
                                          :note_url => 'http://jdigger.github.com/git-process')
    config_auth_token = auth['token']
    lib.config('gitProcess.github.authToken', config_auth_token)
    config_auth_token
  end


  def config_auth_token
    if @auth_token.nil?
      c_auth_token = lib.config('gitProcess.github.authToken')
      @auth_token = (c_auth_token.nil? or c_auth_token.empty?) ? nil : c_auth_token
    end
    @auth_token
  end


  def logger
    @lib.logger
  end


  class GithubServiceError < StandardError
  end


  class NoRemoteRepository < GithubServiceError
  end

end
