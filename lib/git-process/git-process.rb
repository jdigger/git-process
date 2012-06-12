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

  class Process
    attr_reader :lib

    @@server_name = 'origin'
    @@master_branch = 'master'

    def initialize(dir, options = {})
      @lib = Git::GitLib.new(dir, options)
    end


    def Process.remote_master_branch
      "#{@@server_name}/#{@@master_branch}"
    end


    def Process.server_name
      @@server_name
    end


    def Process.master_branch
      @@master_branch
    end


    def rebase_to_master
      unless lib.status.clean?
        raise UncommittedChangesError.new
      end

      if lib.has_a_remote?
        lib.fetch
        rebase(Process::remote_master_branch)
        lib.push(Process::server_name, lib.current_branch, Process::master_branch)
      else
        rebase("master")
      end
    end


    def sync_with_server(rebase)
      unless lib.status.clean?
        raise UncommittedChangesError.new
      end

      lib.fetch

      current_branch = lib.current_branch
      remote_branch = "origin/#{current_branch}"
      old_sha = lib.command('rev-parse', remote_branch)

      rebase(remote_branch)
      rebase(Process::remote_master_branch)

      unless current_branch == Process::master_branch
        lib.fetch
        new_sha = lib.command('rev-parse', remote_branch)
        unless old_sha == new_sha
          logger.warn("'#{current_branch}' changed on '#{Process::server_name}'"+
            " [#{old_sha[0..5]}->#{new_sha[0..5]}]; trying sync again.")
          sync_with_server
        end
        lib.push(Process::server_name, current_branch, current_branch, :force => true)
      else
        merge(remote_branch)
        merge(Process::remote_master_branch)
      end

      unless current_branch == Process::master_branch
        lib.fetch
        if rebase
          new_sha = lib.command('rev-parse', remote_branch)
          unless old_sha == new_sha
            logger.warn("'#{current_branch}' changed on '#{Process::server_name}'"+
                        " [#{old_sha[0..5]}->#{new_sha[0..5]}]; trying sync again.")
            sync_with_server
          end
        end
        lib.push(Process::server_name, current_branch, current_branch, :force => rebase)
      else
        logger.warn("Not pushing to the server because the current branch is the master branch.")
      end
    end


    def rebase(base)
      begin
        lib.rebase(base)
      rescue Git::GitExecuteError => rebase_error
        raise RebaseError.new(rebase_error.message, lib)
      end
    end


    def merge(base)
      begin
        lib.merge(base)
      rescue Git::GitExecuteError => merge_error
        raise MergeError.new(merge_error.message, lib)
      end
    end


    def pull_request
      client = OAuth2::Client.new('015168ac52d54750e525', '9317e6ae5a9e19f4e8140e6ef27370f102a7c324',
                                  # :ssl => {:ca_file => '/etc/ssl/ca-bundle.pem'},
                                  :site => 'https://api.github.com',
                                  :authorize_url => 'https://github.com/login/oauth/authorize',
                                  :token_url => 'https://github.com/login/oauth/access_token')
      url = client.auth_code.authorize_url(:scope => 'repo', :redirect_uri => 'http://localhost:2000/github-oauth2-callback')
      # Thread.new do
        logger.info("Launching #{url} to get authorization.")
        Launchy.open(url)
      # end

      s = HTTPServer.new(:Port => 2000)
      s.mount_proc("/github-oauth2-callback") do |req, res|
        res['Content-Type'] = "text/text"
        res.body = %{
          <html><body>
          <p>Hello. You're calling from a #{req['User-Agent']}</p> <p>I see parameters: #{req.query.keys.join(', ')}</p>
             </body></html>
           }
        Thread.new do
          sleep(1)
          s.shutdown
        end
      end
      trap("INT"){ s.shutdown }
      s.start

      # token = client.auth_code.get_token('36089d4a700e0706177c')
      # puts "token: #{token}"
    end


    def logger
      @lib.logger
    end

  end

end
