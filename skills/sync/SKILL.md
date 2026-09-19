---
name: sync
description: Checkpoint current project changes, incorporate compatible incoming improvements, validate the combined result, and publish it to main. Explicit Sync authorizes ordinary commits, pushes, and compatible merges. Mentioning this skill is not permission to publish.
---

# Sync

Scope is the active repository and its verified remote. One publishing owner at a time. Do not stage or publish files while another helper is still writing them.

## Checkpoint

Inspect branch, working tree, remote, and staged/unstaged changes. Save intended additions, modifications, and deletions, including work not authored by the current agent. Exclude secrets, credentials, ignored artifacts, and private runtime/account data. Preserve a recoverable local checkpoint before integration. Do not discard uncommitted work or overwrite a branch owned by another worktree.

## Reconcile

Fetch remote state. Inspect incoming `main` and relevant open PRs/branches. Incorporate work that adds useful function, fixes defects, or fits current requirements. Newer is not automatically better. Do not resurrect removed skills, wrapper commands, or obsolete architecture. Resolve straightforward conflicts; skip and explain incompatible work.

## Validate and publish

Run meaningful validation on the combined result. Publish to `main` through the permitted direct-push or PR/merge route. Respect required checks and protections. Never force-push, rewrite published history, or bypass protections.

If remote `main` advances, reconcile before publishing. Do not publish a known-broken integration. Preserve the local checkpoint and report blockers.

Do not ask again for each ordinary action already authorized by Sync. Sync is not permission for unrelated releases, issue closures, branch deletion, or repository-setting changes.

Finish with: **committed, incorporated, published, skipped, blocked**. Distinguish a local commit from remote publication.
