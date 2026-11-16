#!/bin/sh
set -eu

cli=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)/wtmgr
scratch=$(mktemp -d "${TMPDIR:-/tmp}/wtmgr-test.XXXXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME='wtmgr test' GIT_COMMITTER_NAME='wtmgr test'
export GIT_AUTHOR_EMAIL=test@example.invalid GIT_COMMITTER_EMAIL=test@example.invalid

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
reject() { if "$@" >"$scratch/output" 2>&1; then fail "unexpected success: $*"; fi; }

"$cli" help >/dev/null
reject "$cli" invalid
reject "$cli" add
reject "$cli" remove a b
cd "$scratch"
reject "$cli" list
mkdir 'repo with spaces'
cd 'repo with spaces'
git init -q
git -c commit.gpgsign=false commit --allow-empty -qm initial
root=$(pwd -P)
base=$scratch/'repo with spaces-worktrees'
# Canonicalize the temporary path (macOS /var can be a symlink).
base=$(CDPATH= cd -- "$scratch" && pwd -P)/'repo with spaces-worktrees'
[ "$("$cli" path feature/one)" = "$base/feature/one" ] || fail 'wrong path'
"$cli" add feature/one >/dev/null
[ -f "$base/feature/one/.git" ] || fail 'worktree missing'
[ "$(git -C "$base/feature/one" branch --show-current)" = feature/one ] || fail 'wrong branch'
mkdir "$base/feature/one/subdir"
cd "$base/feature/one/subdir"
[ "$("$cli" path second)" = "$base/second" ] || fail 'nested worktree path differs'
"$cli" list >"$scratch/list"
grep -F "$base/feature/one" "$scratch/list" >/dev/null || fail 'list omitted worktree'
cd "$root"
printf dirty >"$base/feature/one/untracked"
reject "$cli" remove feature/one
[ -f "$base/feature/one/untracked" ] || fail 'dirty file lost'
rm "$base/feature/one/untracked"
"$cli" remove feature/one
git show-ref --verify --quiet refs/heads/feature/one || fail 'branch deleted'
"$cli" add feature/one >/dev/null
reject "$cli" add feature/one
reject "$cli" add feature/one HEAD
"$cli" remove feature/one
"$cli" add from-start HEAD >/dev/null
"$cli" remove from-start
reject "$cli" add bad-start does-not-exist
for branch in ../escape /absolute 'a/../../escape' -bad 'a b' '@{-1}'; do
    reject "$cli" add "$branch"
    reject "$cli" path "$branch"
    reject "$cli" remove "$branch"
done
mkdir "$scratch/outside"
ln -s "$scratch/outside" "$base/link"
reject "$cli" add link/escape
[ ! -e "$scratch/outside/escape" ] || fail 'followed symlink'
reject "$cli" remove missing
"$cli" add locked >/dev/null
git worktree lock "$base/locked"
reject "$cli" remove locked
git worktree unlock "$base/locked"
"$cli" remove locked

git clone -q --bare "$root" "$scratch/bare.git"
cd "$scratch/bare.git"
bare_target=$("$cli" path bare-feature)
"$cli" add bare-feature >/dev/null
cd "$bare_target"
[ "$("$cli" path bare-feature)" = "$bare_target" ] || fail 'bare worktree path differs'
cd "$scratch/bare.git"
"$cli" remove bare-feature
printf 'All tests passed.\n'
