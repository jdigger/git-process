require 'backports'
require_relative 'git-process-error'
require_relative 'git-abstract-merge-error-builder'

module Git

  class Process

    class MergeError < GitProcessError
      include Git::AbstractMergeErrorBuilder

      attr_reader :error_message, :lib

      def initialize(merge_error_message, lib)
        @lib = lib
        @error_message = merge_error_message

        msg = build_message

        super(msg)
      end


      def continue_command
        'git commit'
      end

    end

  end

end
