# [M] Investigate scheduled ctgrind

## Goal

Kixel Quest measured what the Plan lists and filed it here on its own. For each finding:

1. Diagnose its cause, starting from the culprit's diff and sessions where it has them.
2. Have a second session, one that did not write the diagnosis, try to refute it, and diagnose again when it does.
3. Fix it, accept it with the reason recorded in this Plan, or improve on it further. A fix carries the measurement that shows it.

Then look past the finding: make the related improvements the diagnosis turns up where they fit here, and add the rest as follow-up quests.

## Plan

Each finding keeps the comment Kixel Quest finds it by, so a later run that sees it again adds its sighting here instead of filing it anew.

### `scheduled ctgrind`: failure

<!-- kixel.quest finding {"series":"scheduled ctgrind","culprit":null} -->

- Series: [`scheduled ctgrind`](https://github.com/kixel-ai/rind/actions/runs/44919091128/attempts/1), in jobs.
- 2026-11-23: 2 jobs against a baseline of 0 jobs, +2 jobs, at [`a5d3ea9`](https://github.com/kixel-ai/rind/commit/a5d3ea903dcb8bcf021ff06ce68ef11b9cdc9982). Run 44919091128 attempt 1 failed, failing build (ubuntu-24.04-arm, release), aarch64-portable.
