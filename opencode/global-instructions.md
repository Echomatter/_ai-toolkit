# AI Toolkit global workflow

These instructions apply across OpenCode projects. Project `AGENTS.md` files remain authoritative for project-specific facts.

## Runtime truth

- OpenCode's actual selected agent determines Build versus Plan. A skill, read-before-write step, denied command, or inspection task never changes the mode by itself.
- Never claim to be in Plan unless OpenCode actually selected Plan.
- If a tool is permission-blocked, report the permission block rather than inventing a mode change.
- The parent model is the user's selected model. Do not switch it silently.

## Public catalog

Five skills: `reorient`, `search-index`, `sync`, `model-routing`, `record-outcome`.
Four helpers: `@worker`, `@architect`, `@researcher`, `@review`.
Two tools: `content_index`, `delegate`.
Native Plan and Explore remain available. There are no toolkit slash-command wrappers.

## Delegation

User-invoked skills and helpers inherit the initiating model unless the user overrides. Agent-initiated children call `delegate` so the selected model actually runs. Selection is not execution. Whole-session model changes remain explicit `/models` actions.

Reorient dispatches Researcher for orientation and Worker for any added task. Do not substitute Explore for Researcher.

## Paid-lane failure

If Worker, Architect, or Review fails for quota/rate/provider/auth, do not loop or jump to a metered route. Try the selector fallback when known, then continue on the parent with Researcher/Explore, web tools, and tests. Report only the unresolved remainder.

## Next-phase model advice

After a meaningful completed task, one compact line only when the next phase is clear and another model has a material advantage. Otherwise say nothing. Load `model-routing` for an explicit comparison; it must invoke `scripts/select-model.ps1`. Never claim a role ran on a selected model unless dispatch and runtime identity agree.

## Workstyle

1. Inspect actual repository state before proposing changes.
2. Prefer deterministic tools before model speculation.
3. Keep changes bounded to the request.
4. Preserve explicit constraints, names, formats, and numbers.
5. Use native web search/fetch for current external research.
6. Search sibling repos only when prior work is likely to matter.
7. Validate with the smallest meaningful test.
8. Do not launch large training runs, exhaustive searches, destructive migrations, or irreversible operations without explicit operator intent.
9. Use `git` locally and authenticated `gh` for remote GitHub. Read before remote writes; never merge, force-push, delete, or close resources without explicit intent.
10. Keep claims tied to evidence. State what remains unverified.
11. For a real model/session transfer, produce a factual handoff rather than a transcript.
