---
name: github-ops
description: Use when the task needs GitHub issues, pull requests, workflow runs, releases, repository metadata, or other remote GitHub state; use local git for local state and authenticated GitHub CLI for remote state, with read-before-write safeguards.
---

# GitHub Ops

Goal: use GitHub naturally without adding a GitHub MCP server to every model context.

## Procedure

1. Use `git` for local branch, status, diff, log, blame, and worktree state.
2. Use authenticated `gh` for remote GitHub state:
   - `gh repo view`
   - `gh issue list|view`
   - `gh pr list|view|diff|checks`
   - `gh run list|view`
   - `gh release list|view`
3. Prefer structured `--json` output when the result will be reasoned over programmatically.
4. Read the exact repository/resource before any mutation. “Read before write” means inspect first, then continue with the requested mutation; it does not make the session read-only.
5. Routine remote reads may proceed without approval.
6. If the user explicitly requests a commit, push, issue/PR change, or other ordinary remote mutation, perform the necessary inspection and then attempt that mutation. Let OpenCode's `ask` permission produce the approval prompt where configured.
7. Never infer or announce that the session is in Plan mode because this skill began with read-only inspection or because a command requires approval. Skills do not change the active OpenCode agent/mode. If a tool is blocked, report the actual permission block.
8. Never merge a PR, close/delete a resource, force-push, rewrite published history, change repository settings, or perform destructive remote actions unless the user explicitly asks for that exact action.
9. Do not print tokens or credential files. If auth is missing, report `gh auth login` as the required setup step.
