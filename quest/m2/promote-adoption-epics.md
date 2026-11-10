# [XS] Promote the targets and aws-lc-rs epics out of adoption

## Goal

`quest/m2/adoption/targets/` and `quest/m2/adoption/aws-lc-rs/` are their own
epics at `quest/m2/targets/` and `quest/m2/aws-lc-rs/`, so no epic in this
tree holds another. Adoption's README names them as blockers instead of
children.

## Plan

Decided 2026-11-09 (user, /quest-plan in
[moq-dev/quest#594](https://github.com/moq-dev/quest/pull/594)): epics no
longer nest, since a nested epic means its parent is too large, and every
epic gets a branch its quests land on. ✅ Promote each nested epic to a
sibling in its milestone (rejected: merge its quests into the parent). The same PR promoted `quest/m5/verified-armv7/`.

`quest mv` refuses to move a quest with an open PR, since the PR's branch is
named after the quest's path, so this waits for them. Start no new quest
under the old path first. Then run
`quest mv quest/m2/adoption/targets quest/m2/targets` and
`quest mv quest/m2/adoption/aws-lc-rs quest/m2/aws-lc-rs`; either can go as
soon as its own PRs are done.

## Waiting

- moq-dev/rind: the open PRs under the two epics land or close
  ([#558](https://github.com/moq-dev/rind/pull/558),
  [#554](https://github.com/moq-dev/rind/pull/554),
  [#527](https://github.com/moq-dev/rind/pull/527),
  [#525](https://github.com/moq-dev/rind/pull/525),
  [#524](https://github.com/moq-dev/rind/pull/524) and
  [#497](https://github.com/moq-dev/rind/pull/497) on 2026-11-09). Check
  with `gh pr list -R moq-dev/rind --search "head:quest/m2/adoption/"`
  listing no branch under `targets/` or `aws-lc-rs/`.
