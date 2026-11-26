# [M] Investigate cost/by-model/model:claude-opus-5-5 (tokens), friction/split/category:waiting (h), and 2 more

## Goal

Kixel Quest measured what the Plan lists and filed it here on its own. For each finding:

1. Diagnose its cause, starting from the culprit's diff and sessions where it has them.
2. Have a second session, one that did not write the diagnosis, try to refute it, and diagnose again when it does.
3. Fix it, accept it with the reason recorded in this Plan, or improve on it further. A fix carries the measurement that shows it.

Then look past the finding: make the related improvements the diagnosis turns up where they fit here, and add the rest as follow-up quests.

## Plan

Each finding keeps the comment Kixel Quest finds it by, so a later run that sees it again adds its sighting here instead of filing it anew.

### `cost/by-model/model:claude-opus-5-5 (tokens)`: bottleneck

<!-- kixel.quest finding {"series":"cost/by\u002dmodel/model:claude\u002dopus\u002d5\u002d5 (tokens)","culprit":null} -->

- Series: [`cost/by-model/model:claude-opus-5-5 (tokens)`](https://kixel.quest/factory#bottlenecks-1436343601), in tokens.
- 2026-11-26: 16583354 tokens against a baseline of 16583354 tokens, +0 tokens (+0%). The largest share of cost, 86.4% of its measure over the 30 days to 2026-11-26; too few measurements for a trend.

### `friction/split/category:waiting (h)`: bottleneck

<!-- kixel.quest finding {"series":"friction/split/category:waiting (h)","culprit":null} -->

- Series: [`friction/split/category:waiting (h)`](https://kixel.quest/factory#bottlenecks-1436343601), in h.
- 2026-11-26: 1.277 h against a baseline of 1.277 h, +0 h (+0%). The largest share of friction, 52.82% of its measure over the 30 days to 2026-11-26; too few measurements for a trend.

### `host/gate-cpu/command:nix develop (h)`: bottleneck

<!-- kixel.quest finding {"series":"host/gate\u002dcpu/command:nix develop (h)","culprit":null} -->

- Series: [`host/gate-cpu/command:nix develop (h)`](https://kixel.quest/factory#bottlenecks-1436343601), in h.
- 2026-11-26: 1.797 h against a baseline of 1.797 h, +0 h (+0%). The largest share of host time, 89.22% of its measure over the 30 days to 2026-11-26; too few measurements for a trend.

### `ship/queue (h)`: bottleneck

<!-- kixel.quest finding {"series":"ship/queue (h)","culprit":null} -->

- Series: [`ship/queue (h)`](https://kixel.quest/factory#bottlenecks-1436343601), in h.
- 2026-11-26: 0.9428 h against a baseline of 0.9428 h, +0 h (+0%). The largest share of time to ship, 26.48% of its phases over the 30 days to 2026-11-26; too few measurements for a trend.
