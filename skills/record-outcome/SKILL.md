---
name: record-outcome
description: Record or correct a meaningful task's actual model, result, validation, retries, consumption, and review findings. Automatic recording must stay reliable; explicit recording updates or links the same task rather than duplicating it.
---

# Record Outcome

Do not record trivial orientation/search-only work. Do not invent results. Recording does not rerun the task.

1. Read toolkit root from `$HOME\.config\opencode\ai-toolkit-root.txt`.
2. Prefer values from the actual child dispatch/completion (selected, dispatched, runtime-observed). Distinguish measured, estimated, and unknown.
3. Invoke `scripts\record-task-outcome.ps1`. Pass `-TaskId` when known so a later correction or review finding updates the same observation.

```powershell
$root = (Get-Content "$HOME\.config\opencode\ai-toolkit-root.txt" -Raw).Trim()
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$root\scripts\record-task-outcome.ps1" `
  -Repo "<repo>" -TaskType "bounded_feature" -Model "<actual-model>" -Access "<surface>" `
  -Success:$true -TestsPassed:$true -Attempts 1 -Escalated:$false -ElapsedBand "short" `
  -Role "worker" -ParentModel "<parent-model>" -DelegatedModel "<child-model>"
```

Pass `-TaskType` as a single optionally comma-separated string.

To attach a later review defect:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$root\scripts\record-task-outcome.ps1" -TaskId "<task-id>" -MarkReviewDefect
```

Parent and child attempts are related but distinct. Do not double-count child consumption in parent totals. A failed attempt plus successful fallback is one user task with honest attempt history.
