# Backend activity contract — v1

The backend attaches tokenomics_activity to the existing parent tool part's
state.metadata. OpenCode publishes its ordinary message.part.updated event after
the SDK part update. The durable local delegate receipt also has activity with
the same payload. No extra model calls or public tools are created.

| Field | Meaning |
|---|---|
| schema_version | 1 |
| phase | waiting, working, tool, completed or failed |
| label | Short display text |
| child_session | Native child session ID |
| selected_model | Provider-qualified selected model |
| role | worker, architect, researcher or review |
| tool | Active native tool name, when available |
| subject | File basename, when available |
| completed_tools | Observed completed tool call count |
| elapsed_ms | Time since child dispatch |
| updated_at | UTC timestamp |

Failure events may omit fields not yet observed. Subscribe by session and tool
part ID. Updates occur when activity changes and at most five seconds apart while
polling continues. They are snapshots, not an exactly-once event ledger. Reconnect
by reading the current part/receipt. Always reconcile completion with the receipt;
an activity label is not proof of correctness or a token-savings measurement.

Completion metadata also retains the restoration marker because the host replaces
running metadata when it stores a final result. SDK presentation requests have a
three-second timeout so display failures cannot wait indefinitely.

The Desktop adapter reuses the real call ID and native task card to expose the
child link and current activity. It restores the original delegate call in model
history. V1.18.31 exposes plugin metadata() as an unevaluated Effect; the adapter
uses the existing authenticated SDK part-update endpoint instead. Legacy session
markers are read for compatibility, while new writes use tokenomics names.

Activity never copies reasoning, shell arguments, full paths or raw tool output.
Click the native child card for its full tool transcript. This is current activity
in the parent chat, not a duplicate streaming transcript.
