# [M] Investigate scheduled dart-libraries

## Goal

Kixel Quest measured what the Plan lists and filed it here on its own. For each finding:

1. Diagnose its cause, starting from the culprit's diff and sessions where it has them.
2. Have a second session, one that did not write the diagnosis, try to refute it, and diagnose again when it does.
3. Fix it, accept it with the reason recorded in this Plan, or improve on it further. A fix carries the measurement that shows it.

Then look past the finding: make the related improvements the diagnosis turns up where they fit here, and add the rest as follow-up quests.

## Plan

Each finding keeps the comment Kixel Quest finds it by, so a later run that sees it again adds its sighting here instead of filing it anew.

### `scheduled dart-libraries`: failure

<!-- kixel.quest finding {"series":"scheduled dart\u002dlibraries","culprit":null} -->

- Series: [`scheduled dart-libraries`](https://github.com/kixel-ai/rind/actions/runs/44962598859/attempts/1), in jobs.
- 2026-11-23: 5 jobs against a baseline of 0 jobs, +5 jobs, at [`fb05ada`](https://github.com/kixel-ai/rind/commit/fb05ada3539656104e4c5c50d2be91fa47bc2865). Run 44962598859 attempt 1 failed, failing library (windows-arm64), library (linux), library (android), library (apple), library (windows-x64).
