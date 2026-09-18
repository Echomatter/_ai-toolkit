---
description: Recommend the best currently available model for the next phase without switching models automatically
---

# /recommend-model

Perform library-wide evaluation of all currently eligible models for the requested next phase.

## Operation

1. If arguments are supplied, evaluate them as the next phase. If no arguments were supplied, infer the likely next phase from the current conversation and completed work.

2. Load the current eligible model roster from `routing/model-roster.json`.

3. Load capability evidence from `routing/model-evidence.json`. If evidence is UNPOPULATED or stale, perform web research before recommending.

   Resolve every roster model ID to its canonical ledger entry through `alias_index` before comparing. Fast/mini/year variants share canonical evidence; apply the entry's SKU cautions (speed/effort/config differences) rather than inventing separate evidence.

4. Characterize the requested task along the following axes (not mutually exclusive):
   - repo_navigation, simple_edit, bounded_feature, large_refactor
   - debugging, architecture, code_review, terminal_heavy
   - ml, dsp, firmware, reverse_engineering, research
   - documentation, test_generation, long_context_reading, independent_verification

   Also determine requirements:
   - needs_writes, needs_terminal, needs_web, needs_large_context
   - needs_deep_reasoning, needs_model_diversity, high_consequence_if_wrong

5. Determine resource shape bands:
   - context_demand: tiny / small / medium / large / very_large
   - reasoning_demand: low / medium / high
   - tool_demand: low / medium / high
   - iteration_demand: low / medium / high
   - verification_demand: low / medium / high

6. **Separate model selection from execution-lane selection (mandatory):**

   ## A. Which model is best for this task?
   Evaluate the entire eligible library using evidence from `model-evidence.json`.
   Do NOT start with Routine/Deep/Review lane identity.

   Apply hard compatibility filters BEFORE ranking:
   - `needs_writes = true` cannot be completed solely through read-only `@review`
   - Insufficient context eliminates a model
   - Missing required tools eliminates a model
   - Excluded economic route eliminates a model

   ## B. How should that model be used?
   Only after selecting the model determine execution surface:
   - remain in current Build
   - switch Build with `/models`
   - send a bounded hard chunk to `@deep`
   - run an independent read-only pass through `@review`
   - use `@explore`

   **Lane assignment != capability evidence.** Lane membership may be a weak operational prior. It must never be decisive proof that a model is best.

7. Eliminate models lacking required capabilities:
   - Models without sufficient context window for the task are eliminated.
   - Models without documented tool support needed for the task are eliminated.
   - Models with economics that violate the economic boundary are excluded.
   - `needs_writes = true` tasks cannot use read-only Review as the sole execution surface.

8. For compound tasks like "review and bug-fix this repo":
   - Separate into phases: Phase 1 (diagnosis/review) and Phase 2 (implementation/repair)
   - The advisor may recommend different models or execution surfaces for the two phases
   - Do not pretend a read-only reviewer can perform the repair phase
   - Reject read-only Review as the sole solution when `needs_writes = true`

9. Compare remaining candidates using evidence:
   - Relevant capability evidence from `model-evidence.json` (rating + confidence + source keys + retrieval dates)
   - Benchmark comparability: never rank across benchmark versions (e.g. Terminal-Bench 2.1 vs 4.0) or across harnesses/configurations as if they were the same scale. Scores belong to a (model, harness, configuration) triple; note mismatches instead of silently comparing.
   - Surface each candidate's ledger `cautions` (stealth identity, SKU-vs-benchmark config mismatch, version drift) in the reasoning
   - Context requirement match
   - Tool capability match
   - Observed local history from `routing/task-history.json`
   - Subscription/free/local economics
   - Expected speed/latency
   - Provider/model diversity when verification is important
   - Evidence freshness: if evidence is stale AND top candidates are close, research current evidence before deciding
   - Local task history: require minimum n >= 3 before local history materially changes routing

10. Select one recommended model.

11. Select at most one meaningful fallback.

12. Return output in the following format:

```
Recommended: <model>

Access:
<free / ChatGPT OAuth / Copilot OAuth / local>

Why:
- task-specific reason
- capability evidence (source keys, retrieval dates, benchmark + harness + configuration, confidence)
- relevant context/tool reason
- relevant efficiency/economic reason (efficiency signal, not a bill)
- applicable ledger cautions (if any)

Execution surface:
<build / @deep chunk / @review / /models switch / combination>

Current lane:
<lane identity shown for reference only, NOT as evidence>

Fallback:
<one model, only if meaningfully useful>

Evidence freshness: current / stale / partially stale / UNPOPULATED
Evidence readiness: UNPOPULATED / PARTIAL / READY

Action:
Switch with /models if you want to promote the current session.
```

Do not output a giant model ranking unless the user explicitly asks for it.

## Economic handling

Do not claim that subscription models cost a particular per-task dollar amount to the user.

External API benchmark cost can still be useful as an EFFICIENCY SIGNAL:

```text
tokens consumed
execution time
relative inference cost
```

But clearly distinguish that from the user's actual marginal cost.

## Evidence freshness and readiness

- **UNPOPULATED**: No meaningful sourced capability evidence. Must research before consequential recommendation.
- **PARTIAL**: Some serious candidates researched, others not.
- **READY**: All currently serious candidate models have enough current evidence for meaningful comparison.

If `/recommend-model` finds top candidates are close AND relevant evidence is stale, then research current evidence before deciding. Otherwise use the cache.

Unknown evidence + trivial task (simple search, simple edit, low reasoning/tool demand): use an inexpensive default from the current roster rather than spending time on web research. Reserve research for consequential tasks where evidence is missing or stale.

## Local learning

Record task outcomes via `scripts/record-task-outcome.ps1`. Require minimum n >= 3 before local history materially changes routing. Over time, verified local outcomes gain substantial weight because they describe this user's actual repositories and harness.

## End-of-task advice

At the end of a meaningful completed task, use cached roster/evidence to ask:
1. Is a next phase reasonably clear?
2. Would a different model materially improve the next phase?

If both yes, append only:
```
Next model: <model>
Reason: <specific material advantage for next phase>
Switch with /models if you want to promote the session.
```

Do not recommend switching for marginal differences.

---
