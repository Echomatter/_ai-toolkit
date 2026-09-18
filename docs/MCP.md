# MCP policy

No MCP server is installed by default.

OpenCode already supplies the tools needed by this workflow: repository file/search tools, shell, LSP, webfetch, websearch, skills, and subagents. GitHub is handled through `gh`.

Add an MCP server only when a future task needs a capability that these tools do not provide cleanly (for example a specific SaaS/database integration). Treat every MCP as additional tool-schema/context overhead, especially for smaller models.
