require File.expand_path('../lib/git-process/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors = ['Jim Moore']
  gem.email = %w(moore.jim@gmail.com)
  gem.description = %q{The libraries for the git-process suite of tools}
  gem.summary = %q{The libraries for the git-process suite of tools}
  gem.homepage = 'http://jdigger.github.com/git-process/'
  gem.license = 'Apache-2.0'

  gem.add_dependency 'octokit', '~> 4.3' # GitHub API
  gem.add_dependency 'netrc', '~> 0.11'
  gem.add_dependency 'json', '~> 1.8'
  gem.add_dependency 'trollop', '~> 2.1' # CLI options parser
  gem.add_dependency 'highline', '~> 1.7' # user CLI interaction
  gem.add_dependency 'addressable', '>= 2.3.5', '< 2.4' # URI processing. 2.4 Changes URI parsing
  gem.add_dependency 'gem-man', '~> 0.3' # man page support for Gems

  gem.files = `git ls-files`.split($\).delete_if { |f| f =~ /^\./ }
  gem.test_files = gem.files.grep(%r{^(test|spec|features)/})
  gem.name = 'git-process-lib'
  gem.require_paths = %w(lib)
  gem.version = GitProc::Version::STRING
  gem.platform = Gem::Platform::RUBY
  gem.required_ruby_version = '>= 2.0'
end
