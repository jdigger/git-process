[![Build Status](https://travis-ci.org/jdigger/git-process.png?branch=master)](https://travis-ci.org/jdigger/git-process)

# Purpose #

This provides an easy way to work with a sane git workflow process that encourages using highly-focused branches to encourage collaboration, enable fearless changes, and improve team communication.

See the F.A.Q. for a much more complete explanation for the thoughts and assumptions that motivates this project.


# Installation #

## Unix-based OS (OSX, Linux, etc.) Installation ##

If you are using a Ruby sandboxing system like [RVM](https://rvm.io/) or [rbenv](https://github.com/sstephenson/rbenv)
(either or which I would recommend using) then simply do:

    $ gem install git-process

If you are not using RVM or rbenv, you will likely need to precede that with "`sudo`".

Some older operating systems (such as OSX 10.6) are using an old version of RubyGems, which can cause installation problems. Do "`gem update --system`" to fix.

## Windows Installation ##

1. Install Ruby (if you have not done so already) from http://rubyinstaller.org/
   * If it complains about not being able to compile native code, install [DevKit](http://rubyinstaller.org/downloads).
   * See [this StackOverflow](http://stackoverflow.com/questions/8100891/the-json-native-gem-requires-installed-build-tools/8463500#8463500) for help.
2. Open a command prompt and type `gem install git-process`

## All Operating Systems ##

To get full `git help` and manpage support, do:

    $ alias man="gem man -s"
    $ git config --global man.gem-man.cmd "gem man -s"
    $ git config --global man.viewer gem-man


# Overview #

## Anticipated Use Cases ##

1. User creates new local branch for focused work.
1. User pushes local branch to remote (as feature branch) by merging/rebasing with the integration branch, then pushing to the branch to remote.
1. User closes local branch by rebasing integration branch first, then pushing local to integration.
1. User initiates GitHub "pull request" to ease collaboration.

## Command List ##

* `git new-fb` - Create a new feature branch based on the integration branch.
* `git sync` - Gets the latest changes that have happened on the integration branch and remote feature branch, then pushes your changes to a feature branch on the server.
* `git pull-request` - Creates a Pull Request for the current branch.
* `git to-master` - Rebase against the integration branch, then pushes to it. Knows how to deal "intelligently" with pull-requests.

**All commands are well documented within themselves: Use the "-h" switch to see the full documentation.** (e.g., "`git sync -h`")


# Workflow #

_The following assumes that the integration branch is "origin/master"._

## Code Review Using Pull Requests ##

1. When starting work on a new feature, use "`git new-fb feature-name`".
    * This creates a new branch called "`feature-name`" based on "`origin/master`".
2. After making some changes, if you want to pick up any changes other people have made, as well
   as save your work on the server, do "`git sync`".
    * That will merge in the changes that have occurred in "`origin/master`" and then push the
      result to the "`feature_branch`" branch to the server.
3. When you feel your work is ready for others to look at, do "`git pull-request`" to ask someone to review your changes.
    * If no name or number is provided, it is assumed that you want to create a new pull request with the same name as the current branch.
    * Any changes you make via "`git sync`" are automatically reflected in the pull request.
4. As a reviewer, to see a pull-request, do "`git pull-request ##`" (where "##" is the pull request number) to check
   out the branch associated with the pull request in your repository.
5. If you get the thumbs up from the code-review, use "`git to-master`".
    * This will merge and push your changes into "`origin/master`", closing the pull request.
    * If reviewing the pull request via the web interface was sufficient, or there is otherwise not a reason
      to explicitly checkout the branch first, you can use "`git to-master`" with the pull request number to
      combine both of these steps.
5. If you still need to make changes, do so and use "`git sync`" to keep your branch on the
   server for that feature updated with your work until all issues have been resolved.

```
$ git new-fb my-feature      # 1
# do work                    # 2
$ git commit                 # 3
$ git sync                   # 4
# repeat #2-#4 as necessary  # 5
$ git pull-request           # 6
# repeat #2-#4 as necessary  # 7
$ git to-master              # 8
```

## Working Alone or When Pairing ##

1. When starting work on a new feature, use "`git new-fb feature-name`".
    * This creates a new branch called "`feature-name`" based on "`origin/master`".
2. After making some changes, if you want to pick up any changes other people have made, as well
   as save your work on the server, do "`git sync`".
    * That will rebase the changes that have occurred in "`origin/master`" and then push the
      result to the "`feature_branch`" branch to the server.
3. When you are ready to move your work into the mainline, "`git to-master`".
    * This will rebase and push your changes into "`origin/master`"

```
$ git new-fb my-feature      # 1
# do work                    # 2
$ git commit                 # 3
$ git sync                   # 4
# repeat #2-#4 as necessary  # 5
$ git to-master              # 6
```


## Configurables ##

(See Notes for more details)

* `gitProcess.integrationBranch` : The name of the integration branch. Defaults to `master`, but can be set to `develop` or other.
* `gitProcess.keepLocalIntegrationBranch` : Controls asking about removing the local integration branch. Defaults to 'false' (i.e., do not assume the branch should be there).
* `gitProcess.remoteName` : Explicitly sets the remote server name to use.
* `gitProcess.defaultRebaseSync`: Should `git sync` default to using rebase instead of merge? Defaults to 'true' (i.e., Sync using rebase.)


# Assumptions #

* You should **_never_** do any work directly on "`master`" (or whatever you define the mainline branch as): everything is done on a feature branch.  This is a much safer and more flexible practice than doing everything on the same branch, but may seem odd to people used to old VCSs. In addition to being a much better way of working in general (see the F.A.Q. for more information), it is also a requirement to take advantage of Pull Request functionality.
* When working on a branch, you should be integrating with "`master`" as often as possible.
  * "`git sync`" makes it extremely easy for you to get any changes that are made in "`master`" into your branch so you can react to it immediately.
  * "`git to-master`" then makes it easy to cleanly integrate the changes you have made. If you need to keep the current branch open, use the `--keep` option. Otherwise it closes the branch along with various other house-keeping duties.
* The process that you use should be essentially the same, regardless of whether you are working alone, or on a large distributed team.
  * The exception here is "`git pull-request`" since you typically do not use pull requests when working solo or when pair-programming.


# Notes #

* After publishing changes to the main integration branch (i.e., "`git to-master`") the old feature branch is removed as part of cleanup. Git is then "parked" on a "`_parking_`" branch until a new feature branch is created. Work is not expected to be done on this branch, but any that is done is brought over to a newly created feature branch (i.e., "`git new-fb`").
* If there is a problem (such as a merge conflict), this will try to resolve such errors for you as much as it can do safely. When it can't do so in an automated way, it will try to tell you the process for doing so manually.
* The first time you use a GitHub feature (e.g., "`git pull-request`"), this will ask for your username and password. It does not store them, but instead uses them to get an OAuth2 token, which is stored in "`git config gitProcess.github.authToken`".
* If you want to use a different integration branch other than "`master`", set the "`gitProcess.integrationBranch`" configuration value. (e.g., "`git config gitProcess.integrationBranch my-integ-branch`")
* This tries to respond "intelligently" to the use of 'rerere'.
* By default the first server name reported by `git remote` is used as the server/remote name. Since most projects only have a single remote (i.e., "origin") this works most of the time. But if you have multiple remotes and want to explicitly set it, use the `gitProcess.remoteName` configuration option.
* `git pull-request` shows the URL for the pull request after creating it on the server. Most terminal programs let you click on it to open it in your browser. (e.g., Cmd-Click on OSX.)


# F.A.Q. #

## Q: How is this different from git-flow or GitHub flow? ##

["git-flow"](http://nvie.com/posts/a-successful-git-branching-model/) is designed around having a very strongly defined process around keeping new development, hotfixes, release process changes, etc. all clearly separated. The problem I have with it is that it's too much "process" for not enough gain. (It has a waterfall feel to it, very much against the more modern [Continuous Delivery](http://continuousdelivery.com/) approach.)

["GitHub Flow"](http://scottchacon.com/2011/08/31/github-flow.html) is a lot cleaner, but relies too heavily (IMHO) on web-based tools and on merging instead of rebasing. It is also focussed very tightly on a Continuous Deployment process, which is great for them, but not practical for everyone.


## Q: Wait, I heard "branches are evil." Why should I do something evil? ##

Branches are extremely powerful tools that allow for clean organization/modularization of development.

* Branches make it easy to sandbox changes while they are in a state of flux, while at the same time allowing you to be very fearless about making potentially breaking changes.
    * For example, I commit "green to green": Doing [TDD](http://en.wikipedia.org/wiki/Test-driven_development), I commit every time I have a newly passing test case. So, assuming I'm in a regular development flow, I'm committing my changes every five minutes or so. Tiny commits, but lots of them. What that means is that if I make a "less than wise choice" at some point, it's trivial to rewind to before I'd made the mistake, potentially keep the throw-away code in another branch while I do my cleanup, and generally use the full power of a revision control system to make my life safer and easier. The branch(es) are pretty chaotic, but that's not a problem because before integrating with the mainline, I take a moment to cleanup: Squash related commits together, write clearer commit messages (since now I know what "the answer" is), and generally move from my drafts to a more finished result. (See below on objections related to "lying with rebase.") That may just be me, though, because I'm very paranoid when it comes to computers. I tend to automatically hit Cmd/Ctl-S every time I type a period when I'm writing, or when I close a block when I'm programming. I have a minimum of three copies/backups around the world of all my important documents. And I "`git sync`" frequently to make sure my machine isn't the only place where all my hard work is being stored. Have I mentioned I don't trust computers?

* Branches allow for focused collaboration. Because a branch is about exactly one thing, it means that a team can collaborate around a feature/bug (especially when used in conjunction with a "pull request"), and keep such changes sandboxed until such time that they are ready to bring a larger audience into the mix.
    * Branches encourage being less "shy" about your code. I have heard, on a number of occasions, developers say "I'm not ready to push this to the server yet because \[it's still rough (and embarrassing)]/\[it may break other people]/etc." All of those reasons for "hoarding" code are moot with branches.

Jez Humble, a brilliant Principle at ThoughtWorks Studios, talks a lot about how "branches are evil." Unfortunately, people hear that, know how smart he is, and simply repeat it without really understanding what his objections are. Fortunately, he [posted clarification about what's really meant by that](http://continuousdelivery.com/2011/07/on-dvcs-continuous-integration-and-feature-branches/). He essentially says that the problem is that developers abuse branches by not merging with mainline (i.e., "master") on a regular basis. Not constantly getting changes *from* mainline makes life rough when it comes time to integrate. Not putting your changes *into* mainline means that your changes are not being validated (via [Continuous Integration](http://martinfowler.com/articles/continuousIntegration.html), or -- better -- with [Continuous Delivery](http://continuousdelivery.com/)). Both are, in fact, sins akin to not doing automated testing.

Making it "easier to do things right than wrong" (i.e., using branches and keeping them synced with mainline) was the primary motivation for this project. Every command here is focussed on making it trivial to use branches that stay in sync with mainline and encourage collaboration.


## Q: Why so much emphasis on rebasing? Isn't rebasing a dangerous lie? ##

Like any powerful tool, "`git rebase`" is "dangerous" if used incorrectly, just like "`rm`"/"`del`". You simply need to know when and how to use it safely. And in the world of version control systems, "rebasing" is easily one of the most _**useful**_ tools to come around since the "`commit`" command.

[A famous article](http://paul.stadig.name/2010/12/thou-shalt-not-lie-git-rebase-ammend.html) that people have been parroting in various forms for a while makes the case that rebasing (and its various forms, such as squashing, amending commits, etc.) is a "lie." As with so many things, context is everything.

You almost certainly should *not* rebase things that you have "published." Generally this really means "Don't rebase the 'master' branch!" Fortunately, these scripts make it impossible to rebase the mainline by accident.

Rebasing "your" code is an extremely useful way of communicating clearly. In the "green to green" scenario above about branches, a lot of noise is generated. If someone wants to review my code, or cherry-pick in my changes, it's too much of a mess to effectively do so. Also, as part of the process of squashing, I have the opportunity to write clearer commit message based upon my newly enhanced understanding. The intermediate commits were my "drafts" and I'm now submitting my cleaned up copy.

If you have ever seen an "active" project that uses a process like "git-flow" that encourages a lot of branching and merging, you've seen how hard it can be to follow a particular line of development. Branch lines are flying around everywhere, and half the commits are pretty much pure noise. (e.g., "Merge branch 'master' of ... into master".) It's also hard to follow the order in which commits actually impacted the mainline. In many ways, in practice merges turn into "a truth effectively being a lie" (because it's buried in the noise) versus rebases that are "a lie (changed from it's 'original' form) to tell an effective truth" (clean and very clear about its impact).

One significant advantage of using automation like this is that it lets you have the best of both worlds. For example, "`git sync`" uses "rebase" instead of "merge" in a way to is completely safe for collaboration on the same branch. As long as the other people are also using "`git sync`", it will make sure that changes are automatically incorporated with and brought in line. (See the extensive test suite in "`sync_spec.rb`" if you want to see how this works.)

This project is trying to promote clear communication about reality as it applies to the code, over micro-management over no-longer-relevant history. Thus rational for the judicious use of rebase.


# Contributing #

## Coding Setup ##

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature origin/master`)
3. Commit your changes (`git commit`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

or, if using these scripts:

1. Fork it
2. `git new-fb my-new-feature
3. `git commit`
4. `git sync`
5. `git pull-request`


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
