# [M] Investigate job ctgrind / build (ubuntu-latest, release)

## Goal

Kixel Quest measured what the Plan lists and filed it here on its own. For each finding:

1. Diagnose its cause, starting from the culprit's diff and sessions where it has them.
2. Have a second session, one that did not write the diagnosis, try to refute it, and diagnose again when it does.
3. Fix it, accept it with the reason recorded in this Plan, or improve on it further. A fix carries the measurement that shows it.

Then look past the finding: make the related improvements the diagnosis turns up where they fit here, and add the rest as follow-up quests.

## Plan

Each finding keeps the comment Kixel Quest finds it by, so a later run that sees it again adds its sighting here instead of filing it anew.

### `job ctgrind / build (ubuntu-latest, release)`: flake

<!-- kixel.quest finding {"series":"job ctgrind / build (ubuntu\u002dlatest, release)","culprit":null} -->

- Series: [`job ctgrind / build (ubuntu-latest, release)`](https://github.com/kixel-ai/rind/actions/runs/45464160694/attempts/1), in %.
- A flake: fix it at the root cause now, or disable it until it is fixed and record that here. Never retry it, wait it out, or loosen what it checks. This quest stays open until it is fixed and enabled again.
- 2026-11-26: 50 % against a baseline of 0 %, +50 %, at [`e174bd3`](https://github.com/kixel-ai/rind/commit/e174bd3902337fae58cdfeed8703a1020d7f5b05). Failed in run 45464160694 attempt 1 and passed in run 45464160694 attempt 2 of ctgrind, failing 1 of the 2 times it ran on its commit.
