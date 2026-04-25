---
name: git-fork
description: Fork a GitHub repository and clone it locally with the contributor-style two-remote layout — `upstream` points at the original repo (local default branch tracks it) and `fork` points at the fork. Use when the user asks to fork a repo, set up a contributor clone, or wire up upstream + fork remotes for a repo they're about to contribute to. Keywords - fork, clone, upstream, contribute, set up remotes, github fork.
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
scripts/git-fork <repo> [account] [directory]
```

- `<repo>` (required) — the repository to fork. Accepts `owner/name` or
  any GitHub HTTPS / SSH URL (`https://github.com/owner/name`,
  `git@github.com:owner/name.git`, etc.).
- `[account]` (optional) — the destination owner for the fork. Defaults
  to the currently authenticated `gh` user. Pass `""` to use the
  default while still specifying `[directory]`.
- `[directory]` (optional) — local directory to clone into. Defaults
  to the repo name.

The script:

1. Clones `<repo>` into `./<directory>` with the original as `upstream`.
   The local default branch tracks `upstream/<default>`.
2. Forks `<repo>` to `<account>/<name>` via `gh repo fork`. If
   `<account>` is the upstream owner, the fork step is skipped. If
   `<account>` is not the authenticated user, `--org <account>` is used,
   so the caller must have permission to fork into that org.
3. Adds a `fork` remote pointing at `<account>/<name>`.

The script refuses to overwrite an existing `./<directory>`.

## Example

User: "Fork brevdev/brev-cli for me"

Run, from the directory where the user wants the clone to land:

```
scripts/git-fork brevdev/brev-cli
```

User: "Fork it into the acme org"

```
scripts/git-fork brevdev/brev-cli acme
```

User: "Fork brevdev/brev-cli into ~/work/brev"

```
cd ~/work && scripts/git-fork brevdev/brev-cli "" brev
```

After the script returns, show the user `git -C <directory> remote -v`
so the two-remote layout is visible.

## Requirements

- `git`
- `gh` (GitHub CLI), authenticated. The skill uses `gh api user --jq
  .login` to discover the default account and `gh repo fork` to create
  the fork.
