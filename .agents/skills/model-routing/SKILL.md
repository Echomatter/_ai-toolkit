---
name: model-routing
description: Use when deciding whether free Build/Worker/Index/Explore can finish the task or whether to request approved subscription Deep/Review help; keep routing free-first, bounded, and non-blocking.
---

# Model Routing

Skills never change the active OpenCode mode. Only the runtime/user agent selection determines Build vs Plan.

Goal: finish work with free hosted models and deterministic tools whenever practical. Escalation should improve a narrowed hard problem, not become a prerequisite for ordinary work.

## Lanes

- **Build**: free primary model for normal implementation, debugging, tests, refactors, GitHub reads, and web research.
- **Worker**: free bounded implementation/research child for parallel or context-isolated work.
- **Index**: free mixed-content retrieval worker using `content_index`; best for exhaustive/cross-document lookup.
- **Explore**: native OpenCode read-only repo/code search.
- **Deep**: strongest eligible OAuth/subscription reasoning/implementation lane.
- **Review**: independent read-only OAuth/subscription verifier when available.

## Default route

Use free paths first when they can settle the task:

- deterministic tools before model speculation;
- Explore/grep/LSP for code structure and call paths;
- Index for mixed PDFs/docs/data and "find all" retrieval;
- Worker for bounded implementation, tests, mechanical refactors, or parallel investigation;
- native web tools for current external research.

Do not use a paid lane merely because the task sounds sophisticated.

## Paid escalation

Use Deep when:
- bounded free attempts fail without a materially new hypothesis;
- architecture/state/concurrency/persistence boundaries remain ambiguous;
- correctness depends on subtle algorithms, DSP/ML, security, firmware/recovery, or irreversible data operations;
- a meaningful validation failure cannot be explained;
- the user explicitly asks for stronger reasoning.

Use Review when:
- the user explicitly asks for audit/review;
- a substantial/high-consequence implementation needs independent verification;
- model diversity materially reduces risk.

The generated agent permissions are the economic boundary:
- free subagents are `allow`;
- subscription/OAuth subagents are `ask`.

The user can approve or decline the paid child call. Direct manual `@deep` / `@review` invocation is already an explicit user action.

## Failure behavior

Paid escalation is never a blocking dependency.

If a paid child call is declined or fails due to quota exhaustion, rate limiting, authentication, provider outage, or model unavailability:

1. do not repeatedly retry the paid model;
2. return to the free parent;
3. use Worker/Index/Explore/native web tools to narrow or complete the task;
4. run deterministic validation when possible;
5. report the specific unresolved gap only if the free path cannot settle it.

Do not silently switch the whole session.

## Promotion

For a whole phase that materially benefits from another model, recommend it and let the user switch explicitly with `/models`. For bounded work, prefer a child delegation.

At the end of meaningful work, recommend another model only when the likely next phase is clear and the advantage is material.

## Economic boundary

Automatic routing and recommendations may use:
- current hosted OpenCode free models;
- OpenAI OAuth / ChatGPT subscription models;
- GitHub Copilot OAuth subscription models.

Do not route to local model engines or separately metered API-key/gateway providers.
