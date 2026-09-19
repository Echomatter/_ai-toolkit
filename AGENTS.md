# Toolkit development instructions

This repository is a thin workflow layer around OpenCode. Do not rebuild capabilities OpenCode already provides.

- OpenCode owns Build, Plan, Explore, model/provider plumbing, tools, permissions, web search/fetch, context management, child sessions, and `/models`.
- Keep custom runtime agents limited to Index, Worker, Deep, and Review plus the native `build` ID override used for model/routing configuration.
- Roles are stable; models are dynamically selected. Never hard-wire a model to a general-purpose subagent when the evidence-aware selector can choose at runtime. The deterministic selector (`scripts/select-model.ps1`) is the source of truth; never rank models from memory.
- For bounded delegated implementation, prefer the `delegate` tool with `@worker`. Reserve `@deep` for explicit strong-model escalation.
- Review seeks model/provider diversity from the implementation model; Index stays free-biased and read-only.
- Do not create a switchboard or custom primary Auto agent.
- Never bind convenience commands to Plan unless the command is genuinely planning-only.
- Do not impose broad shell, PowerShell, edit, or external-directory approval rules from the toolkit; those belong to the user's OpenCode settings. Agent files may keep only role-defining restrictions such as Review read-only and allowed subagent topology.
- Whole-session model changes must remain explicit user actions through `/models`.
- Prefer free/deterministic retrieval first: native Explore for code, `@index`/`content_index` for mixed project corpora, and native web tools for current public information.
- Automatic routing may delegate bounded work via the `delegate` tool (normally `@worker`), but must not silently switch the parent session model.
- If a paid Deep/Review lane fails for quota/rate/provider/auth availability, do not loop or jump to metered APIs; continue on free Build/retrieval tools and report only the unresolved remainder.
- Model recommendations should be sparse, task-specific, and evidence-informed. `/recommend-model` is the explicit advisor path.
- Preserve user-authored global OpenCode instructions outside the toolkit-managed block in `~/.config/opencode/AGENTS.md`.
- Automatic routes may use OpenCode free, OpenCode Go subscription, OpenAI OAuth, and GitHub Copilot OAuth surfaces. No separately metered API gateways. Provider-qualified overlaps remain distinct identities.
- Validate PowerShell 5.1 syntax and all skill/command/agent mappings before packaging.
