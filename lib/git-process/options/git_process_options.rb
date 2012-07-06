require 'optparse'
require 'trollop'
require 'git-process/version'

module GitProc

  module GitProcessOptions

    DEBUG = false

    def parse_cli(filename, argv)
      parser = Trollop::Parser.new
      parser.version "#{filename} #{GitProc::Version::STRING}"

      parser.banner "#{summary}\n\n"
      parser.banner "\nUsage:\n    #{usage(filename)}\n\nWhere [options] are:"

      extend_opts(parser)
      standard_opts(parser)

      parser.banner "\n#{description}"

      opts = Trollop::with_standard_exception_handling parser do
        raise Trollop::HelpNeeded if ARGV.empty? and !empty_argv_ok?
        parser.parse argv
      end

      opts[:info] = false if opts[:verbose] || opts[:quiet]
      opts[:info] = true if opts[:info_given]

      post_parse(opts, argv)

      if (DEBUG)
        puts "\n\n#{opts.map{|k,v| "#{k}:#{v}"}.join(', ')}"
        puts "\nargs: #{argv.join(', ')}"
      end

      opts
    end


    def standard_opts(parser)
      parser.opt :info, "Informational messages; show the major things this is doing", :short => :i, :default => true
      parser.opt :quiet, "Quiet messages; only show errors", :short => :q
      parser.opt :verbose, "Verbose messages; show lots of details on what this is doing", :short => :v
      parser.opt :version, "Print version (#{GitProc::Version::STRING}) and exit", :short => :none
      parser.opt :help, "Show this message", :short => :h

      parser.conflicts :verbose, :info, :quiet
    end


    def summary
      "Default summary"
    end


    def usage(filename)
      "#{filename} [options]"
    end


    def description
      "Default description"
    end


    def empty_argv_ok?
      true
    end


    def extend_opts(parser)
      # extension point - does nothing by default
    end


    # def extend_args(argv)
    #   # extension point - does nothing by default
    # end


    def post_parse(opts, argv)
      # extension point - does nothing by default
    end

  end

end
