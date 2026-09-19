---
name: local-repo-research
description: Use when searching the active repo or sibling repositories in the local Dev Drive/workspace for prior implementations, code paths, formats, tests, history, or reusable patterns without modifying those repos.
---

# Local Repo Research

Goal: make the local workspace searchable prior art without turning research into another development task.

## Procedure

1. Decide whether the question is **current-repo tracing** or **cross-repo prior-art search**. For routine current-repo orientation, prefer `repo-reorient`; for current-repo code tracing, use `enhanced-explore`; use this skill when real cross-repo investigation is needed.
2. For cross-repo work, enumerate likely sibling Git repos shallowly from the workspace root. Do not crawl the entire drive or generated/vendor/cache trees.
3. Prefer deterministic search first: LSP/find-references for a known symbol; otherwise `rg`, filename/glob search, manifests, and targeted `git log/blame`.
4. Search by concept as well as exact names when looking for something solved elsewhere (format signatures, UI behavior, parser patterns, DSP terms, file extensions, test names).
5. Treat sibling repositories as read-only unless the user's active task explicitly targets them. Do not "helpfully" patch another repo during research.
6. Cross-check promising findings against tests and call sites before declaring them reusable.
7. Return exact repo/path/symbol references and a short note on what is reusable, what is project-specific, and any licensing/provenance constraint that matters.
8. If execution/building is necessary to answer the question, hand that need back to the primary session rather than converting the researcher into an implementer.
