#!/usr/bin/env ruby
require File.expand_path('../lib/git-process/version', __FILE__)

gems = %w(git-process-lib git-sync git-to-master git-new-fb git-pull-request git-process)

%x[rake manpage 2>&1]

for gem in gems.reverse
  %x[gem uninstall #{gem} -x -v #{GitProc::Version::STRING} 2>&1]
end

for gem in gems
  puts %x(a2x -f manpage -D man docs/#{gem}.1.adoc)
  SystemExit.new($?) if $?.exitstatus

  %x[gem build #{gem}.gemspec]
  SystemExit.new($?) if $?.exitstatus
end

puts %x(gem install ./git-process-#{GitProc::Version::STRING}.gem -l -u)
SystemExit.new($?) if $?.exitstatus
