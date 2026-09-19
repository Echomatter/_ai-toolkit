---
description: Read or update remote GitHub state for the current repository using authenticated gh CLI
---

Load `github-ops`. Use local git for local state and authenticated `gh` commands for the remote GitHub question. Inspect before writing. If the user explicitly requested an ordinary remote mutation such as commit/push or issue/PR metadata change, continue to that mutation and let OpenCode request tool approval where configured. Do not claim Plan mode unless the user actually selected Plan.
