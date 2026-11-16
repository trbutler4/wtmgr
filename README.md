# wtmgr

A tiny Git worktree manager. One POSIX shell script, Git, nothing else.
No runtime, package manager, config file, background service, or shell integration.

## Install

Copy `wtmgr` anywhere on your `PATH`, or run `./wtmgr` directly.

```sh
mkdir -p "$HOME/.local/bin"
cp wtmgr "$HOME/.local/bin/wtmgr"
```

Requires a POSIX shell, standard utilities, and Git with `git worktree remove`
support. The optional picker and path listing also require `git worktree list -z`.
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
refuses dirty or locked worktrees by default, and never deletes branches.
Existing branches cannot be checked out in multiple worktrees: Git's normal
safety checks apply. No automatic pruning or automatic branch deletion.

To intentionally discard uncommitted changes and untracked files:

```sh
wtmgr remove --force feature/login
# Also accepted: wtmgr remove feature/login --force
```

**Warning:** `--force` permanently discards uncommitted work in that checkout.
It passes one `--force` to Git. Locked worktrees remain protected, and the
branch is kept. Repeated `--force` flags are not accepted.

To move or manage worktrees created elsewhere, use `git worktree` directly.

## Fuzzy search

Install `fzf` for the optional picker. All other commands still need only Git.

```sh
wtmgr pick                  # search by branch or path, print selected path
wtmgr pick login            # start with a query
wtmgr list --paths | fzf     # plain paths for your own pipelines
```

The picker includes the main checkout, unmanaged worktrees, and detached
checkouts in the current repository. Bare and prunable entries are excluded.
Spaces, Unicode, quotes, and backslashes in paths are supported. Paths containing
tabs, newlines, or SOH/STX control characters are explicitly rejected by `pick`
and `list --paths` rather than split incorrectly. Plain `list` still works.

For Bash or Zsh, add this optional function to your shell config:

```sh
wtc() {
    local target
    target="$(wtmgr pick "$@")" || return $?
    [ -n "$target" ] || return 0
    builtin cd -- "$target"
}
```

Then use `wtc` or `wtc login` to search and change directories. Escape or no
match leaves your directory unchanged. Avoid unguarded `cd "$(wtmgr pick)"`,
which would try to change to an empty path after cancellation.

## Test

```sh
sh tests/test.sh
WTMGR_TEST_SHELL=/bin/dash /bin/dash tests/test.sh
WTMGR_TEST_SHELL=/bin/bash /bin/bash tests/test.sh
```

Each run copies only `wtmgr` into a temporary directory before exercising real Git
repositories. All three runs passed on macOS, including nested branch paths,
paths with spaces, bare repositories, and dirty/locked removal protection.
When `fzf` is installed, the suite also exercises real fuzzy selection in filter
mode, exact path output, branch search for external worktrees, and no-match failure.
Other operating systems have not been tested.
Tests use disposable local repositories and do not modify your Git configuration.
