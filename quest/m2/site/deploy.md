# [XS] A merge to main deploys rind.kixel.ai

## Goal

`rind.kixel.ai` serves what `site/` builds from `main`, and every merge to `main` deploys within the same CI run. The credential lives in a GitHub environment that only `main` can deploy to, so no pull request's workflow run can read it.

## Plan

Decided 2026-11-12 (maintainer, /quest-plan): ✅ Cloudflare, deployed by CI (rejected: `just deploy` by hand, as moq.dev does, which shows old numbers until someone remembers; GitHub Pages).

In place: `.github/workflows/site-deploy.yml` builds `main`'s tip and runs `wrangler deploy` from `site/deploy/`, whose `wrangler.jsonc` describes an assets-only Worker with `rind.kixel.ai` as its custom domain, on every push to `main`, after each Release run on `main`, and on dispatch. Its job is the only one naming the `site` environment, which exists with a deployment branch rule admitting `main` alone and both Cloudflare secrets. `site/public/_headers` adds `Content-Security-Policy: frame-ancestors 'none'`.

Done 2026-11-17 (orchestrator, through the maintainer's signed-in agent Chrome, per the maintainer's decision on #827):

- Token: `rind-site deploy`, an **account-owned** API token on the `moq.dev` account, which holds the `kixel.ai` zone, not the user token this quest first described: the user-token page didn't render, and Cloudflare recommends account tokens for credentials tied to no person. Policies: Workers Scripts Edit on the account; Zone Read and Workers Routes Edit on `kixel.ai` only; no expiry, no IP filter. It and the account ID are the `site` environment's `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`. Cloudflare scopes Workers Scripts to an account, not one Worker, so the token can deploy any Worker in the account; the environment's branch rule is what keeps it to `main`. `wrangler deploy` with `CLOUDFLARE_ACCOUNT_ID` set needs no `account_id` in `wrangler.jsonc` and no other permission.
- `kixel.ai`'s AI Crawler and Agent access policies were already "Allow (do not block)" and Bot Preference Sync (formerly the managed robots.txt) was off, so nothing changed. Its `/robots.txt` served Cloudflare's content-signals preamble with no rules, apparently because no Worker owned one; the first deploy's fetch confirms what rind's build serves.
- No `rind` DNS record exists in `kixel.ai`, and `rind.kixel.ai` resolved to nothing.

What remains, once the PR merges and its push to `main` runs the first deploy:

- If Wrangler refuses for a missing permission, the token lacks it: add that one permission rather than widening the token.
- Fetch from outside, and record the results here: `/` and `/index.md` (Markdown content type, `Content-Security-Policy: frame-ancestors 'none'` on both, no `Set-Cookie`), `/llms.txt`, and `/robots.txt` byte-identical to `site/public/robots.txt`.
- The next Release run on `main` starts a deploy through `workflow_run`. Confirm the environment admitted it (`gh run list --workflow site-deploy.yml --event workflow_run`), since its branch rule decides that, not the workflow.
- Once those pass, delete this quest and every link to it in a follow-up PR.
