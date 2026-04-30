#!/usr/bin/env bats
#
# End-to-end tests for git-sync against synthetic upstream + fork bare
# repos built by make_contributor_fixture in tests/lib.bash. No gh auth
# or network access required.

setup() {
  # shellcheck disable=SC1091
  source "$BATS_TEST_DIRNAME/lib.bash"
  GIT_SYNC="$(agitentic_script git-sync)"
  # BATS_TEST_TMPDIR isn't set before bats 1.6; allocate one explicitly.
  TMP="$(mktemp -d)"
  setup_restricted_paths "$TMP"
  make_contributor_fixture "$TMP"
  cd "$TMP/local"
}

teardown() {
  rm -rf "$TMP"
}

# ---------------------------------------------------------------------------
# Fast-forward sync (the current-main behaviour)
# ---------------------------------------------------------------------------

@test "git-sync fast-forwards local main and pushes to fork" {
  local upstream_head before
  upstream_head="$(git rev-parse upstream/main)"
  before="$(git rev-parse main)"
  [ "$before" != "$upstream_head" ] # fixture put us behind

  run "$GIT_SYNC"
  [ "$status" -eq 0 ]

  [ "$(git rev-parse main)"      = "$upstream_head" ]
  [ "$(git rev-parse fork/main)" = "$upstream_head" ]
}

# ---------------------------------------------------------------------------
# Already-synced / divergent / --force paths
# ---------------------------------------------------------------------------

@test "git-sync is a no-op when local already matches upstream" {
  git merge -q --ff-only upstream/main
  git push -q fork main

  run "$GIT_SYNC"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already at upstream"* ]]
}

@test "git-sync refuses when local has divergent commits without --force" {
  git commit -q --allow-empty -m "divergent"
  local before
  before="$(git rev-parse main)"

  run "$GIT_SYNC"
  [ "$status" -eq 1 ]
  [[ "$output" == *"has commits not in upstream"* ]]
  # Local must not have moved.
  [ "$(git rev-parse main)" = "$before" ]
}

@test "git-sync exits 1 when git is not on PATH" {
  PATH="$AGITENTIC_NO_GIT_NO_GH_PATH" run /bin/bash "$GIT_SYNC"
  [ "$status" -eq 1 ]
  [[ "$output" == *"'git' is required"* ]]
}

@test "git-sync errors when run outside a git repository" {
  cd "$TMP"
  rm -rf non-repo
  mkdir non-repo
  cd non-repo
  run "$GIT_SYNC"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not inside a git repository"* ]]
}

@test "git-sync errors when upstream remote is missing" {
  git remote remove upstream
  run "$GIT_SYNC"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing required remote 'upstream'"* ]]
}

@test "git-sync errors when fork remote is missing" {
  git remote remove fork
  run "$GIT_SYNC"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing required remote 'fork'"* ]]
}

@test "git-sync errors when the working tree is dirty" {
  echo dirty >> file
  run "$GIT_SYNC"
  [ "$status" -eq 1 ]
  [[ "$output" == *"uncommitted changes"* ]]
}

@test "git-sync creates local branch when it does not yet exist" {
  # Move onto a different branch so we can delete main.
  git checkout -q -b holding-pen
  git branch -D main
  local upstream_head
  upstream_head="$(git rev-parse upstream/main)"

  run "$GIT_SYNC"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Creating local main"* ]]
  [ "$(git rev-parse main)" = "$upstream_head" ]
}

@test "git-sync updates main without moving HEAD when on a different branch" {
  git checkout -q -b feature
  local feature_head before_main upstream_head
  feature_head="$(git rev-parse HEAD)"
  before_main="$(git rev-parse main)"
  upstream_head="$(git rev-parse upstream/main)"
  [ "$before_main" != "$upstream_head" ]

  run "$GIT_SYNC"
  [ "$status" -eq 0 ]
  # main advanced to upstream/main.
  [ "$(git rev-parse main)" = "$upstream_head" ]
  # Current branch (feature) was not touched.
  [ "$(git rev-parse HEAD)"    = "$feature_head" ]
  [ "$(git symbolic-ref --short HEAD)" = "feature" ]
}

@test "git-sync --branch <name> syncs a non-default branch" {
  # Seed a 'feature' branch on upstream with one commit beyond upstream/main.
  (
    cd "$TMP/seed"
    git checkout -q -b feature main
    git commit --allow-empty -q -m "feature commit"
    git push -q upstream feature
  )

  run "$GIT_SYNC" --branch feature
  [ "$status" -eq 0 ]
  local upstream_feature_head
  upstream_feature_head="$(git rev-parse upstream/feature)"
  [ "$(git rev-parse feature)"      = "$upstream_feature_head" ]
  [ "$(git rev-parse fork/feature)" = "$upstream_feature_head" ]
  # main (current branch) is untouched.
  [ "$(git symbolic-ref --short HEAD)" = "main" ]
}

@test "git-sync --force discards divergent commits and force-pushes" {
  git commit -q --allow-empty -m "divergent"
  local upstream_head divergent
  upstream_head="$(git rev-parse upstream/main)"
  divergent="$(git rev-parse main)"
  [ "$divergent" != "$upstream_head" ]

  run "$GIT_SYNC" --force
  [ "$status" -eq 0 ]

  [ "$(git rev-parse main)"      = "$upstream_head" ]
  [ "$(git rev-parse fork/main)" = "$upstream_head" ]
}

# ---------------------------------------------------------------------------
# --prune
#
# Asserts:
#   - ff-ancestor branch (strict ancestor of upstream/main)        → pruned
#   - patch-equivalent branch (same change via cherry-pick)         → pruned
#   - novel branch (commit not on upstream at all)                  → kept
#   - current branch (checked out at prune time)                    → kept
#   - main (the synced branch itself)                               → kept
# ---------------------------------------------------------------------------

@test "git-sync --prune deletes merged branches, keeps novel / current / synced" {
  git fetch -q upstream main

  # ff-ancestor: strict ancestor of upstream/main → should be pruned.
  git branch ff-ancestor upstream/main~

  # patch-equivalent: same tree change as upstream/main's tip but from a
  # different parent. `git cherry` treats it as already-merged.
  git checkout -q -b patch-src upstream/main~
  git cherry-pick upstream/main >/dev/null
  git branch -f patch-equivalent
  git checkout -q main
  git branch -D patch-src >/dev/null

  # novel: has a commit not on upstream at all → should be kept.
  git branch novel
  git checkout -q novel
  git commit -q --allow-empty -m "novel commit"
  git checkout -q main

  # current: sit on this during the run → must be kept.
  git branch current-branch upstream/main~
  git checkout -q current-branch

  run "$GIT_SYNC" --prune
  [ "$status" -eq 0 ]
  [[ "$output" == *"deleted ff-ancestor"* ]]
  [[ "$output" == *"deleted patch-equivalent"* ]]
  [[ "$output" != *"deleted novel"* ]]
  [[ "$output" != *"deleted current-branch"* ]]
  [[ "$output" != *"deleted main"* ]]

  # Confirm the refs themselves.
  ! git rev-parse --verify --quiet refs/heads/ff-ancestor      >/dev/null
  ! git rev-parse --verify --quiet refs/heads/patch-equivalent >/dev/null
  git rev-parse --verify --quiet refs/heads/novel            >/dev/null
  git rev-parse --verify --quiet refs/heads/current-branch   >/dev/null
}
