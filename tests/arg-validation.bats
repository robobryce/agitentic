#!/usr/bin/env bats
#
# Each skill script rejects specific bad inputs before making any
# network call. We exercise those paths directly — no gh auth or
# network access required.

setup() {
  # shellcheck disable=SC1091
  source "$BATS_TEST_DIRNAME/lib.bash"
  GIT_CREATE="$(agitentic_script git-create)"
  GIT_FORK="$(agitentic_script git-fork)"
  GIT_CLONE="$(agitentic_script git-clone)"
  GIT_SYNC="$(agitentic_script git-sync)"
  # Isolate cwd so any accidental filesystem side-effects land in a
  # throwaway dir, not the repo. BATS_TEST_TMPDIR isn't set before bats
  # 1.6, so allocate one explicitly.
  TMP="$(mktemp -d)"
  cd "$TMP"
}

teardown() {
  rm -rf "$TMP"
}

# ---------------------------------------------------------------------------
# git-create
# ---------------------------------------------------------------------------

@test "git-create --help prints usage and exits 2" {
  run "$GIT_CREATE" --help
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage: git-create"* ]]
}

@test "git-create rejects 'owner/name' as <name>" {
  run "$GIT_CREATE" "owner/name"
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be just the repo name"* ]]
}

@test "git-create rejects too many positional args" {
  run "$GIT_CREATE" a b c d
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage: git-create"* ]]
}

@test "git-create rejects no arguments" {
  run "$GIT_CREATE"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage: git-create"* ]]
}

@test "git-create rejects empty-string <name>" {
  run "$GIT_CREATE" ""
  [ "$status" -eq 2 ]
  [[ "$output" == *"<name> is required"* ]]
}

# ---------------------------------------------------------------------------
# git-fork
# ---------------------------------------------------------------------------

@test "git-fork rejects unparseable slug" {
  run "$GIT_FORK" "not-a-slug"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot parse"* ]]
}

@test "git-fork rejects triple-segment slug" {
  run "$GIT_FORK" "a/b/c"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot parse"* ]]
}

@test "git-fork rejects no arguments" {
  run "$GIT_FORK"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage: git-fork"* ]]
}

# ---------------------------------------------------------------------------
# git-clone
# ---------------------------------------------------------------------------

@test "git-clone rejects unparseable slug" {
  run "$GIT_CLONE" "not-a-slug"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot parse"* ]]
}

@test "git-clone rejects no arguments" {
  run "$GIT_CLONE"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage: git-clone"* ]]
}

# ---------------------------------------------------------------------------
# git-sync
# ---------------------------------------------------------------------------

@test "git-sync rejects unknown argument" {
  run "$GIT_SYNC" --wat
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown argument"* ]]
}

@test "git-sync --branch without value is rejected" {
  run "$GIT_SYNC" --branch
  [ "$status" -eq 2 ]
  [[ "$output" == *"needs an argument"* ]]
}
