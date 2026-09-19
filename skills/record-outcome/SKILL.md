---
name: record-outcome
description: Record or correct validated task results using actual execution receipts. Link reviews and consumption once; distinguish measured, estimated and unknown.
---

# Record Outcome

Do not infer successful implementation from a completed model response. Validate the requested behavior first. Do not rerun the task merely to record it.

Resolve the toolkit root from the installed `ai-toolkit-root.txt`. Call `scripts/record-task-outcome.ps1` with the real task ID returned by `delegate`, actual model, repo, task types and observed test/result values. Pass task types as one comma-separated string when using PowerShell `-File`.

The recorder reads a matching runtime receipt, checks selected versus observed model, and imports child-specific usage. Same task ID updates one observation. A later review defect uses `-TaskId <id> -MarkReviewDefect` and remains attached to the original attempt. Do not create a new success to hide it.

Parent/child costs are related, not separate charges to sum twice. A fallback leaves an honest attempt history. Legacy all-session CLI measurements remain estimates because same-model concurrency and rounded counters cannot establish exact task consumption.

Binding, provider, quota and deployment failures are operational observations, not poor coding performance by the intended model. No fabricated model self-identification, measured zero balances, or subscription-dollar savings. Read-only reviewers return their findings to Build for recording rather than bypassing the role's write boundary.
