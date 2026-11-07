# [M] rind's assembly is byte-identical to the proven object code

## Goal

CI proves that every routine rind imports with a published proof (s2n-bignum's by `admin/parse-asm`, Vale's by `admin/import-hacl`, aws-lc's proven SHA-512) assembles, in rind's build, to the same instruction bytes as the object code the proof checked. Alternatively it proves a recorded, justified difference, such as an appended `vzeroupper`. The transliteration then leaves the trust base, and ALGORITHMS.md drops its "they check s2n-bignum's own build, not rind's transliteration" caveat.

## Plan

- Build each upstream's object code at its pinned revision, extract each routine's bytes, and compare them with the bytes in rind's compiled `asm!` and naked functions. Relocations and alignment padding need a normalization step, documented in the check.
- Run it for x86_64 and aarch64, and fail when a re-import changes bytes without a matching proof revision.
