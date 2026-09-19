# Packaging assessment — 2026-09-19

Recommendation: retain the existing local OpenCode plugin during development;
eventually distribute it as one versioned npm package. No migration implemented.

OpenCode already loads local plugins and npm packages, including scoped packages.
Our `opencode/plugins/delegation.ts` is already inside that native container. A
package can ship the runtime, scripts, routing evidence and profile assets together,
reducing checkout-path and version skew. It would still need a small ownership-aware
step for the five skill folders, customized Build/four helpers and managed global
instruction block. Keep user state and receipts outside a replaceable package cache.
Remove the old local entry during migration: OpenCode can load local and npm entries
separately, which would duplicate hooks.

The installed CLI/Desktop are 1.18.31. The CLI exposes `opencode plugin <module>`
with global/force flags. OpenCode's separately documented v2 plugin API includes a
broader plugin manager and plugin-owned storage. Its APIs and configuration differ;
do not copy v2 setup into the installed v1 adapter without a compatibility migration.

Native sessions, permissions, tools and model plumbing remain OpenCode's job.
The selector's evidence/economics and validated outcome policy remain toolkit work;
a package manager does not replace those decisions. Do not add a second agent host,
MCP server, primary switchboard or custom plugin manager for distribution.

Primary references inspected:

- [OpenCode local/npm plugins](https://dev.opencode.ai/docs/plugins/)
- [OpenCode v2 plugin management](https://opencode.ai/v2/docs/plugins)
- [OpenCode v2 plugin API](https://opencode.ai/v2/docs/build/plugins)
