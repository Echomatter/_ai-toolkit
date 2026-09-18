---
name: content-index-research
description: Use for exhaustive cross-document retrieval in the active project, especially requests like find all, everywhere, complete inventory, all references, repeated values, or cross-source comparison. Use the deterministic content_index tool as a locator/completeness aid and verify governing sources before authoritative claims.
---

# Content Index Research

Use the project content index to improve recall across mixed corpora without replacing native code search.

## When to use

Prefer this skill when the request asks for:
- all/every occurrence across a large mixed repository;
- cross-document or cross-source comparison;
- repeated identifiers, values, rules, or records;
- PDF/DOCX/XLSX/JSON/XML/CSV/ZIP corpus retrieval;
- completeness where ordinary grep/search could miss alternate locations.

For source code symbols/call graphs, prefer native Explore/grep/LSP first. The content index is primarily a mixed-content corpus layer.

## Workflow

1. Call `content_index` with `operation=status` when corpus freshness may matter.
2. Rebuild only when missing/stale or when a fact layer materially helps. Do not rebuild every turn.
3. Search exact names/phrases first, then expand terminology deliberately.
4. Union and deduplicate candidate source/locator results.
5. Use `sources`, `unit`, and `facts` when they materially narrow the corpus.
6. Inspect the actual governing source before exact claims or edits.
7. Report coverage gaps or extraction failures rather than claiming perfect completeness.

## Fact modes

- `none`: normal retrieval; default.
- `general`: broad structured/scalar comparison.
- `special`: focused FAMILY=REGEX overlay for a specific question.
- `both`: only when broad facts and a focused overlay are both independently useful.

Keep special rules narrow and derived from the request.

## Trust rules

INDEX != SOURCE.
Search rank != authority.
Fact row != verified fact.
OCR != printed text.

The index answers "where should I look?" and "what might I have missed?" The source answers "what is true?"
