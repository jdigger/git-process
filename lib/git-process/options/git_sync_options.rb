require 'git-process/options/git_process_options'

module GitProc

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
