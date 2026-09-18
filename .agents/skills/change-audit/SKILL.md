---
name: change-audit
description: Use after a material change, or when explicitly asked to review/audit work, to check that the implementation satisfies the request without regressions, dropped requirements, or unrelated churn.
---

# Change Audit

Goal: decide whether the change actually did the requested job.

## Procedure

1. Read the request/task contract and the complete relevant diff. Do not audit against memory alone.
2. Check scope: unrelated formatting, cleanup, config churn, generated files, or accidental edits should be called out.
3. Check completeness: search renamed/removed symbols, call sites, configs, docs, tests, schemas, and exports that must stay consistent.
4. Run the smallest meaningful validation that covers the changed behavior. If the environment cannot run it, state that limitation.
5. For bug fixes, reproduce the original symptom or a direct equivalent when practical; reading code alone is not proof.
6. During an active refactor, do not flag temporary code/docs mismatch as a defect unless the requested milestone says they should already agree.
7. Report only real issues, unmet requirements, regression risks, and meaningful verification gaps. Avoid style nitpicks unless style is itself the contract.
8. Do not silently fix findings while acting as an independent verifier unless explicitly asked to switch into implementation mode.
