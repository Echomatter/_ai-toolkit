---
name: search-index
description: Search indexed project documents and data; check index freshness, refresh when needed, and return useful source locations and coverage limitations. Verify decisive claims against originals. Procedure for the current model, not a compulsory Researcher launch.
---

# Search Index

Use the `content_index` tool for mixed project corpora (docs and data: Markdown/text, YAML, CSV/TSV, JSON/JSONL, XML, TOML/INI, DOCX, XLSX, PDF, safe ZIP members). The index is a locator, not source authority.

This skill does not spawn Researcher. Loading it from Researcher must not spawn another Researcher.

## When to use

- find-all / every-reference / inventory
- cross-document comparison or repeated values
- structured facts across heterogeneous files
- large mixed corpora where grep will miss formats

For code symbols and call paths, use native Explore/grep/read. A missing index hit must never block code search. Source extensions such as `.ts`, `.ps1`, and `.py` are not indexed.

## Workflow

1. `content_index status` when freshness matters.
2. Rebuild only if missing/stale or a requested fact mode helps.
3. Search exact names/phrases first; expand aliases deliberately.
4. Deduplicate source/locator hits.
5. Read the governing source before claims, edits, schemas, or numbers.

Rebuild modes: `none` (default), `general`, `special`, `both`. Do not rebuild every turn.

An explicit index rebuild may trigger a lightweight model-inventory/quota freshness check through existing routing scripts. That is not a full model-research pass and must not recurse.

INDEX != SOURCE. Rank != authority. Fact row != verified fact.
