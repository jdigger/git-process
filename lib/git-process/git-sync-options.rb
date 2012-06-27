require 'optparse'
require 'git-process-options'

module Git

  class Process

    class SyncOptions
      include GitProcessOptions

      attr_reader :rebase, :force


      def initialize(filename, argv)
        @rebase = false
        @force = false
        parse(filename, argv)
      end


      def extend_opts(opts)
        opts.on("-r", "--rebase", "Rebase instead of merge") do |v|
          @rebase = true
        end

        opts.on("-f", "--force", "Force the push") do |v|
          @force = true
        end
      end
    end

  end

end
