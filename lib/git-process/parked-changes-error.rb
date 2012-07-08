require 'git-process/git-process-error'

module GitProc

  class ParkedChangesError < GitProcessError
    include GitProc::AbstractErrorBuilder

    attr_reader :error_message, :lib

    def initialize(lib)
      @lib = lib
      msg = build_message
      super(msg)
    end


    def human_message
      "You made your changes on the the '_parking_' branch instead of a feature branch.\n"+"Please rename the branch to be a feature branch."
    end


    def build_commands
      ['git branch -m _parking_ my_feature_branch']
    end

  end

end
