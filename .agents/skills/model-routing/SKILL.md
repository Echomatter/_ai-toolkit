---
name: model-routing
description: Use when deciding whether the current OpenCode Build session should handle work itself or delegate to Explore, Index, Deep, or Review; prefer deterministic/free retrieval and escalate to subscription models only when the task evidence justifies it.
---

# Model Routing

Skills never change the active OpenCode mode. Only OpenCode runtime/user agent selection determines Build vs Plan.

Goal: finish the work with the cheapest adequate path without turning routing into a conversation of its own.

## Lanes

- **Build**: native primary agent on the routine/free model. Normal implementation, bounded debugging, tests, and ordinary research.
- **Explore**: native read-only source-code/repository search and tracing.
- **Index**: free read-only mixed-corpus retrieval over docs, structured data, PDFs, spreadsheets, archives, and other indexed project sources.
- **Worker**: generic implementation/reasoning subagent for bounded delegated tasks. The selector chooses which model performs the role; call the `delegate` tool first and invoke the recommended agent.
- **Deep**: explicit strong-model escalation lane. Reserved for deliberate escalation, not every difficult task.
- **Review**: independent read-only verification when warranted, seeking model/provider diversity from the implementation.

For public/upstream information use native web tools. For source-code symbols/call paths use Explore. For mixed project content and "find all" work use Index.

## Free-first retrieval

Before escalating:
1. inspect the actual repo state;
2. use grep/LSP/Explore for code;
3. use Index for large mixed corpora or completeness searches;
4. use native web tools for current public information;
5. run bounded deterministic validation.

Do not spend paid-model context rediscovering material that a free/deterministic tool can narrow first.

## Stay in Build when

- the task is localized or mechanically understandable;
- tests or bounded validation can settle correctness;
- one or two bounded attempts are reasonable;
- retrieval can reduce uncertainty enough to continue safely;
- a free model can complete the work.

## Escalate to Deep when

`@deep` means explicitly requesting strong-model escalation. Use it only when at least one is true after narrowing:

- the user explicitly requests the strongest available reasoning model;
- bounded implementation/debug attempts with adequate models failed without a materially new hypothesis;
- the remaining work genuinely exceeds what free/adequate models can handle (ambiguous architecture/state ownership, subtle algorithms, realtime/DSP/ML, security, firmware/recovery, irreversible data operations, or unexplained validation failures the free model cannot explain).

For ordinary difficult tasks, prefer `delegate(role="worker", ...)` and let the selector choose the least-expensive adequate model.

Prefer a **bounded @deep chunk** over switching the whole session. This preserves the free Build parent as a natural fallback.

## Paid-model failure handling

A failed paid escalation is not automatically a failed task.

If Deep, Review, or Worker becomes unavailable because of quota exhaustion, rate limiting, provider outage, authentication failure, or another provider-side error after OpenCode's own retry handling:
- try the selector's fallback model when known;
- do not loop on the same paid lane;
- return to the free Build parent;
- continue with Index, Explore, native web tools, and deterministic tests where useful;
- narrow the unresolved problem as far as possible on free tools;
- do not silently jump to a different paid provider or a metered API route;
- if the remaining work truly requires stronger reasoning to be safe, report the unavailable escalation and the specific unresolved point.

If the user manually switched the whole session to a paid model, automatic session failover is outside this toolkit's control. Prefer chunk delegation when graceful fallback matters.

## Review

Use Review for explicit audits, consequential changes, broad Deep changes, or when independent model diversity materially reduces risk. Review is read-only.

If Review is unavailable, perform a best-effort free verification pass using Build plus Index/Explore/tests and state that independent paid verification was unavailable if it matters.

## Promotion semantics

- **Retrieval delegation:** use `@index` or `@explore` freely to keep the parent context small.
- **Implementation delegation:** call the `delegate` tool, then invoke the recommended agent (normally `@worker`).
- **Chunk escalation:** send only the narrowed hard part to `@deep` when explicit escalation is warranted.
- **Session promotion:** recommend `/models` only when the remaining phase broadly needs the stronger model and the benefit is material.
- **Verification:** use `@review` / `/audit` when independent verification is worth the extra model call, seeking diversity from the implementation model.
- **Stay put:** if free Build plus validation is adequate, do not recommend a switch.

## Economic boundary

Automatic routing may use only:
- current OpenCode free hosted models;
- ChatGPT subscription models connected through OpenAI OAuth;
- GitHub Copilot subscription models connected through Copilot OAuth.

There is no local-model engine path. Do not automatically route into separately metered API-key providers or gateways.
