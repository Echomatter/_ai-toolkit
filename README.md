# OpenCode Build Routing Toolkit

A thin workflow layer for OpenCode Desktop and CLI: five skills, our customized Build parent plus four helpers, the deterministic content index, and evidence-aware child execution. OpenCode owns the underlying models, authentication, native tools, permissions and sessions.

## Public catalog

| Kind | Names |
|---|---|
| Skills | `reorient`, `search-index`, `sync`, `model-routing`, `record-outcome` |
| Helpers | `@worker`, `@architect`, `@researcher`, `@review` |
| Custom tools | `content_index`, `delegate` |

Build is customized, not stock. Native Plan and Explore remain. There are no toolkit slash-command wrappers. Skills may still appear in OpenCode's native slash menu, but only one definition exists per skill.

User-invoked work keeps the selected parent model. Roles do not own models. For automatic child work, `delegate` calls the existing selector, creates a native child session, sends the provider-qualified model with the prompt, and checks returned session/message identity. It already runs the child: do not invoke another Worker after its result.

**Verification status:** the repository contains isolated execution/selection/deployment/outcome tests. Live cross-model execution through your installed, authenticated OpenCode remains a release gate. Read [verification and limits](docs/VERIFICATION.md) before treating fixture passes as live proof.

## Install the candidate

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "F:\_ai-toolkit\scripts\install.ps1"
```

Use the checked-out candidate revision. Fully quit and restart OpenCode afterward. The installer deploys the existing `delegate` tool through a plugin and removes its manifest-owned old advisory definition. It backs up changed owned resources, verifies copies/link targets, preserves unrelated skills and global instructions, and fails on unowned conflicts rather than deleting them.

For missing prerequisite software, `scripts/bootstrap.cmd` remains available. For an existing installation, use the normal installer above. Do not wipe account credentials, chat history or the OpenCode database.

## Working model

Reorient assigns orientation to Researcher and an additional task to Worker, preserving its full constraints and using the handoff before dependent edits. Other small tasks can stay in customized Build; useful roles are not compulsory stations in every request.

Researcher chooses index, native code search, relevant sibling repositories and web sources according to the question. The content index searches documents/data, not ordinary `.ts`, `.ps1` or `.py` source. Missing index hits never prevent code search.

Model Routing owns guidance; the existing selector owns deterministic capability and economic comparisons. No Economics agent or second ranking system is needed. Quota observations and recorded execution failures remain distinct from model capability evidence.

Review is read-only. Managed read-only children cannot use arbitrary shell or mutating custom tools. Return authorized validation/index maintenance to Build. Record Outcome attaches actual receipt usage after meaningful validation rather than assuming an agent's final answer is correct.

Sync is an explicit publishing workflow: checkpoint current work, inspect and integrate compatible incoming improvements, validate the final revision, then publish to `main` through permitted protections. Research alone never authorizes Sync.

## Tests

See [verification](docs/VERIFICATION.md) for isolated commands, the required live exercise and remaining limitations. The runtime workflow runs on Windows with no paid-model dependency; results are not evidence of actual provider model quality.
