require File.expand_path('../git-lib', __FILE__)
require 'shellwords'

module Git

  class Process
    attr_reader :lib

    def initialize(dir, options = {})
      @lib = Git::GitLib.new(dir, options)
    end


    def rebase_to_master
      unless lib.status.clean?
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
        raise RebaseError.new(rebase_error.message, lib)
      end
    end


    def git
      lib.git
    end


    private


    def logger
      @lib.logger
    end


    class GitProcessError < RuntimeError
    end


    class RebaseError < GitProcessError
      attr_reader :resolved_files, :unresolved_files, :commands

      def initialize(rebase_error_message, lib)
        @lib = lib
        @status = lib.status

        @commands = []

        @resolved_files = find_resolved_files(rebase_error_message)
        @unresolved_files = find_unresolved_files

        msg = build_message

        super(msg)
      end


      def find_resolved_files(rebase_error_message)
        resolved_files = []

        unmerged.each do |file|
          resolved_file = (/Resolved '#{file}' using previous resolution./m =~ rebase_error_message)
          resolved_files << file if resolved_file
        end

        resolved_files.sort
      end


      def find_unresolved_files
        if unmerged.length != resolved_files.length
          unmerged.find_all {|f| !resolved_files.include?(f)}.sort
        else
          []
        end
      end


      def build_message
        msg = 'There was a problem merging.'

        resolved_files.each do |file|
          if modified.include? file
            msg += "\n'#{file}' was modified in both branches, and 'rerere' automatically resolved it."
          end
        end

        unless @lib.git.config('rerere.enabled')
          msg << "\n\nConsider turning on 'rerere'.\nSee http://git-scm.com/2010/03/08/rerere.html for more information."
        end

        unresolved_files.each do |file|
          if modified.include? file
            msg += "\n'#{file}' was modified in both branches."
          end
        end

        commands = build_commands
        msg << "\n\nCommands:\n\n  #{commands.join("\n  ")}"
      end


      def build_commands
        commands = []

        commands << 'git config --global rerere.enabled true' unless @lib.git.config('rerere.enabled')

        resolved_files.each do |file|
          commands << "# Verify that 'rerere' did the right thing for '#{file}'."
        end

        unless unresolved_files.empty?
          shell_escaped_files = unresolved_files.map{|f| f.shellescape}
          commands << "git mergetool #{shell_escaped_files.join(' ')}"
        end

        commands << "git add -A" unless unresolved_files.empty?
        commands << "git rebase --continue"

        commands
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
