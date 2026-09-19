# Verification and remaining integration gates

This repair replaces advice-only delegation with a bounded native-session adapter.
It does not claim that every provider or installed OpenCode release was tested live.
The complete v3 product brief is a continuing contract, not a blanket completion claim.

## Isolated automated checks

- `node --test tests/delegate-runtime.test.mjs`: controller tested with a fake SDK and independently returned messages, including a deliberately wrong-model adapter.
- `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/selector-contract.ps1`: isolated quota, economics, capability, context, identity, and no-candidate cases.
- `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/deployment-contract.ps1`: install twice, reconcile drift with backup, uninstall and reinstall in a temporary home.
- `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/outcome-contract.ps1`: actual-receipt attribution, outcome upserts, preserved review findings and corrupt-history protection.
- Existing structural and content-index smoke checks remain in Windows CI.

Default tests do not read production credentials, alter real history, call a paid model, merge real branches, or edit the user's installed profile. Fixture successes do not become model capability evidence.

## Required installed-runtime gate

After isolated checks pass, test the candidate deployment in an isolated profile or disposable worktree. The normal deployment command is:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "F:\_ai-toolkit\scripts\install.ps1"
```

Fully quit and restart OpenCode; the old process has not loaded new source merely because files changed. Use the real `delegate` tool on a bounded read-only inspection, selecting a qualified child different from the parent. Inspect the actual session/message records and `.state/delegation` receipt: selected, dispatched and observed route, parent unchanged, role, permissions, tool continuation, returned result. Repeat free-parent/Go-child when both routes are usable. Same-model-only execution does not prove cross-model binding.

The adapter expects the v1 SDK client's `session.create/get/message/messages/promptAsync/status/abort`, `app.agents` and `config.get`. Server parent linkage and per-session permissions are checked before sending inference. A runtime that strips them is rejected rather than used unrestricted. The pre-inference model hook and separately observed message metadata are different checks. This proves provider-reported route identity, not undisclosed underlying model weights.

Cancellation uses native abort, two idle observations and no outstanding tool parts. This cannot prove that arbitrary detached user shell processes stopped. Consequently failed writers are never automatically replaced: inspect partial changes and detached work first. Unverified stop retains a writer lock under `.state/delegation`; do not clear it until the relevant execution is inspected and stopped.

## Scope and honest limitations

- Economics remains in the existing selector. No Economics agent, second scheduler, or additional public skill is introduced.
- Reorient's Researcher-to-Worker handoff and Sync are skill-driven workflows; the complete live end-to-end scenarios still require the installed runtime. Controller fixtures alone do not certify them.
- The injected SDK plugin has not been exercised with the user's authenticated Desktop/CLI and real model routes by these offline tests. Independent live Go-model review is also pending.
- Managed read-only children cannot execute arbitrary shell, mutations, or unknown custom tools. Build performs authorized validation/index maintenance and supplies the evidence. No-file-changes requests also prohibit index rebuilds.
- Execution completion is not task correctness. Receipt validation stays pending until actual checks are recorded with Record Outcome. Coarse all-session CLI measurements remain estimates; structured child counters are preferred.
- Normalized Go/Copilot comparisons use existing public-pricing priors and reported entitlements. ChatGPT API-rate proxies are not calibrated subscription quota. Detailed active-model/tool/wait timing, pricing tiers/cache-write costs, and measured cross-provider savings are not yet fully calibrated.
- Failure scope is conservative. Unknown-reset auth/model/pool failures may require an explicit verified repair before their specific block is removed. Do not erase all account state/history to recover one route.
- A stale telemetry-only exhaustion observation still needs durable recovery-state reconciliation across provider windows; fresh execution failures are recorded separately. Current inventory refresh ordering and automatic evidence/price maintenance also need further work.
- Existing discovery diagnostics, refresh scripts and documentation outside the repaired execution path may still contain legacy assumptions. Validate the actual deployed catalog, not those older summaries alone.
- Preserve the v3 requirements for nested shared budgets, in-flight quota reservations, controlled model trials, full resume reconciliation, explicit coordinated maintenance, baseline comparisons, and richer learning. They are not silently implemented by this controller.

## Deployment safety

Only manifest-owned targets inside recognized deployment roots are retired/replaced. Changed copies and removed links receive backups outside discovery. Actual link targets and content are verified. Unowned conflicts fail rather than being deleted by name. Templates remain outside agent discovery. A malformed manifest/history is preserved, not replaced with an empty success state.

Source-level consistency is not a substitute for the installed-runtime gate. Report source, fixture, CI, live provider and user-installation results separately.
