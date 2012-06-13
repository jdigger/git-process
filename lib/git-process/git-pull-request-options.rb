require 'backports'
require_relative 'git-process-options'

module Git

  class Process

    class PullRequestOptions
      include GitProcessOptions

      def initialize(filename, argv)
        parse(filename, argv)
      end
    end

  end

end
