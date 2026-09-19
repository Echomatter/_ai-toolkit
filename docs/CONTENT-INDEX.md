# Project content index

The toolkit includes a deterministic mixed-corpus retrieval layer based on `tools/Project_Content_Indexer.py`.

OpenCode exposes it through the global `content_index` custom tool and the free `@index` subagent.

## Why it exists

Native Explore/LSP/grep remain the right tools for source-code discovery. The content index is for the rest of a project: documentation, structured data, PDFs, spreadsheets, office documents, archives, and large mixed corpora where "find all of it" needs better recall than ad-hoc searching.

The index is not source authority. It returns candidate sources and locators; exact claims and edits should be verified against the governing source.

## Storage

The OpenCode wrapper stores the generated SQLite index in Git metadata when the current project is a Git repository, using `git rev-parse --git-path opencode-content-index.sqlite`. This avoids adding generated index files to the working tree.

For a non-Git directory it falls back to:

`.content-index/Project_Content_Index.sqlite`

## Operations

The custom tool supports:
- `status`
- `search`
- `sources`
- `unit`
- `facts`
- `meta`
- `rebuild`

Rebuilds are atomic and validated before replacing the stable database.

## Retrieval policy

Use `/index` or `@index` freely for exhaustive corpus research. User-invoked retrieval inherits the initiating model and never waits for a configured free model. AI-driven delegation may use the selector to choose a cheaper adequate route.

For code symbols and call paths, use native `@explore`. For current public information, use native web tools. For mixed project content, use `@index` / `content_index`.

## Fact modes

- `none`: fastest; ordinary retrieval.
- `general`: broad reusable structured/prose facts.
- `special`: request-specific `FAMILY=REGEX` overlays.
- `both`: general plus focused overlays.

Prefer the least expensive mode that materially helps the task.
