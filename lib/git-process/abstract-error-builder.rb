require 'shellwords'

module GitProc

  #
  # Assumes that there are two attributes defined: error_message, lib
  #
  module AbstractErrorBuilder

    def commands
      @commands ||= build_commands
    end


    def build_message
      msg = human_message

      msg << append_commands
    end


    def append_commands
      commands.empty? ? '' : "\n\nCommands:\n\n  #{commands.join("\n  ")}"
    end


    def human_message
      ''
    end


    def build_commands
      []
    end


    def shell_escaped_files(files)
      shell_escaped_files = files.map{|f| f.shellescape}
      shell_escaped_files.join(' ')
    end

  end

end
