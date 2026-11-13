# [S] A merge to main deploys rind.kixel.ai

## Goal

`rind.kixel.ai` serves what `site/` builds from `main`, and every merge that changes the site or a file it reads deploys within the same CI run. A pull request can never reach the credential.

## Plan

Decided 2026-11-12 (maintainer, /quest-plan): ✅ Cloudflare, deployed by CI (rejected: `just deploy` by hand, as moq.dev does, which shows old numbers until someone remembers; GitHub Pages).

- A Cloudflare Worker that serves the build's static files, with `rind.kixel.ai` as its custom domain. kixel.ai's DNS is already on Cloudflare, and the name did not resolve on 2026-11-12, so nothing is displaced.
- The Worker serves each page's Markdown twin with a Markdown content type, and sets no cookie.
- The deploy job runs only on a push to `main`, in a GitHub environment that holds the token, so a pull request's workflow run, a fork's included, has no way to read it. Pull requests keep the build job [the landing page](/quest/m2/site/landing.md) added.
- Deploy on any merge that changes `site/` or a file the build reads, and say in the workflow which files those are. If that list is hard to keep right, deploy on every merge: the build is small.
- After the first deploy, fetch the site and its `llms.txt` from outside and put the result in the PR.

## Waiting

- Maintainer: create a Cloudflare API token that can deploy this one Worker and attach `rind.kixel.ai` to it, and add it with the account ID as secrets of a `site` environment in the repository. It needs the maintainer's Cloudflare login and mints a credential, so an agent does not do it alone; one can do it through the maintainer's signed-in browser if they say so. Check: `gh api repos/kixel-ai/rind/environments/site/secrets` lists both.

## Required

- [The landing page builds from the repository](/quest/m2/site/landing.md) - the `site/` project and its build job, which this deploys
