# GitHub integration

No GitHub MCP server is required for the default workflow.

## Local repository state

Use `git`:

```powershell
git status
git diff
git log
git show
git grep
```

## Remote GitHub state

Install/authenticate GitHub CLI:

```powershell
gh auth login
```

Then OpenCode can use read operations such as:

```powershell
gh repo view
gh issue list
gh issue view 123
gh pr list
gh pr view 42
gh pr diff 42
gh pr checks 42
gh run list
gh run view <id>
```

The toolkit permissions allow common remote reads without repeated approval. Remote mutations still fall back to approval, while PR merging and repository deletion are denied in the default Build lane.

The `github-ops` skill defines the operating rules.
