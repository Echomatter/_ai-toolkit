# Toolkit development instructions

This repository is a thin workflow layer around OpenCode. Do not rebuild capabilities OpenCode already provides.

- OpenCode owns Build, Plan, Explore, model/provider plumbing, tools, permissions, web search/fetch, context management, child sessions, and `/models`.
- Keep the public catalog to five skills (`reorient`, `search-index`, `sync`, `model-routing`, `record-outcome`), customized Build plus four helpers (`worker`, `architect`, `researcher`, `review`), and two tools (`content_index`, `delegate`).
- Roles are jobs, not models. Never hard-wire a model to a helper when `delegate` plus `scripts/select-model.ps1` can bind a child at execution time.
- User-invoked skills and helpers inherit the selected parent model. Agent-initiated children use the selector and must actually run on the chosen model.
- Review is read-only. Researcher must not modify project source. Worker does not spawn Worker.
- Do not create a switchboard, custom primary Auto agent, or toolkit slash-command wrappers.
- Never bind convenience commands to Plan. Skills do not switch Build into Plan.
- Do not impose broad shell, PowerShell, edit, or external-directory approval rules from the toolkit.
- Whole-session model changes remain explicit user actions through `/models`.
- Prefer free/deterministic retrieval first. Missing index hits must never block code search.
- If a paid child fails for quota/rate/provider/auth, do not loop or jump to metered APIs; continue on the parent and report the unresolved remainder.
- Preserve user-authored global OpenCode instructions outside the toolkit-managed block in `~/.config/opencode/AGENTS.md`.
- Automatic routes may use OpenCode free, OpenCode Go, OpenAI OAuth, and GitHub Copilot OAuth. No separately metered API gateways.
- Validate PowerShell 5.1 syntax and all skill/agent/tool mappings before packaging.
