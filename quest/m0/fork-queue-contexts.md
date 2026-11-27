# [S] Fork PRs carry the queue's required contexts without a dispatch

## Goal

A fork PR's head carries the merge queue's required contexts (`Queue build / Build`, `Queue build / Build aarch64 Linux`, reported as skipped) after every push, with no person or agent dispatching anything, and no code from the PR runs to report them.

## Plan

Planned with the maintainer on 2026-11-27 (`/quest-run`).

- The failure: a fork PR's `pull_request` runs wait for approval on every push. Until someone approves them, `queue.yml` reports no skipped context, and GitHub refuses to enqueue with "N of N required status checks are expected". [kixel-ai/rind#931](https://github.com/kixel-ai/rind/pull/931) was blocked twice this way and landed only after `gh workflow run queue.yml -R kixel-ai/rind --ref main -f sha=<head>`.
- ✅ Fix it in rind with a job that runs only `main`'s code and never checks out the PR (rejected: having kixel-ai/quest's land fixer dispatch `queue.yml`; dispatching by hand). Recommended: a `pull_request_target` job, or one triggered from `queue.yml`'s existing `report` path, that posts the skipped check runs on the head SHA. First confirm whether GitHub holds `pull_request_target` runs from a fork for approval. If it does, pick a trigger it doesn't hold, such as a schedule over open fork PRs.
- Keep `queue.yml`'s `workflow_dispatch` path as the manual fallback.
