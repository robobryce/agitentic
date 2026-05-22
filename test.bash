#!/usr/bin/env bash
# Run the project's tests. Mirrors the jobs in .github/workflows/ci.yml so
# "works locally" == "will pass CI".
#
# Usage:
#   ./test.bash              lint + unit (default; fast, no side effects)
#   ./test.bash --lint       shellcheck + bash -n on plugin scripts and the
#                            test harness, script-executable check, jq
#                            manifest validation, agentskills.io skill
#                            validation.
#   ./test.bash --unit       bats suite (tests/*.bats). The fixture-based
#                            git-sync tests build synthetic bare repos
#                            locally; no network or gh auth required.
#   ./test.bash --secrets    gitleaks scan of full history + working tree
#   ./test.bash --all        lint + unit + secrets, in order
#   ./test.bash -h|--help    print this usage

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

need() {
    command -v "$1" >/dev/null 2>&1 \
        || { echo "test.bash: missing dependency: $1" >&2; return 1; }
}

# Collect every file under plugins/*/skills/*/scripts/*. These are the
# executable skill scripts; they have no extension and are recognised by
# their #! line.
plugin_scripts() {
    find plugins -type f -path '*/scripts/*' -print0
}

run_lint() {
    echo "=== lint ==="
    need bash
    need shellcheck
    need jq
    need python3

    local -a scripts=()
    mapfile -d '' scripts < <(plugin_scripts)
    if (( ${#scripts[@]} == 0 )); then
        echo "test.bash: no scripts found under plugins/*/skills/*/scripts/" >&2
        return 1
    fi

    echo "--- shellcheck (scripts + harness) ---"
    for f in "${scripts[@]}"; do
        echo "==> shellcheck $f"
        shellcheck --source-path=SCRIPTDIR -x "$f"
    done
    # Lint the dispatcher, the shared bash lib, and the gh stub. .bats
    # files are in bats' own dialect, not plain bash, so skip them here.
    local -a harness=(test.bash tests/lib.bash tests/stubs/gh)
    for f in "${harness[@]}"; do
        echo "==> shellcheck $f"
        shellcheck --source-path=SCRIPTDIR -x "$f"
    done

    echo "--- bash -n (scripts + harness) ---"
    for f in "${scripts[@]}" "${harness[@]}"; do
        echo "==> bash -n $f"
        bash -n "$f"
    done

    echo "--- scripts are executable ---"
    local fail=0
    for f in "${scripts[@]}" tests/stubs/gh; do
        if [[ ! -x "$f" ]]; then
            echo "::error file=$f::script is not executable (chmod +x)"
            fail=1
        fi
    done
    (( fail == 0 )) || return 1

    echo "--- plugin / marketplace manifests ---"
    for f in \
        .agents/plugins/marketplace.json \
        .claude-plugin/marketplace.json \
        plugins/*/.claude-plugin/plugin.json \
        plugins/*/.codex-plugin/plugin.json; do
        echo "==> jq . $f"
        jq -e . "$f" >/dev/null
    done
    jq -e '.name and .owner.name and (.plugins | type == "array" and length > 0)' \
        .claude-plugin/marketplace.json >/dev/null
    jq -e '.name and .interface.displayName and (.plugins | type == "array" and length > 0) and (.plugins[] | .name and .source.source == "local" and .source.path and .policy.installation and .policy.authentication and .category)' \
        .agents/plugins/marketplace.json >/dev/null
    for f in plugins/*/.claude-plugin/plugin.json; do
        jq -e '.name and .version and .description' "$f" >/dev/null
    done
    for f in plugins/*/.codex-plugin/plugin.json; do
        jq -e '.name and .version and .description and .skills == "./skills/"' "$f" >/dev/null
    done

    echo "--- agentskills.io skills ---"
    python3 .github/validate_skills.py
}

run_unit() {
    echo "=== unit (bats) ==="
    need bats
    need git
    # The fixture helper expects a usable git identity. Inherit whatever
    # the caller has; set a harmless fallback if not.
    if ! git config --global --get user.email >/dev/null 2>&1; then
        export GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-test@example.com}"
        export GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-$GIT_AUTHOR_EMAIL}"
    fi
    if ! git config --global --get user.name >/dev/null 2>&1; then
        export GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-Test}"
        export GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME:-$GIT_AUTHOR_NAME}"
    fi
    bats tests/
}

run_secrets() {
    echo "=== secret scan (gitleaks) ==="
    need gitleaks
    gitleaks detect --source . --redact --verbose --exit-code 1
    gitleaks detect --source . --no-git --redact --verbose --exit-code 1
}

usage() {
    sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
}

if [ $# -eq 0 ]; then
    run_lint
    run_unit
    exit 0
fi

for arg in "$@"; do
    case "$arg" in
        --lint)    run_lint ;;
        --unit)    run_unit ;;
        --secrets) run_secrets ;;
        --all)
            run_lint
            run_unit
            run_secrets
            ;;
        -h|--help) usage; exit 0 ;;
        *)
            echo "test.bash: unknown arg: $arg" >&2
            usage >&2
            exit 2
            ;;
    esac
done
