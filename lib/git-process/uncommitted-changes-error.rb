require 'git-process-error'

module Git

  class Process

    class UncommittedChangesError < GitProcessError
      def initialize()
        super("There are uncommitted changes.\nPlease either commit your changes, or use 'git stash' to set them aside.")
      end
    end

  end

end
