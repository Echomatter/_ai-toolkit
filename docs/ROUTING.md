# Routing

Roles are stable; models are dynamically selected. Free-first means cheapest adequate: use the least expensive currently available model that is adequately qualified for the specific delegated task, escalating to subscription models only when the evidence says they materially improve the chance of success.

## Build — routine/free

Primary interactive mode for the toolkit. It starts work immediately and handles ordinary implementation, debugging, tests, refactors, GitHub reads, and web research.

## Explore — native OpenCode

Read-only active-repository search and tracing. Build delegates here when a child context will reduce noise.

## Index — free mixed-corpus retrieval

Use `@index` for exhaustive discovery across project docs, structured data, PDFs, spreadsheets, and archives. It is pinned to the free Build model so paid agents can offload retrieval before spending subscription-model context. The `delegate` tool with `role=index` always applies a free bias.

Use native Explore for source-code symbols/call paths; Index is for the broader project knowledge/data corpus.

## Worker — dynamic delegated execution

Use `@worker` for bounded implementation/reasoning: debugging, features, refactors, tests, ML/DSP/firmware work, architecture, and terminal-heavy investigation. Call the `delegate` tool first; it runs the deterministic selector over cached roster/evidence/history and returns the selected model plus execution guidance. The selector decides which model performs the Worker role — this replaces treating "difficult task" as synonymous with one particular model.

## Deep — explicit strong-model escalation

Used when the user deliberately wants the strongest available model regardless of free-first automatic routing, when adequate-model attempts have already failed, or when the remaining work genuinely exceeds what free/adequate models can handle. Automatic routing increasingly prefers `delegate(role="worker", ...)` over `@deep` for ordinary difficult tasks. `@deep` remains available as the explicit escape hatch.

A hard **chunk** can be delegated to Deep automatically while the parent Build session remains on its current model.

## Review — independent read-only lane

Used for explicit audits and consequential changes. Prefer a different provider/model from the implementation: pass `needs_model_diversity = true` with `exclude_model` set to the implementation model. If no adequate diverse model is available, degrade gracefully and report that independence is limited.

## Session promotion

The toolkit never changes the current session model automatically.

When the next phase broadly benefits from a stronger model, Build may recommend the exact configured model and tell the user to switch explicitly with `/models`. Use `/recommend-model` for an evidence-backed recommendation on demand.

At the end of a meaningful completed task, a one-line recommendation appears only when the likely next phase is clear and changing models would materially improve the work. Otherwise there is no routing commentary.

## Delegation

Target automatic behavior:

```text
Build
 |- native Explore
 |    source-code navigation
 |
 |- Index
 |    free mixed-corpus retrieval
 |
 |- Dynamic Worker
 |    selector chooses actual model
 |
 `- Review
      selector chooses independent verifier
```

Paid escalation is a **selection outcome**, not the definition of a role. Ordinary delegation uses cached evidence only and never triggers web research; `/refresh-model-evidence` remains the explicit research workflow.

## External research

Build uses native `websearch` and `webfetch`. The experimental Scout agent is intentionally not required.

## Economic boundary

Automatic routing and model advice may use only current OpenCode free models, OpenAI OAuth models, and GitHub Copilot OAuth models. API-key/gateway models are excluded unless the user explicitly changes the policy.

See `MODEL-ADVISOR.md` for evidence and recommendation rules.

## Paid-lane failure

If a bounded Deep/Review/Worker call exhausts quota or fails at the provider after OpenCode retry handling, try the selector's fallback model when known, then return to free Build and continue with Index/Explore/web/tests. Do not repeatedly call the unavailable lane or silently select another paid/metered provider.
