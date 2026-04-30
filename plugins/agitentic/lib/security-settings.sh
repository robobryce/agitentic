#!/usr/bin/env bash
# Shared library: default security settings applied to new repos by
# git-create and git-fork. Mirrors the structure of repo-settings.sh so
# the two skills stay consistent.
#
# Usage (from a script under plugins/agitentic/skills/*/scripts/):
#   source "$(dirname "${BASH_SOURCE[0]}")/../../../lib/security-settings.sh"
#   agitentic_apply_security_settings <owner/repo>
#
# Overrides: read from the [security] section of ~/.agitentic (git config
# format), or $AGITENTIC_CONFIG if set. All three default to true; set
# any to false to skip that step. Failures are warned-about but
# non-fatal — the underlying repo is already created by the caller.

# Enable dependabot alerts, automated security updates, and CodeQL
# default scanning on the given "owner/repo" slug.
agitentic_apply_security_settings() {
  local repo_slug="$1"
  local -A settings=(
    [dependabot-alerts]=true
    [dependabot-security-updates]=true
    [codeql-default-setup]=true
  )

  local config_file="${AGITENTIC_CONFIG:-$HOME/.agitentic}"
  if [[ -f "$config_file" ]]; then
    local key value
    while IFS='=' read -r key value; do
      case "$key" in
        security.*) settings["${key#security.}"]="$value" ;;
      esac
    done < <(git config -f "$config_file" --list)
  fi

  echo "==> Applying security settings to ${repo_slug}"

  if [[ "${settings[dependabot-alerts]}" == "true" ]]; then
    echo "  enabling dependabot alerts"
    gh api --silent --method PUT "/repos/${repo_slug}/vulnerability-alerts" \
      || echo "  (warning: dependabot alerts not enabled)"
  fi

  if [[ "${settings[dependabot-security-updates]}" == "true" ]]; then
    echo "  enabling dependabot security updates"
    gh api --silent --method PUT "/repos/${repo_slug}/automated-security-fixes" \
      || echo "  (warning: dependabot security updates not enabled)"
  fi

  if [[ "${settings[codeql-default-setup]}" == "true" ]]; then
    echo "  enabling CodeQL default setup"
    gh api --silent --method PATCH "/repos/${repo_slug}/code-scanning/default-setup" \
      -f state=configured \
      || echo "  (warning: CodeQL default setup not enabled — repo may have no supported languages yet)"
  fi
}
