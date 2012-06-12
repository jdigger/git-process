require 'optparse'

module Git

  class Process

    module GitProcessOptions

      attr_reader :quiet, :verbose


      def quiet
        @quiet
      end


      def verbose
        @verbose
      end


      def log_level
        if quiet
          Logger::ERROR
        elsif verbose
          Logger::DEBUG
        else
          Logger::INFO
        end
      end


      def parse(filename, argv)
        OptionParser.new do |opts|
          opts.banner = "Usage: #{filename} [ options ]"

          opts.on("-q", "--quiet", "Quiet") do |v|
            @quiet = true
          end

          opts.on("-v", "--verbose", "Verbose") do |v|
            @verbose = true
            @quiet = false
          end

          opts.on("-h", "--help", "Show this message") do
            puts opts
            exit(-1)
          end

          extend_opts(opts)

          begin
            begin
              opts.parse!(argv)
            rescue OptionParser::ParseError => e
              raise "#{e.message}\n#{opts}"
            end
          rescue RuntimeError => e
            STDERR.puts e.message
            exit(-1)
          end
        end
      end

      def extend_opts(opts)
        # extension point - does nothing by default
      end

    end

  end

end
