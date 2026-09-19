# Tokenomics OpenCode Desktop

A thin workflow layer for OpenCode Desktop and CLI: five skills, our customized Build parent plus four helpers, the deterministic content index, and evidence-aware child execution. OpenCode owns the underlying models, authentication, native tools, permissions and sessions.

Backend root: this folder contains all scripts, routing data, tools and tests. Terminal UI planning and the Codex stub are sibling folders.

## Public catalog

| Kind | Names |
|---|---|
| Skills | `reorient`, `search-index`, `sync`, `model-routing`, `record-outcome` |
| Helpers | `@worker`, `@architect`, `@researcher`, `@review` |
| Custom tools | `content_index`, `delegate` |

Build is customized, not stock. Native Plan and Explore remain. There are no toolkit slash-command wrappers. Skills may still appear in OpenCode's native slash menu, but only one definition exists per skill.

User-invoked work keeps the selected parent model. Roles do not own models. For automatic child work, `delegate` calls the existing selector, creates a native child session, sends the provider-qualified model with the prompt, and checks returned session/message identity. It already runs the child: do not invoke another Worker after its result.

Desktop shows each real delegated child as a clickable native agent card, showing its selected model and current tool activity. Click the card to inspect the child's tools, progress and result. This display adapter reuses the same call/session; it never starts a second agent. Model-facing history retains the original `delegate` call. See [the visibility and economics audit](docs/ECONOMICS-AUDIT.md) for compatibility and measured usage.

**Verification status:** tested on OpenCode Desktop and CLI 1.18.31 with live cross-model child execution, unchanged parent models, a Researcher-to-Worker edit workflow, and isolated Windows PowerShell 5.1 regressions. See [verification and limits](docs/VERIFICATION.md) for evidence and provider coverage.

## Install V1

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1
```

Use the checked-out V1 revision. Fully quit and restart OpenCode afterward. The installer deploys the existing `delegate` tool through a plugin and removes its manifest-owned old advisory definition. It backs up changed owned resources, verifies copies/link targets, preserves unrelated skills and global instructions, and fails on unowned conflicts rather than deleting them.

For missing prerequisite software, `scripts/bootstrap.cmd` remains available. For an existing installation, use the normal installer above. Do not wipe account credentials, chat history or the OpenCode database.

## Working model

Reorient assigns orientation to Researcher and an additional task to Worker, preserving its full constraints and using the handoff before dependent edits. Other small tasks can stay in customized Build; useful roles are not compulsory stations in every request.

Researcher chooses index, native code search, relevant sibling repositories and web sources according to the question. The content index searches documents/data, not ordinary `.ts`, `.ps1` or `.py` source. Missing index hits never prevent code search.

Model Routing owns guidance; the existing selector owns deterministic capability and economic comparisons. No Economics agent or second ranking system is needed. Quota observations and recorded execution failures remain distinct from model capability evidence.

Review is read-only. Managed read-only children cannot use arbitrary shell or mutating custom tools. Return authorized validation/index maintenance to Build. Record Outcome attaches actual receipt usage after meaningful validation rather than assuming an agent's final answer is correct.

Sync is an explicit publishing workflow: checkpoint current work, inspect and integrate compatible incoming improvements, validate the final revision, then publish to `main` through permitted protections. Research alone never authorizes Sync.

## Tests

Run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-all.ps1` for the offline suites. See [verification](docs/VERIFICATION.md) for separate live exercises and limitations. CI needs no OAuth credentials or paid calls; its fixtures are not model-quality benchmarks.

Explicit user requests such as `freeOnly true` and "use only free models" are also
checked by the backend if a parent accidentally omits the tool flag. This narrow
syntax guard complements the normal required `freeOnly` argument; it is not a
general language interpreter. Paid children still use native permission prompts.

## V1 maintenance

Use [bounded evidence refresh](skills/model-routing/evidence-refresh.md) and [V1 verification](docs/V1-VERIFICATION.md). Actual outcome history is local in `.state/task-history.json`; the tracked routing file is an empty portable seed. Activity schema is documented in [STATUS-EVENTS.md](docs/STATUS-EVENTS.md).
