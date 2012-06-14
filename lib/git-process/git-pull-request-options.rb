require 'backports'
require_relative 'git-process-options'

module Git

  class Process

    class PullRequestOptions
      include GitProcessOptions

      attr_reader :user, :password

      def initialize(filename, argv)
        parse(filename, argv)
      end

      def extend_opts(opts)
        opts.on("-u", "--user name", String, "GitHub account username") do |user|
          @user = user
        end

        opts.on("-p", "--password pw", String, "GitHub account password") do |password|
          @password = password
        end
      end
    end

  end

end
