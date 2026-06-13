---
name: git-fork
description: Fork a GitHub repository and clone it locally with the contributor-style two-remote layout — `upstream` points at the original repo (local default branch tracks it) and `fork` points at the fork. Also applies sensible repo settings to the fork (`delete_branch_on_merge=true`, wiki/projects/merge-commit/squash-merge disabled), overridable via `~/.agitentic`. Use when the user asks to fork a repo, set up a contributor clone, or wire up upstream + fork remotes for a repo they're about to contribute to. Keywords - fork, clone, upstream, contribute, set up remotes, github fork.
license: Apache-2.0 WITH LLVM-exception
compatibility: Requires git and the GitHub CLI (`gh`), authenticated.
allowed-tools: Bash
---

# git-fork

Fork a GitHub repository, clone the upstream locally, and configure two
remotes so the workflow is ready for contributions:

- `upstream` → the original repository. The local default branch tracks
  `upstream/<default>`.
- `fork` → the user's fork (or a specified org's fork).

## When to use this skill

Use this skill when the user asks to:

- Fork a repo and clone it for contribution work.
- Set up `upstream` / `fork` remotes for a repo.
- "Fork X for me", "fork X to org Y", "set up a contributor clone of X".

Do **not** use this skill when:

- The user only wants to clone a repo (no fork). Use `git clone` directly.
- The user only wants to fork on GitHub without a local clone. Use `gh
  repo fork` directly.

## How to invoke

Run the bundled script:

```
scripts/git-fork <repo> [name] [account] [directory]
```

- `<repo>` (required) — the repository to fork. Accepts `owner/name` or
  any GitHub HTTPS / SSH URL (`https://github.com/owner/name`,
  `git@github.com:owner/name.git`, etc.).
- `[name]` (optional) — the name to use for the fork on GitHub (and
  the default local directory). Defaults to the upstream repo name.
  Pass `""` to use the default while still specifying `[account]` or
  `[directory]`.
- `[account]` (optional) — the destination owner for the fork. Defaults
  to the currently authenticated `gh` user. Pass `""` to use the
  default while still specifying `[directory]`.
- `[directory]` (optional) — local directory to clone into. Defaults
  to `[name]`.

The script:

1. Clones `<repo>` into `./<directory>` with the original as `upstream`.
   The local default branch tracks `upstream/<default>`.
2. Forks `<repo>` to `<account>/<name>` via `gh repo fork`. If
   `<account>/<name>` matches the upstream, the fork step is skipped. If
   `<account>` is not the authenticated user, `--org <account>` is used,
   so the caller must have permission to fork into that org. If `<name>`
   differs from the upstream repo name, `--fork-name <name>` is used.
3. Applies repo settings to the fork via `gh repo edit` (skipped if the
   fork step was skipped). Defaults:
   - `delete-branch-on-merge=true`
   - `enable-wiki=false`
   - `enable-projects=false`
   - `enable-merge-commit=false`
   - `enable-squash-merge=false`
   - `enable-rebase-merge=true`
   - `enable-auto-merge=true`
   - `allow-update-branch=true`
4. Enables dependabot alerts, dependabot automated security updates,
   and CodeQL default scanning on the fork (each toggleable via
   `[security]` in `~/.agitentic`). Failures here are warned-about,
   not fatal. Skipped when the fork step was skipped.
5. Adds a `fork` remote pointing at `<account>/<name>`.

The script refuses to overwrite an existing `./<directory>`.

## Configuration: `~/.agitentic`

Fork repo settings are read from the `[repo]` section of `~/.agitentic`
(or `$AGITENTIC_CONFIG` if set). The same section is used by
`agitentic:git-create`, so a single config file controls both skills.
File format is git config (INI-like):

```ini
[repo]
    delete-branch-on-merge = true
    enable-wiki = false
    enable-projects = false
    enable-merge-commit = false
    enable-squash-merge = false
    enable-rebase-merge = true
```

Keys map directly to `gh repo edit` flags. Built-in defaults apply for
keys not in the file, so users can override individual settings without
re-specifying the rest.

If `~/.agitentic` doesn't exist, the built-in defaults are used.

Security settings live in a separate `[security]` section. All three
default to `true`; set any to `false` to skip that step:

```ini
[security]
    dependabot-alerts = true
    dependabot-security-updates = true
    codeql-default-setup = true
```

## Example

User: "Fork brevdev/brev-cli for me"

Run, from the directory where the user wants the clone to land:

```
scripts/git-fork brevdev/brev-cli
```

User: "Fork nvidia/cccl as autocuda-cccl"

```
scripts/git-fork nvidia/cccl autocuda-cccl
```

User: "Fork it into the acme org"

```
scripts/git-fork brevdev/brev-cli "" acme
```

User: "Fork brevdev/brev-cli into ~/work/brev"

```
cd ~/work && scripts/git-fork brevdev/brev-cli "" "" brev
```

After the script returns, show the user `git -C <directory> remote -v`
so the two-remote layout is visible.

## Requirements

- `git`
- `gh` (GitHub CLI), authenticated. The skill uses `gh api user --jq
  .login` to discover the default account and `gh repo fork` to create
  the fork.
