require 'git-process-options'

module Git

  class Process

    class NewFeatureBranchOptions
      include GitProcessOptions

      attr_reader :branch_name

      def initialize(filename, argv)
        @filename = filename
        argv << "-h" if argv.empty?
        parse(filename, argv)
      end


      def extend_opts(opts)
        opts.banner = "Usage: #{@filename} [ options ] branch_name"
      end


      def extend_args(argv)
        raise OptionParser::ParseError.new("Must have exactly one branch name.") if argv.length != 1

        @branch_name = argv.pop
      end

    end

  end

end
