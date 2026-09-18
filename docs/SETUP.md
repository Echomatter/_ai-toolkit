# Setup

1. Run `scripts\bootstrap.cmd`.
2. Connect OpenAI and/or GitHub Copilot inside OpenCode if desired.
3. Run `gh auth login` for remote GitHub operations.
4. Run `scripts\refresh-routing.cmd` after provider/model changes.
5. Fully quit and reopen OpenCode Desktop, or start a new session after routing changes.
6. Confirm native **Build** and **Plan** are available.
7. Type `@` and confirm `worker`, `index`, `deep`, `review`, plus native `explore`.
8. Confirm `/index` and `/recommend-model` appear in slash commands.
9. Run `scripts\doctor.cmd -Deep`.

Normal work should stay free-first in Build/Worker/Index/Explore.

Agent-initiated paid Deep/Review use prompts for approval. If you decline or the provider is quota/rate/auth unavailable, the free path continues.

The toolkit does not install or manage a local model engine.
