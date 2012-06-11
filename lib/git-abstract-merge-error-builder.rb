require File.expand_path('../git-lib', __FILE__)
require File.expand_path('../git-process-error', __FILE__)
require 'shellwords'

module Git

  #
  # Assumes that there are two attributes defined: error_message, lib, continue_command
  #
  module AbstractMergeErrorBuilder

    def commands
      @commands ||= build_commands
    end


    def resolved_files
      @resolved_files ||= find_resolved_files
    end


    def unresolved_files
      @unresolved_files ||= find_unresolved_files
    end


    def find_resolved_files
      resolved_files = []

      unmerged.each do |file|
        resolved_file = (/Resolved '#{file}' using previous resolution./m =~ error_message)
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

      unless lib.git.config('rerere.enabled')
        msg << "\n\nConsider turning on 'rerere'.\nSee http://git-scm.com/2010/03/08/rerere.html for more information."
      end

      unresolved_files.each do |file|
        if modified.include? file
          msg += "\n'#{file}' was modified in both branches."
        end
      end

      msg << "\n\nCommands:\n\n  #{commands.join("\n  ")}"
    end


    def build_commands
      commands = []

      commands << 'git config --global rerere.enabled true' unless lib.rerere_enabled?

      resolved_files.each do |file|
        commands << "# Verify that 'rerere' did the right thing for '#{file}'."
      end

      unless unresolved_files.empty?
        escaped_files = shell_escaped_files(unresolved_files)
        commands << "git mergetool #{escaped_files}"
        unresolved_files.each do |f|
          commands << "# Verify '#{f}' merged correctly."
        end
        commands << "git add #{escaped_files}"
      end

      commands << continue_command if continue_command

      commands
    end


    def shell_escaped_files(files)
      shell_escaped_files = files.map{|f| f.shellescape}
      shell_escaped_files.join(' ')
    end


    attr_writer :unmerged, :added, :deleted, :modified


    def unmerged
      @unmerged ||= lib.status.unmerged
    end


    def added
      @added ||= lib.status.added
    end


    def deleted
      @deleted ||= lib.status.deleted
    end


    def modified
      @modified ||= lib.status.modified
    end

  end

end
