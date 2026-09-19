# Verification — 2026-09-19

## Follow-up: free-only review and subscription approval

The user's two review attempts in `ses_f45708efdffeMKWqS0McUcoMrL` returned
`no_qualified_route` with zero attempts. No independent reviewer ran. The parent's
claimed successful review/outcome was incorrect; the recorder rejected those
unexecuted results and did not add false successes.

Repaired the user's FreeOnly addition: PS 5.1 boolean parsing, pre-scoring
`opencode-free` surface filtering, structured empty results, plugin/bridge wiring,
dispatch enforcement and inherited child constraints. Invalid CLI flag values fail
closed. Bounded review now requires known coding evidence and discloses that basis;
specialist/consequential reviews retain strict review-evidence requirements. Review
defaults to a distinct canonical model. No capability ratings were invented.

Validation: all eight offline suites passed, including 44 Node runtime/presentation/
usage tests. The final selector suite passed 33 checks; additional outcome tests
reject no-route and declined-permission successes without changing history.

Live free validation:

- Nemotron 3.5 Lightning parent -> Muse Spark 1.3 reviewer, completed with matching
  selected/dispatched/observed identity; scoped static review found no defects.
  Child `ses_f4531f342ffeotCN1VAniu79rw`: input 36,455, output 1,703, reasoning
  5,263, cache read 7,394, provider-reported dollars 0. Recorded once as a validated
  review observation; the parent ran the actual offline checks.
- A plain-language request, without prescribed tool arguments, made Muse delegate
  to MiMo v2.5 Free with `freeOnly: true`, role Review and model diversity. It
  completed its bounded static review without edits or findings. Receipt
  `98f8bf7082d044dce7196c31281065467f997142035497773edc451cf504c0d0`.
- Desktop displayed the native permission prompt for `openai/gpt-5.5` before any
  child creation. Deny produced `paid_permission_declined`, attempts `[]`, and no
  subscription inference. The initial Desktop test also exercised no-route reporting
  and correctly said no child ran. Native permission allows explicit saved approvals;
  it does not guarantee a new prompt after the user chooses Always Allow.

The updated plugin/profiles were installed and Desktop restarted. No paid model
inference was used in this follow-up. Session counters remain separate from parent
usage; savings remain unmeasured without a comparable parent-only baseline.
Packaging was assessed in [PACKAGING.md](PACKAGING.md), not migrated.

## Source and installed environment

Started from local main `8b496a25accb67ea31160d6b18971f38c0d8c36f`.
Fetched GitHub and incorporated the newer PR #4 branch through `d0a8690`, preserving
its native SDK adapter and isolated contracts. Completion work is on
`codex/finish-desktop-cli` in `F:\_ai-toolkit`; no merge or remote publication was performed.
OpenCode CLI is 1.18.31; installed Desktop is 1.18.31.0.

The real profile was upgraded with recoverable backups. CLI discovery returned
exactly the five toolkit skills plus OpenCode's built-in customize-opencode skill.
Desktop's helper menu visibly showed architect, researcher, review and worker,
alongside native Explore/General; Build and Plan remained in the primary menu.
The runtime tool registry had exactly content_index and delegate as toolkit tools.
The final profile was installed twice with an identical manifest; Desktop was fully
restarted and its saved successful integration result remained visible.

| Public surface | Final names |
|---|---|
| Skills | reorient, search-index, sync, model-routing, record-outcome |
| Helpers | worker, architect, researcher, review |
| Primary | customized Build; native Plan preserved |
| Tools | content_index, delegate |

Completion changes cover deployment/catalog, selector, native delegation/plugin,
outcome recording, inventory/quota refresh, read-only content indexing, launcher,
validation/doctor, retained skill procedures, behavioral tests, CI and documentation.
The final local commit and complete changed-file list are available in `git show --stat`.

## What was repaired

- Explicit catalog prevents retired source overlays from becoming installed skills.
- Ownership journals, verified links, backups and pre-copy journaling support clean,
  old, repeated, interrupted and lost-manifest installations. Same-named user files
  survive. Global user instructions outside the managed block remain verbatim.
- Fixed PowerShell 5.1 JSON-array handling and null backup-path atomic replacement.
- Real child execution uses native SDK sessions, role permissions, explicit models,
  bounded waits, abort checks and worktree writer locks. No parent model switch.
- No-write assignments and read-only roles block shell, edits, unknown mutating tools
  and index rebuilds; restrictions persist through native descendants and restart.
- Required unknown capabilities/context cannot qualify through a strong average.
  Qualified free routes win ordinary work; consequential escalation explains its
  capability advantage. Null, singleton, diversity and stay-put metadata are tested.
- Outcome upserts preserve corrections, review links and execution attempts. Runtime
  session identities and per-child counters remain distinct from account estimates.
- Inventory refresh no longer rewrites timestamps or truncates nested outcome history;
  corrupt model evidence is preserved. Evidence refresh has a retained internal procedure.
- CLI launcher uses the installed integration, avoiding duplicate source/global hooks.
- A free provider failure may retry one qualified free reader; it cannot silently
  fall through to subscription inference. Paid failures return directly to Build.

