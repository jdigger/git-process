require File.expand_path('../git-process-error', __FILE__)
require File.expand_path('../git-abstract-merge-error-builder', __FILE__)

module Git

  class Process

    class RebaseError < GitProcessError
      include Git::AbstractMergeErrorBuilder

      attr_reader :error_message, :lib

      def initialize(rebase_error_message, lib)
        @lib = lib
        @error_message = rebase_error_message

        msg = build_message

        super(msg)
      end

    end

  end

end
