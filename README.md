# agitentic

Agentic git/GitHub helpers, packaged as
[agentskills.io](https://agentskills.io)-compliant skills and shipped as a
Claude Code plugin.

## Skills

- **`agitentic:git-fork`** — fork a GitHub repository and clone it with
  the contributor-style two-remote layout. The local default branch
  tracks `upstream/<default>`; a `fork` remote points at your fork.
- **`agitentic:git-sync`** — fetch `upstream/<branch>` and propagate it
  to local `<branch>` and `fork/<branch>`. Fast-forward by default;
  `--force` allows hard-reset + force-push. Branch defaults to
  upstream's default branch.

Each skill lives under `plugins/agitentic/skills/<name>/` and is a
self-contained agentskills.io skill (`SKILL.md` + a `scripts/`
directory).

## Install (Claude Code)

The repo is a Claude Code plugin marketplace. Install via:

```
/plugin marketplace add robobryce/agitentic
/plugin install agitentic@robobryce-agitentic
```

Then invoke a skill by name, e.g. `/agitentic:git-fork`.

## Use the scripts directly (no plugin)

Each skill is a thin wrapper around a self-contained shell script. The
scripts are usable on their own and are designed to be droppable on
your `$PATH` as `git` subcommands:

```bash
cp plugins/agitentic/skills/git-fork/scripts/git-fork ~/bin/git-fork
cp plugins/agitentic/skills/git-sync/scripts/git-sync ~/bin/git-sync
git fork brevdev/brev-cli
git sync
```

### `git-fork <repo> [account]`

- `<repo>` — `owner/name`, or a GitHub HTTPS / SSH URL.
- `[account]` — destination owner for the fork. Defaults to the
  authenticated `gh` user.

Example:

```bash
$ git-fork brevdev/brev-cli
==> Cloning brevdev/brev-cli (remote: upstream)
==> Forking brevdev/brev-cli → robobryce/brev-cli
==> Adding fork remote → https://github.com/robobryce/brev-cli.git
==> Done.
fork      https://github.com/robobryce/brev-cli.git (fetch)
fork      https://github.com/robobryce/brev-cli.git (push)
upstream  https://github.com/brevdev/brev-cli.git (fetch)
upstream  https://github.com/brevdev/brev-cli.git (push)
```

`git-fork` requires `git` and the [GitHub CLI](https://cli.github.com/)
(`gh`) on your `$PATH`, and `gh` must be authenticated.

### `git-sync [--branch <branch>] [--force]`

Fast-forward local `<branch>` and `fork/<branch>` to `upstream/<branch>`.
With no flags, refuses to discard divergent commits; pass `--force` for
a hard-reset + force-push (`--force-with-lease`).

```bash
$ git sync
==> Fetching upstream/main
==> Fast-forwarding local main to upstream/main
==> Pushing main → fork
==> Done.
  local main → 5ad5c19...
  fork/main  → 5ad5c19...
```

`git-sync` requires `git` and the repo to have `upstream` and `fork`
remotes (e.g. set up by `git-fork`).

## Project structure

```
.claude-plugin/
  marketplace.json           - Claude Code plugin marketplace manifest
plugins/
  agitentic/
    .claude-plugin/
      plugin.json            - plugin manifest
    skills/
      git-fork/
        SKILL.md             - agentskills.io skill (metadata + instructions)
        scripts/git-fork     - the script the skill runs
      git-sync/
        SKILL.md
        scripts/git-sync
.github/workflows/ci.yml     - lint scripts, validate manifests, sanity-check skills
LICENSE.txt                  - Apache 2.0 with LLVM exception
```

## License

Apache License 2.0 with LLVM exception. See [`LICENSE.txt`](LICENSE.txt).
