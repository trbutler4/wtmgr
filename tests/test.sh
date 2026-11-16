#!/bin/sh
set -eu

cli=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)/wtmgr
scratch=$(mktemp -d "${TMPDIR:-/tmp}/wtmgr-test.XXXXXXXX")
# Exercise deployment as a standalone copied executable, not from its source tree.
cp "$cli" "$scratch/wtmgr"
cli=$scratch/wtmgr
run_cli() {
    if [ -n "${WTMGR_TEST_SHELL:-}" ]; then
        "$WTMGR_TEST_SHELL" "$cli" "$@"
    else
        "$cli" "$@"
    fi
}
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME='wtmgr test' GIT_COMMITTER_NAME='wtmgr test'
export GIT_AUTHOR_EMAIL=test@example.invalid GIT_COMMITTER_EMAIL=test@example.invalid

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
reject() { if "$@" >"$scratch/output" 2>&1; then fail "unexpected success: $*"; fi; }

run_cli help >/dev/null
reject run_cli invalid
reject run_cli add
reject run_cli remove a b
reject run_cli remove --force
reject run_cli remove --force --force
reject run_cli remove --force a b
reject run_cli list --bogus
reject run_cli pick a b
cd "$scratch"
reject run_cli list
mkdir 'repo with spaces'
cd 'repo with spaces'
git init -q
git -c commit.gpgsign=false commit --allow-empty -qm initial
root=$(pwd -P)
base=$scratch/'repo with spaces-worktrees'
# Canonicalize the temporary path (macOS /var can be a symlink).
base=$(CDPATH= cd -- "$scratch" && pwd -P)/'repo with spaces-worktrees'
[ "$(run_cli path feature/one)" = "$base/feature/one" ] || fail 'wrong path'
run_cli add feature/one >/dev/null
[ -f "$base/feature/one/.git" ] || fail 'worktree missing'
[ "$(git -C "$base/feature/one" branch --show-current)" = feature/one ] || fail 'wrong branch'
mkdir "$base/feature/one/subdir"
cd "$base/feature/one/subdir"
[ "$(run_cli path second)" = "$base/second" ] || fail 'nested worktree path differs'
run_cli list >"$scratch/list"
grep -F "$base/feature/one" "$scratch/list" >/dev/null || fail 'list omitted worktree'
run_cli list --paths >"$scratch/paths"
grep -Fx "$base/feature/one" "$scratch/paths" >/dev/null || fail 'paths listing corrupted spaces'
if command -v fzf >/dev/null 2>&1; then
    selected=$(FZF_DEFAULT_OPTS='--filter=feature/one' run_cli pick)
    [ "$selected" = "$base/feature/one" ] || fail 'fzf did not return exact path'
    FZF_DEFAULT_OPTS='--filter=NO_SUCH_WORKTREE_12345' reject run_cli pick
else
    printf 'Skipping optional fzf tests: fzf not installed.\n'
fi
cd "$root"
printf dirty >"$base/feature/one/untracked"
reject run_cli remove feature/one
[ -f "$base/feature/one/untracked" ] || fail 'dirty file lost'
rm "$base/feature/one/untracked"
run_cli remove feature/one
git show-ref --verify --quiet refs/heads/feature/one || fail 'branch deleted'
run_cli add feature/one >/dev/null
reject run_cli add feature/one
reject run_cli add feature/one HEAD
run_cli remove feature/one
run_cli add from-start HEAD >/dev/null
run_cli remove from-start
reject run_cli add bad-start does-not-exist
for branch in ../escape /absolute 'a/../../escape' -bad 'a b' '@{-1}'; do
    reject run_cli add "$branch"
    reject run_cli path "$branch"
    reject run_cli remove "$branch"
done
mkdir "$scratch/outside"
ln -s "$scratch/outside" "$base/link"
reject run_cli add link/escape
[ ! -e "$scratch/outside/escape" ] || fail 'followed symlink'
reject run_cli remove missing
run_cli add locked >/dev/null
git worktree lock "$base/locked"
reject run_cli remove locked
reject run_cli remove --force locked
git worktree unlock "$base/locked"
run_cli remove locked

for branch in force-before force-after; do
    run_cli add "$branch" >/dev/null
    printf tracked >"$base/$branch/tracked"
    git -C "$base/$branch" add tracked
    git -C "$base/$branch" -c commit.gpgsign=false commit -qm tracked
    printf modified >"$base/$branch/tracked"
    printf untracked >"$base/$branch/untracked"
    reject run_cli remove "$branch"
    if [ "$branch" = force-before ]; then
        run_cli remove --force "$branch"
    else
        run_cli remove "$branch" --force
    fi
    [ ! -e "$base/$branch" ] || fail 'force did not remove dirty checkout'
    git show-ref --verify --quiet "refs/heads/$branch" || fail 'force deleted branch'
done

git worktree add -qb external-label "$scratch/external checkout" HEAD
run_cli list --paths >"$scratch/paths"
grep -Fx "$(CDPATH= cd -- "$scratch/external checkout" && pwd -P)" "$scratch/paths" >/dev/null || fail 'external checkout missing'
if command -v fzf >/dev/null 2>&1; then
    selected=$(FZF_DEFAULT_OPTS='--filter=external-label' run_cli pick)
    [ "$selected" = "$(CDPATH= cd -- "$scratch/external checkout" && pwd -P)" ] || fail 'branch search missed external path'
fi
git worktree remove "$scratch/external checkout"
git worktree add -q --detach "$scratch/detached checkout" HEAD
if command -v fzf >/dev/null 2>&1; then
    selected=$(FZF_DEFAULT_OPTS='--filter=detached' run_cli pick)
    [ "$selected" = "$(CDPATH= cd -- "$scratch/detached checkout" && pwd -P)" ] || fail 'detached checkout missing'
fi
git worktree remove "$scratch/detached checkout"
git worktree add -q --detach "$scratch/quoted\"checkout" HEAD
run_cli list --paths >"$scratch/paths"
grep -Fx "$(CDPATH= cd -- "$scratch/quoted\"checkout" && pwd -P)" "$scratch/paths" >/dev/null || fail 'quoted path corrupted'
git worktree remove "$scratch/quoted\"checkout"
newline_path="$scratch/newline
checkout"
git worktree add -q --detach "$newline_path" HEAD
reject run_cli list --paths
reject run_cli pick
git worktree remove "$newline_path"

git clone -q --bare "$root" "$scratch/bare.git"
cd "$scratch/bare.git"
bare_target=$(run_cli path bare-feature)
run_cli add bare-feature >/dev/null
cd "$bare_target"
[ "$(run_cli path bare-feature)" = "$bare_target" ] || fail 'bare worktree path differs'
cd "$scratch/bare.git"
run_cli remove bare-feature
reject run_cli list --paths
printf 'All tests passed.\n'
