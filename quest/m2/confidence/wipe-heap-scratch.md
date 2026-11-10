# [M] Heap scratch from a private key is wiped before it is freed

## Goal

Under `wipe`, a test allocator fails when a block freed during a private-key operation still holds bytes derived from the key. It covers RSA signing, decryption, and key generation, key loading and export, and every other operation that allocates while it holds a secret. A planted unwiped buffer fails it.

## Plan

Planned from the 2026-11-09 tooling audit. rind wipes this scratch by hand, and no test would notice a missing wipe:

- `rind/src/low/posint.rs` zeroes the coprimality scratch (`:170-173`), the table of a secret base's powers (`:518-556`), and a third buffer (`:568-576`). The PKCS#8 paths allocate too (`rind/src/high/pkcs8.rs:132,154`).
- `rind/tests/zeroing.rs` reads only the `size_of::<T>()` bytes of the value it drops (`:231`), never the blocks that value or its operations freed.
- `rind-aws-lc-rs/tests/zeroing.rs` has an allocator that scans each freed block for 16 bytes of the secret itself. That finds a verbatim copy. It cannot find derived scratch, such as CRT intermediates or a window table, which is as good as the key and never holds its bytes. rind has no such allocator at all.

Constraints:

- Only key-derived scratch is wiped. Messages, public values, and encodings of public keys are freed as they are, so "every freed block is zero" is the wrong test.
- Recommended: decide by dependence rather than by content. Run each operation under two keys with the same public inputs and flag a freed block whose bytes differ between the runs and are not zero. Whatever varies with the key alone is derived from it. Pick inputs whose by-design outputs agree, such as two ciphertexts of one plaintext.
- An explicit allowlist of call sites is the alternative; it rots as code moves, so prefer it only where the two-run test cannot separate a case.
- Reuse the adapter's allocator and its `detects_a_leak` pattern rather than writing a second one.
- The allocator needs its own test binary, since a `#[global_allocator]` covers a whole one.
- It runs wherever the zeroing test does: `just ci` on the host, and the nightly tiers. RSA key generation is slow; keep its run in the nightly.
- Fix a missing wipe it finds in the same PR when it is small.

## Required

- [The zeroing test checks every byte of every secret type on every backend](/quest/m2/confidence/zeroing-every-byte.md) - the tier and Windows runs this check then rides, and the reworked harness it shares

## Related

- [BINSEC checks RSA's private operation and ChaCha20's AVX2 kernel](/quest/m2/confidence/binsec.md) - the other check on RSA's private paths
