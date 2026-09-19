# Economics review and agent visibility audit — 2026-09-19

Audited the existing OpenCode conversation “Review token economic calculations with
free models”, parent `ses_f45708efdffeMKWqS0McUcoMrL`. No economics recommendations
were implemented in this pass; changes address visibility and recording accuracy.

## Actual execution and usage

Independent `opencode export` records agree exactly with both completed child receipts.

| Session/job | Actual model | Input | Output | Cache read | Reasoning |
|---|---|---:|---:|---:|---:|
| Parent/orchestration | openai/gpt-5.6-luna | 35,802 | 2,045 | 221,184 | 361 |
| Researcher/orientation | openai/gpt-5.5 | 99,046 | 3,470 | 290,816 | 1,170 |
| Researcher/economics | opencode/mimo-v2.5-free | 100,121 | 8,547 | 1,088,832 | 0 |

All three sessions report zero cache writes and zero provider dollars. OAuth zero
dollars does not mean zero subscription consumption. Cache reads are distinct runtime
counters, not additional uncached input. Reasoning is kept separate without assuming
it can be added to a provider's output figure. The two child model identities are
selected = dispatched = observed. Every parent assistant response remained Luna.

The independent Review call returned `no_qualified_route` with no child and no model
usage. The parent then obtained a second Researcher, not a successful Review role.
The finance-specialized Ling route did not run. Describing MiMo as proven
“finance-oriented” is unsupported by this execution alone.

Luna really offloaded work, but this does not prove a net saving against a Luna-only
run. There is no equivalent baseline. The workflow also consumed GPT-5.5 subscription
capacity, and both children read far more than the caller's token estimates. Broad
orientation and long returned reports can erase the economic benefit of delegation.
The first call requested terminal/deep-reasoning/diversity capabilities; the selector
found no proven free match and escalated. `preferredCostClass: free` is a preference,
not a hard spending constraint. A future hard free-only option is warranted.

The separate audit ledger is
`.state/session-usage/ses_f45708efdffeMKWqS0McUcoMrL.json`. It includes the parent's
own counters once, without duplicating child consumption or claiming measured savings.

## Recording corrections

Original child counters and provider identities were accurate. However:

- Both Researcher outcomes were mislabeled implementation; corrected to research.
- The recorder overwrote the paid escalation with false because it equated escalation
  with retry count. Paid escalation is now distinct from `fallback_used`.
- Parent usage was absent from child-only history; the separate session ledger fills
  that audit gap without adding a fabricated model-quality observation.
- MiMo's review contains mathematical errors, so its original outcome now has a linked
  review defect (`economics-audit-2026-09-19`). Existing successful test results remain
  intact; passing the repository suite does not validate every research claim.

Corrections update the same TaskIds, preserve revisions, and keep the prior history
backup at `.state/economics-history-before-correction.json`.

## Assessment of recommendations

Confirmed useful: account for cache-write tokens/rates; surface estimated Go limits
and pricing freshness; read Copilot's credit-dollar value from configuration; clarify
OpenAI proxy semantics; add 95–99% boundary cases; distinguish free preference from
free-only authorization. These are source-code/accounting conclusions, not a fresh
verification of external provider prices.

Corrections to the free review:

- Omitting cache-write cost can change rankings because models have different rates
  and workloads. Its claimed uniform ranking preservation and 10–30% magnitude were
  unsupported. Underestimating cost is not conservative budgeting.
- At 99% utilization with a 20% window share, pressure is `500 * monthlyFraction`.
  Final expense is `monthlyFraction * (1 + 500 * monthlyFraction)`, not automatically
  500 times the original expense. If the fraction is 0.001, the multiplier is 1.5.
- Go/Copilot class 0 outranking OpenAI's proxy class 1 reflects the current policy;
  that policy is not proof that the winning subscription is economically cheaper.

## Native agent cards

OpenCode 1.18.31's Desktop renderer recognizes child navigation only for the native
`task` part. Its generic custom-tool renderer ignores output/child metadata.
Sources: [native task renderer](https://github.com/anomalyco/opencode/blob/v1.18.31/packages/session-ui/src/components/message-part.tsx)
and [generic tool renderer](https://github.com/anomalyco/opencode/blob/v1.18.31/packages/session-ui/src/components/basic-tool.tsx).

The adapter presents the existing delegate part as a native task card using the
documented part-update endpoint. It preserves the call ID, result, status and actual
child session, verifies child ownership/model metadata, and explicitly labels the
card `delegate`. No task is re-executed. Original tool/input metadata is retained and
restored before history reaches a model. Completion now also preserves child metadata
through the plugin's structured tool result.

Two existing cards were repaired from verified receipts without any new model call.
Desktop was restarted and the free Researcher's card was clicked to inspect its real
transcript. A separate free-model live test verified automatic card creation and a
successful parent continuation; model history restoration did not cause duplicate work.
While a child is running, its card has native running status; opening it shows the
child's ongoing tools and messages. It is not an inline expansion of every child step.

Compatibility boundary: this uses OpenCode's current native renderer and plugin
message-transform contract. Raw exports expose `tool: task` plus
`tokenomics_delegate_display.original_tool: delegate`. Consumers must honor that
provenance. Removing the plugin removes model-history restoration; restore original
parts from that metadata before uninstalling or exporting to another runtime.
`node scripts/repair-delegate-cards.mjs LOCAL_SERVER SESSION_ID` repairs an existing
session with a backup and no inference. Add `--restore` to return its original tool
parts and mark them display-disabled, preventing the event hook from reapplying cards.

## Validation

Full Windows PowerShell 5.1 offline suite passed. Final focused runtime/presentation/
usage tests passed (40 tests), including exact history restoration, no duplicate child,
v1 authenticated transport support, deduplicated usage and incomplete-usage labeling.
Outcome fixtures cover paid escalation without fallback. Live check session:
`ses_f455b813affe5W0mEiZZtRJgRm`; child `ses_f455b47ccffe1gxe2rEH2sVJ3x`.
Raw logs/exports and backups remain ignored under `.state`.
