"""Console-script entry point for `agitentic`.

agitentic has no CLI of its own — its skills are shell scripts the host
runs. The `agitentic` console command exists to register the plugin with
the hosts: `agitentic install-plugins` does it explicitly, and a bare
`agitentic` invocation runs the one-time auto-registration and prints how
to invoke the skills.
"""

from __future__ import annotations

import sys

from agitentic_pkg._install import auto_install_once
from agitentic_pkg._install import main as install_main

_USAGE = """\
agitentic — git skills for coding agents (a Claude Code / Codex plugin).

The skills run inside your agent host, not from this command. This command
registers the plugin so the host can discover them:

  agitentic install-plugins      register the plugin with Claude Code / Codex
                                 (also runs once automatically after install)

Then invoke a skill with your host's syntax, e.g. `/agitentic:git-fork`
(Claude Code) or `$agitentic git-fork` (Codex).
"""


def main(argv: list[str] | None = None) -> int:
    args = sys.argv[1:] if argv is None else argv
    if args and args[0] == "install-plugins":
        return install_main(args[1:])
    # Bare / unrecognised invocation: do the one-time auto-registration and
    # show how to reach the skills.
    auto_install_once()
    sys.stdout.write(_USAGE)
    return 0


if __name__ == "__main__":
    sys.exit(main())
