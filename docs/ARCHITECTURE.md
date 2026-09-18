# Architecture

```text
OpenCode Desktop
 |
 |-- Build (free primary)
 |    |-- Explore (native read-only code/repo search)
 |    |-- Worker  (free bounded coding/research)
 |    |-- Index   (free mixed-content retrieval)
 |    |-- Deep    (subscription/OAuth; ASK when agent-launched)
 |    `-- Review  (subscription/OAuth; ASK when agent-launched; read-only)
 |
 |-- Plan (native; user selects explicitly)
 |
 |-- content_index custom tool
 |    `-- tools/Project_Content_Indexer.py -> project .content-index SQLite/FTS5
 |
 |-- /recommend-model
 |    `-- deterministic selector + evidence ledger
 |
 |-- native websearch/webfetch
 |-- git + gh
 |-- ~/.agents/skills/*
 `-- ~/.config/opencode/AGENTS.md
      `-- toolkit-managed global routing/advice block + preserved user content
```

OpenCode owns execution, provider/model plumbing, `/models`, tools, permissions, context management, and child sessions.

The toolkit adds only:
- model assignments and economic permission boundaries;
- free Worker/Index helpers;
- deterministic model advice/evidence;
- the mixed-content retrieval tool;
- reusable skills and commands.

## Escalation boundary

Free hosted helpers run normally. Subscription/OAuth child calls are rendered as `ask`. Declining or exhausting a paid model returns work to the free parent instead of blocking the task.

Whole-session model changes remain explicit `/models` actions.

## Installation

Desktop-visible agents, commands, and the `content_index` tool are linked/copied into `~/.config/opencode/`. Portable skills are installed under `~/.agents/skills/`.

The toolkit-managed global `AGENTS.md` block carries current Build/Search/Deep/Review assignments and free-first fallback behavior without replacing user-authored instructions.
