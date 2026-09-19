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

The toolkit does not impose shell/Git approval policy. Remote reads and mutations follow your OpenCode permission settings; the `sync` skill still requires explicit intent for destructive operations such as merging, deleting, force-pushing, or rewriting published history.

The `sync` skill defines the publishing contract.
