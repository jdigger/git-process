require 'git-process/options/git_process_options'

module GitProc

  class ToMasterOptions
    include GitProcessOptions

    def initialize(filename, argv)
      parse(filename, argv)
    end
  end

end
