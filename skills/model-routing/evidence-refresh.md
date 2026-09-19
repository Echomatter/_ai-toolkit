# Explicit evidence refresh

Use this procedure only when the user requests model evidence maintenance. Ordinary
delegation reads the cached roster and evidence; it does not browse or modify them.

1. Capture `opencode --version`, connected provider IDs and eligible model IDs using
   `scripts/refresh-routing.ps1`. Keep exact provider-qualified identities. Inventory
   discovery is not proof of account entitlement or successful inference. Do not
   export credentials. Preserve operational blocks until recovery is verified.
2. List the actual research gaps before browsing: identity/alias, context input and
   output limits, tool use, terminal work, reasoning, task capabilities, and freshness.
   Unknown and searched-with-no-evidence are separate states. Do not fill either with
   optimistic numerical defaults.
3. Read official provider documentation/model cards first, then independent evidence
   relevant to the intended task. Register every URL in `routing/model-evidence.json`
   with publisher, retrieval timestamp and what it supports. Distinguish marketing
   claims, public evaluations and observed local outcomes. Do not infer that a
   provider alias has identical capabilities, context or economics to another route.
4. Record confidence and supporting source keys for each capability. Record exact
   benchmark version, harness, agent/tool setup, reasoning settings and date. Compare
   scores only when these are comparable; otherwise explain the gap. A single local
   fixture is not a model benchmark. Provider failures are availability evidence.
5. Validate aliases against the actual inventory, including Go identity mappings.
   Preserve unknown variants and unsupported aliases as research gaps. Keep provider
   price proxies separate from subscription usage, measured session tokens and cash
   charges. Label estimated or unavailable quota conversion explicitly.
6. Stage refreshed JSON before replacing the cache. Verify schema version, models,
   aliases, registered sources, timestamps, capability ratings/confidence, context
   numbers and benchmark metadata. Run `scripts/validate.ps1` and the selector/quota
   contracts against the candidate. Reject malformed JSON or dangling source keys.
7. Set readiness honestly: partial evidence stays partial. Update evidence freshness
   only for evidence actually retrieved, not because inventory or quotas refreshed.
   Summarize changed identities, confidence, exclusions and remaining research gaps.

No new public skill, command wrapper, routing layer or parent-model switch is involved.
