module PullRequestHelper

  def create_pull_request(opts = {})
    v = {
        :head_remote => 'testrepo',
        :head_repo => 'test_repo',
        :base_repo => 'test_repo',
        :head_branch => 'test_branch',
        :base_branch => 'source_branch',
        :api_url => 'https://api.github.com',
        :pr_number => '32',
        :state => 'open',
    }
    v.merge! opts
    v[:ssh_head_url] = "git@github.com:#{opts[:head_repo] || v[:head_repo]}.git" unless opts.has_key?(:ssh_head_url)
    v[:ssh_base_url] = "git@github.com:#{opts[:base_repo] || v[:base_repo]}.git" unless opts.has_key?(:ssh_base_url)
    PullRequestHelper::_basic_pull_request_data(v)
  end


  def self._basic_pull_request_data(opts = {})
    {
        :number => opts[:pr_number],
        :state => opts[:state],
        :head => {
            :remote => opts[:head_repo], # pseudo-property for testing
            :ref => opts[:head_branch],
            :repo => {
                :name => opts[:head_repo],
                :ssh_url => opts[:ssh_head_url],
            }
        },
        :base => {
            :remote => opts[:base_repo], # pseudo-property for testing
            :ref => opts[:base_branch],
            :repo => {
                :name => opts[:base_repo],
                :ssh_url => opts[:ssh_base_url],
            }
        }
    }
  end


  # @abstract the Hash/JSON of the pull request structure to use
  # @return [Hash]
  def pull_request
    raise NotImplementedError
  end


  def api_url(remote_name, glib = gitlib)
    GitHubService::Configuration.new(glib.config, :remote_name => remote_name).base_github_api_url_for_remote
  end


  def stub_get_pull_request(pr)
    stub_get("#{api_url(pr[:head][:remote])}/repos/#{pr[:head][:repo][:name]}/pulls/#{pr[:number]}", :body => pr)
  end


  def stub_fetch(which_remote, glib = gitlib)
    rem = pull_request[which_remote][:remote]
    glib.stub(:fetch).with(rem)
  end


  #
  # Adds a remote to git's configuration based on {#pull_request}
  #
  # @param [:head, :base] which_remote
  #
  def add_remote(which_remote, glib = gitlib)
    glib.remote.add(pull_request[which_remote][:remote], pull_request[which_remote][:repo][:ssh_url])
  end


  # Verifies the branch is checked out from the HEAD branch of the pull
  #   request and created by the same name
  def expect_checkout_pr_head(glib = gitlib)
    pr = pull_request
    glib.should_receive(:checkout).with(pr[:head][:ref], :new_branch => "#{pr[:head][:remote]}/#{pr[:head][:ref]}")
  end


  # Verifies the tracking for the new branch is set to the BASE branch
  #   of the pull request
  def expect_upstream_set(glib = gitlib)
    pr = pull_request
    glib.should_receive(:branch).with(pr[:head][:ref], :upstream => "#{pr[:base][:remote]}/#{pr[:base][:ref]}")
  end

end
