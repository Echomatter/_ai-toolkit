---
description: OpenCode native Build agent with toolkit routing. Tool approvals inherit the user's OpenCode permission settings.
mode: primary
model: __ROUTINE_MODEL__
steps: 40
permission:
  plan_enter: deny
  task:
    "*": deny
    explore: allow
    index: allow
    worker: allow
    deep: allow
    review: allow
---

