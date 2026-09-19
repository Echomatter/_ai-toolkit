<p align="center"><img src="assets/tokenomics-banner.svg" alt="Tokenomics AI Tool Kit" width="900"></p>

# Tokenomics AI Tool Kit · V1

Keep a capable model in charge. Give bounded work to suitable cheaper models, verify
what actually ran, and learn from validated results.

**V1 targets OpenCode Desktop 1.18.31.** The same backend supports OpenCode CLI.
OpenCode owns models, authentication, permissions, native tools and child sessions.

| Folder | Responsibility | Status |
|---|---|---|
| [Tokenomics-OpenCode-Desktop](Tokenomics-OpenCode-Desktop/) | Backend plugin: routing, delegation, outcome recording and structured activity | V1 |
| [Tokenomics-OpenCode-Terminal](Tokenomics-OpenCode-Terminal/) | Future terminal UI: sidebar, dialogs and detailed screens | Design boundary; CLI already uses the backend |
| [Tokenomics-Codex-Desktop](Tokenomics-Codex-Desktop/) | Codex implementation | Stub; TBD |

## Start

Clone this repository and run from its root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Tokenomics-OpenCode-Desktop\scripts\install.ps1
```

Fully restart OpenCode after installing. Open the repository root for cross-folder
work, or the Desktop folder for backend development. Use [the orientation prompt](OPENCODE-ORIENTATION.md)
to update an existing conversation after the folder move.

The installer preserves unrelated global instructions, credentials and conversations.
It migrates the old owned root locator and deployment links. Local receipts, usage,
quota observations and capture files stay in the Desktop folder's ignored .state.

## What V1 does

- Keeps the selected parent model; binds each automatic child to its selected route.
- Shows the real child's model and current tool activity in a native clickable chat card.
- Enforces free-only delegation and uses OpenCode's native paid-child permission prompt.
- Records actual session usage, failures and separately validated outcomes.
- Refreshes evidence in bounded, source-backed batches without changing model weights.

The public catalog remains five skills, customized Build plus four helpers, and two
tools. No replacement router UI, model selector or context manager is installed.

See [Desktop documentation](Tokenomics-OpenCode-Desktop/README.md),
[V1 verification](Tokenomics-OpenCode-Desktop/docs/V1-VERIFICATION.md) and
[packaging boundaries](Tokenomics-OpenCode-Terminal/README.md).
No npm publication or terminal UI migration is included in V1.
