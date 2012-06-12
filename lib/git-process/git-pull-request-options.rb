require 'git-process-options'

module Git

  class Process

    class PullRequestOptions
      include GitProcessOptions

      attr_reader :user, :password, :description, :title, :filename

      def initialize(filename, argv)
        @filename = filename
        parse(filename, argv)
      end

      def extend_opts(opts)
        opts.banner = "Usage: #{filename} [ options ] [pull_request_title]"

        opts.on("-u", "--user name", String, "GitHub account username") do |user|
          @user = user
        end

        opts.on("-p", "--password pw", String, "GitHub account password") do |password|
          @password = password
        end

        opts.on(nil, "--desc description", String, "Description of the changes.") do |desc|
          @description = desc
        end
      end


      def extend_args(argv)
        @title = argv.pop unless argv.empty?
      end

    end

  end

end
