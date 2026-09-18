---
description: Refresh the model capability evidence database through real current web research
agent: build
subagent: true
---

# /refresh-model-evidence

Repopulate `routing/model-evidence.json` with current, sourced capability evidence. This workflow performs real web retrieval; it must not claim success if no retrieval occurred.

## Rules

- Use the session's `websearch`/`webfetch` tools for all evidence. Do not use remembered model knowledge, placeholder objects, or inferences from model names.
- Never leave a researched capability as a bare `unknown`. If research cannot establish it, store `rating = unknown` with `research_status = searched_no_direct_evidence`.
- `unknown` must mean "we researched it but cannot establish it reliably", never "we never looked".
- Do not mix availability with evidence. Availability stays in `routing/model-roster.json`; this workflow only touches `routing/model-evidence.json`.
- Never change the session model or agent. Never touch lane assignments; lanes are owned by `refresh-routing`.

## Procedure

1. Load `routing/model-roster.json` for the current eligible model list and `routing/model-evidence.json` for existing evidence and freshness dates.

2. Determine the serious candidate set (at minimum):
   - current Routine, Index, Deep, and Review assignments from `routing/state.json`;
   - plausible competing free coding models;
   - plausible competing OpenAI OAuth models;
   - plausible competing Copilot OAuth models.

3. For each serious candidate, in priority order, run this search loop with the session's `websearch`/`webfetch` tools. Every claim must come from actual retrieval in this run; never from model memory or inference.

   a. Identity first: `websearch "<model> <provider alias> release"` and `webfetch` the provider or catalog page for the exact roster ID. Confirm the version and the hosted surface you are evidencing (OpenCode free, OpenAI OAuth, GitHub Copilot). Prefer evidence measured on the same surface when one exists; never substitute a different SKU/variant silently.
   b. Provider evidence: `websearch "<model> <docs|release|benchmarks>"`, then `webfetch` the official documentation/release page for context window, tool support, coding focus, and reasoning controls.
   c. Independent evidence: `websearch "<model> <Terminal-Bench|SWE-bench|DeepSWE|Coding Agent Index|SWE-Atlas> <Artificial Analysis|BenchmarkList|Vals>"`, then `webfetch` at least one independent benchmark article or comparison. Prefer agent-harness runs (CAI v1.5 / TB4) over model-level scores, and version-pinned numbers over aggregate rankings.
   d. Record, do not summarize away: after each fetch, capture the source URL, a `retrieved_at` date, and only the claims that page actually supports (benchmark/harness/version/config). Merge or discard near-duplicate sources before they enter `sources`.

4. Update `routing/model-evidence.json` (schema_version 2 — keep this exact shape):
   - Top level: `schema_version`, `generated_at`, `evidence_as_of` (date), `advisor_readiness` + honest `readiness_reason`, `policy` invariants, `current_assignments_snapshot`, `serious_candidate_set`, `evidence_classes`, `sources` registry, `alias_index` covering **every** roster eligible ID, `models` keyed by canonical ID, prioritized `research_queue`.
   - `sources` registry: every source gets publisher, title, URL, `retrieved_at`, what it `supports`, and any `caution`. No registered source, no claim.
   - Evidence classes are exactly `VERIFIED_LOCAL`, `VERIFIED_CATALOG`, `PROVIDER_REPORTED`, `INDEPENDENT`, `INFERRED`.
   - Per model: `provider`, `aliases`, `research_status` (`researched_current` / `provider_researched` / `partially_researched` / `identity_only` / `stale_variant`), `positioning`, `context` with `confidence`, capabilities as `{rating, confidence, evidence[source keys], note?}`, `benchmarks[]` each with `benchmark`, `value`, `unit`, `harness`, `configuration`, and `comparability` whenever versions/harnesses differ, `efficiency` with `interpretation`, `research_gaps`, `cautions`, `source_keys`, `last_researched_at`.
   - Ratings are exactly `strong / good / adequate / weak / unknown` with `confidence = high / medium / low`. Unknown capabilities carry a note (what was searched) — never a bare `unknown`.
   - Benchmark versions are never stored as comparable numbers: record the version/harness/config on every benchmark; flag legacy versions (e.g. Terminal-Bench 2.1 vs 4.0) as non-comparable.
   - Move open `research_gaps` that matter for likely next phases onto `research_queue` with priority + reason.
   - Set `evidence_as_of`, `advisor_readiness`, and `readiness_reason` honestly.
   - Validate the file parses as JSON and every `alias_index` target exists in `models` before finishing.

5. Report:
   - models researched, sources collected per model, capabilities still unknown and why;
   - resulting freshness and readiness states.

If no web retrieval occurred (tools unavailable or skipped), stop and report failure. Do not write the file and do not claim the advisor is evidence-based.
