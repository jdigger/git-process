[![Build Status](https://secure.travis-ci.org/jdigger/git-process.png)](http://travis-ci.org/jdigger/git-process)

# Purpose #

This provides an easy way to work with a sane git workflow process.


# Installation #

    $ gem install git-process

# Overview #

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
    * This will merge and push your changes into "`origin/master`"
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

* It's assumed that you **_never_** do any work directly on "master": everything is done on a
  feature branch.  This is a much safer and more flexible practice, but may seem odd to
  people used to old VCSs.
    * After publishing changes to the main integration branch (i.e., "`git to-master`") the
      old feature branch is removed as part of cleanup. Git is then "parked" on a "`_parking_`"
      branch until a new feature branch is created. Work is not expected to be done on this
      branch, but any that is done is brought over to a newly created feature branch (i.e.,
      "`git new-fb`").
* The first time you use a GitHub feature (e.g., "`git pull-request`"), this will ask for your
  username and password. It does not store them, but instead uses them to get an OAuth2 token,
  which is stored in "`git config gitProcess.github.authToken`".

## Misc ##

* http://git-scm.com/2010/03/08/rerere.html
* http://git.kernel.org/?p=git/git.git;a=blob;f=contrib/rerere-train.sh;hb=HEAD
* https://github.com/b4mboo/git-review


# Contributing #

## Coding Setup ##

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

The tests are written for RSpec 2.
