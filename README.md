# agitentic

Git skills for coding agents.
They are [agentskills.io](https://agentskills.io)-compliant and
shipped as an agent plugin for Claude Code, Codex, and Agent Skills-compatible harnesses.

## Skills

- **`agitentic:git-fork`** — fork a GitHub repository and clone it with
  the contributor-style two-remote layout. The local default branch
  tracks `upstream/<default>`; a `fork` remote points at your fork.
- **`agitentic:git-clone`** — clone a repo locally with the same
  two-remote layout, against an **existing** fork (no fork creation, no
  repo-settings changes).
- **`agitentic:git-sync`** — fetch `upstream/<branch>` and propagate it
  to local `<branch>` and `fork/<branch>`. Fast-forward by default;
  `--force` allows hard-reset + force-push. Branch defaults to
  upstream's default branch.
- **`agitentic:git-create`** — create a new public GitHub repository,
  initialise a local clone with one empty commit on `main`, push, and
  apply your standard repo settings.

Each skill lives under `plugins/agitentic/skills/<name>/` and is a
self-contained agentskills.io skill (`SKILL.md` + a `scripts/`
directory).

## Install

### pip (registers the plugin with every host)

`pip install` the package from GitHub, then run `agitentic install-plugins` — it registers the plugin with whichever hosts are present (`claude` and/or `codex`), so the `agitentic:*` skills become discoverable:

```bash
pip install "git+https://github.com/brycelelbach/agitentic"
agitentic install-plugins
```

The first `agitentic` command after install runs the registration automatically (pip itself can't run install-time code, so it's deferred to first use); `agitentic install-plugins` is the explicit/repeat form. It skips any host whose CLI isn't on PATH and is safe to re-run. Set `AGITENTIC_NO_AUTO_INSTALL=1` to disable the automatic first-run registration. The skills are self-contained shell scripts (they need only `git` and `gh` on PATH), so there is nothing else to install.

### Host plugin marketplace

Register the plugin marketplace directly in a host instead:

Claude Code:

```
/plugin marketplace add brycelelbach/agitentic
/plugin install agitentic@robobryce-agitentic
```

Codex:

```bash
codex plugin marketplace add brycelelbach/agitentic
codex plugin add agitentic@robobryce-agitentic
```

Other Agent Skills-compatible harnesses can install from the plugin payload at `plugins/agitentic/` or from the individual skill directories under `plugins/agitentic/skills/`.

Invoke a skill using your host's skill syntax. In Claude Code, use `/agitentic:git-fork`; in Codex, use `$agitentic git-fork`.

## Use the scripts directly (no plugin)

Each skill is a thin wrapper around a self-contained shell script.
You can call them directly:

```bash
plugins/agitentic/skills/git-fork/scripts/git-fork     <repo> [name] [account] [directory]
plugins/agitentic/skills/git-clone/scripts/git-clone   <repo> [name] [account] [directory]
plugins/agitentic/skills/git-sync/scripts/git-sync     [--branch <branch>] [--force]
plugins/agitentic/skills/git-create/scripts/git-create <name> [account] [directory]
```

Or drop them on your `$PATH` to make them `git` subcommands:

```bash
cp plugins/agitentic/skills/git-fork/scripts/git-fork     ~/bin/git-fork
cp plugins/agitentic/skills/git-clone/scripts/git-clone   ~/bin/git-clone
cp plugins/agitentic/skills/git-sync/scripts/git-sync     ~/bin/git-sync
cp plugins/agitentic/skills/git-create/scripts/git-create ~/bin/git-create
git fork brevdev/brev-cli
git clone brevdev/brev-cli
git sync
git create my-tool
```

### `git-fork <repo> [name] [account] [directory]`

- `<repo>` — `owner/name`, or a GitHub HTTPS / SSH URL.
- `[name]` — name to use for the fork on GitHub. Defaults to the
  upstream repo name. Pass `""` to use the default while still
  specifying `[account]` or `[directory]`.
- `[account]` — destination owner for the fork. Defaults to the
  authenticated `gh` user. Pass `""` to use the default while still
  specifying `[directory]`.
- `[directory]` — local directory to clone into. Defaults to `[name]`.

After forking, `git-fork` applies repo settings to the fork via
`gh repo edit` (see [Repo settings](#repo-settings) below).

Example:

```bash
$ git-fork brevdev/brev-cli
==> Cloning brevdev/brev-cli (remote: upstream)
==> Forking brevdev/brev-cli → robobryce/brev-cli
==> Applying repo settings to robobryce/brev-cli
==> Adding fork remote → https://github.com/robobryce/brev-cli.git
==> Done.
fork      https://github.com/robobryce/brev-cli.git (fetch)
fork      https://github.com/robobryce/brev-cli.git (push)
upstream  https://github.com/brevdev/brev-cli.git (fetch)
upstream  https://github.com/brevdev/brev-cli.git (push)
```

Use `[name]` when you want the fork on GitHub to have a different name
than the upstream — e.g. forking `nvidia/cccl` as `autocuda-cccl`:

```bash
$ git-fork nvidia/cccl autocuda-cccl
```

### `git-clone <repo> [name] [account] [directory]`

- `<repo>` — `owner/name`, or a GitHub HTTPS / SSH URL. The upstream
  repo.
- `[name]` — name of the existing fork on GitHub. Defaults to the
  upstream repo name. Pass `""` to use the default while still
  specifying `[account]` or `[directory]`.
- `[account]` — owner of the existing fork. Defaults to the
  authenticated `gh` user. Pass `""` to use the default while still
  specifying `[directory]`.
- `[directory]` — local directory to clone into. Defaults to `[name]`.

Unlike `git-fork`, this does not create a fork or apply repo settings —
the fork must already exist on GitHub.

Example:

```bash
$ git-clone brevdev/brev-cli
==> Verifying fork robobryce/brev-cli exists
==> Cloning brevdev/brev-cli into ./brev-cli (remote: upstream)
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

### `git-create <name> [account] [directory]`

- `<name>` — repository name. Just the name, not `owner/name` (use
  `[account]` for the owner).
- `[account]` — GitHub user or organization. Defaults to the
  authenticated `gh` user. Pass `""` to use the default while still
  specifying `[directory]`.
- `[directory]` — local directory to initialise. Defaults to the repo
  name.

Creates `github.com/<account>/<name>` (public), initialises
`./<directory>`, makes an empty initial commit on `main`, pushes, and
applies repo settings (see [Repo settings](#repo-settings) below).

Example:

```bash
$ git-create my-tool
==> Creating robobryce/my-tool on GitHub (public)
==> Initialising ./my-tool
==> Pushing initial commit
==> Applying repo settings to robobryce/my-tool
==> Done.
origin    https://github.com/robobryce/my-tool.git (fetch)
origin    https://github.com/robobryce/my-tool.git (push)
```

## Repo settings

`git-fork` and `git-create` both apply repo settings to the GitHub repo
they touch (the new fork or the new repo, respectively). Defaults:

| Setting                  | Default |
|--------------------------|---------|
| `delete-branch-on-merge` | `true`  |
| `enable-wiki`            | `false` |
| `enable-projects`        | `false` |
| `enable-merge-commit`    | `false` |
| `enable-squash-merge`    | `false` |

Override any subset of these by writing a `[repo]` section in
`~/.agitentic` (git config format):

```ini
[repo]
    enable-wiki = true
    enable-merge-commit = true
```

Keys map to `gh repo edit` flags. Built-in defaults still apply for
keys not in the file, so you only need to specify what you want to
change. Set `$AGITENTIC_CONFIG` to read from a different path.

## Dependencies

The following must be in your `$PATH`:

- `bash`
- `git`
- `gh`, the [GitHub CLI](https://cli.github.com/). It must be authenticated.

## Project structure

```
.agents/plugins/
  marketplace.json           - Codex and agent marketplace manifest
.claude-plugin/
  marketplace.json           - Claude Code plugin marketplace manifest
plugins/
  agitentic/
    .claude-plugin/
      plugin.json            - Claude Code plugin manifest
    .codex-plugin/
      plugin.json            - Codex plugin manifest
    skills/
      ${SKILL}/              - An individual skill
        SKILL.md             - agentskills.io skill (metadata + instructions)
        scripts/
.github/workflows/ci.yml     - Lint scripts, validate manifests, sanity-check skills
LICENSE.txt                  - Apache 2.0 with LLVM exception
```

## License

Apache License 2.0 with LLVM exception. See [`LICENSE.txt`](LICENSE.txt).
