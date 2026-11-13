# [S] A merge to main deploys rind.kixel.ai

## Goal

`rind.kixel.ai` serves what `site/` builds from `main`, and every merge that changes the site or a file it reads deploys within the same CI run. The credential lives in a GitHub environment that only `main` can deploy to, so no pull request's workflow run can read it.

## Plan

Decided 2026-11-12 (maintainer, /quest-plan): ✅ Cloudflare, deployed by CI (rejected: `just deploy` by hand, as moq.dev does, which shows old numbers until someone remembers; GitHub Pages).

- A Cloudflare Worker that serves the build's static files, with `rind.kixel.ai` as its custom domain. kixel.ai's DNS is already on Cloudflare, and the name did not resolve on 2026-11-12, so nothing is displaced.
- The Worker serves each page's Markdown twin with a Markdown content type, and sets no cookie.
- The token is a secret of a `site` environment whose deployment branch rule allows `main` alone. The rule is what keeps it from a pull request, not the workflow's trigger: an environment's secrets go to any job that names it, a branch in this repository can add such a job to its own pull request, and the trigger is a line that pull request can edit. GitHub enforces the branch rule outside the workflow ([deployment branches and tags](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments#deployment-branches-and-tags)). A fork's pull request gets no secrets either way.
- Create the environment and its rule before the token exists, so it is never a secret without one: `gh api -X PUT repos/kixel-ai/rind/environments/site` with a custom deployment branch policy, then one policy named `main`. An agent with admin on the repository can do this step; only the secret's value needs the maintainer.
- The deploy job runs on a push to `main` and names that environment. Pull requests keep the build job [the landing page](/quest/m2/site/landing.md) added, which needs no secret.
- Deploy on any merge that changes `site/` or a file the build reads, and say in the workflow which files those are. If that list is hard to keep right, deploy on every merge: the build is small.
- After the first deploy, fetch the site and its `llms.txt` from outside and put the result in the PR.

## Waiting

- Maintainer: create a Cloudflare API token that can deploy this one Worker and attach `rind.kixel.ai` to it, and add it with the account ID as secrets of a `site` environment in the repository. It needs the maintainer's Cloudflare login and mints a credential, so an agent does not do it alone; one can do it through the maintainer's signed-in browser if they say so. Add them only once the environment's branch rule is in place. Check: `gh api repos/kixel-ai/rind/environments/site/deployment-branch-policies --jq '.branch_policies[].name'` prints `main` and nothing else, and `gh api repos/kixel-ai/rind/environments/site/secrets --jq '.secrets[].name'` lists both.

## Required

- [The landing page builds from the repository](/quest/m2/site/landing.md) - the `site/` project and its build job, which this deploys
