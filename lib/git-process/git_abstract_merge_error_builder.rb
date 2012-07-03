require 'git-process/abstract_error_builder'
require 'shellwords'

module GitProc

  #
  # Assumes that there are three attributes defined: error_message, lib, continue_command
  #
  module AbstractMergeErrorBuilder
    include GitProc::AbstractErrorBuilder

    def resolved_files
      @resolved_files ||= find_resolved_files
    end


    def unresolved_files
      @unresolved_files ||= (unmerged - resolved_files)
    end


    def find_resolved_files
      resolved_files = []

      unmerged.each do |file|
        resolved_file = (/Resolved '#{file}' using previous resolution./m =~ error_message)
        resolved_files << file if resolved_file
      end

      resolved_files.sort
    end


    def human_message
      msg = 'There was a problem merging.'

      resolved_files.each do |file|
        if modified.include? file
          msg << "\n'#{file}' was modified in both branches, and 'rerere' automatically resolved it."
        end
      end

      unless lib.rerere_enabled?
        msg << "\n\nConsider turning on 'rerere'.\nSee http://git-scm.com/2010/03/08/rerere.html for more information."
      end

      unresolved_files.each do |file|
        if modified.include? file
          msg << "\n'#{file}' was modified in both branches."
        end
      end

      msg
    end


    def build_commands
      commands = []

      commands << 'git config --global rerere.enabled true' unless lib.rerere_enabled?

      resolved_files.each do |file|
        commands << "# Verify that 'rerere' did the right thing for '#{file}'."
      end

      unless resolved_files.empty? or lib.rerere_autoupdate?
        escaped_files = shell_escaped_files(resolved_files)
        commands << "git add #{escaped_files}"
      end

      unless unresolved_files.empty?
        mergeable = unresolved_files & modified
        commands << "git mergetool #{shell_escaped_files(mergeable)}" unless mergeable.empty?
        mergeable.each do |f|
          commands << "# Verify '#{f}' merged correctly."
        end
        (unresolved_files & added).each do |f|
          commands << "# '#{f}' was added in both branches; Fix the conflict."
        end
        commands << "git add #{shell_escaped_files(unresolved_files)}"
      end

      commands << continue_command if continue_command

      commands
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
