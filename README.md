# agitentic

Git skills for coding agents.
They are [agentskills.io](https://agentskills.io)-compliant and
shipped as a Claude Code plugin.

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

Each skill is a thin wrapper around a self-contained shell script.
You can call them directly:

```bash
plugins/agitentic/skills/git-fork/scripts/git-fork <repo> [account] [directory]
plugins/agitentic/skills/git-sync/scripts/git-sync [--branch <branch>] [--force]
```

Or drop them on your `$PATH` to make them `git` subcommands:

```bash
cp plugins/agitentic/skills/git-fork/scripts/git-fork ~/bin/git-fork
cp plugins/agitentic/skills/git-sync/scripts/git-sync ~/bin/git-sync
git fork brevdev/brev-cli
git sync
```

### `git-fork <repo> [account] [directory]`

- `<repo>` — `owner/name`, or a GitHub HTTPS / SSH URL.
- `[account]` — destination owner for the fork. Defaults to the
  authenticated `gh` user. Pass `""` to use the default while still
  specifying `[directory]`.
- `[directory]` — local directory to clone into. Defaults to the repo
  name.

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

### `git-sync [--branch <branch>] [--force]`

Fast-forward local `<branch>` and `fork/<branch>` to `upstream/<branch>`.
Without flags, refuses to discard divergent commits; pass `--force` for
a hard-reset + force-push (`--force-with-lease`). `<branch>` defaults
to `upstream`'s default branch.

Example:

```bash
$ git-sync
==> Fetching upstream/main
==> Fast-forwarding local main to upstream/main
==> Pushing main → fork
==> Done.
  local main → 5ad5c19...
  fork/main  → 5ad5c19...
```

## Dependencies

The following must be in your `$PATH`:

- `bash`
- `git`
- `gh`, the [GitHub CLI](https://cli.github.com/). It must be authenticated.

## Project structure

```
.claude-plugin/
  marketplace.json           - Claude Code plugin marketplace manifest
plugins/
  agitentic/
    .claude-plugin/
      plugin.json            - Plugin manifest
    skills/
      ${SKILL}/              - An individual skill
        SKILL.md             - agentskills.io skill (metadata + instructions)
        scripts/
.github/workflows/ci.yml     - Lint scripts, validate manifests, sanity-check skills
LICENSE.txt                  - Apache 2.0 with LLVM exception
```

## License

Apache License 2.0 with LLVM exception. See [`LICENSE.txt`](LICENSE.txt).
