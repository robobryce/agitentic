"""agitentic — pip-installable installer for the agitentic agent plugin.

agitentic's skills are self-contained shell scripts, so there is no Python
runtime to ship. What a `pip install` adds is the host-registration step a
`pip install` alone cannot do: registering the plugin with Claude Code
and/or Codex so the `agitentic:*` skills are discoverable. That runs via
the `agitentic install-plugins` console command, which the package also
triggers once on first invocation.
"""

from pathlib import Path

__all__ = ["plugin_root"]


def plugin_root() -> Path:
    """Absolute path to the bundled `plugins/agitentic/` payload."""
    return Path(__file__).resolve().parent / "plugins" / "agitentic"
