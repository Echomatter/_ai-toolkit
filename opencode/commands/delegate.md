---
description: Recommend the best model/agent for a bounded child task without switching the session model
agent: build
---

# /delegate

Use the toolkit's `delegate` custom tool to characterize a bounded task and recommend the best model/agent combination. Do not manually rank the library from lane names. Do not switch the session model automatically.

## Procedure

1. Characterize the bounded task into one or more task types:
   `repo_navigation, simple_edit, bounded_feature, large_refactor, debugging, architecture, code_review, terminal_heavy, ml, dsp, firmware, reverse_engineering, research, documentation, test_generation, long_context_reading, independent_verification`.

2. Determine the delegation role:
   - `worker` — generic implementation/reasoning (debugging, features, refactors, tests, ML/DSP/firmware analysis, architecture, terminal-heavy investigation)
   - `review` — independent verification (read-only; pass `needsModelDiversity: true` and `excludeModel` set to the implementation model when known)
   - `index` — exhaustive mixed-corpus retrieval (always free-biased)

3. Call the `delegate` tool with the role, task description, task types, and requirement flags (`needsWrites`, `needsTerminal`, `needsWeb`, `needsDeepReasoning`, `highConsequenceIfWrong`, `needsModelDiversity`, `excludeModel`, `preferredCostClass`).

4. Treat the tool result as authoritative for the selected model, adequacy, fallback, evidence freshness, and execution guidance. Ordinary delegation uses cached evidence only and never triggers web research.

5. Follow the execution guidance honestly:
   - `can_delegate_to_agent: true` — invoke the recommended agent (`@worker`, `@deep`, `@review`, `@index`) with the bounded task.
   - `needs_models_switch: true` — the selected model is not pinned to any child agent. Advise a manual `/models` switch; do not pretend delegation ran that model.
   - `recommended_agent: combination` — preserve the phase split (diagnosis/review first, then implementation/repair). `needs_writes = true` can never be satisfied solely through read-only Review.
   - If a stale-evidence warning is present on a consequential task, report the limitation but proceed; only `/refresh-model-evidence` performs live research.

## Output

Return:

```text
Role: <worker / review / index>

Selected model: <model>
Access: <free / ChatGPT OAuth / Copilot OAuth>
Adequacy: <strong / adequate / weak / unknown>

Recommended agent: <@worker / @deep / @review / @index / combination>
Pinned agent model: <model or "no pin found">
Model matches pin: <yes / no>

Fallback: <at most one meaningful alternative>

Evidence freshness: <current / partially stale / stale / very stale / UNPOPULATED>

Action:
<delegate to @worker / delegate to @deep / run /audit / switch manually with /models>
```

## Paid-lane fallback

If the delegated call is unavailable because of quota/rate/provider/auth failure, try the fallback model when known, then continue with free Build + `@index`/`@explore`/web/test work and report only the unresolved remainder. Do not automatically choose a different paid provider.

## /delegate vs /recommend-model

`/delegate` answers: what model should perform this bounded child task? `/recommend-model` answers: what model should the whole session explicitly use for the next phase? Do not merge those concepts.
