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
    origin_url = lib.config('remote.origin.url')

    raise GitHubService::NoRemoteRepository.new("There is no value set for 'remote.origin.url'") if origin_url.empty?

    if /^git@/ =~ origin_url
      host = origin_url.sub(/^git@(.*?):.*$/, '\1')
      site = host_to_site(host, false)
    else
      uri = URI.parse(origin_url)
      host = uri.host
      scheme = uri.scheme

      raise URI::InvalidURIError.new("Need a scheme in URI: '#{origin_url}'") unless scheme

      if host.nil?
        # assume that the 'scheme' is the named configuration in ~/.ssh/config
        host = hostname_from_ssh_config(scheme, opts[:ssh_config_file] ||= "#{ENV['HOME']}/.ssh/config")
      end

      raise GitHubService::NoRemoteRepository.new("Could not determine a host from #{origin_url}") if host.nil?

      site = host_to_site(host, scheme == 'https')
    end
    site
  end


  def hostname_from_ssh_config(host_alias, config_file)
    if File.exists?(config_file)
      config_lines = File.new(config_file).readlines

      in_host_section = false
      host_name = nil

      config_lines.each do |line|
        line.chop!
        if /^\s*Host\s+#{host_alias}\s*$/ =~ line
          in_host_section = true
          next
        end
        if in_host_section and (/^\s*HostName\s+\S+\s*$/ =~ line)
          host_name = line.sub(/^\s*HostName\s+(\S+)\s*$/, '\1')
          break
        end
      end
      host_name
    else
      nil
    end
  end


  def host_to_site(host, ssl)
    if /github.com$/ =~ host
      'https://api.github.com'
    else
      "http#{ssl ? 's' : ''}://#{host}"
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
