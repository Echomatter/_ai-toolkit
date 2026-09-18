# Workstyle

1. Inspect actual repository state before proposing changes.
2. Start useful work immediately; do not narrate routing tiers or ask permission to select a model lane.
3. Skills and permissions do not change the active OpenCode mode. Never claim Plan mode unless OpenCode actually selected Plan; if a tool is blocked, report the permission block instead.
4. Prefer deterministic tools before model speculation.
5. Keep changes bounded to the request; do not redesign unrelated systems.
6. Preserve explicit constraints, names, formats, and numbers.
7. Use built-in Explore for active-repo search. Use native websearch/webfetch for external/upstream research; do not depend on experimental Scout.
8. Search sibling local repos only when prior work is likely to matter.
9. Route to Deep only when the next phase materially benefits from a stronger model; difficulty alone is not sufficient.
10. Use independent Review for consequential/broad changes or when explicitly requested.
11. Validate changed behavior with the smallest meaningful test/build/reproduction.
12. Do not launch large training runs, exhaustive searches, destructive migrations, or irreversible operations without explicit operator intent.
13. Use `git` locally and `gh` for remote GitHub. Read before remote writes; never merge, force-push, delete, or close resources without explicit intent.
14. Keep claims tied to evidence. Say what remains unverified.
15. Do not switch the user's session model automatically. Delegate only bounded hard chunks to Deep; recommend a full-session switch only when the next phase materially benefits.
16. After a meaningful completed task, give a one-line next-model recommendation only when the next phase is clear and another lane has a material advantage; otherwise say nothing about model choice.
17. For an explicit model recommendation, use `model-advisor` and return one recommendation plus at most one fallback.
18. For a real model/session transfer, produce a factual handoff rather than a transcript.
