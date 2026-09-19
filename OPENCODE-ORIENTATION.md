Orient to Tokenomics AI Tool Kit V1 after the repository reorganization.

Read the root AGENTS.md, README.md and tokenomics.json first, then the AGENTS.md
and README.md inside Tokenomics-OpenCode-Desktop.

The three folders are:
- Tokenomics-OpenCode-Desktop: the working V1 backend for OpenCode Desktop and CLI.
  Routing, delegation, evidence, outcome recording and structured status live here.
- Tokenomics-OpenCode-Terminal: the future native terminal UI module; currently a
  design stub. Reuse the backend. Do not implement or publish an npm package yet.
- Tokenomics-Codex-Desktop: stub only; implementation TBD.

Old root-level scripts, routing, tools, skills, opencode, tests and docs now live
inside Tokenomics-OpenCode-Desktop. Run backend maintenance/tests from that folder.
Resolve installed backend paths using ~/.config/opencode/tokenomics-root.txt.
Local history, receipts, captures and quota state live in its ignored .state.

Use Reorient for a bounded read-only orientation. Return the folder map, current
branch/status, installed-root consistency and any stale path references. Do not
invent an implementation task or edit files merely to orient.

Keep the current parent model. Use freeOnly for any automatic child in this
orientation. Delegate already executes the selected child; do not launch it twice.
For later work, send one bounded deliverable with named inputs/allowed files,
an acceptance check and a stopping point. Use the evidence status/show/capture/apply
workflow for requested research, checkpoint each small batch and review its actual
sources. Do not rewrite the entire catalog or reweight models to force routes.
Keep OpenCode's native permissions, models, child sessions and tools.
