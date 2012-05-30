# -*- encoding: utf-8 -*-
require File.expand_path('../lib/git-process/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Jim Moore"]
  gem.email         = ["moore.jim@gmail.com"]
  gem.description   = %q{A set of scripts to make working with git easier and more consistent}
  gem.summary       = %q{A set of scripts for a good git process}
  gem.homepage      = ""

  gem.add_development_dependency "rspec"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "git-process"
  gem.require_paths = ["lib"]
  gem.version       = Git::Process::VERSION
  gem.platform      = Gem::Platform::RUBY
  gem.executables   << 'git-remerge'
  gem.required_ruby_version = '>= 1.8.1'
end
