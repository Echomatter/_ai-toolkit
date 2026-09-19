---
name: model-routing
description: Own model-choice guidance, evidence refresh, quota economics, and explanation of delegated selections. Advice does not switch a session. Child selection must execute on the chosen model via the delegate tool.
---

# Model Routing

Skills never change the active OpenCode mode. Parent models never change silently.

## Two jobs

- **Advice** for the user's next phase: recommend; do not switch.
- **Child selection**: call `delegate`, then the selected child must actually run on the chosen model. A recommendation that another role ignores is not execution.

Use `scripts/select-model.ps1`. Do not rank models from memory or lane names. Capability qualification is separate from economics. Unknown capability is not adequate. Unknown price or missing telemetry is not free or unlimited. No unapproved overage.

## Roles (jobs, not models)

- **Build**: customized parent. User's selected model.
- **Worker**: bounded implementation when assigned.
- **Architect**: hard tradeoffs / architecture. Name does not force Plan or an expensive model.
- **Researcher**: orientation and investigation. Read-only on project source.
- **Review**: independent read-only verification. Prefer a different model family when a capable alternative exists. Same-model review is not cross-model verification.

User-invoked skills/helpers inherit the selected parent model unless the user overrides. Agent-initiated children use `delegate`. Explicit user model override wins.

## Stay in Build when

Localized work, tests can settle it, retrieval reduced uncertainty, a free/adequate model can finish it.

## Delegate a child when

Bounded extra work, orientation (Researcher), independent review, or a narrowed hard decision (Architect). Call `delegate` first for agent-initiated work. Preserve parent. One attempt; no competing writer.

## Advice line (optional)

After a meaningful completed task, one line only when the next phase is clear and another model has a material advantage:

`Next model: <id> — <reason>. <stay | use @researcher/@explore | delegate via @worker | @architect | @review | switch with /models>`

Otherwise say nothing about models.

## Refresh

Only an explicit evidence refresh does live model research. Ordinary routing uses cached evidence. Coordinated index refresh may light-check inventory/quota once; do not cycle index → routing → research → index.

Eligible surfaces: OpenCode free, OpenCode Go, OpenAI OAuth, GitHub Copilot OAuth. Provider-qualified IDs stay distinct. No metered API gateways.
