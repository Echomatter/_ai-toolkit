# OpenCode Build Routing Toolkit

A small workflow layer for OpenCode Desktop and CLI. OpenCode remains the execution harness; this toolkit adds model-aware Build routing, portable skills, strong-model delegation, independent review, and explicit next-phase model advice.

## What OpenCode already owns

OpenCode owns Build, Plan, Explore, tools, permissions, provider authentication, websearch/webfetch, context management, model discovery, `/models`, and child sessions. The toolkit does not replace those capabilities.

OpenCode's Scout agent is experimental in the stable line and is **not required** here. Build performs external research with native web tools and uses Explore for active-repository search.

## What this toolkit adds

### Desktop agents

- **Build** — OpenCode's native primary ID, pinned to the current free/routine model with guarded permissions.
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
- `handoff-brief`

### Commands

- `/reorient` — refresh repository context without entering Plan.
- `/prior-art` — search sibling local repos through Explore.
- `/github` — use local git + authenticated `gh`; writes follow normal OpenCode approval.
- `/audit` — independent Review child session.
- `/routing` — explain current lane assignments.
- `/recommend-model` — recommend the best current model for the next phase without switching it.

## Routing and promotion

1. Build starts immediately on a current free/routine model.
2. Build uses native Explore for active-repo search and native web tools for current external research.
3. A bounded hard portion may be delegated automatically to Deep.
4. Review independently audits meaningful changes when requested or warranted.
5. The toolkit **never switches the whole session automatically**.
6. When the next phase clearly benefits from another model, Build may append one compact `Next model:` recommendation. If there is no material advantage, it says nothing about models.
7. `/recommend-model` performs the deeper evidence-backed comparison on demand.

`routing/model-roster.json` is regenerated from the models and non-metered access surfaces OpenCode can actually see.

Eligible automatic/recommended surfaces are OpenCode free models, OpenAI OAuth/ChatGPT subscription models, GitHub Copilot OAuth models, and optional local Ollama. Separately metered API gateways are excluded.

## Install / refresh

```powershell
F:\_ai-toolkit\scripts\bootstrap.cmd
F:\_ai-toolkit\scripts\doctor.cmd -Deep
```

Bootstrap preserves any user-authored `%USERPROFILE%\.config\opencode\AGENTS.md` content and maintains the toolkit guidance inside a marked block.

After bootstrap, **fully quit and reopen OpenCode Desktop**. You should see **Build** and **Plan**. Typing `@` should expose `deep`, `review`, and OpenCode's built-in `explore`.

When your connected model inventory changes:

```powershell
F:\_ai-toolkit\scripts\refresh-routing.cmd
```

Then start a new OpenCode session (or restart Desktop) so the refreshed model assignments and global guidance are cleanly loaded.

## GitHub

Use normal local `git` plus authenticated GitHub CLI:

```powershell
gh auth login
```

No GitHub MCP is required.

## Optional local fallback

Ollama/Qwen is not required. Install it only if you want an offline/private fallback:

```powershell
F:\_ai-toolkit\scripts\install-local-fallback.cmd
```

## MCP

No MCP server is required for the default workflow. Add one only for a capability OpenCode and the CLI tools do not already provide.

See `docs/ROUTING.md` and `docs/MODEL-ADVISOR.md` for the routing and promotion model.
