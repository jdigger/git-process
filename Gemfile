source 'http://rubygems.org'

group :default do
  gem 'octokit', '~> 1.24' # GitHub API
  gem 'json', '~> 1.8'
  gem 'trollop', '~> 1.16' # CLI options parser
  gem 'highline', '1.6.13' # user CLI interaction. There is a bug in 1.6.14
  gem 'addressable', '~> 2.3' # URI processing

  # lock down external dependency
  gem 'faraday', '0.8.9'
end

group :development do
  gem 'rake', '~> 0.9'
  gem 'yard', '~> 0.8' # documentation generator
  gem 'redcarpet', '~> 2'
end

group :test do
  gem 'rspec', '~> 2.99'
  gem 'webmock', '~> 1' # network mocking
  gem 'rugged', '~> 0.18.0.gh.de28323'
end
