# [XS] A merge to main deploys rind.kixel.ai

## Goal

`rind.kixel.ai` serves what `site/` builds from `main`, and every merge to `main` deploys within the same CI run. The credential lives in a GitHub environment that only `main` can deploy to, so no pull request's workflow run can read it.

## Plan

Decided 2026-11-12 (maintainer, /quest-plan): ✅ Cloudflare, deployed by CI (rejected: `just deploy` by hand, as moq.dev does, which shows old numbers until someone remembers; GitHub Pages).

In place: `.github/workflows/site-deploy.yml` builds `main`'s tip and runs `wrangler deploy` from `site/deploy/`, whose `wrangler.jsonc` describes an assets-only Worker with `rind.kixel.ai` as its custom domain, on every push to `main`, after each Release run on `main`, and on dispatch. Its job is the only one naming the `site` environment, which exists with a deployment branch rule admitting `main` alone and no secrets yet. `site/public/_headers` adds `Content-Security-Policy: frame-ancestors 'none'`.

What remains, once the two `Waiting` items clear:

- Check before the first deploy: `gh api repos/kixel-ai/rind/environments/site/deployment-branch-policies --jq '.branch_policies[].name'` prints `main` and nothing else, and `gh api repos/kixel-ai/rind/environments/site/secrets --jq '.secrets[].name'` lists `CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_API_TOKEN`.
- Run the first deploy with `gh workflow run site-deploy.yml --ref main`. If Wrangler refuses for a missing permission, the token lacks it: add that one permission rather than widening the token.
- Fetch from outside, and record in the PR: `/` and `/index.md` (Markdown content type, `Content-Security-Policy: frame-ancestors 'none'` on both, no `Set-Cookie`), `/llms.txt`, and `/robots.txt` byte-identical to `site/public/robots.txt`.
- The next Release run on `main` starts a deploy through `workflow_run`. Confirm the environment admitted it (`gh run list --workflow site-deploy.yml --event workflow_run`), since its branch rule decides that, not the workflow.

## Waiting

- Maintainer: create the Cloudflare API token and add it, with the account ID, as the `site` environment's secrets. An agent cannot mint a credential without your Cloudflare login; the 2026-11-12 decision lets one do it through your signed-in agent Chrome (`agent-browser`) while you are present. In the dashboard, My Profile → API Tokens → Create Token → Custom token, named `rind-site deploy`, with Account → Workers Scripts → Edit (your account only) and Zone → Zone → Read and Zone → Workers Routes → Edit (zone `kixel.ai` only), no client IP filter, no expiry or one you will renew. Then `gh secret set CLOUDFLARE_API_TOKEN --env site --repo kixel-ai/rind` and paste the token at its prompt, and `gh secret set CLOUDFLARE_ACCOUNT_ID --env site --repo kixel-ai/rind --body <account ID from the dashboard's Workers overview>`. Done when `gh api repos/kixel-ai/rind/environments/site/secrets --jq '.secrets[].name'` lists both. Cloudflare scopes Workers Scripts to an account, not one Worker, so the token can deploy any Worker in the account; the environment's branch rule is what keeps it to `main`.
- Maintainer: in Cloudflare's dashboard for `kixel.ai`, turn off "Block AI bots" and "Instruct AI bot traffic with robots.txt" (Security → Settings, or AI Crawl Control), so the build's `robots.txt`, which welcomes AI crawlers by name, is served as written. Only your login reaches zone settings, and a token able to change them would be far wider than deploying needs. Done when both show off; the first deploy's `/robots.txt` fetch confirms it. Also confirm no DNS record named `rind` exists in the zone (a CNAME there blocks the custom domain); none resolved on 2026-11-12.
