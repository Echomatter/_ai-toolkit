# Tokenomics OpenCode Desktop V1 verification

Tested on Windows with OpenCode Desktop and CLI 1.18.31, Node and Python, on
19 September 2026. The repository was reorganized after preserving a local Git
checkpoint and the user's uncommitted evidence refresh.

## Verified

- All offline suites passed after the folder move: PowerShell 5.1 parsing, structural
  catalog validation, selector/quota regressions, content indexing, installation,
  outcome recording and refresh preservation.
- The final runtime suite passes 49 tests, including host completion replacing
  metadata, original delegate-history restoration, paid permission rejection,
  inherited free-only restrictions, omitted freeOnly flags and child identity.
- Five evidence contracts pass: duplicate keys, schema/reference rejection,
  stale-batch protection, captured-byte integrity, interrupted-commit replay and
  automatic OS lock release. A real public-source capture also succeeded.
- Isolated deployment tests cover migration from the old root locator and managed
  instruction markers, preserving user-authored instructions and recoverable backups.
  The actual installation points to Tokenomics-OpenCode-Desktop.
- Live CLI: free Muse Spark delegated a catalog read to free MiMo V2.5. Selected,
  dispatched and observed child models matched; exported parent messages retained
  Muse Spark. Completion retained the original delegate identity and freeOnly input.
- Live Desktop: the real MiMo Worker card changed from waiting for first tool to
  Working / 3 tool calls completed while the child was still running, then Finished.
  Three named files were read; no child shell or edits occurred. The clickable native
  card points to the actual child session. Completion restores delegate history.

## Bugs found by live tests

OpenCode 1.18.31 does not evaluate a plugin's host metadata Effect. The adapter now
uses its authenticated part-update API. The host also replaces metadata at final
completion while retaining the displayed task name; completionMetadata preserves
the original delegate call so the parent does not misinterpret it as a second task.

One free parent omitted the requested freeOnly flag. The chosen child was free, but
the receipt correctly exposed the missing constraint. A narrow backend guard now
retains explicit free-only user instructions independently of that omitted argument.
Tests include a paid selector result that must never dispatch in this case.

An OpenCode Desktop instance cached the former project identity across the GitHub
repository rename, causing a foreign-key error on new-session creation. Restarting
Desktop after the rename resolved this without database edits or lost conversations.

## Evidence and economics

The retained cache has 67 aliases, 57 canonical models and 107 sources, with no
structural errors. [The evidence report](MODEL-EVIDENCE-REFRESH.md) distinguishes
verified structure, the independent free-model spot review and unreviewed claims.
A free Muse Spark code review also identified evidence-transaction recovery and
metadata preservation issues; fixes were verified with regression tests.

The user's test actually dispatched three successful free Researcher children,
one successful free Review and two timed-out free Workers. The failed attempts are
now recorded as operational outcomes, with measured child usage where available.
They do not count as model-capability failures. Local historical results were
preserved in .state/task-history.json; the public seed is empty.

This proves offloaded execution, not a percentage saving. Parent and child counters
remain separate. An equivalent parent-only baseline is absent, so no token, quota
or cash-savings claim is made. Go pricing remains an explicitly labeled base-rate,
first-context-tier allocation estimate.

## Limits

Desktop progress is a compact activity snapshot, not a duplicate child transcript.
Click the card for the child's full native transcript. The adapter is version-specific;
future OpenCode UI/SDK changes need revalidation. Provider testing here used free
routes; paid permission and provider-failure paths use offline fixtures.

Terminal UI and Codex Desktop folders are stubs. No npm package was published.
Historical verification documents describe earlier revisions; this report governs V1.
