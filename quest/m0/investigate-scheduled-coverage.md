# [M] Investigate scheduled coverage

## Goal

Kixel Quest measured what the Plan lists and filed it here on its own. For each finding:

1. Diagnose its cause, starting from the culprit's diff and sessions where it has them.
2. Have a second session, one that did not write the diagnosis, try to refute it, and diagnose again when it does.
3. Fix it, accept it with the reason recorded in this Plan, or improve on it further. A fix carries the measurement that shows it.

Then look past the finding: make the related improvements the diagnosis turns up where they fit here, and add the rest as follow-up quests.

## Plan

Each finding keeps the comment Kixel Quest finds it by, so a later run that sees it again adds its sighting here instead of filing it anew.

### `scheduled coverage`: failure

<!-- kixel.quest finding {"series":"scheduled coverage","culprit":null} -->

- Series: [`scheduled coverage`](https://github.com/kixel-ai/rind/actions/runs/46092106690/attempts/1), in jobs.
- 2026-11-28: 1 jobs against a baseline of 0 jobs, +1 jobs, at [`813a39a`](https://github.com/kixel-ai/rind/commit/813a39ae88b57a7b463ddd492599ce669f3cadb6). Run 46092106690 attempt 1 failed, failing gate.
