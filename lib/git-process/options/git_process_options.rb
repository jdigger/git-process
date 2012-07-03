require 'optparse'
require 'git-process/version'

module GitProc

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
        banner = "Usage: #{filename} [ options ]"
        opts.banner = banner

        opts.on("-q", "--quiet", "Quiet") do
          @quiet = true
        end

        opts.on("-v", "--verbose", "Verbose") do
          @verbose = true
          @quiet = false
        end

        opts.on("-h", "--help", "Show this message") do
          puts opts
          exit(-1)
        end

        opts.on(nil, "--version", "Print the version") do
          puts "#{filename} version #{GitProc::Version::STRING}"
          exit(0)
        end

        extend_opts(opts)

        begin
          begin
            opts.parse!(argv)

            extend_args(argv)
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


    def extend_args(argv)
      # extension point - does nothing by default
    end

  end

end
