require 'optparse'
require 'backports'
require_relative 'git-process-options'

module Git

  class Process

    class ToMasterOptions
      include GitProcessOptions

      def initialize(filename, argv)
        parse(filename, argv)
      end
    end

  end

end
