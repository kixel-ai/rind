# m2: later work

## Goal

Work that follows the release MoQ switches to: the speed and armv7 work that
does not block it.

## Required

- [Fastest at every algorithm](/quest/m2/speed/README.md) - every algorithm on every path as fast as any permissive source
- [Fuzzing covers every hostile-input surface](/quest/m2/fuzz-coverage.md) - signatures, KDFs, XChaCha, and ML-KEM fuzzed nightly on a kept corpus
- [Imported code is checked to regenerate exactly](/quest/m2/import-reproducible.md) - importers rerun in CI, and generators write atomically
- [armv7's crypto-extension assembly is checked for constant time](/quest/m2/armv7-crypto-ext-ct.md) - the path valgrind can't see gets a trace comparison
