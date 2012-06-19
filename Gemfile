source "http://rubygems.org"

gem "rake", "~> 0.9.2", :group => :development
gem "git", "~> 1.2.5"
#gem "rugged"  # "git" bindings for libgit2
gem "launchy", "~> 2.1.0" # web browser interaction
gem "octokit", "~> 1.4.0" # GitHub API
gem "json", "~> 1.7.3"
gem "highline", "~> 1.6.12" # user CLI interaction
gem "termios", "~> 0.9.4"  # used by highline to make things a little nicer
gem "system_timer", "~> 1.2.4" # Needed by faraday via octokit

group :test do
  gem "rspec", "~> 2.10.0", :group => :test
  gem "rspec-mocks", "~> 2.10.0", :group => :test
  gem "webmock", "~> 1.8.7", :group => :test # network mocking
end
