---
name: repo-reorient
description: Use when re-entering a repository after time away or another agent's work; quickly establish the task-relevant current state without turning orientation into an architecture project.
---

# Repo Reorient

Goal: recover enough current context to work safely, then start the requested task.

## Procedure

1. Read the nearest applicable repo instructions first (`AGENTS.md`, Copilot instructions, CONTRIBUTING, task-relevant README/design notes). Do not ingest every design document by default.
2. Check current branch, working-tree status, and a short recent log. Treat uncommitted/refactor work as first-class current state.
3. Inspect the files, tests, manifests, and entry points relevant to the requested task. Avoid mapping unrelated subsystems.
4. Prefer current code + diff + test reality over stale prose when they conflict during active work; note the mismatch instead of "correcting" it automatically.
5. Find the actual validation commands from manifests/CI/scripts rather than guessing.
6. Stop orienting once you can answer: what is being changed, what rules apply here, what is in progress, and how will this task be checked.
