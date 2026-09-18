# Model Advisor

The advisor separates free execution, paid escalation, and whole-session promotion.

## Default economics

Routine work stays on hosted free models. Search/retrieval should prefer native tools, web tools, Explore, Worker, and Index before subscription escalation.

## Delegation

A bounded hard problem may be sent to `@deep`. Independent verification may be sent to `@review`.

When those lanes resolve to subscription/OAuth models, OpenCode asks the user before an agent launches them.

If permission is declined or the paid model is quota/rate/auth/provider unavailable, the free parent continues. The paid failure should not block the task.

## Promotion

When the rest of a phase broadly benefits from a different model, the toolkit recommends a model but never switches the session automatically. Use `/models` explicitly.

## Explicit recommendation

```text
/recommend-model <next phase>
```

The deterministic selector evaluates currently eligible hosted-free and OAuth/subscription models using sourced evidence plus local task history.

When the recommended model is subscription/OAuth, the fallback should be the best eligible hosted-free candidate so quota/service exhaustion has a usable path.

Separately metered API gateways/providers and local model engines remain outside automatic advice.

## Evidence policy

Use official provider/model documentation for concrete capabilities and recent task-relevant independent evidence for coding/agent quality. Benchmark values belong to their model+harness+configuration and are not universal rankings.

## Current files

- `routing/model-roster.json` — currently accessible eligible models/surfaces.
- `routing/model-evidence.json` — sourced capability evidence.
- `routing/task-history.json` — empirical local outcomes.
- `routing/state.json` — current Build/Search/Deep/Review assignments.
