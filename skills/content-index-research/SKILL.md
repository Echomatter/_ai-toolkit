---
name: content-index-research
description: Use for exhaustive mixed-corpus discovery, cross-document comparison, repeated values, structured facts, or requests to find all references across project docs/data; use the deterministic content_index tool as a locator and verify governing sources before authoritative claims.
---

# Content Index Research

Use the `content_index` custom tool for mixed project corpora. It indexes documentation and data sources such as Markdown/text, YAML, CSV/TSV, JSON/JSONL, XML, TOML/INI, DOCX, XLSX, PDF, and safe ZIP members.

The index is a **locator and completeness aid**, not source authority.

## When to use it

Prefer the index when the user asks for:
- "find all", "every reference", "everywhere", or a complete inventory;
- cross-document comparison or repeated values;
- structured-data discovery across heterogeneous files;
- facts/statistics that are expensive to recover with repeated raw reads;
- a large project corpus where ordinary grep is likely to miss alternate formats.

For source-code symbols/call paths, use `enhanced-explore` (index-guided Explore) instead of raw Explore/LSP/grep alone. Use this skill for the surrounding docs/data corpus.

## Normal workflow

1. Run `content_index status` when freshness matters.
2. Rebuild only if the index is missing/stale or the requested fact mode materially helps.
3. Search exact names/phrases first.
4. Expand terminology deliberately: aliases, acronyms, old names, related identifiers, and concepts discovered in results.
5. Union and deduplicate source/locator results.
6. Use `unit` or `facts` to narrow the candidate set.
7. Read the actual governing source before exact claims, edits, rules, schemas, or numbers.

## Rebuild modes

- `none`: retrieval only; default and cheapest.
- `general`: reusable scalar/prose/table facts.
- `special`: focused fact overlay using the smallest useful `FAMILY=REGEX` set for the request.
- `both`: broad facts plus a focused overlay.

Do not rebuild reflexively every turn.

## Trust rules

- INDEX != SOURCE.
- Search rank != authority.
- Fact row != verified fact.
- Aggregate statistic != semantic reconciliation.
- OCR != printed text.
- Inferred role/status/routing rank are hints only.

Report extraction failures/truncation when they could affect completeness.
