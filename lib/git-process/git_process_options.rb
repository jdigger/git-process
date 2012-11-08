# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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

      if DEBUG
        puts "\n\n#{opts.map { |k, v| "#{k}:#{v}" }.join(', ')}"
        puts "\nargs: #{argv.join(', ')}"
      end

      opts
    end


    def standard_opts(parser)
      parser.opt :info, "Informational messages; show the major things this is doing", :default => true, :short => :none
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


    #noinspection RubyUnusedLocalVariable
    def extend_opts(parser)
      # extension point - does nothing by default
    end


    #noinspection RubyUnusedLocalVariable
    def post_parse(opts, argv)
      # extension point - does nothing by default
    end

  end

end
