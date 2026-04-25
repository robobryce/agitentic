---
name: git-create
description: Create a new public GitHub repository, initialise a local clone, make an empty initial commit on `main`, push, and apply sensible repo settings (`delete_branch_on_merge=true`, wiki/projects/merge-commit/squash-merge disabled). Settings are overridable via the `[repo]` section of `~/.agitentic`. Use when the user asks to create a new GitHub repo, start a new project, scaffold a fresh repository, or initialise a repo with their standard settings. Keywords - create repo, new repo, gh repo create, scaffold, initialise, init.
license: Apache-2.0 WITH LLVM-exception
compatibility: Requires git and the GitHub CLI (`gh`), authenticated.
allowed-tools: Bash
---

# git-create

Create a new GitHub repository, set up a local clone with an empty
initial commit on `main`, push, and apply sensible repo settings.

The new repo is **public** and shares the same default settings (and
the same `~/.agitentic` `[repo]` override mechanism) as the
`agitentic:git-fork` skill, so a contributor's fork and a freshly-
created repo end up configured identically.

## When to use this skill

Use this skill when the user asks to:

- "Create a new repo / GitHub project / repository called X".
- "Start a new project on GitHub".
- "Scaffold a repo with my usual settings".
- "Make a fresh repo and clone it locally".

Do **not** use this skill when:

- The repo already exists. Use `git clone` (or `agitentic:git-fork`)
  instead.
- The user wants a private/internal repo. The script hardcodes
  `--public`. Use `gh repo create --private` directly if needed.
- The user wants the repo populated from an existing local
  directory. Use `gh repo create --source=. --push` directly.

## How to invoke

Run the bundled script:

```
scripts/git-create <name> [account] [directory]
```

- `<name>` (required) — repository name. Just the name, not
  `owner/name`. Use `[account]` to specify an owner.
- `[account]` (optional) — GitHub user or organization to create the
  repo in. Defaults to the authenticated `gh` user. Pass `""` to use
  the default while still specifying `[directory]`.
- `[directory]` (optional) — local directory to initialise. Defaults
  to the repo name.

The script:

1. Creates `github.com/<account>/<name>` via `gh repo create --public`.
2. Initialises `./<directory>` as a local git repo on `main`.
3. Adds `origin` pointing at the new repo URL.
4. Makes an empty initial commit (`git commit --allow-empty`).
5. Pushes `main` to `origin`.
6. Applies repo settings via `gh repo edit` (see "Configuration"
   below).

The script refuses to overwrite an existing `./<directory>`, and fails
loudly if the GitHub repo already exists.

## Configuration: `~/.agitentic`

Repo settings are read from the `[repo]` section of `~/.agitentic` (or
`$AGITENTIC_CONFIG` if set). The same section is used by
`agitentic:git-fork`, so a single config file controls both skills.
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

## Examples

User: "Create a new repo called my-tool"

```
scripts/git-create my-tool
```

User: "Make a fresh repo `playground` in the acme org, into ~/work/play"

```
cd ~/work && scripts/git-create playground acme play
```

After the script returns, show the user `git -C <directory> log --oneline`
to confirm the empty initial commit, and `git -C <directory> remote -v`
for the origin remote.

## Requirements

- `git`
- `gh` (GitHub CLI), authenticated. The skill uses `gh repo create`
  and `gh repo edit`, so the token must have `repo` scope.
