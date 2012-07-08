require 'git-process/git-abstract-merge-error-builder'

module GitProc

  class RebaseError < GitProcessError
    include GitProc::AbstractMergeErrorBuilder

    attr_reader :error_message, :lib

    def initialize(rebase_error_message, lib)
      @lib = lib
      @error_message = rebase_error_message

      msg = build_message

      super(msg)
    end


    def continue_command
      'git rebase --continue'
    end

  end

end
