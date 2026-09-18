---
description: Use the free index worker to search or refresh the active project's mixed-content corpus
agent: index
subagent: true
---

Load `content-index-research` and use the `content_index` tool.

Interpret the user's arguments as the retrieval task. Check index status when freshness matters. Rebuild only when missing/stale or when a requested fact layer materially helps. Prefer exact search first, then terminology expansion, and return source/locator evidence plus any coverage gaps.

Do not treat index output as authoritative source content.
