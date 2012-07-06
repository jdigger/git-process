require 'git-process/git-process'
require 'git-process/github_pull_request'
require 'highline/import'


module GitProc

  class PullRequest < Process
    include GitLib


    def initialize(dir, opts)
      super
      @title = opts[:title]
      @base_branch = opts[:base_branch] || master_branch
      @head_branch = opts[:head_branch] || branches.current
      @repo_name = opts[:repo_name] || repo_name()
      @title = opts[:title] || ask_for_pull_title()
      @description = opts[:description] || ask_for_pull_description()
      @user = opts[:user]
      @password = opts[:password]
    end


    def runner
      pr = GitHub::PullRequest.new(self, @repo_name, {:user => @user, :password => @password})
      pr.create(@base_branch, @head_branch, @title, @description)
    end


    private


    def ask_for_pull_title
      ask("What <%= color('title', [:bold]) %> do you want to give the pull request? ") do |q|
        q.validate = /^\w+.*/
      end
    end


    def ask_for_pull_description
      ask("What <%= color('description', [:bold]) %> do you want to give the pull request? ")
    end

  end

end
