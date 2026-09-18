---
description: Record a meaningful completed task outcome for local model-routing history
agent: build
---

# /record-outcome

Record compact local performance evidence for a completed meaningful task.

Do not record trivial orientation/search-only work. Do not invent results.

1. Read the toolkit root from `$HOME\.config\opencode\ai-toolkit-root.txt`.
2. Infer from the completed task only when clear:
   - repo name
   - task type(s)
   - actual model ID used
   - access surface
   - success/failure
   - whether meaningful tests passed
   - attempt count
   - whether escalation occurred
   - elapsed band: `short / medium / long`
   - delegation role when the work was delegated: `worker / review / index` (omit for direct Build work)
   - delegated model when it differs from the recorded model, and the parent session model at delegation time
3. If any required value is genuinely unknown, ask one concise question rather than fabricate it.
4. Invoke `scripts\record-task-outcome.ps1` with those values. Pass `-Role`, `-DelegatedModel`, and `-ParentModel` when the task was delegated so future selection can learn from delegation outcomes.

   ```powershell
   $root = (Get-Content "$HOME\.config\opencode\ai-toolkit-root.txt" -Raw).Trim()
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$root\scripts\record-task-outcome.ps1" `
     -Repo "<repo>" -TaskType "bounded_feature" -Model "<model>" -Access "<surface>" `
     -Success:$true -TestsPassed:$true -Attempts 1 -Escalated:$false -ElapsedBand "short" `
     -Role "worker" -ParentModel "<parent-model>"
   ```

   Pass `-TaskType` as a single (optionally comma-separated) string. PowerShell `-File` CLI parsing does not preserve `@(...)` arrays; extra elements spill into other parameters.
5. Return the emitted Task ID. Keep it with the task so a later independent review can mark defects against the same observation.

To mark that a later review found a defect in an existing task, invoke:

```powershell
$root = (Get-Content "$HOME\.config\opencode\ai-toolkit-root.txt" -Raw).Trim()
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$root\scripts\record-task-outcome.ps1" -TaskId "<task-id>" -MarkReviewDefect
```

This command records local empirical evidence only. It does not switch models or change routing by itself.
