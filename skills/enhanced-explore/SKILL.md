---
name: enhanced-explore
description: Use instead of plain Explore for codebase where-is, how-does-it-work, symbol, entry-point, call-path, and implementation questions; guide native Explore with deterministic content-index and @index locator evidence first, then verify in source.
---

# Enhanced Explore

Goal: answer codebase questions with guided Explore, not blind whole-repo walks.

Use this instead of raw Explore when the request names code: symbols, files, entry points, call paths, behavior, implementations, or "where/how does X work".

Do not use this for docs/data-only "find all" inventories; use `content-index-research`. Do not use this for sibling-repo prior art; use `local-repo-research`. For fresh orientation only, use `repo-reorient`, then switch here when investigation starts.

## Procedure

1. State the code target in one line: symbol, behavior, or entry point.
2. Get cheap locator evidence first: run `content_index status` when freshness matters, then `search` exact names/phrases; expand aliases, acronyms, old names, and related identifiers once. Delegate broad mixed-corpus discovery to `@index` when it keeps parent context small.
3. Constrain native Explore to the locator hits: directories, files, and patterns. Never start with an unbounded full-repo walk.
4. Trace outward one hop from confirmed hits: definitions, call sites, tests, manifests, and entry points. Prefer LSP/find-references for a known symbol; otherwise use `rg`, glob, and targeted `git log/blame`.
5. Read the governing source before claiming behavior. Verify decisive call paths in code, not from search rank or index snippets.
6. Return repo/path/symbol evidence plus a one-line behavior note each; state coverage gaps and what was not searched.

## Rules

- Read-only unless the user's active task explicitly requests implementation.
- Inherit the initiating model; never wait on model selection or switch models.
- INDEX != SOURCE; search rank != authority.
- Stop when the target is located and behavior is verified; do not map unrelated subsystems.
