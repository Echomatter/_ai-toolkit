---
name: model-routing
description: Model-choice guidance, evidence refresh and quota economics. Advice does not switch a session; delegate executes agent-initiated child work on the selected model.
---

# Model Routing

Skills do not change mode. Preserve the user's parent model and explicit provider, privacy and spending restrictions. Economics is a deterministic calculation inside the existing selector, not another agent or skill.

## Advice versus execution

For a requested next-phase recommendation, characterize the work and call `scripts/select-model.ps1`. Explain one recommended route and a useful fallback; do not switch the session. Ordinary localized work may remain in customized Build.

For agent-initiated child work, invoke `delegate` with the required role, complete bounded assignment, relevant handoff, constraints and task types. The tool already executes the child. Do not follow it with native `task` or an `@worker` invocation: that duplicates work and may inherit the wrong model. Check selected/dispatched/observed identity in the receipt. A completed execution is not proof of task correctness; validate it.

## Roles

Build is our customized parent. Worker implements bounded work. Architect resolves hard technical decisions. Researcher owns orientation and investigation using appropriate index, Explore and web sources. Review checks without editing. Roles have no permanent model identity.

Reorient's required Researcher/Worker handoff remains. Other tasks do not need every helper. Prefer a capable distinct model family for independent review when available; do not pretend a same-model review is cross-model verification.

For a bounded independent code review, call `delegate` with `role: review`, canonical `taskTypes: [code_review]`, and the actual requirements and files to inspect. Review defaults to a different canonical model from the parent; pass `excludeModel` for the implementation model if it differs from the parent. Do not lead the reviewer toward a desired verdict. Default bounded review qualifies from known coding evidence; it does not establish specialist review ability. Use `reviewMode: specialist` or the applicable consequence/deep-reasoning flags for stronger review requirements.

When the user asks for free models, set `freeOnly: true` on every applicable delegation, including follow-up reviews. This is inherited by children. `preferredCostClass: free` is a preference, not a spending limit. The CLI equivalent is `-FreeOnly true` (PowerShell 5.1). No qualifying free model means no child runs; report the diagnostics without silently trying a subscription.

## Economics and failure

Qualify capability first, then compare expected capacity consumption and scarcity. Unknown evidence is not adequacy. Missing telemetry is not unlimited quota; unknown prices are not free. Use validated task history and labeled workload estimates without making the caller guess tokens. Preserve provider-qualified routes and separate shared pools from model identity.

No separately metered gateways or unapproved overage. A known exhausted pool is not a useful fallback. The tool permits at most one appropriate read-only retry and returns failed writers for inspection. Do not create another writer while the original may still run.

Subscription children request OpenCode's native `paid_delegate` permission after selection and before session creation. Managed agents default this permission to `ask`; explicit user permission rules and saved approvals remain OpenCode's responsibility. The prompt identifies the model and surface. Declining leaves the parent unchanged and does not dispatch a child. Never approve this prompt on the user's behalf.

Require a `completed` receipt with matching selected/dispatched/observed identity before claiming a child reviewed anything. A no-route result or declined permission is not an independent review and cannot be recorded as success. A parent self-review can help but must be labeled as such. Do not repeat the same failed delegation unchanged.

## Maintenance

Ordinary routing uses dated cached evidence. Explicit evidence refresh may use Researcher for targeted current research. Index maintenance can coordinate freshness checks once, but must not create an index/routing/research loop. Provider telemetry failure must not break project search.

For an explicitly requested evidence refresh, follow [the internal procedure](evidence-refresh.md), including source provenance, confidence, alias checks and validation before accepting the cache.

After validation, use Record Outcome with the returned task ID so actual session usage is linked once. Provider/binding/infrastructure failures are not poor coding performance by the recommended model.
