[![Build Status](https://secure.travis-ci.org/jdigger/git-process.png)](http://travis-ci.org/jdigger/git-process)

# Purpose and Motivation #

This provides an easy way to work with a sane git workflow process.
Short-lived feature branches can work quite well, but the formal git-flow process can be rather heavy in cost.

# Installation #

    $ sudo gem install git-process

## Configurables ##
See notes for more details

* OAuth2 Token 
* The name of the integration branch (defaults to `origin/master`, but can be set to `develop` or other)

---
# Overview #

## Anticipated Use Cases ##

1. User Creates new local branch
1. User pushes local branch to remote (as feature branch) by rebasing integration branch, then pushing branch to remote
1. User closes local branch by rebasing integration branch first, then pushing local to integration
1. User initiates GitHub "pull request"

## Command List ##

* `git new-fb` - Create a new feature branch based on the integration branch.
* `git sync` - Gets the latest changes that have happened on the integration branch, then pushes your changes to a "private" branch on the server.
* `git pull-request` - Creates a Pull Request for the current branch.
* `git to-master` - Rebase against the integration branch, then pushes to it.

# Workflow #

_The following assumes that the integration branch is "origin/master"._

## Code Review Using Pull Requests ##

1. When starting work on a new feature, use "`git new-fb feature-name`".
    * This creates a new branch called "`feature-name`" based on "`origin/master`".
2. After making some changes, if you want to pick up any changes other people have made, as well
   as save your work on the server, do "`git synch`".
    * That will merge in the changes that have occurred in "`origin/master`" and then push the
      result to the "`feature_branch`" branch to the server.
3. When you feel your work is ready for others to look at, do another "`git sync`" to post your
   changes to the server, and then "`git pull-request`" to ask someone to review your changes.
4. If you get the thumbs up from the code-review, use "`git to-master`".
    * This will merge and push your changes into "`origin/master`", closing the pull request.
5. If you still need to make changes, do so and use "`git sync`" to keep your branch on the
   server for that feature updated with your work until all issues have been resolved.

## Working Alone or When Pairing ##

1. When starting work on a new feature, use "`git new-fb feature-name`".
    * This creates a new branch called "`feature-name`" based on "`origin/master`".
2. After making some changes, if you want to pick up any changes other people have made, as well
   as save your work on the server, do "`git synch`".
    * That will merge in the changes that have occurred in "`origin/master`" and then push the
      result to the "`feature_branch`" branch to the server.
3. When you are ready to merge your work into the mainline, "`git to-master`".
    * This will merge and push your changes into "`origin/master`"


# Notes #

* It's assumed that you **_never_** do any work directly on "`master`": everything is done on a
  feature branch.  This is a much safer and more flexible practice, but may seem odd to
  people used to old VCSs. In addition to being a much better way of working in general,
  it is also a requirement to take advantage of Pull Request functionality.
    * After publishing changes to the main integration branch (i.e., "`git to-master`") the
      old feature branch is removed as part of cleanup. Git is then "parked" on a "`_parking_`"
      branch until a new feature branch is created. Work is not expected to be done on this
      branch, but any that is done is brought over to a newly created feature branch (i.e.,
      "`git new-fb`").
* If there is a problem (such as a merge conflict), this will try to resolve such errors
  for you as much as it can do safely. When it can't do so in an automated way, it will try
  to tell you the process for doing so manually.
* The first time you use a GitHub feature (e.g., "`git pull-request`"), this will ask for your
  username and password. It does not store them, but instead uses them to get an OAuth2 token,
  which is stored in "`git config gitProcess.github.authToken`".
* If you want to use a different integration branch other than "`master`", set the
  "`gitProcess.integrationBranch`" configuration value. (e.g.,
  "`git config gitProcess.integrationBranch my-integ-branch`")
* This tries to respond "intelligently" to the use of 'rerere'.


# Contributing #

## Coding Setup ##

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

The tests are written for RSpec 2.

## License ##

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

[http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0 "License Link")

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
