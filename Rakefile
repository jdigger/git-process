#!/usr/bin/env rake
#require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'yard'
require 'yard/rake/yardoc_task'

desc 'Default: run specs.'
task :default => :spec

desc "Run specs"
RSpec::Core::RakeTask.new do |t|
  t.pattern = "./spec/**/*_spec.rb" # don't need this, it's default.
end

desc "Create docs"
YARD::Rake::YardocTask.new

desc 'Update manpage from asciidoc file'
task :manpage do
  system('find docs/ -type f -exec a2x -f manpage -D man/man1 {} \;')
end
