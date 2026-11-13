# [XS] The correctness post and rind.kixel.ai are announced

## Goal

The maintainer's second blog post, about how rind is verified, is published, and it and `rind.kixel.ai` are announced together.

## Plan

Decided 2026-11-12 (maintainer, /quest-plan): ✅ announce the site with a new post once everything feasible is formally verified (rejected: announce with rind 0.4; announce the site by itself when it goes live; no announcement). The launch post was about speed and cost and did not cover correctness, so that is the second story. ✅ "Everything feasible" is the m4 verified epic: every hot tier of x86_64 and aarch64 proven (rejected: the m3 epic, which is sooner but leaves recorded gaps for the post to explain; the m5 epic, which waits for the cold tiers few machines run).

- The site is live and indexed long before this; the announcement is what sends people to it.
- As with the launch post, the maintainer writes the prose. Its charts and the pull request live in moq.dev's repository, whose quest tree plans them; [the verified-code map](/quest/m2/site/verified.md) is the data to draw from.
- When the post is up, link it from the README and from the site beside the launch post, and delete this quest.
- Any post outside the maintainer's organisations is theirs to send. An agent drafts one only when asked.

## Waiting

- Maintainer: write and publish the post, and send the announcement. An agent cannot: the words and the accounts are the maintainer's.

## Required

- [Every rind path is proven, with the smallest trust base](/quest/m4/verified/README.md) - the claim the post makes
- [rind.kixel.ai gets a developer from a first visit to a first build](/quest/m2/site/README.md) - the site it announces
