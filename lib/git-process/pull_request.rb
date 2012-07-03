require 'git-process/git-process'
require 'git-process/github_pull_request'
require 'shellwords'
require 'highline/import'


module GitProc

  class PullRequest < Process
    include GitLib


    def pull_request(repo_name, base, head, title, body, opts = {})
      repo_name ||= repo_name
      base ||= master_branch
      head ||= branches.current
      title ||= ask_for_pull_title
      body ||= ask_for_pull_body
      GitHub::PullRequest.new(self, repo_name, opts).pull_request(base, head, title, body)
    end


    def ask_for_pull_title
      ask("What <%= color('title', [:bold]) %> do you want to give the pull request? ") do |q|
        q.validate = /^\w+.*/
      end
    end


    def ask_for_pull_body
      ask("What <%= color('description', [:bold]) %> do you want to give the pull request? ")
    end

  end

end
