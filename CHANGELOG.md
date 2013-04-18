# CHANGELOG - 1.0.9 #

### Since 1.0.8 ###

* Changed to use HTTPS instead of HTTP by default for GitHub API usage.

### Since 1.0.7 ###

* Fixed bug in git_status. [GH-93](https://github.com/jdigger/git-process/issues/93)

### Since 1.0.6 ###

* Fixed bug caused by CLI conflict on -i. [GH-13](https://github.com/jdigger/git-process/issues/13)

### Since 1.0.5 ###

* Adds option to make rebase the default for git-sync. [GH-82](https://github.com/jdigger/git-process/issues/82)
* git-sync is now "safer" when working with other people on the same branch. [GH-80](https://github.com/jdigger/git-process/issues/80)
* Interactive rebase is now an option for git-to-master. [GH-13](https://github.com/jdigger/git-process/issues/13)
* Simplified/improved arguments for git-pull-request [GH-86](https://github.com/jdigger/git-process/issues/86)
* Adds some more known statuses. [GH-84](https://github.com/jdigger/git-process/issues/84), [GH-88](https://github.com/jdigger/git-process/issues/88)

### Since 1.0.4 ###

* Do not try to fetch/push when doing sync if there is not remote. (#70)
* git-sync now merges in upstream changes. (#79)
* Simplified Windows installation instructions. (#76 #77)

### Since 1.0.3 ###

* Gets rid of infinite loop in Highline library. (GH-72)

### Since 1.0.2 ###

* Removes the last of the gem dependencies that require native code. This makes it fully compatible
  with systems like Windows.
* Adds an option to explicitly set the remote server name.

### Since 1.0.1 ###

* Changes to dependencies to allow this to work on both Ruby 1.8 and 1.9

### Since 0.9.7 ###

* Adds --keep option to git-to-master
* Fixes problem trying to add/remove an empty list of files
* Documentation updates

### Since 0.9.7 ###

* Adds --keep option to git-to-master
* Fixes problem trying to add/remove an empty list of files
* Documentation updates

### Since 0.9.6 ###

* Cleans up Gem dependencies

### Since 0.9.5 ###

* Cleans up some error messages
* Improved documentation
* Adds support for spaces and renames in Status
* No longer complains if it can't find _parking_
* Prompts to remove the local version of the integration branch
* Adds help for handling changed files
