#!/usr/bin/env bats
#
# End-to-end tests for git-fork. See git-create.bats for the stub setup.
# Each test seeds a synthetic upstream bare repo, then runs git-fork and
# asserts that the fork bare materialised, the local clone has both
# remotes, and gh was called with the expected arguments.

setup() {
  # shellcheck disable=SC1091
  source "$BATS_TEST_DIRNAME/lib.bash"
  GIT_FORK="$(agitentic_script git-fork)"

  TMP="$(mktemp -d)"
  setup_gh_stub "$TMP"
  seed_bare_repo "orig/repo"

  WORK="$TMP/work"
  mkdir -p "$WORK"
  cd "$WORK"
}

teardown() {
  rm -rf "$TMP"
}

gh_log_matches() {
  grep -E -c "$1" "$STUB_GH_LOG" || true
}

@test "git-fork clones upstream, creates fork, adds both remotes" {
  run "$GIT_FORK" orig/repo
  [ "$status" -eq 0 ]

  # Fork bare materialised under the default stub account.
  [ -d "$BARE_ROOT/testuser/repo.git" ]

  # Local clone has both remotes pointing at the intended GitHub URLs.
  [ -d "$WORK/repo/.git" ]
  [ "$(git -C "$WORK/repo" config --get remote.upstream.url)" = "https://github.com/orig/repo.git" ]
  [ "$(git -C "$WORK/repo" config --get remote.fork.url)"     = "https://github.com/testuser/repo.git" ]

  # gh was called with the expected subcommands.
  [ "$(gh_log_matches '^gh api user --jq \.login$')" -ge 1 ]
  [ "$(gh_log_matches '^gh repo fork orig/repo --clone=false$')" -eq 1 ]
  [ "$(gh_log_matches '^gh repo edit testuser/repo ')" -eq 1 ]
}

@test "git-fork accepts an https URL and normalises to owner/name" {
  run "$GIT_FORK" https://github.com/orig/repo.git
  [ "$status" -eq 0 ]
  [ -d "$BARE_ROOT/testuser/repo.git" ]
  [ "$(git -C "$WORK/repo" config --get remote.upstream.url)" = "https://github.com/orig/repo.git" ]
}

@test "git-fork accepts an ssh URL" {
  run "$GIT_FORK" git@github.com:orig/repo.git
  [ "$status" -eq 0 ]
  [ -d "$BARE_ROOT/testuser/repo.git" ]
}

@test "git-fork accepts an ssh:// URL" {
  run "$GIT_FORK" ssh://git@github.com/orig/repo.git
  [ "$status" -eq 0 ]
  [ -d "$BARE_ROOT/testuser/repo.git" ]
  [ "$(git -C "$WORK/repo" config --get remote.upstream.url)" = "https://github.com/orig/repo.git" ]
}

@test "git-fork accepts http:// URL" {
  run "$GIT_FORK" http://github.com/orig/repo.git
  [ "$status" -eq 0 ]
  [ -d "$BARE_ROOT/testuser/repo.git" ]
}

@test "git-fork strips trailing slash from slug" {
  run "$GIT_FORK" https://github.com/orig/repo/
  [ "$status" -eq 0 ]
  [ -d "$BARE_ROOT/testuser/repo.git" ]
}

@test "git-fork honours [account] and forks into an org via --org" {
  seed_bare_repo "other/thing"
  run "$GIT_FORK" other/thing myorg my-dir
  [ "$status" -eq 0 ]

  [ -d "$BARE_ROOT/myorg/thing.git" ]
  [ -d "$WORK/my-dir/.git" ]
  [ "$(git -C "$WORK/my-dir" config --get remote.upstream.url)" = "https://github.com/other/thing.git" ]
  [ "$(git -C "$WORK/my-dir" config --get remote.fork.url)"     = "https://github.com/myorg/thing.git" ]

  # --org flag should appear on the fork call since account != authed user.
  [ "$(gh_log_matches '^gh repo fork other/thing --clone=false --org myorg$')" -eq 1 ]
}

@test "git-fork short-circuits when [account] is the upstream owner" {
  run "$GIT_FORK" orig/repo orig
  [ "$status" -eq 0 ]
  [[ "$output" == *"Skipping fork"* ]]

  # No fork bare and no fork/edit/security calls should have been made.
  [ ! -d "$BARE_ROOT/testuser/repo.git" ]
  [ "$(gh_log_matches '^gh repo fork ')" -eq 0 ]
  [ "$(gh_log_matches '^gh repo edit ')" -eq 0 ]
  [ "$(gh_log_matches 'vulnerability-alerts')" -eq 0 ]
  [ "$(gh_log_matches 'automated-security-fixes')" -eq 0 ]
  [ "$(gh_log_matches 'code-scanning/default-setup')" -eq 0 ]

  # The local clone still happens; fork remote still gets added (pointing
  # at orig/repo — this is the script's existing behaviour).
  [ -d "$WORK/repo/.git" ]
  [ "$(git -C "$WORK/repo" config --get remote.upstream.url)" = "https://github.com/orig/repo.git" ]
  [ "$(git -C "$WORK/repo" config --get remote.fork.url)"     = "https://github.com/orig/repo.git" ]
}

