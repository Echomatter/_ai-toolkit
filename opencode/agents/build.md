---
description: OpenCode native Build agent with toolkit routing and guarded remote-write permissions.
mode: primary
model: opencode/muse-spark-1.3-contributor-free
steps: 40
permission:
  read: allow
  glob: allow
  grep: allow
  lsp: allow
  skill: allow
  webfetch: allow
  websearch: allow
  question: allow
  plan_enter: deny
  external_directory: ask
  doom_loop: ask
  edit: allow
  bash:
    "*": ask
    "git status*": allow
    "git diff*": allow
    "git log*": allow
    "git show*": allow
    "git grep*": allow
    "git branch --show-current*": allow
    "rg *": allow
    "where.exe *": allow
    "Get-ChildItem *": allow
    "Get-Content *": allow
    "Select-String *": allow
    "python -m pytest*": allow
    "pytest*": allow
    "npm test*": allow
    "npm run test*": allow
    "npm run build*": allow
    "dotnet test*": allow
    "cargo test*": allow
    "ctest*": allow
    "gh auth status*": allow
    "gh repo view*": allow
    "gh issue list*": allow
    "gh issue view*": allow
    "gh pr list*": allow
    "gh pr view*": allow
    "gh pr diff*": allow
    "gh pr checks*": allow
    "gh run list*": allow
    "gh run view*": allow
    "gh release list*": allow
    "gh release view*": allow
    "opencode auth list*": allow
    "opencode models*": allow
    "ollama list*": allow
    "ollama show*": allow
    "git commit*": ask
    "git push*": ask
    "git reset --hard*": deny
    "git clean*": deny
    "gh pr merge*": deny
    "gh repo delete*": deny
  task:
    "*": deny
    explore: allow
    deep: allow
    review: allow
---
