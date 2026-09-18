# OpenCode Free-First Toolkit

A thin workflow layer for OpenCode Desktop and CLI. OpenCode remains the execution harness; this toolkit adds free-first delegation, approval-gated subscription escalation, evidence-aware model advice, and deterministic mixed-content project retrieval.

## What OpenCode already owns

OpenCode owns Build, Plan, native Explore, tools, permissions, provider authentication, web search/fetch, context management, model discovery, `/models`, and child sessions. The toolkit does not replace those systems.

## Runtime model

### Agents

- **Build** — free primary model for normal work.
- **Worker** — free bounded coding/research subagent.
- **Index** — free retrieval subagent for exhaustive mixed-content corpus search.
- **Explore** — OpenCode's native read-only repo/code search.
- **Deep** — strongest eligible OpenAI/Copilot subscription model.
- **Review** — independent read-only subscription verifier.

Free subagents are allowed normally. When Deep or Review resolves to a subscription/OAuth model, agent-to-agent invocation is configured as **ask**, so OpenCode asks before spending that quota.

If a paid call is declined or fails because quota/rate/auth/provider availability is exhausted, the parent continues with free Worker/Index/Explore/native tools. Paid escalation is useful, not a blocking dependency.

Manual `@deep`, `@review`, or `/models` use remains explicit user control.

## Project content index

The toolkit includes `tools/Project_Content_Indexer.py` plus a global OpenCode custom tool named `content_index`.

The index is a deterministic SQLite/FTS5 retrieval layer for mixed project corpora including Markdown/text, JSON/XML/TOML/INI, CSV/TSV/XLSX, DOCX, PDF, and safe ZIP members. It is useful for requests such as:

- "find all references to..."
- cross-document comparisons
- repeated identifiers/values
- large rules/reference corpora
- structured fact inventory

Use `@index` or `/index` for this work. Native Explore/grep/LSP remain the preferred path for source-code symbols and call graphs.

The index is a locator/completeness aid, not source authority. Exact claims and edits should be checked against the governing source.

## Portable skills

- `repo-reorient`
- `local-repo-research`
- `github-ops`
- `change-audit`
- `evidence-ledger`
- `bounded-experiment`
- `model-routing`
- `model-advisor`
- `handoff-brief`
- `content-index-research`

## Commands

- `/reorient` — refresh repository context.
- `/prior-art` — search sibling local repos.
- `/github` — use local git + authenticated `gh`.
- `/index` — use the free index worker for mixed-content retrieval/rebuilds.
- `/audit` — request independent Review.
- `/routing` — explain current routing.
- `/recommend-model` — deterministic evidence-aware model recommendation.
- `/refresh-model-evidence` — refresh sourced model evidence through current web research.
- `/record-outcome` — record local empirical model performance.

## Routing principles

1. Start on hosted free models.
2. Prefer deterministic tools, native web/search, Explore, Index, and Worker.
3. Ask before agent-initiated subscription Deep/Review calls.
4. If paid escalation fails or is declined, continue free-first rather than stopping.
5. Never switch the whole session automatically.
6. Keep separately metered API-key/gateway providers outside automatic routing.
7. Use `/recommend-model` only when model choice materially matters.

`routing/model-roster.json` records current eligible access. `routing/model-evidence.json` records sourced capability evidence. `routing/task-history.json` records local outcomes.

## Install / refresh

```powershell
F:\_ai-toolkit\scripts\bootstrap.cmd
F:\_ai-toolkit\scripts\doctor.cmd -Deep
```

Bootstrap preserves user-authored global OpenCode instructions outside the toolkit-managed block.

After bootstrap, fully quit and reopen OpenCode Desktop. Build and Plan remain the primary modes. Typing `@` should expose `worker`, `index`, `deep`, `review`, and OpenCode's native `explore`.

Refresh routing after provider/model inventory changes:

```powershell
F:\_ai-toolkit\scripts\refresh-routing.cmd
```

## Permissions

The toolkit does not set broad shell/PowerShell approval rules. Those remain under your OpenCode settings.

The only agent-specific permission rules are role/routing rules such as Review being read-only and paid subagent invocation requiring approval.

## GitHub

Use normal local `git` plus authenticated GitHub CLI:

```powershell
gh auth login
```

No GitHub MCP is required.

## MCP

No MCP server is required for the default workflow. Add one only when OpenCode and local CLI/custom tools do not already provide the capability.

See `docs/ROUTING.md`, `docs/MODEL-ADVISOR.md`, and `docs/CONTENT-INDEX.md`.
