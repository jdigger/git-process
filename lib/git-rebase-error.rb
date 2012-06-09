require File.expand_path('../git-lib', __FILE__)
require File.expand_path('../git-process-error', __FILE__)
require 'shellwords'

module Git

  class Process

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

    end

  end

end
