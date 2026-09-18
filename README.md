# OpenCode Build Routing Toolkit

A small workflow layer for OpenCode Desktop and CLI. OpenCode remains the execution harness; this toolkit adds free-first retrieval, deterministic mixed-corpus indexing, evidence-aware model routing, bounded strong-model delegation, independent review, and explicit next-phase model advice.

## What OpenCode already owns

OpenCode owns Build, Plan, Explore, tools, permissions, provider authentication, websearch/webfetch, context management, model discovery, `/models`, and child sessions. The toolkit does not replace those capabilities.

OpenCode's Scout agent is experimental in the stable line and is **not required** here. Build performs external research with native web tools and uses Explore for active-repository search.

## What this toolkit adds

### Desktop agents

- **Build** — OpenCode's native primary ID, pinned to the current free/routine model. Shell/tool approval behavior inherits your OpenCode permission settings.
- **Index** — free read-only helper for exhaustive mixed-corpus discovery through the deterministic project content index.
- **Deep** — subagent pinned to the strongest eligible subscription model available through OpenAI OAuth or GitHub Copilot OAuth.
- **Review** — independent read-only subagent, preferably on a different provider/model.

OpenCode Desktop loads these from `%USERPROFILE%\.config\opencode\agents\`.

### Portable skills

- `repo-reorient`
- `local-repo-research`
- `github-ops`
- `change-audit`
- `evidence-ledger`
- `bounded-experiment`
- `model-routing`
- `model-advisor`
- `content-index-research`
- `handoff-brief`

### Commands

- `/reorient` — refresh repository context without entering Plan.
- `/prior-art` — search sibling local repos through Explore.
- `/github` — use local git + authenticated `gh`; writes follow normal OpenCode approval.
- `/audit` — independent Review child session.
- `/routing` — explain current lane assignments.
- `/recommend-model` — characterize the task, invoke the deterministic evidence-aware selector, and recommend the best current model without switching it.
- `/refresh-model-evidence` — refresh sourced model capability evidence through current web research.
- `/record-outcome` — record a meaningful task result so local success, retries, escalation, and later review defects can influence future routing.
- `/index` — run the free corpus-retrieval helper for exhaustive project-content discovery.

## Routing and promotion

1. Build starts immediately on a current free/routine model.
2. Build uses native Explore for source-code search, `@index` for large mixed project corpora, and native web tools for current public research.
3. Broad retrieval is narrowed on free/deterministic tools before paid escalation.
4. A bounded hard portion may be delegated to Deep only when the remaining task warrants it.
5. Review independently audits meaningful changes when requested or warranted.
6. If a paid lane is unavailable because of quota/provider failure, work falls back to free Build + Index/Explore/web rather than looping or jumping to a metered route.
7. The toolkit **never switches the whole session automatically**.
8. When the next phase clearly benefits from another model, Build may append one compact `Next model:` recommendation. If there is no material advantage, it says nothing about models.
9. `/recommend-model` performs the deeper evidence-backed comparison on demand.

`routing/model-roster.json` is regenerated from the models and non-metered access surfaces OpenCode can actually see. Capability claims live separately in `routing/model-evidence.json`; empirical outcomes live in `routing/task-history.json`.

Eligible automatic/recommended surfaces are OpenCode free models, OpenAI OAuth/ChatGPT subscription models, and GitHub Copilot OAuth models. Separately metered API gateways are excluded.

## Install / refresh

```powershell
F:\_ai-toolkit\scripts\bootstrap.cmd
F:\_ai-toolkit\scripts\doctor.cmd -Deep
```

Bootstrap preserves any user-authored `%USERPROFILE%\.config\opencode\AGENTS.md` content and maintains the toolkit guidance inside a marked block.

After bootstrap, **fully quit and reopen OpenCode Desktop**. You should see **Build** and **Plan**. Typing `@` should expose `index`, `deep`, `review`, and OpenCode's built-in `explore`.

When your connected model inventory changes:

```powershell
F:\_ai-toolkit\scripts\refresh-routing.cmd
```

Then start a new OpenCode session (or restart Desktop) so the refreshed model assignments and global guidance are cleanly loaded.

## Permissions and nested agents

The toolkit does **not** set broad shell/PowerShell approval rules. Build and Deep inherit your OpenCode permission settings; Review adds only the role-defining `edit: deny` restriction.

Nested subagents are allowed selectively when your OpenCode `subagent_depth` permits them:

- Build -> Explore / Index / Deep / Review
- Deep -> Explore / Index / Review
- Review -> Explore / Index

The toolkit does not set `subagent_depth` for you. OpenCode defaults to depth 1; set it to 2 in your own OpenCode configuration if you want one additional nested level.

## Project content index

The toolkit installs a global `content_index` OpenCode custom tool backed by `tools/Project_Content_Indexer.py`. It creates a validated SQLite/FTS5 locator index over mixed project docs/data and stores the generated database in Git metadata when possible so it does not pollute the working tree.

Use native Explore/LSP/grep for code. Use `@index` / `content_index` for "find all", cross-document, PDF/spreadsheet/JSON/XML/archive, and other large-corpus work. The index is a locator, not source authority.

See `docs/CONTENT-INDEX.md`.

## GitHub

Use normal local `git` plus authenticated GitHub CLI:

```powershell
gh auth login
```

No GitHub MCP is required.


## MCP

No MCP server is required for the default workflow. Add one only for a capability OpenCode and the CLI tools do not already provide.

See `docs/ROUTING.md` and `docs/MODEL-ADVISOR.md` for the routing and promotion model.