## Live provider and Desktop evidence

These are actual session/message records, independently checked against the durable
receipts under `.state/delegation`, not model self-reports or offline SDK fixtures.

| Entry point | Parent before and after | Child role | Selected = dispatched = observed | Result |
|---|---|---|---|---|
| CLI | opencode/big-pickle | worker | opencode/muse-spark-1.3-contributor-free | Read catalog and returned all five skills |
| Desktop UI | opencode/muse-spark-1.3-contributor-free | worker | openai/gpt-5.6-sol | Read catalog and returned all five skills |
| CLI Reorient | opencode/muse-spark-1.3-contributor-free | researcher, then worker | opencode/mimo-v2.5-free for both | Orientation completed before the exact authorized one-word edit |

First proof receipt: `f043dffd36ffbdd630faadf742eab5c9a2ba85539bef7076d0edf59822b16429`.
Desktop proof receipt: `3f52c3edf626b0f25cd61ae46a55a273d51a518c5e48c945c49903f1ad4ae6ca`.
The first child reported 7,611 input, 330 output and 7,266 cache-read tokens; the
Desktop child reported 6,104 input, 73 output and 5,632 cache-read tokens.
Both reported provider cost zero; this does not imply zero subscription-quota use.

The real parent assistant-message histories retained their original model IDs.
A deliberately wrong expected model was rejected against both live child histories.
Reconstructed guards using actual stored child metadata rejected shell and index
rebuild calls and allowed read. These checks made no provider requests or shell calls.

The free provider rejects requests when a bash deny removes the native shell schema.
A controlled pair of native requests reproduced that behavior. The adapter keeps
that schema visible and rejects shell execution in the pre-tool hook. Explicit user
bash denies remain authoritative; such a provider may reject those user configurations.
Full process restart is necessary after plugin changes because module imports are cached.

## Tests actually run

All offline commands use Windows PowerShell 5.1. CI runs the deterministic suites
without credentials; live commands are opt-in and excluded from CI.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-all.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/validate.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-advisor.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-delegate.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-quota-routing.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-content-index.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/deployment-contract.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/outcome-contract.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/refresh-contract.ps1
node --test tests/delegate-runtime.test.mjs
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/live-delegation.ps1 -Live
node tests/verify-runtime-evidence.mjs http://127.0.0.1:41967 .state/delegation/f043dffd36ffbdd630faadf742eab5c9a2ba85539bef7076d0edf59822b16429.json
node tests/verify-runtime-evidence.mjs http://127.0.0.1:41967 .state/delegation/3f52c3edf626b0f25cd61ae46a55a273d51a518c5e48c945c49903f1ad4ae6ca.json
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/install.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/refresh-quota.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1
scripts\opencode.cmd debug skill
```

Results: offline suites pass; the final delegation run passes all 33 behavioral
tests; structural validation has zero failures/warnings;
live cross-model contract and both runtime-evidence checks pass. Doctor has zero
failures and one expected warning: evidence coverage is PARTIAL. Install fixtures
cover clean, upgrade, repeat, interruption, partial/lost manifest, unrelated legacy
and canonical conflicts, stale source overlays, instruction preservation and backups.

Delegation fixtures cover paid-parent/free-child, free-parent/stronger-child,
independent review, no route, wrong model, permission refusal, cancellation,
ambiguous dispatch, writer locking, tool continuation and restart. Nested depth 2
is tested offline; the real user's unset depth remains OpenCode's default 1.
No broad shell approval rule or depth increase was installed. The follow-up adds
only the narrow `paid_delegate: ask` default to managed agents.
The inspected user configuration retains `permission: "allow"` and an unset depth.
Helpers inherit native permissions and parent session rules; Researcher/Review and
explicit no-write assignments additionally receive edit denies plus pre-tool guards.
Selector fixtures pass free-first, unknown capability/context, zero candidates,
singleton compound work, stay-put metadata, diversity and blocked subscription pools.
Outcome fixtures pass correction upserts, fallback attempt linkage, review-defect
retention and explicit implementation/review links without duplicate observations.

## Coverage boundaries

Go was weekly-limited and Copilot's live small-model request reported exhausted
monthly quota. They were not retried. The connected ChatGPT account explicitly
rejected gpt-5.3-codex-spark as unsupported; that model-specific failure is cached
locally. These are provider/account limitations, not implementation success claims.
The initial pass covered paid-parent/free-child and independent Review with fixtures;
the follow-up above also verified two live free independent reviews. We did not
spend more subscription quota to make every branch live. Desktop did
successfully exercise free-parent/subscription-child execution.

Evidence remains partial for some newly discovered models; unknown capability
never earns adequacy. API-price proxies and aggregate account counters are estimates,
not exact subscription consumption. Shell/tool stop observations cannot prove that
an arbitrary detached OS process has stopped; failed writers are never automatically
replaced. Reorient's bounded live test passed; it is not an exhaustive model benchmark.
Local raw logs, runtime receipts and account telemetry stay in ignored `.state`.
