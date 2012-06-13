require 'backports'
require_relative 'git-lib'
require_relative 'uncommitted-changes-error'
require_relative 'git-rebase-error'
require 'shellwords'
require 'oauth2'
require 'launchy'
require 'webrick'
include WEBrick


module Git

  class PullRequest
    attr_reader :lib

    @@CLIENT_ID = '015168ac52d54750e525'
    @@CLIENT_KEY = '9317e6ae5a9e19f4e8140e6ef27370f102a7c324'
    @@API_SITE = 'https://api.github.com'
    @@AUTHORIZE_URL = 'https://github.com/login/oauth/authorize'
    @@TOKEN_URL = 'https://github.com/login/oauth/access_token'
    @@REDIRECT_URI = 'http://localhost:2000/github-oauth2-callback'

    def initialize(lib)
      @lib = lib
    end


    def pull_request
      auth_token
    end


    def auth_token
      unless @auth_token
        @auth_token = lib.config['gitProcess.github.authToken']
        unless @auth_token
          client = OAuth2::Client.new(@@CLIENT_ID, @@CLIENT_KEY,
                                      :site => @@API_SITE,
                                      :authorize_url => @@AUTHORIZE_URL,
                                      :token_url => @@TOKEN_URL)
          url = client.auth_code.authorize_url(:scope => 'repo', :redirect_uri => @@REDIRECT_URI)
          logger.info("Launching #{url} to get authorization.")
          Launchy.open(url)

          s = HTTPServer.new(:Port => 2000)
          s.mount_proc("/github-oauth2-callback") do |req, res|
            code = req.query['code']
            logger.debug { "Received a code (#{code}) back from GitHub's authenticator."}

            auth_token = client.auth_code.get_token(code)
            token = auth_token.token
            logger.debug { "Got auth_token: #{token}"}
            logger.debug { "refresh_token: #{auth_token.refresh_token}" }
            logger.debug { "expires_in: #{auth_token.expires_in}" }
            logger.debug { "expires_at #{auth_token.expires_at}" }
            logger.debug { "params: #{auth_token.params.map{|k,v| "#{k}: #{v}" }.join(', ')}" }
            logger.debug { "options: #{auth_token.options.map{|k,v| "#{k}: #{v}" }.join(', ')}" }

            logger.debug { "Saving token in configuration as 'gitProcess.github.authToken'." }
            lib.config('gitProcess.github.authToken', token)

            @auth_token = token

            res['Content-Type'] = "text/html"
            res.body = %{
              <html><body>
              <p>Thank you. <tt><b>git-process</b></tt> is now authorized.</p>
              </body></html>
            }
            Thread.new do
              sleep(1)
              s.shutdown
            end
          end
          trap("INT"){ s.shutdown }
          s.start
        end
      end
      @auth_token
    end


    def logger
      @lib.logger
    end

  end

end
