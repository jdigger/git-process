require File.expand_path('../git-lib', __FILE__)
require 'shellwords'

module Git

  class Process
    attr_reader :lib

    def initialize(dir, options = {})
      @lib = Git::GitLib.new(dir, options)
    end


    def rebase_to_master
      if !lib.status.clean?
        raise UncommittedChangesError.new
      end

      lib.fetch if lib.has_a_remote?

      rebase(lib.has_a_remote? ? "origin/master" : "master")

      lib.push("origin", "master") if lib.has_a_remote?
    end


    def sync_with_server
      if !lib.status.clean?
        raise UncommittedChangesError.new
      end

      lib.fetch
      rebase("origin/master")
      if lib.current_branch != 'master'
        lib.push("origin", lib.current_branch)
      else
        logger.warn("Not pushing to the server because the current branch is the master branch.")
      end
    end


    def rebase(base)
      begin
        lib.rebase(base)
      rescue Git::GitExecuteError => rebase_error
        handle_rebase_error(rebase_error.message)
      end
    end


    def git
      lib.git
    end


    private


    def logger
      @lib.logger
    end


    def handle_rebase_error(rebase_error_message)
      raise RebaseError.new(rebase_error_message, lib)

      # git.status.each do |status|
      #   if remerged_file?(status, rebase_error_message)
      #     lib.add(status.path)
      #   end
      # end

      # if lib.status.clean?
      #   lib.rebase_continue
      # end

    end


    class GitProcessError < RuntimeError
    end


    class RebaseError < GitProcessError
      def initialize(rebase_error_message, lib)
        @status = lib.status
        rerere_enabled = lib.git.config('rerere.enabled')
        resolved_files = []

        msg = 'There was a problem merging.'
        @status.unmerged.each do |file|
          resolved_file = (/Resolved '#{file}' using previous resolution./m =~ rebase_error_message)

          if @status.modified.include? file
            if (resolved_file)
              resolved_files << file
              msg += "\n'#{file}' was modified in both branches, and 'rerere' automatically resolved it."
            else
              msg += "\n'#{file}' was modified in both branches."
            end
          end
        end

        resolved_files.sort!
        if !rerere_enabled
          msg += "\n\nConsider turning on 'rerere'."
          msg += "\nSee http://git-scm.com/2010/03/08/rerere.html for more information."
        else
          resolved_files.each do |file|
            msg += "\nVerify that 'rerere' did the right thing for '#{file}'."
          end
        end

        if @status.unmerged.length != resolved_files.length
          unresolved_files = @status.unmerged.find_all {|f| !resolved_files.include?(f)}
          shell_escaped_files = unresolved_files.map{|f| f.shellescape}
          msg += "'rerere' was not able to resolve some files. Run:\n\ngit mergetool #{shell_escaped_files.join(' ')}\n"
        end

        if lib.git.config('rerere.autoupdate')
          msg += "\nIf everything looks good, simply run:\n\ngit rebase --continue"
        else
          shell_escaped_files = resolved_files.map{|f| f.shellescape}
          msg += "\nIf everything looks good, run:\n\ngit add #{shell_escaped_files.join(' ')} && git rebase --continue"
        end

        super(msg)
      end


      def unmerged
        @status.unmerged
      end


      def added
        @status.added
      end


      def deleted
        @status.deleted
      end


      def modified
        @status.modified
      end


      def shell_quote(file)
        
      end

    end


    class UncommittedChangesError < GitProcessError
      def initialize()
        super("There are uncommitted changes.\nPlease either commit your changes, or use 'git stash' to set them aside.")
      end
    end

  end

end
