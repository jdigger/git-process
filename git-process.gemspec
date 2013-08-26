require File.expand_path('../lib/git-process/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors = ["Jim Moore"]
  gem.email = %w(moore.jim@gmail.com)
  gem.description = %q{A set of scripts to make working with git easier and more consistent}
  gem.summary = %q{A set of scripts for a good git process}
  gem.homepage = "http://jdigger.github.com/git-process/"
  gem.license = 'ASL2'

  gem.add_dependency "git-sync", GitProc::Version::STRING
  gem.add_dependency "git-new-fb", GitProc::Version::STRING
  gem.add_dependency "git-to-master", GitProc::Version::STRING
  gem.add_dependency "git-pull-request", GitProc::Version::STRING

  gem.files = %w(README.md LICENSE.txt CHANGELOG.md)
  gem.name = "git-process"
  gem.version = GitProc::Version::STRING
  gem.platform = Gem::Platform::RUBY
  gem.required_ruby_version = '>= 1.8.7'
end
