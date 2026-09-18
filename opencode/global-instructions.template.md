# AI Toolkit global workflow

These instructions apply across OpenCode projects. Project `AGENTS.md` files remain authoritative for project-specific facts.

## Runtime truth

- OpenCode's actual selected agent determines Build versus Plan. A skill, read-before-write step, denied command, or inspection task never changes the mode by itself.
- Never claim to be in Plan unless OpenCode actually selected Plan.
- If a tool is permission-blocked, report the permission block rather than inventing a mode change.

## Routing

Current generated lanes:

- Routine / Build: `__ROUTINE_MODEL__`
- Index: `__ROUTINE_MODEL__` (free retrieval helper)
- Worker: `__WORKER_MODEL__` (dynamic delegated execution; model chosen by evidence-aware selector)
- Deep: `__DEEP_MODEL__` (explicit strong-model escalation only)
- Review: `__REVIEW_MODEL__`

Start useful work immediately on the current free Build model. Use `@explore` for source-code search/tracing, `@index` for exhaustive mixed-corpus retrieval, and native web tools for current public information. For bounded delegated implementation, call the `delegate` tool first and invoke the recommended agent (`@worker` normally). Delegate only a narrowed hard chunk to `@deep` after the escalation criteria in `model-routing` are met, or when the user explicitly requests the strongest model. Use `@review` or `/audit` for independent verification.

Do not announce routing tiers before doing work. Do not automatically switch the user's current model.

## Paid-lane failure

If a Deep, Review, or Worker invocation ultimately fails because of quota/rate/provider/auth availability, do not keep retrying or jump to a metered route. Try the selector's fallback model when known, then continue in free Build with `@index`, `@explore`, web tools, and deterministic validation. Report a block only when the unresolved remainder genuinely requires stronger reasoning.

## Delegation

Roles are stable; models are dynamically selected. The `delegate` tool calls the deterministic evidence-aware selector over cached roster/evidence/history and returns the selected model plus execution guidance. Ordinary delegation uses cached evidence only and never triggers web research. If the result carries a stale-evidence warning on a consequential task, report the limitation but proceed; only `/refresh-model-evidence` performs live research. If `needs_models_switch` is true, the selected model is not pinned to any child agent: advise a manual `/models` switch rather than pretending delegation ran that model. Whole-session model changes always remain explicit user actions.

## Lane assignment vs recommendation invariant

Lane assignment is NOT recommendation. `routine/index/worker/deep/review` are execution defaults and sockets, not model rankings. A full-repo review can legitimately recommend either Deep or Review depending on evidence. Routine/Index/Worker/Deep/Review remain useful execution defaults but must not predetermine the answer when `/recommend-model` is called.

## Next-phase model advice

After a **meaningful completed task**, make a next-model recommendation only when all of these are true:

1. the likely next phase is reasonably clear from the current work;
2. another eligible model from the full library has a material capability advantage for that phase; and
3. the recommendation would change what the user should do next.

A recommendation requires a meaningful difference such as:
- current model lacks a required capability;
- next phase crosses into Deep territory;
- context requirement exceeds current model's practical envelope;
- evidence strongly favors another model for this task type;
- current model already failed or escalated;
- verification benefits from an independent model;
- local history shows materially worse outcomes with the current model.

If two models are essentially equivalent, stay on the current model. Avoid pointless switching.

When those conditions are met, append one compact line at the end of the normal result:

`Next model: <model or lane> — <task-specific reason>. <action>`

Valid actions are normally `stay`, `use @index/@explore`, `delegate via @worker`, `delegate the hard chunk to @deep`, `run /audit`, or `switch manually with /models`.

If the current model remains adequate, the next phase is unclear, or the difference is marginal, say nothing about model choice. Do not nag. Maximum 2–3 lines.

For an explicit model question or an ambiguous high-value choice, load `model-advisor` or use `/recommend-model`. The advisor must invoke the deterministic `scripts/select-model.ps1` engine rather than manually choosing from lane labels. If the selector reports missing/stale evidence for a consequential decision, research current sources, refresh evidence, and rerun the selector. Never turn an ordinary completion into a benchmark report.

When making an end-of-task next-model recommendation, use the deterministic selector when practical. Never recommend `@deep` or `@review` for a model that is not actually pinned to that subagent; recommend a manual `/models` switch instead.

## Workstyle

1. Inspect actual repository state before proposing changes.
2. Prefer deterministic tools before model speculation.
3. Keep changes bounded to the request; do not redesign unrelated systems.
4. Preserve explicit constraints, names, formats, and numbers.
5. Use native web search/fetch for current external research; do not depend on experimental Scout.
6. Search sibling repos only when prior work is likely to matter.
7. Validate changed behavior with the smallest meaningful test, build, or reproduction.
8. Do not launch large training runs, exhaustive searches, destructive migrations, or irreversible operations without explicit operator intent.
9. Use `git` locally and authenticated `gh` for remote GitHub. Read before remote writes; never merge, force-push, delete, or close resources without explicit intent.
10. Keep claims tied to evidence and state what remains unverified.
11. For a real model/session transfer, produce a factual handoff rather than a transcript.
