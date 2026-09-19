---
name: reorient
description: Researcher recovers task-relevant repository context. Worker performs the user's additional task after the handoff. Bare Reorient returns orientation without inventing work.
---

# Reorient

Our customized Build owns the complete request and keeps the selected parent model.

1. Call `delegate` with role `researcher`, task types appropriate to research/repo navigation, and `needsWrites: false`. Include the added user's task as orientation context. Researcher chooses read/index/Explore/web as appropriate; do not substitute a generic Explore invocation for Researcher.
2. Read the returned research result and receipt. The tool already executed Researcher: do not launch a second copy via native task. The handoff includes applicable instructions, branch/worktree and existing changes, relevant source locations/decisions, blockers, observed versus inferred findings, and actual validation commands.
3. For a specific additional task, call `delegate` with role `worker` and that exact wording, exclusions and relevant research handoff. Set `needsWrites: true` only when edits are authorized. Explanations and planning-only tasks remain read-only. Receive context before orientation-dependent edits; sequential dispatch is sufficient.
4. Bare Reorient or a focus qualifier alone does not invent an implementation. An explicit no-subagents override wins and must be described honestly. A Researcher already assigned orientation loads this procedure without recursively delegating itself.
5. Validate the added work, reconcile results and return the requested deliverable, not merely 'reoriented'. Record meaningful validated outcomes using their actual receipt IDs, without duplicating child usage in the parent total.

Reuse relevant existing research and recheck affected facts if the worktree changed. Do not keep a model generating to wait, repeat the same full survey in Worker, or assign Build the same implementation in parallel.

If a helper is unavailable, use bounded recovery or a disclosed direct Build fallback. Never claim an agent ran from a recommendation alone. Failed writers require inspection and confirmed stop before further writing. Reorient does not authorize Sync or publication.
