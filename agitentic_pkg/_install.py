"""`agitentic install-plugins` — register the agent plugin with every host.

agitentic ships no Python runtime; its skills are shell scripts. The one
thing a `pip install` cannot do on its own is make the host discover the
skills — Claude Code and Codex each read a plugin marketplace. This
command performs those registrations:

  * Claude Code — `claude plugin marketplace add <repo>` +
    `claude plugin install <plugin>@<marketplace> --scope user`.
  * Codex — `codex plugin marketplace add <repo>` +
    `codex plugin add <plugin>@<marketplace>`.

Every step degrades to a warning rather than an error when a host binary
is absent or a registration returns non-zero, so installing on a
Claude-only or Codex-only box — or re-running — is safe and idempotent.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

# The marketplace repo (hosts .claude-plugin/marketplace.json at its root),
# the marketplace name that manifest declares, and the plugin within it.
MARKETPLACE_REPO = "brycelelbach/agitentic"
MARKETPLACE_NAME = "robobryce-agitentic"
PLUGIN_NAME = "agitentic"


def _warn(msg: str) -> None:
    print(f"warning: {msg}", file=sys.stderr)


def _run(cmd: list[str]) -> bool:
    """Run a host command, streaming output. True on exit 0, else warn."""
    try:
        proc = subprocess.run(cmd, check=False)  # noqa: PLW1510 (check handled)
    except OSError as exc:
        _warn(f"{cmd[0]} failed to launch: {exc}")
        return False
    if proc.returncode != 0:
        _warn(f"`{' '.join(cmd)}` returned {proc.returncode}")
        return False
    return True


def _install_for_host(host_bin: str, repo: str) -> None:
    """`<host> plugin marketplace add` + install/add. `claude` uses `plugin
    install ... --scope user`; `codex` uses `plugin add`."""
    if not _run([host_bin, "plugin", "marketplace", "add", repo]):
        _warn(
            f"{host_bin} marketplace add {repo} did not succeed "
            "(no access, or already added) — continuing."
        )
    if host_bin == "claude":
        _run(
            [
                host_bin,
                "plugin",
                "install",
                f"{PLUGIN_NAME}@{MARKETPLACE_NAME}",
                "--scope",
                "user",
            ]
        )
    else:
        _run([host_bin, "plugin", "add", f"{PLUGIN_NAME}@{MARKETPLACE_NAME}"])


def install_plugins(
    repo: str = MARKETPLACE_REPO, *, claude: bool = True, codex: bool = True
) -> int:
    """Register the plugin with whichever of Claude Code / Codex is present.
    Returns 0 always — a host being absent is not an error, since this also
    runs as the one-time auto-registration on first invocation and must
    never fail the command the user actually asked for."""
    did_something = False
    if claude and shutil.which("claude"):
        print("Registering the agitentic plugin with Claude Code…")
        _install_for_host("claude", repo)
        did_something = True
    elif claude:
        _warn("claude not on PATH; skipping Claude Code plugin registration.")
    if codex and shutil.which("codex"):
        print("Registering the agitentic plugin with Codex…")
        _install_for_host("codex", repo)
        did_something = True
    elif codex:
        _warn("codex not on PATH; skipping Codex plugin registration.")
    if not did_something:
        _warn(
            "neither `claude` nor `codex` was found on PATH; nothing was registered. "
            "Re-run `agitentic install-plugins` once a host CLI is available."
        )
    return 0


def _sentinel_path() -> Path:
    """Per-install marker recording that auto-registration has run once."""
    base = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    return Path(base) / "agitentic" / "plugins-registered"


def auto_install_once() -> None:
    """Register the plugin the first time the console command runs after a
    `pip install`, then never again. A `pip install` cannot run code itself
    (pip builds a wheel, bypassing setup hooks), so registration is deferred
    to the next invocation. Set `AGITENTIC_NO_AUTO_INSTALL=1` to opt out.
    Best-effort: any failure here never blocks the command the user ran."""
    if os.environ.get("AGITENTIC_NO_AUTO_INSTALL"):
        return
    sentinel = _sentinel_path()
    if sentinel.exists():
        return
    try:
        sentinel.parent.mkdir(parents=True, exist_ok=True)
        sentinel.write_text("")
    except OSError:
        return  # no writable state dir → skip silently, run again next time
    try:
        install_plugins()
    except Exception:  # noqa: BLE001 — auto-registration must never break the command
        pass


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="agitentic install-plugins",
        description="Register the agitentic agent plugin with Claude Code and Codex.",
    )
    parser.add_argument(
        "--repo",
        default=MARKETPLACE_REPO,
        help=f"marketplace repo (owner/name). Default: {MARKETPLACE_REPO}.",
    )
    parser.add_argument(
        "--claude-only", action="store_true", help="register only with Claude Code."
    )
    parser.add_argument(
        "--codex-only", action="store_true", help="register only with Codex."
    )
    args = parser.parse_args(argv)
    return install_plugins(
        args.repo,
        claude=not args.codex_only,
        codex=not args.claude_only,
    )


if __name__ == "__main__":
    sys.exit(main())
