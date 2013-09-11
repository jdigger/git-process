require File.expand_path('../lib/git-process/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors = ["Jim Moore"]
  gem.email = %w(moore.jim@gmail.com)
  gem.description = %q{Fetches the latest repository from the server, rebases/merges the current branch against the changes in the integration branch, then pushes the result up to a branch on the server of the same name. (Unless told not to.)}
  gem.summary = %q{Gets the latest changes that have happened on the integration branch, then pushes your changes to a feature branch on the server.}
  gem.homepage = "http://jdigger.github.com/git-process/"
  gem.license = 'ASL2'

  gem.add_dependency "git-process-lib", GitProc::Version::STRING

  gem.files = %w(README.md LICENSE CHANGELOG.md bin/git-new-fb)
  gem.files << 'man/git-new-fb.1'
  gem.executables = ['git-new-fb']
  gem.name = "git-new-fb"
  gem.version = GitProc::Version::STRING
  gem.platform = Gem::Platform::RUBY
  gem.required_ruby_version = '>= 1.8.7'
end
