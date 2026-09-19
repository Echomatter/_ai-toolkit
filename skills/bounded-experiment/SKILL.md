---
name: bounded-experiment
description: Use when an uncertain ML, DSP, solver, API, performance, or implementation idea should be tested cheaply before committing to it; keep the experiment small, reproducible, and disposable.
---

# Bounded Experiment

Goal: answer one uncertain question with the smallest reproducible experiment that can settle it.

## Procedure

1. State the hypothesis internally in one line.
2. Define a concrete work bound before running: examples include one API call, one tiny dataset, N iterations, one fixture, one benchmark case, or one smoke-test configuration. Prefer work/attempt bounds over vague wall-clock estimates.
3. Use scratch/temp output or an isolated fixture where possible. Do not contaminate reference/read-only sources.
4. Record the exact input/config/seed/metric that matters for reproduction.
5. Stop when the hypothesis is confirmed, refuted, or the defined bound is exhausted. Report inconclusive rather than silently expanding into a large run.
6. Full training runs, exhaustive searches, large dataset generation, long benchmarks, or expensive cloud jobs require explicit operator intent.
7. Clean up disposable artifacts unless they are useful evidence or the user asked to keep them.
