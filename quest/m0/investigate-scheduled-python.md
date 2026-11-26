# [M] Investigate scheduled python

## Goal

Kixel Quest measured what the Plan lists and filed it here on its own. For each finding:

1. Diagnose its cause, starting from the culprit's diff and sessions where it has them.
2. Have a second session, one that did not write the diagnosis, try to refute it, and diagnose again when it does.
3. Fix it, accept it with the reason recorded in this Plan, or improve on it further. A fix carries the measurement that shows it.

Then look past the finding: make the related improvements the diagnosis turns up where they fit here, and add the rest as follow-up quests.

## Plan

Each finding keeps the comment Kixel Quest finds it by, so a later run that sees it again adds its sighting here instead of filing it anew.

### `scheduled python`: failure

<!-- kixel.quest finding {"series":"scheduled python","culprit":null} -->

- Series: [`scheduled python`](https://github.com/kixel-ai/rind/actions/runs/45534947433/attempts/1), in jobs.
- 2026-11-26: 1 jobs against a baseline of 0 jobs, +1 jobs, at [`91daf8a`](https://github.com/kixel-ai/rind/commit/91daf8a684dd6c45085ba35cac006d376efa52b8). Run 45534947433 attempt 1 failed, failing sdist.
