---
name: evidence-ledger
description: Use when verification, research provenance, reverse engineering, experiments, or handoffs require traceable evidence; keep the ledger terse and internal unless the evidence itself is useful to the user.
---

# Evidence Ledger

Goal: keep completion and research claims tied to things actually observed.

## Procedure

1. Capture only evidence that matters: what was checked, the command/tool/source, and the result.
2. Prefer primary evidence (test output, actual file contents, API results, hashes, reproduced behavior) over inference.
3. For investigation work, label the status when useful: **verified**, **reported**, **inferred**, or **unknown**.
4. Do not narrate the ledger while working. Keep it in scratch/session context and surface only the evidence needed to support the result or handoff.
5. If something cannot be verified in the current environment, say exactly what remains unverified rather than upgrading inference into fact.
6. Before claiming done, make sure every important acceptance criterion has matching evidence or an explicit limitation.
