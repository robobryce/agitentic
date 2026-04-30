#!/usr/bin/env bash
# Shared helpers for the agitentic bats suite. Each .bats test file sources
# this from its setup() function and calls make_contributor_fixture to
# build a synthetic upstream/fork pair under $BATS_TEST_TMPDIR.
#
# No network or gh auth is required — every remote is a local bare repo.

set -euo pipefail

# Resolved by each caller's setup(). Exposed so tests can build the
# absolute path to any skill script without duplicating that logic.
agitentic_repo_root() {
  cd "$BATS_TEST_DIRNAME/.." && pwd
}

agitentic_script() {
  local skill="$1"
  echo "$(agitentic_repo_root)/plugins/agitentic/skills/$skill/scripts/$skill"
}

# Set up an isolated environment where `gh` is a stub and GitHub HTTPS
# URLs resolve to bare repos under <root>/bare/. After this call the
# caller's shell has:
#
#   $PATH              prefixed with <root>/bin (contains `gh` stub)
#   $AGITENTIC_NO_GIT_NO_GH_PATH   PATH with coreutils only (no git, no
#                      gh) — for testing the `command -v git` guard.
#   $AGITENTIC_NO_GH_PATH          PATH with coreutils + git, no gh —
#                      for testing the `command -v gh` guard.
#   $HOME              set to <root> (isolates git config)
#   $BARE_ROOT         <root>/bare — where repo slugs materialise
#   $STUB_GH_LOG       <root>/gh.log — every stub invocation logged here
#   $STUB_GH_USER      "testuser" (overridable before/after this call)
#   $STUB_GH_BARE_ROOT same as $BARE_ROOT
#
# Also installs a global git `url.<BARE_ROOT>/.insteadOf https://github.com/`
# rewrite so any `git clone/push` against an https://github.com/ URL
# transparently hits the local bare root.
setup_gh_stub() {
  local root="$1"
  mkdir -p "$root/bin" "$root/bare"

  # PATH stub. Symlink so shellcheck on the real stub covers it.
  ln -sf "$(agitentic_repo_root)/tests/stubs/gh" "$root/bin/gh"

  setup_restricted_paths "$root"

  export PATH="$root/bin:$PATH"
  export HOME="$root"
  export BARE_ROOT="$root/bare"
  export STUB_GH_BARE_ROOT="$BARE_ROOT"
  export STUB_GH_LOG="$root/gh.log"
  : > "$STUB_GH_LOG"
  export STUB_GH_USER="${STUB_GH_USER:-testuser}"

  git config --global "url.$BARE_ROOT/.insteadOf" "https://github.com/"
  git config --global user.email "test@example.com"
  git config --global user.name  "Test"
  # Suppress the "hint: Using 'master' as the name of the initial branch"
  # noise that shows up on hosts where init.defaultBranch isn't set.
  git config --global init.defaultBranch main
}

# Build two minimal-PATH sandbox directories under <root> and export
# their paths:
#   $AGITENTIC_NO_GIT_NO_GH_PATH   coreutils only — neither git nor gh.
#   $AGITENTIC_NO_GH_PATH          coreutils + git — no gh.
# Host gh/git may well live under /usr/bin alongside the coreutils, so
# we can't just strip entries from PATH. Build sandboxes from scratch
# and symlink in only what we want.
setup_restricted_paths() {
  local root="$1"
  mkdir -p "$root/bin-no-git-no-gh" "$root/bin-no-gh"
  local cmd tool
  for cmd in dirname basename realpath env cat mktemp find sort rm grep sed; do
    if tool="$(command -v "$cmd")"; then
      ln -sf "$tool" "$root/bin-no-git-no-gh/$cmd"
      ln -sf "$tool" "$root/bin-no-gh/$cmd"
    fi
  done
  ln -sf "$(command -v git)" "$root/bin-no-gh/git"
  export AGITENTIC_NO_GIT_NO_GH_PATH="$root/bin-no-git-no-gh"
  export AGITENTIC_NO_GH_PATH="$root/bin-no-gh"
}

# Seed a bare repo at $BARE_ROOT/<slug>.git with a single commit on main.
# Callers use this to pre-populate an upstream (or pre-existing fork) that
# the script under test will fetch/clone from.
seed_bare_repo() {
  local slug="$1"
  local bare="$BARE_ROOT/$slug.git"
  mkdir -p "$bare"
  git init -q --bare "$bare"
  git -C "$bare" symbolic-ref HEAD refs/heads/main
  local work
  work="$(mktemp -d)"
  (
    cd "$work"
    git init -q -b main
    git config user.email seed@example.com
    git config user.name "Seed"
    echo "$slug" > README
    git add README
    git commit -q -m "seed $slug"
    git push -q "$bare" main
  )
  rm -rf "$work"
}

# Build an upstream bare repo + a clone with `upstream` and `fork` remotes
# under <root>. Leaves two directories behind:
#   <root>/upstream.git  bare repo, three commits on main
#   <root>/fork.git      bare repo, initially at the first commit
#   <root>/local         git clone of upstream, with `fork` added as a
#                        second remote, and local main reset one commit
#                        behind upstream/main so a fast-forward is
#                        actually needed.
make_contributor_fixture() {
  local root="$1"
  mkdir -p "$root"
  (
    cd "$root"
    git init -q --bare upstream.git
    git init -q --bare fork.git
    git -C upstream.git symbolic-ref HEAD refs/heads/main
    git -C fork.git     symbolic-ref HEAD refs/heads/main

    git init -q -b main seed
    cd seed
    git config user.email test@example.com
    git config user.name "Test"
    echo one > file
    git add file
    git commit -q -m "one"
    git remote add upstream "$root/upstream.git"
    git remote add fork "$root/fork.git"
    git push -q upstream main
    git push -q fork main

    echo two > file
    git commit -qam "two"
    git push -q upstream main

    echo three > file
    git commit -qam "three"
    git push -q upstream main
    cd ..

    git clone -q -o upstream "$root/upstream.git" local
    cd local
    git config user.email test@example.com
    git config user.name "Test"
    git remote add fork "$root/fork.git"
    git fetch -q fork
    # Put local main one commit behind upstream/main so the test exercises
    # a real fast-forward.
    git reset -q --hard HEAD~
  )
}
