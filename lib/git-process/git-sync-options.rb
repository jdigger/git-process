require 'optparse'
require 'backports'
require_relative 'git-process-options'

module Git

  class Process

    class SyncOptions
      include GitProcessOptions

      def initialize(argv)
        parse(argv)
      end
    end

  end

end
