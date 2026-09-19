# Routing

Roles are jobs, not models. Free-first means cheapest adequate: use the least expensive currently available model that is adequately qualified for the specific delegated task, escalating to subscription models only when the evidence says they materially improve the chance of success.

## Build — customized parent

Primary interactive mode for the toolkit, on the user's selected model. It starts work immediately and handles ordinary implementation, debugging, tests, refactors, GitHub reads, and web research. Build never switches its own model.

## Explore — native OpenCode

Read-only active-repository search and tracing. Build delegates here when a child context will reduce noise. Researcher may use it for bounded code questions.

## Researcher — orientation and investigation

Owns Reorient orientation and broader investigation: content index, native code search, sibling repos, web as the question requires. Read-only on project source. Load the `search-index` skill for mixed docs/data lookups; missing index hits must never block code discovery. AI-driven delegation through `role=researcher` may apply a free bias.

## Worker — bounded implementation

Use `@worker` for bounded implementation/reasoning: debugging, features, refactors, tests, architecture, terminal-heavy investigation. Call the `delegate` tool first; it runs the deterministic selector over cached roster/evidence/history and must bind the selected model at execution. This replaces treating "difficult task" as synonymous with one particular model.

## Architect — hard tradeoffs

Used for difficult plans, tradeoff evaluations, and complex technical questions. The name does not force Plan mode or an expensive model. May implement a bounded change when authorized.

## Review — independent read-only verification

Used for explicit audits and consequential changes. Prefer a different provider/model family from the implementation: pass `needs_model_diversity = true` with `exclude_model` set to the implementation model. If no adequate diverse model is available, degrade gracefully and report that independence is limited. A same-model review is not cross-model verification.

## Session promotion

The toolkit never changes the current session model automatically.

When the next phase broadly benefits from a stronger model, Build may recommend the exact model and tell the user to switch explicitly with `/models`. Load the `model-routing` skill for an evidence-backed comparison on demand.

At the end of a meaningful completed task, a one-line recommendation appears only when the likely next phase is clear and changing models would materially improve the work. Otherwise there is no routing commentary.

## Delegation

Target automatic behavior:

```text
Build
 |- native Explore
 |    source-code navigation
 |
 |- Researcher
 |    orientation and mixed-corpus investigation
 |
 |- Worker / Architect
 |    delegate binds the selected model per child
 |
 `- Review
      independent verifier, preferably another model family
```

Paid escalation is a **selection outcome**, not the definition of a role. Ordinary delegation uses cached evidence only and never triggers web research; the explicit model-routing refresh remains the research workflow.

## External research

Build uses native `websearch` and `webfetch`. The experimental Scout agent is intentionally not required.

## Economic boundary

Automatic routing and model advice may use current OpenCode free models, OpenCode Go subscription models, OpenAI OAuth models, and GitHub Copilot OAuth models. Provider-qualified overlaps remain distinct, so cost/access evidence is not silently transferred between surfaces. API-key/gateway models are excluded unless the user explicitly changes the policy.

See the `model-routing` skill for evidence and recommendation rules.

## Paid-lane failure

If a bounded Worker/Architect/Review call exhausts quota or fails at the provider after OpenCode retry handling, try the selector's fallback model when known, then return to the parent Build and continue with Researcher/Explore/web/tests. Do not repeatedly call the unavailable lane or silently select another paid/metered provider.
