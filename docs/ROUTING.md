# Routing

## Build — routine/free

Primary interactive mode for the toolkit. It starts work immediately and handles ordinary implementation, debugging, tests, refactors, GitHub reads, and web research.

## Explore — native OpenCode

Read-only active-repository search and tracing. Build delegates here when a child context will reduce noise.

## Index — free mixed-corpus retrieval

Use `@index` for exhaustive discovery across project docs, structured data, PDFs, spreadsheets, and archives. It is pinned to the free Build model so paid agents can offload retrieval before spending subscription-model context.

Use native Explore for source-code symbols/call paths; Index is for the broader project knowledge/data corpus.

## Deep — strong subscription lane

Used only after concrete escalation conditions: repeated bounded failure, unresolved architecture/state boundaries, hard algorithmic or high-consequence work, unexplained validation failures, or explicit request for strongest reasoning.

A hard **chunk** can be delegated to Deep automatically while the parent Build session remains on its current model.

## Review — independent read-only lane

Used for explicit audits and consequential changes. Prefer a different provider/model from Deep.

## Session promotion

The toolkit never changes the current session model automatically.

When the next phase broadly benefits from a stronger model, Build may recommend the exact configured model and tell the user to switch explicitly with `/models`. Use `/recommend-model` for an evidence-backed recommendation on demand.

At the end of a meaningful completed task, a one-line recommendation appears only when the likely next phase is clear and changing models would materially improve the work. Otherwise there is no routing commentary.

## External research

Build uses native `websearch` and `webfetch`. The experimental Scout agent is intentionally not required.

## Economic boundary

Automatic routing and model advice may use only current OpenCode free models, OpenAI OAuth models, and GitHub Copilot OAuth models. API-key/gateway models are excluded unless the user explicitly changes the policy.

See `MODEL-ADVISOR.md` for evidence and recommendation rules.

## Paid-lane failure

If a bounded Deep/Review call exhausts quota or fails at the provider after OpenCode retry handling, return to free Build and continue with Index/Explore/web/tests. Do not repeatedly call the unavailable lane or silently select another paid/metered provider.
