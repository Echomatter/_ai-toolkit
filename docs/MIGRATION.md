# Migration from earlier toolkit versions

The canonical architecture is now OpenCode routed execution. Zed/Copilot/Codex-specific agent profiles and the old switchboard are not part of this package.

`scripts/install.ps1` installs the explicit `opencode/catalog.json` catalog. Stale retired source folders are ignored. It replaces the manifest-owned advisory delegate file with the executing plugin tool and does not recreate command wrappers.

Retirement requires a manifest entry, independent ownership journal, or verified link into this toolkit. A legacy name alone is never ownership. Ambiguous legacy items survive with a warning; unowned canonical conflicts stop installation. Changed owned resources receive recoverable backups outside discovery.

Normal migration is simply:

```powershell
F:\_ai-toolkit\scripts\bootstrap.cmd
F:\_ai-toolkit\scripts\refresh-routing.cmd
F:\_ai-toolkit\scripts\doctor.cmd -Deep
```

Each resource is journaled before copying. Rerun installation after interruption. A lost checkout manifest recovers from the independent journal under `~/.local/share/ai-toolkit/installations`. If both journals are lost, copies remain conflicts; verified links can still establish ownership. Malformed journals are preserved and reported.

Global AGENTS.md text outside the managed block is preserved verbatim. Resource and instruction backups live under `~/.local/share/ai-toolkit/backups`. Fully restart OpenCode after installation; a running process can cache imported plugin modules. Desktop and CLI share the installed integration. Do not delete provider credentials, configuration or conversations.