@test "git-fork applies fork settings with defaults" {
  run "$GIT_FORK" orig/repo
  [ "$status" -eq 0 ]
  local edit_line
  edit_line=$(grep -E '^gh repo edit testuser/repo ' "$STUB_GH_LOG")
  [[ "$edit_line" == *"--allow-update-branch=true"* ]]
  [[ "$edit_line" == *"--delete-branch-on-merge=true"* ]]
  [[ "$edit_line" == *"--enable-auto-merge=true"* ]]
  [[ "$edit_line" == *"--enable-merge-commit=false"* ]]
  [[ "$edit_line" == *"--enable-projects=false"* ]]
  [[ "$edit_line" == *"--enable-squash-merge=false"* ]]
  [[ "$edit_line" == *"--enable-wiki=false"* ]]
}

@test "git-fork enables all three security endpoints on the fork" {
  run "$GIT_FORK" orig/repo
  [ "$status" -eq 0 ]
  [ "$(gh_log_matches '^gh api --silent --method PUT /repos/testuser/repo/vulnerability-alerts$')" -eq 1 ]
  [ "$(gh_log_matches '^gh api --silent --method PUT /repos/testuser/repo/automated-security-fixes$')" -eq 1 ]
  [ "$(gh_log_matches '^gh api --silent --method PATCH /repos/testuser/repo/code-scanning/default-setup -f state=configured$')" -eq 1 ]
}

@test "git-fork honours [repo] overrides in ~/.agitentic on the fork" {
  cat > "$HOME/.agitentic" <<'EOF'
[repo]
  enable-wiki = true
  enable-squash-merge = true
EOF
  run "$GIT_FORK" orig/repo
  [ "$status" -eq 0 ]
  local edit_line
  edit_line=$(grep -E '^gh repo edit testuser/repo ' "$STUB_GH_LOG")
  [[ "$edit_line" == *"--enable-wiki=true"* ]]
  [[ "$edit_line" == *"--enable-squash-merge=true"* ]]
  # Unspecified keys still default.
  [[ "$edit_line" == *"--delete-branch-on-merge=true"* ]]
}

@test "git-fork honours [security] overrides in ~/.agitentic on the fork" {
  cat > "$HOME/.agitentic" <<'EOF'
[security]
  codeql-default-setup = false
EOF
  run "$GIT_FORK" orig/repo
  [ "$status" -eq 0 ]
  [ "$(gh_log_matches 'vulnerability-alerts')" -eq 1 ]
  [ "$(gh_log_matches 'automated-security-fixes')" -eq 1 ]
  [ "$(gh_log_matches 'code-scanning/default-setup')" -eq 0 ]
}

@test "git-fork tolerates a failing security endpoint without failing the run" {
  export STUB_GH_API_FAIL="vulnerability-alerts"
  run "$GIT_FORK" orig/repo
  [ "$status" -eq 0 ]
  [[ "$output" == *"(warning: dependabot alerts not enabled"* ]]
  # Later endpoints still attempted, local clone still completed.
  [ -d "$WORK/repo/.git" ]
  [ "$(gh_log_matches 'automated-security-fixes')" -eq 1 ]
}

@test "git-fork exits 1 when git is not on PATH" {
  PATH="$AGITENTIC_NO_GIT_NO_GH_PATH" run /bin/bash "$GIT_FORK" orig/repo
  [ "$status" -eq 1 ]
  [[ "$output" == *"'git' is required"* ]]
}

@test "git-fork exits 1 when gh is not on PATH" {
  PATH="$AGITENTIC_NO_GH_PATH" run /bin/bash "$GIT_FORK" orig/repo
  [ "$status" -eq 1 ]
  [[ "$output" == *"'gh' (GitHub CLI) is required"* ]]
}

@test "git-fork refuses when target directory already exists" {
  mkdir "$WORK/repo"
  run "$GIT_FORK" orig/repo
  [ "$status" -eq 1 ]
  [[ "$output" == *"already exists"* ]]
  # The script may resolve the default account via `gh api user` first,
  # but must reject before any state-changing fork or edit call.
  [ "$(gh_log_matches '^gh repo fork ')" -eq 0 ]
  [ "$(gh_log_matches '^gh repo edit ')" -eq 0 ]
}
