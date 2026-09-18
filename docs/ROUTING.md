# Routing

## Build — free primary

Normal interactive work starts on the hosted free routine model. Build handles ordinary implementation, debugging, tests, refactors, GitHub reads, and web research.

## Worker — free bounded work

Use `@worker` for context-isolated implementation, tests, mechanical refactors, or targeted investigation. Worker is pinned to the free routine model.

## Index — free corpus retrieval

Use `@index` for exhaustive mixed-content search, cross-document evidence mapping, and "find all" requests. It is pinned to the free search model and uses the deterministic `content_index` tool.

Native Explore/grep/LSP remain the preferred code-structure search path.

## Deep — subscription escalation

Deep is used only after the free path has narrowed a genuinely hard problem: repeated bounded failure, unresolved architecture/state boundaries, subtle algorithmic/DSP/ML/security/firmware work, unexplained validation failures, or explicit strongest-model requests.

When Deep is a subscription/OAuth model, an agent attempting to launch it gets an OpenCode approval prompt. Declining that prompt does not stop the task.

## Review — subscription independent verification

Review is read-only and used for explicit audits or consequential changes. When it is a subscription/OAuth model, agent-initiated Review also requires approval.

## Paid failure behavior

Paid subagents are optional accelerators, not dependencies.

If Deep/Review is declined or fails because quota, rate limit, authentication, outage, or model availability is exhausted:

1. do not repeatedly retry it;
2. return to the free parent;
3. use Worker/Index/Explore/native web tools;
4. validate deterministically where possible;
5. report only the remaining unresolved gap.

## Session promotion

The toolkit never changes the current session model automatically. If a whole phase materially benefits from another model, recommend it and let the user switch explicitly with `/models`.

## Economic boundary

Automatic routing/model advice may use:
- current hosted OpenCode free models;
- OpenAI OAuth / ChatGPT subscription models;
- GitHub Copilot OAuth subscription models.

Local model engines and separately metered API-key/gateway providers are intentionally outside the toolkit.

See `MODEL-ADVISOR.md` and `CONTENT-INDEX.md`.
