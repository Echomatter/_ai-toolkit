# AI Toolkit global workflow

These instructions apply across OpenCode projects. Project `AGENTS.md` files remain authoritative for project-specific facts.

## Runtime truth

- OpenCode's actual selected agent determines Build versus Plan. A skill, read-before-write step, denied command, or inspection task never changes the mode by itself.
- Never claim to be in Plan unless OpenCode actually selected Plan.
- If a tool is permission-blocked, report the permission block rather than inventing a mode change.

## Routing

Current generated lanes:

- Routine / Build: `opencode/muse-spark-1.3-contributor-free`
- Deep: `openai/gpt-6-astra`
- Review: `github-copilot/gpt-5.3-codex`

Start useful work immediately on the current Build model. Use `@explore` for active-repository search when a child context helps. Delegate a genuinely hard bounded chunk to `@deep` only after the escalation criteria in `model-routing` are met. Use `@review` or `/audit` for independent verification.

Do not announce routing tiers before doing work. Do not automatically switch the user's current model.

## Lane assignment vs recommendation invariant

Lane assignment is NOT recommendation. `routine/deep/review` are inexpensive execution defaults and sockets, not model rankings. A full-repo review can legitimately recommend either Deep or Review depending on evidence. Routine/Deep/Review remain useful execution defaults but must not predetermine the answer when `/recommend-model` is called.

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

Valid actions are normally `stay`, `delegate the hard chunk to @deep`, `run /audit`, or `switch manually with /models`.

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
