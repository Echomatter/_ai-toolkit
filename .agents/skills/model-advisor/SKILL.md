---
name: model-advisor
description: Evaluate the entire eligible model library for the next phase; recommend one model and at most one fallback; grounded in task fit, current access, and fresh evidence without switching models automatically.
---

# Model Advisor

Evaluate the entire currently eligible model library to recommend the best model for the next phase. Do not turn every task into a model comparison.

## Critical invariant

Lane assignment != capability evidence.

Lane membership (Routine/Deep/Review) may be a weak operational prior. It must never be decisive proof that a model is best. The advisor must evaluate the entire eligible library independently.

## Economic boundary

Automatic or recommended routes may use only:

- current OpenCode free models;
- models available through OpenAI OAuth / the user's ChatGPT subscription;
- models available through GitHub Copilot OAuth / the user's Copilot subscription;
- optional local Ollama models.

Do not recommend metered API-key providers, OpenRouter, Vercel AI Gateway, or other separately billed gateways unless the user explicitly changes this policy.

Treat economics accurately:

- OpenCode free models: currently free, but availability can change.
- OpenAI OAuth and GitHub Copilot OAuth: subscription/quota access, not a per-token API price.
- local Ollama: no marginal model charge, but local compute/time still matters.

Never claim remaining subscription quota unless a tool actually reports it.

## Decide what the next phase needs

Classify the actual next work, not the prestige of the model name. Useful task dimensions include:

- routine localized implementation;
- repository search/tracing;
- broad architecture or state ownership;
- difficult debugging with failed bounded attempts;
- algorithmic, DSP, ML, firmware, security, concurrency, or data-integrity reasoning;
- large-context synthesis;
- independent verification;
- tool-heavy GitHub/research work.

Prefer staying on the current model when deterministic validation can settle the task cheaply.

### Task characterization axes

```text
repo_navigation       simple_edit       bounded_feature
large_refactor      debugging       architecture
code_review         terminal_heavy  ml
dsp                   firmware        reverse_engineering
research              documentation test_generation
long_context_reading  independent_verification
```

Also determine requirements:

```text
needs_writes
needs_terminal
needs_web
needs_large_context
needs_deep_reasoning
needs_model_diversity
high_consequence_if_wrong
```

Do not force every task into exactly one category. A task may be:

```text
code_review + terminal_heavy + ml + independent_verification
```

That combination should influence selection.

### Resource shape estimation

Estimate resource shape using defensible bands:

```text
context_demand: tiny / small / medium / large / very_large
reasoning_demand: low / medium / high
tool_demand: low / medium / high
iteration_demand: low / medium / high
verification_demand: low / medium / high
```

Do not invent exact token needs unless actual information is available.

## Inventory the eligible library

1. Run `opencode models --refresh` and inspect `opencode auth list` to discover what is actually available.
2. Exclude providers that are not eligible under the economic boundary above:
   - OpenAI model exists but OAuth absent → excluded.
   - OpenAI OAuth present → eligible.
   - Copilot model exists but OAuth absent → excluded.
   - Copilot OAuth present → eligible.
   - OpenCode free model → eligible while currently listed.
   - API-key-only provider → excluded from automatic routing.
   - Ollama model → eligible only when actually installed locally.
3. Load the generated roster from `routing/model-roster.json`.
4. Load capability evidence from `routing/model-evidence.json`.

## Evidence readiness states

The advisor reports one of three readiness states:

- **UNPOPULATED**: No meaningful sourced capability evidence. Must research before consequential recommendation.
- **PARTIAL**: Some serious candidates researched, others not. Use what exists; flag gaps.
- **READY**: All currently serious candidate models have enough current evidence for meaningful comparison.

If `/recommend-model` finds top candidates are close AND relevant evidence is stale, then research current evidence before deciding. Otherwise use the cache.

## Evaluate all eligible models

For each model in the eligible library, assess the following capability dimensions. Each rating must be traceable to a source:

### VERIFIED LOCAL

- Model exists in current OpenCode inventory (roster).
- OAuth provider connected (detected by `opencode auth list`).
- Model successfully completed a task in local history (from `routing/task-history.json`).
- Model failed tests or required escalation.

### PROVIDER-REPORTED

From official model/provider documentation (stored in `model-evidence.json`):

- Context window (input/output tokens).
- Tool support (file edits, terminal, web).
- Provider-described coding focus.
- Reasoning controls and strengths.

### INDEPENDENT

External benchmark/evaluation evidence (stored in `model-evidence.json`):

- Repository understanding benchmarks.
- Long-horizon software engineering results.
- Terminal/agentic work results.
- Code repair effectiveness.
- Reasoning benchmarks.

Do not treat a benchmark as a universal model ranking.

### VERIFIED CATALOG

- Current provider/catalog identity or availability fact (model listed, retired, renamed, stealth/undisclosed).
- Free-model identity/pricing status from the host catalog, never as coding-quality evidence.

### INFERRED

Derived conclusion such as:

> This model appears better suited to a terminal-heavy debugging task.

Keep the inference separate from source facts.

#### Capability rating bands

Prefer qualitative bands with confidence:

```text
strong / good / adequate / weak / unknown
```

with:

```text
confidence = high / medium / low
```

If a capability is completely unknown, store `unknown` rather than guessing.

## Ledger quality rules (schema v2)

`routing/model-evidence.json` is the ledger. Every entry must meet these rules so future recommendations stay evidence-based instead of decaying into folklore:

