# Project Content Index

The toolkit includes a deterministic mixed-content retrieval layer:

```text
tools/Project_Content_Indexer.py
opencode/tools/content_index.ts
@index
/index
content-index-research
```

The maintained Python script builds a project-local SQLite/FTS5 database at:

```text
.content-index/Project_Content_Index.sqlite
```

The database is generated state. It is a locator/completeness aid, not source authority.

## Good uses

Use the content index for:
- "find all" / "every reference" requests;
- large mixed documentation/reference corpora;
- JSON/XML/CSV/XLSX cross-source queries;
- PDF/DOCX retrieval;
- repeated identifiers/values;
- cross-document comparisons and fact inventory.

Use native Explore/grep/LSP first for program source-code symbols, call graphs, and ordinary code navigation.

## Supported corpus types

```text
.md .txt .rst .log .yaml .yml
.csv .tsv
.json .jsonl .ndjson
.xml .backup
.toml .ini .cfg
.docx .xlsx
.pdf
.zip
```

PDF text extraction uses `pdftotext` when available. OCR is opt-in.

## Normal workflow

1. Check status when freshness may matter.
2. Rebuild only when missing/stale or when the requested fact mode materially helps.
3. Search exact terms first.
4. Expand aliases/alternate terminology for completeness.
5. Deduplicate candidate source/locator results.
6. Read the relevant indexed unit when useful.
7. Verify the governing source before exact claims or edits.

The global OpenCode tool exposes these operations:

```text
status
search
sources
unit
facts
meta
rebuild
```

## Fact modes

- `none` — ordinary retrieval; cheapest default.
- `general` — broad scalar/structured fact extraction.
- `special` — focused `FAMILY=REGEX` overlay derived from the current request.
- `both` — broad facts plus a focused overlay when both are independently useful.

Do not invent a large ontology merely because the index supports special rules.

## Trust rules

- INDEX != SOURCE.
- Search rank != authority.
- Fact row != verified fact.
- Aggregate statistic != semantic reconciliation.
- OCR != printed text.
- A newer filename does not automatically make a source governing.

## Rebuild contract

Rebuilds are atomic. The indexer inventories and hashes sources, builds a temporary database, validates SQLite integrity/foreign keys/FTS parity, and replaces the stable database only after validation passes.

Extraction failures and truncation remain visible rather than silently retaining stale content.
