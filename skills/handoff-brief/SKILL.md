---
name: handoff-brief
description: Use when work is genuinely being transferred, paused, resumed, or escalated to another model/session; produce a compact factual continuation brief rather than a transcript or general status report.
---

# Handoff Brief

Goal: let another model/session continue immediately without re-discovering the important state.

## Procedure

1. State the current goal and exact repository/branch/commit or working-tree state when relevant.
2. List meaningful files changed/created and decisions already made, especially constraints that must not be undone.
3. Include commands/checks actually run and their results; mark anything still unverified.
4. Call out blockers, known failures, deliberately deferred work, and active refactors.
5. Identify which lane/model is taking over when this is a model escalation and why that lane is justified.
6. End with the next concrete action.
7. Keep it short. Use this only for a real handoff/pause/resume/escalation, not automatically at the end of every ordinary task.
