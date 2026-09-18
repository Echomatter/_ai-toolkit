# Toolkit development instructions

This repository is a thin workflow layer around OpenCode. Do not rebuild capabilities OpenCode already provides.

- OpenCode owns Build, Plan, Explore, model/provider plumbing, tools, permissions, web search/fetch, context management, child sessions, and `/models`.
- Keep custom runtime agents limited to Deep and Review plus the native `build` ID override used for model/permission configuration.
- Do not create a switchboard or custom primary Auto agent.
- Never bind convenience commands to Plan unless the command is genuinely planning-only.
- Whole-session model changes must remain explicit user actions through `/models`.
- Automatic routing may delegate bounded hard chunks to Deep, but must not silently switch the parent session model.
- Model recommendations should be sparse, task-specific, and evidence-informed. `/recommend-model` is the explicit advisor path.
- Preserve user-authored global OpenCode instructions outside the toolkit-managed block in `~/.config/opencode/AGENTS.md`.
- Automatic routes may use only OpenCode free, OpenAI OAuth, GitHub Copilot OAuth, and optional Ollama surfaces. No separately metered API gateways.
- Validate PowerShell 5.1 syntax and all skill/command/agent mappings before packaging.
