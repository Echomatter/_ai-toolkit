# Setup

1. Run `scripts\bootstrap.cmd`.
2. Connect OpenAI and/or GitHub Copilot inside OpenCode if desired.
3. Run `gh auth login` for remote GitHub operations.
4. Run `scripts\refresh-routing.cmd` after provider/model changes.
5. Fully quit and reopen OpenCode Desktop, or start a new session after routing changes.
6. Confirm native **Build** and **Plan** are available.
7. Type `@` and confirm built-in `explore` plus toolkit `researcher`, `worker`, `architect`, `review` are available.
8. Run `scripts\doctor.cmd -Deep`.
9. Confirm the five skills (`reorient`, `search-index`, `sync`, `model-routing`, `record-outcome`) resolve.

Normal work should stay in Build. Use Plan only when you explicitly select it.

For a hard bounded chunk, Build may delegate to Architect via the `delegate` tool. For a whole next phase that needs a stronger model, the toolkit recommends a model but leaves the actual `/models` switch to you.

The terminal launcher remains optional. Normal work can use OpenCode Desktop.
