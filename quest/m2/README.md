# m2: later work

## Goal

Work that follows the release MoQ switches to: the speed and armv7 work that
does not block it.

## Required

- [Fastest at every algorithm](/quest/m2/speed/README.md) - every algorithm on every path as fast as any permissive source
- [Fuzzing covers every hostile-input surface](/quest/m2/fuzz-coverage.md) - signatures, KDFs, XChaCha, and ML-KEM fuzzed nightly on a kept corpus
- [Regeneration uses pinned cross tools](/quest/m2/pin-cross-tools.md) - the regeneration check can't fail on a runner image update
