# Migration from earlier toolkit versions

The canonical architecture is now OpenCode routed execution. Zed/Copilot/Codex-specific agent profiles and the old switchboard are not part of this package.

`bootstrap.cmd` now cleans the exact legacy skill names and retired Copilot/Codex agent-profile filenames emitted by earlier editions of this toolkit, even when the old `.state/install-manifest.json` was lost because the toolkit folder was replaced. Existing manifest-owned current skills are left for the normal installer to refresh.

If you intentionally reused one of those exact legacy names for your own unrelated customization, run bootstrap with `-PreserveLegacyToolkitArtifacts` through PowerShell instead of the `.cmd` wrapper and reconcile that item manually.

Normal migration is simply:

```powershell
F:\_ai-toolkit\scripts\bootstrap.cmd
F:\_ai-toolkit\scripts\refresh-routing.cmd
F:\_ai-toolkit\scripts\doctor.cmd -Deep
```

Do not delete editor/provider configuration until this OpenCode workflow works on a real repository.
