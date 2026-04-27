---
name: git-sync
description: Sync the local default branch and `fork/<branch>` to `upstream/<branch>`. Fetches upstream, fast-forwards the local branch, and pushes the result to the fork. Use when the user asks to sync a fork, pull in upstream changes, update main from upstream, or "bring my fork up to date". Pairs with the agitentic:git-fork skill, which sets up the `upstream` and `fork` remotes this skill expects.
license: Apache-2.0 WITH LLVM-exception
compatibility: Requires git, with `upstream` and `fork` remotes already configured (see the agitentic:git-fork skill).
allowed-tools: Bash
---

# git-sync

Sync the local default branch and `fork/<branch>` to `upstream/<branch>`.
The default mode is fast-forward only, so divergent local commits are
preserved (the script exits with an error and the user decides what to
do). Pass `--force` to hard-reset and force-push when the user
explicitly wants to discard divergent work.

## When to use this skill

Use this skill when the user asks to:

- "Sync my fork", "update my fork", "pull upstream into my fork".
- "Bring main up to date with upstream", "fast-forward main".
- "Reset my fork to upstream" (use `--force`).

Do **not** use this skill when:

- The repo doesn't have `upstream` / `fork` remotes — set them up first
  with the `agitentic:git-fork` skill.
- The user wants to merge a feature branch from upstream into a working
  branch — that's a regular `git fetch` + `git merge`, not a sync.

## How to invoke

Run the bundled script from inside the repository:

```
scripts/git-sync [--branch <branch>] [--force] [--prune]
```

- `--branch <branch>` — branch to sync. Defaults to upstream's default
  branch (read from `refs/remotes/upstream/HEAD`, usually `main`).
- `--force` — allow non-fast-forward updates. Hard-resets local
  `<branch>` to `upstream/<branch>` and force-pushes (`--force-with-lease`)
  to fork. Use this when the user explicitly says "reset", "overwrite",
  or "discard local commits".
- `--prune` — after syncing, delete any other local branches whose
  commits are all patch-equivalent to commits on `upstream/<branch>`.
  Catches merge, rebase, and squash merges. The synced branch and the
  currently checked-out branch are never deleted.

The script:

1. Refuses to run if the working tree has uncommitted changes.
2. Verifies `upstream` and `fork` remotes exist.
3. Fetches `upstream/<branch>`.
4. Updates the local `<branch>` ref:
   - No-op if already at upstream.
   - Fast-forward if local is an ancestor of upstream.
   - Hard-reset if `--force` is set.
   - Otherwise errors out (divergent commits would be lost).
5. Pushes `<branch>` to `fork`. With `--force`, uses
   `--force-with-lease` (refuses to clobber commits the local view doesn't
   know about).
6. With `--prune`, iterates local branches and deletes each one whose
   commits are all patch-equivalent to `upstream/<branch>` (detected
   via `git cherry`).

## Examples

User: "Sync my fork with upstream"

```
scripts/git-sync
```

User: "Reset main to whatever upstream has"

```
scripts/git-sync --force
```

User: "Sync the `release-1.x` branch"

```
scripts/git-sync --branch release-1.x
```

User: "Sync and clean up branches that have already been merged"

```
scripts/git-sync --prune
```

After the script returns, confirm by showing the user
`git log --oneline -3 main` and `git rev-parse main fork/main upstream/main`.

## Requirements

- `git`
- `upstream` and `fork` remotes configured. The
  `agitentic:git-fork` skill sets these up.
- For pushing to `fork`, the user must have push access to the fork
  repo (typically true if it's their own).
