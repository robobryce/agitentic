#!/usr/bin/env bash
# Shared library: default repo settings applied by git-create and
# git-fork. Keeping the defaults and merge logic in one place ensures
# the two skills stay consistent.
#
# Usage (from a script under plugins/agitentic/skills/*/scripts/):
#   source "$(dirname "${BASH_SOURCE[0]}")/../../../lib/repo-settings.sh"
#   agitentic_apply_repo_settings <owner/repo>
#
# Overrides: read from the [repo] section of ~/.agitentic (git config
# format), or $AGITENTIC_CONFIG if set. Built-in defaults still apply
# for keys not in the file.

# Built-in default settings. Keys are `gh repo edit` long-flag names
# without the leading `--`. Values are whatever that flag accepts.
agitentic_default_repo_settings() {
  cat <<'EOF'
delete-branch-on-merge=true
enable-wiki=false
enable-projects=false
enable-merge-commit=false
enable-squash-merge=false
enable-auto-merge=true
allow-update-branch=true
EOF
}

# Apply repo settings to the given "owner/repo" slug via `gh repo edit`.
# Overrides from the config file are merged over the built-in defaults.
agitentic_apply_repo_settings() {
  local repo_slug="$1"
  local -A settings=()
  local key value

  while IFS='=' read -r key value; do
    [[ -n "$key" ]] || continue
    settings["$key"]="$value"
  done < <(agitentic_default_repo_settings)

  local config_file="${AGITENTIC_CONFIG:-$HOME/.agitentic}"
  if [[ -f "$config_file" ]]; then
    echo "==> Reading repo settings from $config_file"
    while IFS='=' read -r key value; do
      case "$key" in
        repo.*) settings["${key#repo.}"]="$value" ;;
      esac
    done < <(git config -f "$config_file" --list)
  fi

  local sorted_keys
  mapfile -t sorted_keys < <(printf '%s\n' "${!settings[@]}" | LC_ALL=C sort)
  local edit_args=()
  for key in "${sorted_keys[@]}"; do
    edit_args+=("--${key}=${settings[$key]}")
  done

  echo "==> Applying repo settings to ${repo_slug}"
  gh repo edit "$repo_slug" "${edit_args[@]}"
}
