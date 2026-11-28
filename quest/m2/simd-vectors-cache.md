# [S] admin/prove caches the intrinsic vectors' check

## Goal

`admin/prove lean` checks `SimdVectors.lean`, the `#guard`s that test each x86_64 intrinsic model against the instruction on this CPU, only when the vectors or the models they test change, instead of on every run.

Non-goals: testing fewer models, or trusting another CPU's vectors.

## Plan

Measured in [kixel-ai/rind#1182](https://github.com/kixel-ai/rind/pull/1182) on a 24-core host shared with other agents: after `lake build` finishes, `lake env lean "$out/SimdVectors.lean"` takes 230 to 257 s of every `admin/prove lean` run, unchanged or not: most of an unchanged run's 4:27, and 4 of the 6 minutes a one-line ML-KEM edit now costs.

- `admin/simd-vectors` writes the same file on the same CPU, so the check's result depends only on that file and the modules it imports. Building it as a Lake module, such as one `admin/prove` writes into `proofs/` and `lake build` names, lets Lake's artifact cache skip it when neither changed, and replay it on another checkout of the same host.
- Measure first where its 4 minutes go (import, elaboration, or `#guard`'s evaluation): if one model's vectors dominate, a faster evaluation of them may win more than the cache.
- The file must still be generated and checked on every host whose CPU differs, since the vectors are this CPU's.

## Related

- [Split charon/aeneas Funs.lean per algorithm family](/quest/m2/split-aeneas-extractions.md) - cut the rebuild after an edit, which leaves this check as the largest fixed cost
