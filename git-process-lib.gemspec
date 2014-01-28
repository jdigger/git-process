require File.expand_path('../lib/git-process/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors = ["Jim Moore"]
  gem.email = %w(moore.jim@gmail.com)
  gem.description = %q{The libraries for the git-process suite of tools}
  gem.summary = %q{The libraries for the git-process suite of tools}
  gem.homepage = "http://jdigger.github.com/git-process/"
  gem.license = 'ASL2'

  gem.add_dependency "octokit", "~> 1.24" # GitHub API
  gem.add_dependency "json", "~> 1.7.3"
  gem.add_dependency "trollop", "~> 1.16.2" # CLI options parser
  gem.add_dependency "highline", "1.6.13" # user CLI interaction. There is a bug in 1.6.14
  gem.add_dependency "addressable", "~> 2.3" # URI processing
  gem.add_dependency "gem-man", "~> 0.3" # man page support for Gems

  # lock down external dependency
  gem.add_dependency "multipart-post", "~> 1.2.0"

  gem.files = `git ls-files`.split($\).delete_if { |f| f =~ /^\./ }
  gem.test_files = gem.files.grep(%r{^(test|spec|features)/})
  gem.name = "git-process-lib"
  gem.require_paths = %w(lib)
  gem.version = GitProc::Version::STRING
  gem.platform = Gem::Platform::RUBY
  gem.required_ruby_version = '>= 1.8.7'
end
