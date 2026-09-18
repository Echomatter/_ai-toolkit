---
description: Recommend the best currently available model for the next phase without switching models automatically
agent: build
subagent: true
---

# /recommend-model

Use the toolkit's deterministic evidence-aware selector as the source of truth. Do not manually rank the library from lane names.

## Procedure

1. Characterize the requested next phase into one or more task types:
   `repo_navigation, simple_edit, bounded_feature, large_refactor, debugging, architecture, code_review, terminal_heavy, ml, dsp, firmware, reverse_engineering, research, documentation, test_generation, long_context_reading, independent_verification`.

2. Determine these requirements:
   - `needs_writes`
   - `needs_terminal`
   - `needs_web`
   - estimated minimum context tokens when genuinely known; otherwise 0
   - `needs_deep_reasoning`
   - `needs_model_diversity`
   - `high_consequence_if_wrong`
   - current model ID when known
   - when independent verification is requested, the implementation/current model to exclude as the diversity reference

3. Read the toolkit root from:

   `$HOME\.config\opencode\ai-toolkit-root.txt`

   Then invoke:

   `<toolkit-root>\scripts\select-model.ps1`

   with the structured task types and requirement flags. Parse its JSON output.

   Example shape:

   ```powershell
   $root = (Get-Content "$HOME\.config\opencode\ai-toolkit-root.txt" -Raw).Trim()
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$root\scripts\select-model.ps1" `
     -TaskType @('debugging','terminal_heavy') `
     -NeedsWrites:true -NeedsTerminal:true -NeedsDeepReasoning:true -HighConsequence:true
   ```

   For independent verification, also pass `-NeedsModelDiversity:true` and `-ExcludeModel <implementation-model>` when that model is known.

4. Treat the selector output as authoritative for:
   - ranked recommendation
   - fallback
   - evidence freshness/readiness
   - whether current evidence requires fresh research
   - execution surface
   - compound diagnosis/repair phases

   Do not replace its result merely because a configured lane "sounds right."

5. If `needs_research = true`, perform current web research before giving the final answer:
   - use official provider/model documentation for identity, context, tools, and current capabilities;
   - use current independent coding-agent evidence when available;
   - update `routing/model-evidence.json` according to the `model-advisor` evidence rules;
   - rerun `select-model.ps1` after the evidence update.

   If web research cannot be performed, report that the recommendation is provisional. Do not pretend missing evidence is current.

6. Execution-surface integrity is mandatory:
   - `@deep` is valid only when the recommended model is the model currently pinned to Deep.
   - `@review` is valid only when the recommended review model is currently pinned to Review.
   - otherwise recommend a manual `/models` switch.
   - `needs_writes = true` can never be satisfied solely through read-only Review.

7. For compound requests such as "review and bug-fix this repo", preserve the selector's phase split. Diagnosis and repair may use different models/surfaces.

## Output

Return:

```text
Recommended: <model>

Access:
<free / ChatGPT OAuth / Copilot OAuth>

Why:
- task-specific evidence-backed reason
- relevant benchmark/provider/local-history evidence
- important caution or evidence gap, if any

Execution surface:
<build / @deep chunk / @review / /models switch / combination>

Fallback:
<at most one meaningful alternative>

Evidence freshness:
<current / partially stale / stale / very stale / UNPOPULATED>

Evidence readiness:
<UNPOPULATED / PARTIAL / READY>

Action:
<stay / delegate / audit / switch manually with /models>
```

Do not output a full leaderboard unless explicitly requested.

Lane identity is operational context, not capability evidence. Never switch the session model automatically.