1. **Canonical identity via `alias_index`.** Every eligible roster ID resolves to one canonical entry. Fast/mini/year variants share the canonical entry; record SKU-level differences (speed/effort/config) as cautions, never as separate invented evidence.
2. **Provenance via `sources` registry.** Every capability cites source keys; every source records publisher, URL, retrieval date, what it supports, and any caution. A claim without a registered source is not evidence.
3. **`research_status` per model, honestly set:** `researched_current` (provider + independent, current) / `provider_researched` (positioning only, no independent run) / `partially_researched` / `identity_only` (e.g. stealth models — empirical history only) / `stale_variant` (superseded; do not research twice, point at the current variant).
4. **No bare `unknown`.** An unknown rating must say what was searched (`searched_no_direct_evidence`) or why it is out of scope. `unknown` means "researched but not established", never "never looked".
5. **Benchmark versions are never the same scale.** Terminal-Bench 2.1 vs 4.0, index v1.5 vs older agent scores — record `benchmark`, `harness`, `configuration`, and a `comparability` note. Cross-version numbers inform; they do not rank.
6. **Scores are model + harness + settings.** A benchmark value belongs to the triple (model, harness, configuration). Note when the benchmarked configuration (e.g. max reasoning) may not match the SKU the user can actually invoke.
7. **Efficiency is a signal, not a bill.** Tokens/time/relative cost compare models; subscription OAuth means no per-task marginal cost. Say which one you mean, every time.
8. **Cautions travel with the model.** Stealth identity, SKU-vs-benchmark mismatch, benchmark-version drift, and lane-coincidence warnings live in the entry's `cautions`, so they surface at recommendation time instead of being rediscovered.
9. **Gaps become queue items.** Anything in `research_gaps` that matters for likely next phases goes on the prioritized `research_queue` (high/medium/deprioritized with reasons), so refresh work starts from the queue instead of from scratch.

## Hard compatibility filters

Before ranking models, eliminate impossible model/execution combinations:

- `needs_writes = true` cannot be completed solely through read-only `@review`
- Insufficient context eliminates a model
- Missing required tools eliminates a model
- Excluded economic route eliminates a model
- Subscription model without matching OAuth is eliminated

## Compound task handling

A request such as "review and bug-fix this repo" contains separate phases:

```text
Phase 1 — diagnosis/review
Phase 2 — implementation/repair
```

The advisor may recommend different models or execution surfaces for the two phases. Do not pretend a read-only reviewer can perform the repair phase.

## Separate model selection from execution-lane selection (mandatory)

The advisor must answer two different questions in this order:

### A. Which model is best for this task?

Evaluate the entire eligible library using evidence. Do not start with Routine/Deep/Review lane identity.

### B. How should that model be used?

Only after selecting the model determine whether the task should:

- remain in current Build;
- switch Build with `/models`;
- send a bounded hard chunk to `@deep`;
- run an independent read-only pass through `@review`;
- use `@explore`.

## Promotion versus delegation

- If only one hard bounded chunk needs stronger reasoning, recommend delegating that chunk to `@deep` while keeping the parent Build session where it is.
- If the remainder of the phase broadly requires stronger reasoning or context, recommend manually switching the current session with `/models`.
- For independent verification, recommend `@review` or `/audit`; do not switch the implementation session merely to perform review.
- Never switch the user's model or agent automatically.

## Local empirical task history

Make `routing/task-history.json` real rather than dead scaffolding. Record compact metadata for completed meaningful tasks via `scripts/record-task-outcome.ps1`.

Require a minimum sample size before local history materially changes routing:

```text
n < 3 → anecdotal only
n >= 3 → may influence ranking
n >= 10 → substantial weight
```

Over time, verified local outcomes gain substantial weight because they describe this user's actual repositories and harness.

## End-of-task advice

At the end of a meaningful completed task, use cached roster/evidence to ask:

```text
Is a next phase reasonably clear?
```

If no: say nothing.

If yes: Would a different model materially improve the next phase?

If no: say nothing.

If yes, append only a concise note:

```
Next model: <model>
Reason: <specific material advantage for next phase>
Switch with /models if you want to promote the session.
```

Do not recommend switching for marginal differences.

## Output

Return at most:

- **Recommendation:** one model/lane or "stay on current model".
- **Why:** one or two task-specific reasons referencing evidence.
- **Access:** free, subscription OAuth, or local.
- **Execution surface:** build / @deep chunk / @review / /models switch / combination.
- **Action:** stay, delegate to `@deep`, run `/audit`, or switch manually with `/models`.
- **Fallback:** at most one alternative, only if materially useful.

Do not dump a leaderboard unless the user explicitly asks for one.

## Evidence freshness

Each evidence record should include freshness information:

- Provider capabilities: refresh when model inventory changes or evidence becomes stale.
- Independent benchmarks: refresh periodically or when choosing between close candidates.
- OpenCode free-model availability: refresh during normal routing refresh.

Do not use `model-roster.generated_at` as evidence freshness. Track `model-evidence.json.evidence_as_of` (UTC date) plus per-model `last_researched_at` separately; `generated_at` timestamps are UTC ISO-8601.

## Example line of reasoning

When comparing candidates for a terminal-heavy debugging task:

1. Model A has documented 32K context, observed success on Python repo debugging (verified local), but no terminal evidence.
2. Model B has documented 128K context, observed failure on DSP reasoning (verified local), but strong terminal-agent evidence.
3. Model C is an OpenCode free model with no observed debugging evidence.

For this task: Model B is recommended for its terminal-agent evidence, Model A as fallback if context depth is needed, Model C excluded.

**Lane identity is NOT part of this reasoning.** If the Review lane happens to use Model B, that is a coincidence, not evidence.
