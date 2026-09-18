# Toolkit development instructions

This repository is a thin workflow layer around OpenCode. Do not rebuild capabilities OpenCode already provides.

- OpenCode owns Build, Plan, Explore, model/provider plumbing, tools, permissions, web search/fetch, context management, child sessions, and `/models`.
- Keep custom runtime agents small and functional: free Worker + Index, paid Deep + Review, plus the native `build` ID override.
- Do not create a switchboard or custom primary Auto agent.
- Never bind convenience commands to Plan unless the command is genuinely planning-only.
- Do not impose broad shell, PowerShell, edit, or external-directory approval rules from the toolkit; those belong to the user's OpenCode settings. Agent files may keep only role-defining restrictions such as Review read-only and allowed subagent topology.
- Whole-session model changes must remain explicit user actions through `/models`.
- Free Worker/Index/Explore delegation may run normally. Agent-initiated subscription Deep/Review calls must use `ask`; declined/quota/rate/auth/provider failures fall back to the free path rather than blocking work.
- Model recommendations should be sparse, task-specific, and evidence-informed. `/recommend-model` is the explicit advisor path.
- Preserve user-authored global OpenCode instructions outside the toolkit-managed block in `~/.config/opencode/AGENTS.md`.
- Keep the `content_index` integration as a deterministic locator/completeness aid; exact claims still require the governing source.
- Automatic routes may use only hosted OpenCode free, OpenAI OAuth, and GitHub Copilot OAuth surfaces. No local model engine and no separately metered API gateways.
- Validate PowerShell 5.1 syntax and all skill/command/agent mappings before packaging.
