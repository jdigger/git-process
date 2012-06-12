require 'optparse'
require 'backports'
require_relative 'git-process-options'

module Git

  class Process

    class SyncOptions
      include GitProcessOptions

      attr_reader :rebase


      def initialize(filename, argv)
        @rebase = false
        parse(filename, argv)
      end


      def extend_opts(opts)
        opts.on("-r", "--rebase", "Rebase instead of merge") do |v|
          @rebase = true
        end
      end
    end

  end

end
