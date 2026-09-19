---
name: reorient
description: Have Researcher recover task-relevant repository context. When the user adds a specific task, also assign that exact task to Worker after the orientation handoff. Bare Reorient returns orientation without inventing work.
---

# Reorient

Build owns the user's full request. This skill defines required handoffs; it does not transfer ownership or switch Plan.

## Dispatch (required)

1. Dispatch **Researcher** for repository orientation. Do not substitute Explore, Search Index, or a parent-only survey and claim Researcher ran.
2. If the user also asked for a specific additional task, dispatch **Worker** with that exact wording plus exclusions, repo instructions, and existing-work constraints.
3. If there is no additional task, dispatch Researcher only. A focus qualifier (e.g. "focus on quota") narrows orientation; it does not invent a repair.
4. An explicit no-subagents override wins. Report that deviation.

## Ordering

Researcher and Worker may run sequentially. Worker may prepare safely, but must not make orientation-dependent edits before the handoff. Do not keep a model generating merely to wait. Do not give Build and Worker the same implementation assignment in parallel.

## Researcher handoff (compact)

Include only what the task needs:

- applicable repo instructions
- branch/worktree and uncommitted-change state
- relevant source locations and decisions
- known blockers
- actual validation commands
- observed vs inferred, marked

Worker uses this handoff; it does not repeat a full reorientation. It still verifies governing sources for files it will change. Recheck affected state if it changed before editing.

## Completion

Orientation delivered. Additional task, when present, completed, user-deferred, or reported blocked. An orientation summary alone is not completion of an implementation request.

If a required helper is unavailable, use bounded recovery. Build may do a clearly disclosed fallback. Never start a second writer before the original is stopped or isolated.
