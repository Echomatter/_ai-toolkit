# OpenCode Build Routing Toolkit

A thin workflow layer for OpenCode Desktop and CLI. OpenCode remains the execution harness. This toolkit adds five skills, a customized Build parent plus four helpers, a deterministic content index, and evidence-aware child delegation.

## Public catalog

**Skills** (one name each): `reorient`, `search-index`, `sync`, `model-routing`, `record-outcome`.

**Helpers:** `@worker`, `@architect`, `@researcher`, `@review`.

**Tools:** `content_index`, `delegate`.

Native Plan and Explore remain. There are no toolkit slash-command wrappers.

Roles are jobs, not models. User-invoked skills and helpers inherit the selected parent model. Agent-initiated children use `delegate` plus `scripts/select-model.ps1` and must actually run on the chosen model.

## What OpenCode already owns

Build, Plan, Explore, tools, permissions, provider authentication, websearch/webfetch, context management, model discovery, `/models`, and child sessions.

## Install / refresh

```powershell
F:\_ai-toolkit\scripts\bootstrap.cmd
F:\_ai-toolkit\scripts\doctor.cmd -Deep
```

Bootstrap preserves user-authored `%USERPROFILE%\.config\opencode\AGENTS.md` content outside the toolkit-managed block.

After bootstrap, fully quit and reopen OpenCode Desktop. You should see **Build** and **Plan**. Typing `@` should expose `researcher`, `worker`, `architect`, `review`, and native `explore`.

When connected inventory changes:

```powershell
F:\_ai-toolkit\scripts\refresh-routing.cmd
```

Then start a new OpenCode session so refreshed guidance loads.

## Permissions and nested agents

The toolkit does not set broad shell/PowerShell approval rules.

- Build -> Explore / Researcher / Worker / Architect / Review
- Worker -> Explore / Researcher / Review
- Architect -> Explore / Researcher / Review
- Review -> Explore / Researcher
- Researcher is read-only on project source

OpenCode defaults to `subagent_depth` 1; set it to 2 in your own config if you want one nested level.

## Content index

`content_index` indexes mixed project docs/data, not ordinary `.ts`/`.ps1`/`.py` source. Missing index hits must never block code search. See `docs/CONTENT-INDEX.md`.

## Sync

An explicit Sync request checkpoints, reconciles compatible incoming work, validates, and publishes to `main`. Mentioning the skill is not permission to publish.

Eligible automatic surfaces: OpenCode free, OpenCode Go, OpenAI OAuth, GitHub Copilot OAuth. No separately metered API gateways.
