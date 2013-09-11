#!/usr/bin/env rake
#require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'yard'
require 'yard/rake/yardoc_task'
require 'fileutils'
require File.expand_path('../lib/git-process/version', __FILE__)

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
  FileUtils::rm_r('man') if File.directory?('man')
  FileUtils::mkdir('man')
  %x[find docs/ -type f -exec a2x -a version=#{GitProc::Version::STRING} -f manpage -D man {} \\;]
end

desc 'Update htmldoc from asciidoc file'
task :htmldoc do
  FileUtils::rm_r('htmldoc') if File.directory?('htmldoc')
  FileUtils::mkdir('htmldoc')
  system('find docs/ -type f -exec a2x -f xhtml -D htmldoc {} \;')
end
