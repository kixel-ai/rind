# [S] The launch post can say what building rind cost in AI tokens, time, and money

## Goal

Before the launch post, rind has a tally of the AI tokens, time, and cost at API list prices it took to build, from the graviola bootstrap on 2026-10-27 to the launch, with the method stated so readers can trust the numbers.

## Plan

Decided with the maintainer on 2026-11-06, in a planning interview. Settled; don't ask again (✅ is the chosen option):

- Goal: a blog-ready tally with its method ✅ / also a per-day breakdown.
- Scope: rind with downstream migrations apart ✅ / rind only / everything combined. The headline counts sessions whose working directory is a rind checkout. Migration work elsewhere (MoQ's rind epic in moq-dev/moq, the Bun fork) is a second, separate line.
- Time: the calendar span, summed agent wall-clock ("agent hours", which shows the parallelism), and the maintainer's active hours, estimated from their prompt timestamps with gaps over about 15 minutes counted as away ✅. CI runner time is left out.
- Sources: Claude Code and Codex from their logs, plus a labeled rough estimate for the third-party bots ✅ / Claude and Codex only / Claude only. Claude Code includes subagents and T3 delegate threads.
- Output: the numbers and the method in the PR body for the maintainer to copy into the post, with nothing new committed ✅ / an `admin/` script / a `docs/` page.
- Milestone: m1, which the launch post requires ✅ / m0.

Where the data is:

- Claude Code: `~/.claude/projects/*/` on the maintainer's workstation, including `subagents/` directories. Each assistant message records its model and usage by type (input, cache writes by TTL, cache reads, output including thinking), so the cost can be priced exactly per model. rind sessions start on 2026-10-28 there (377 through 2026-11-06); find the bootstrap day's sessions by working directory, since some ran from moq or `~/work` checkouts. `ssh desktop` holds one more rind project; `ssh nixos` holds none.
- Codex: `~/.codex/sessions/2026/` on the workstation, filtered by working directory, priced at the model's API list price.
- Bots (Pullfrog, CodeRabbit, CodSpeed's analysis): no usage logs. Estimate from their run and comment counts on moq-dev/rind, and label it as a rough estimate in its own line.

Price each model at its published API list price for the tier and cache TTL used, and state the price table and its date in the method. Count each message once: a session file resumed or forked into another must not double-count. Run the tally as close to the post as practical, and rerun if the post slips by days.
