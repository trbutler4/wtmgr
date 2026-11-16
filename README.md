# wtmgr

A tiny Git worktree manager. One POSIX shell script, Git, nothing else.
No runtime, package manager, config file, background service, or shell integration.

## Install

Copy `wtmgr` anywhere on your `PATH`, or run `./wtmgr` directly.

```sh
mkdir -p "$HOME/.local/bin"
cp wtmgr "$HOME/.local/bin/wtmgr"
```

Requires a POSIX shell and Git with `git worktree remove` support.
Designed for macOS, Linux, BSD, and Git Bash on Windows. Tests run locally on macOS.

## Use

From inside a Git repository:

```sh
wtmgr add feature/login       # existing branch, or new branch from HEAD
wtmgr add fix/bug main        # new branch starting at main
wtmgr list
cd "$(wtmgr path feature/login)"
# work, commit, then leave the worktree before removing it
cd "$(wtmgr path fix/bug)"
wtmgr remove feature/login
```

For a repository at `/projects/app`, managed worktrees go in
`/projects/app-worktrees/<branch>`. Branches containing `/` use nested directories.
The location stays the same when invoked from a linked worktree or subdirectory.
Bare repositories are supported too. With a separately stored Git directory,
the layout is derived from that directory's parent, not the checkout location.

`path` prints the expected location, even before a worktree exists.
`list` includes all Git worktrees. `remove` only targets the managed location,
refuses dirty or locked worktrees, and never deletes branches.
Existing branches cannot be checked out in multiple worktrees: Git's normal
safety checks apply. No force flag, automatic pruning, or automatic branch deletion.

To move or manage worktrees created elsewhere, use `git worktree` directly.

## Test

```sh
sh tests/test.sh
WTMGR_TEST_SHELL=/bin/dash /bin/dash tests/test.sh
WTMGR_TEST_SHELL=/bin/bash /bin/bash tests/test.sh
```

Each run copies only `wtmgr` into a temporary directory before exercising real Git
repositories. All three runs passed on macOS, including nested branch paths,
paths with spaces, bare repositories, and dirty/locked removal protection.
Other operating systems have not been tested.
Tests use disposable local repositories and do not modify your Git configuration.
