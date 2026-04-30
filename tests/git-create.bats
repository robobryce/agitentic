#!/usr/bin/env bats
#
# End-to-end tests for git-create. A stub `gh` (tests/stubs/gh) services
# `gh api user`, `gh repo create`, and `gh repo edit` against a local
# bare-repo root, and a global insteadOf rewrite makes
# https://github.com/... URLs resolve to that same root. The script
# therefore runs its real code path — init, commit, push, remote-add —
# with no network or authentication.

setup() {
  # shellcheck disable=SC1091
  source "$BATS_TEST_DIRNAME/lib.bash"
  GIT_CREATE="$(agitentic_script git-create)"

  TMP="$(mktemp -d)"
  setup_gh_stub "$TMP"

  WORK="$TMP/work"
  mkdir -p "$WORK"
  cd "$WORK"
}

teardown() {
  rm -rf "$TMP"
}

# Grep helper: count occurrences of a line matching <pattern> in the
# gh stub log. Used to assert the script called gh with the expected args.
gh_log_matches() {
  grep -E -c "$1" "$STUB_GH_LOG" || true
}

@test "git-create creates repo under default account, pushes initial commit" {
  run "$GIT_CREATE" myrepo
  [ "$status" -eq 0 ]

  # Bare repo materialised under the fake account.
  [ -d "$BARE_ROOT/testuser/myrepo.git" ]
  # And it received the initial commit pushed from the local clone.
  [ -n "$(git -C "$BARE_ROOT/testuser/myrepo.git" rev-parse --verify refs/heads/main 2>/dev/null)" ]

  # Local directory looks right.
  [ -d "$WORK/myrepo/.git" ]
  [ "$(git -C "$WORK/myrepo" config --get remote.origin.url)" = "https://github.com/testuser/myrepo.git" ]
  [ "$(git -C "$WORK/myrepo" symbolic-ref --short HEAD)" = "main" ]

  # gh was called with the expected subcommands.
  [ "$(gh_log_matches '^gh api user --jq \.login$')" -ge 1 ]
  [ "$(gh_log_matches '^gh repo create testuser/myrepo --public$')" -eq 1 ]
  [ "$(gh_log_matches '^gh repo edit testuser/myrepo ')" -eq 1 ]
}

@test "git-create honours [account] and [directory] arguments" {
  run "$GIT_CREATE" myrepo myorg some-dir
  [ "$status" -eq 0 ]

  [ -d "$BARE_ROOT/myorg/myrepo.git" ]
  [ -d "$WORK/some-dir/.git" ]
  [ "$(git -C "$WORK/some-dir" config --get remote.origin.url)" = "https://github.com/myorg/myrepo.git" ]
  # Default-account lookup should NOT have run when [account] was passed.
  [ "$(gh_log_matches '^gh api user')" -eq 0 ]
}

@test "git-create passes \"\" as [account] to keep default but override [directory]" {
  run "$GIT_CREATE" myrepo "" custom-dir
  [ "$status" -eq 0 ]

  [ -d "$BARE_ROOT/testuser/myrepo.git" ]
  [ -d "$WORK/custom-dir/.git" ]
  [ "$(git -C "$WORK/custom-dir" config --get remote.origin.url)" = "https://github.com/testuser/myrepo.git" ]
}

@test "git-create applies default repo settings via gh repo edit" {
  run "$GIT_CREATE" myrepo
  [ "$status" -eq 0 ]
  # Every built-in default from lib/repo-settings.sh should be on the edit line.
  local edit_line
  edit_line=$(grep -E '^gh repo edit testuser/myrepo ' "$STUB_GH_LOG")
  [[ "$edit_line" == *"--allow-update-branch=true"* ]]
  [[ "$edit_line" == *"--delete-branch-on-merge=true"* ]]
  [[ "$edit_line" == *"--enable-auto-merge=true"* ]]
  [[ "$edit_line" == *"--enable-merge-commit=false"* ]]
  [[ "$edit_line" == *"--enable-projects=false"* ]]
  [[ "$edit_line" == *"--enable-squash-merge=false"* ]]
  [[ "$edit_line" == *"--enable-wiki=false"* ]]
}

@test "git-create honours ~/.agitentic [repo] overrides" {
  cat > "$HOME/.agitentic" <<'EOF'
[repo]
  enable-wiki = true
  enable-squash-merge = true
EOF
  run "$GIT_CREATE" myrepo
  [ "$status" -eq 0 ]

  local edit_line
  edit_line=$(grep -E '^gh repo edit testuser/myrepo ' "$STUB_GH_LOG")
  [[ "$edit_line" == *"--enable-wiki=true"* ]]
  [[ "$edit_line" == *"--enable-squash-merge=true"* ]]
  # Unspecified keys still get their defaults.
  [[ "$edit_line" == *"--delete-branch-on-merge=true"* ]]
  [[ "$edit_line" == *"--enable-projects=false"* ]]
}

@test "git-create enables all three security endpoints by default" {
  run "$GIT_CREATE" myrepo
  [ "$status" -eq 0 ]
  [ "$(gh_log_matches '^gh api --silent --method PUT /repos/testuser/myrepo/vulnerability-alerts$')" -eq 1 ]
  [ "$(gh_log_matches '^gh api --silent --method PUT /repos/testuser/myrepo/automated-security-fixes$')" -eq 1 ]
  [ "$(gh_log_matches '^gh api --silent --method PATCH /repos/testuser/myrepo/code-scanning/default-setup -f state=configured$')" -eq 1 ]
}

@test "git-create honours [security] overrides in ~/.agitentic" {
  cat > "$HOME/.agitentic" <<'EOF'
[security]
  dependabot-alerts = false
  codeql-default-setup = false
EOF
  run "$GIT_CREATE" myrepo
  [ "$status" -eq 0 ]
  # Disabled endpoints not called.
  [ "$(gh_log_matches 'vulnerability-alerts')" -eq 0 ]
  [ "$(gh_log_matches 'code-scanning/default-setup')" -eq 0 ]
  # Still-enabled endpoint is called.
  [ "$(gh_log_matches '^gh api --silent --method PUT /repos/testuser/myrepo/automated-security-fixes$')" -eq 1 ]
}

@test "git-create tolerates a failing security endpoint without failing the run" {
  export STUB_GH_API_FAIL="code-scanning/default-setup"
  run "$GIT_CREATE" myrepo
  [ "$status" -eq 0 ]
  [[ "$output" == *"(warning: CodeQL default setup not enabled"* ]]
  # Repo still materialised; earlier endpoints still called.
  [ -d "$BARE_ROOT/testuser/myrepo.git" ]
  [ "$(gh_log_matches 'vulnerability-alerts')" -eq 1 ]
  [ "$(gh_log_matches 'automated-security-fixes')" -eq 1 ]
}

@test "git-create refuses when target directory already exists" {
  mkdir "$WORK/myrepo"
  run "$GIT_CREATE" myrepo
  [ "$status" -eq 1 ]
  [[ "$output" == *"already exists"* ]]
  # Nothing should have been created remotely either.
  [ ! -d "$BARE_ROOT/testuser/myrepo.git" ]
}
