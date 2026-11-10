# [S] A PR that would redden a nightly learns before it merges

## Goal

A pull request that touches a nightly check's inputs runs that check before it can merge, and the checks cheap enough for the gate are in `just ci`. Each of the seven regressions [moq-dev/rind#513](https://github.com/moq-dev/rind/pull/513) repairs would have shown red on the PR that caused it.

## Plan

Planned from the 2026-11-09 tooling audit. The gate runs a debug test pass on one x86_64 host; every other check runs after the merge, and `alert.yml:51` reports only scheduled failures. Scheduled runs from 2026-10-28 to 2026-11-08:

| Workflow | Red | Of |
|---|---|---|
| quality lints | 9 | 12 |
| ctgrind | 7 | 12 |
| build | 4 | 12 |
| fuzz | 2 | 10 |
| mutants | 1 | 1 |
| timing | 1 | 1 |

asan, coverage, x86-cpu, prove, and regenerate stayed green. A check that is already red hides the next failure: a new leak on a night ctgrind was red for its setup would have changed nothing anyone saw.

What reddened them, as #513 traces it:

- [moq-dev/rind#315](https://github.com/moq-dev/rind/pull/315): `admin/structure`, red five nights from 2026-11-04.
- [moq-dev/rind#458](https://github.com/moq-dev/rind/pull/458): armv7's zeroing test, red two nights. This one was a real bug, unwiped ARM AES key bytes under `wipe`.
- [moq-dev/rind#462](https://github.com/moq-dev/rind/pull/462): four of `build.yml`'s six Dart rows.
- [moq-dev/rind#482](https://github.com/moq-dev/rind/pull/482) and [moq-dev/rind#459](https://github.com/moq-dev/rind/pull/459): ctgrind's OAEP test and its adapters suite.
- [moq-dev/rind#455](https://github.com/moq-dev/rind/pull/455): the mutation run's survivors, on its first scheduled run.
- [moq-dev/rind#483](https://github.com/moq-dev/rind/pull/483): every timing row, on its first scheduled run.
- The unstable rustfmt check drifted with no single cause. The earlier reds, from 2026-10-30, were not traced.

Guidance:

- `prove.yml:10` and `regenerate.yml:11` already run on pull requests that touch their inputs. Give the other nightlies the same `pull_request` path filters, per job where a workflow's jobs have different inputs: armv7 and the portable job on their backends and scripts, the Dart rows on `rind-dart/`, ctgrind on its runner, its suppressions, and each `tests/ctgrind.rs`.
- A PR pays only for the checks whose inputs it touches. ctgrind's and x86-cpu's inputs are all of `rind/src`, which is most PRs; recommended there is the one job per workflow that fails fastest, not the whole matrix.
- `admin/structure` and the unstable rustfmt check take seconds: move them into `just ci`, with their tools pinned in the flake. `lints.yml`'s third job, aarch64 clippy over every target, needs an arm64 runner and stays there with a path filter.
- `mutants.yml:53` mutates only the last day's diff, so a night that fails for another reason never mutates that day's changes. On a pull request, mutate the PR's own diff through the `base` input (`mutants.yml:15`), which closes that hole.
- Timing takes hours on quiet hardware and stays weekly. Check on pull requests only that its shells and build still work.
- A path-filtered workflow cannot be a required context, since it reports nothing when it skips. The runs are advisory on the PR, where [CONTRIBUTING.md](/CONTRIBUTING.md) already asks for failing checks to be fixed.
- A fork's runs wait for approval, as now.

## Related

- [Each adapter's API is diffed against its upstream's](/quest/m2/confidence/adapter-api-diff.md) - a new check that must not become another nightly-only one
