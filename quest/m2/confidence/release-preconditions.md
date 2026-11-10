# [M] Safe wrappers around assembly enforce their preconditions in release builds

## Goal

In a release build, no safe function in `rind/src/low/` reaches assembly or raw-pointer code with arguments that break its length, alignment, or table-size precondition. Each either takes a type that carries the precondition, checks it in every build, or is an `unsafe fn` whose callers state why it holds. A release-mode test calls every wrapper that still takes slices with mismatched ones, and each panics before its assembly runs. The `rsa_priv`, `rsa_pub`, and `rsa_gen` benches stay within noise of `main`.

Today the check exists only in debug builds, so the soundness of a release binary rests on every caller. No caller breaks one now; this guards the next one.

## Plan

Found by the 2026-11-09 API and hostile-input audit. Its evidence:

- `rind/src/low/` has 125 `debug_assert!` calls in 63 files. About 95 state a slice length or a relation between lengths, and 12 a 32-byte alignment. The rest state value ranges and return codes, which are out of scope unless breaking one reads or writes out of bounds.
- `rind/src/low/inline_assembly_safety.rs:22-29` records the design inherited from graviola: a precondition goes in the Rust type where it fits, and in a `debug_assert` otherwise.
- The assembly behind many of these takes one length for several slices, so a shorter slice is an out-of-bounds read or write: `rind/src/low/x86_64/bignum_modadd.rs:69-71`, `bignum_modsub.rs:70-72`, `bignum_modinv.rs:269-271`, `bignum_montredc.rs:152`, `bignum_mul.rs:104`, `bignum_demont.rs:124-125`, and `mont.rs:25` and `:37`, with the same in `rind/src/low/aarch64/`.
- Some preconditions have no check at all: `rind/src/low/x86_64/bignum_copy_row_from_table.rs:70` checks `z` against `width`, but not that `table` holds `height * width` words.
- The ML-KEM routines take `&mut [i16; 256]`, which does not carry the 32-byte alignment `rind/src/low/x86_64/mlkem_ntt.rs:34-35` asserts. `Coeffs` supplies it (`rind/src/mid/mlkem768.rs:409`).
- The hash compressors assert a whole number of blocks (`rind/src/low/x86_64/sha256.rs:12`, `sha512.rs:24`). The audit did not trace what their assembly does with a partial block.

Callers traced, none of which breaks a precondition:

- Every `PosInt` method in `rind/src/low/posint.rs` that reaches these wrappers: `is_coprime` (`:169`), `montifier` (`:231`), `mont_sqr_into` (`:307`), `mont_mul_into` (`:329`), `mont_redc` (`:341`), `from_montgomery` (`:371`), `mul` (`:389`), `mod_inverse` (`:565`), `reduce_even` (`:585`), `sub` (`:643`), and `sub_mod` (`:658`). Each takes its lengths from the modulus's `used`, through `as_words_with_len_of` (`:190`) where the operand may be narrower.
- A hostile RSA private key with unbalanced primes: `RsaPrivateKey::new` widens the narrower prime to the other's width before anything multiplies (`rind/src/mid/rsa_priv.rs:69-73`).
- AES-GCM: `vale()` checks the 2^32 bound itself (`rind/src/low/x86_64/aes_gcm.rs:49`) before the kernel that asserts it (`aes_gcm_avx.rs:88`).

Recommended, for the implementer to confirm with measurements:

- Prefer a type where one fits: a fixed array, or `&[[u8; 64]]` for whole hash blocks, so the check cannot be skipped and costs nothing.
- Otherwise `assert!` on the variable-length bignum and Montgomery wrappers. One comparison beside a multiplication of 16 words or more should not show in a bench.
- Make a wrapper an `unsafe fn` only where an `assert!` measurably slows a hot path, and give each of its callers a `SAFETY` comment. This moves the proof to the callers rather than removing it, so it is the last choice.
- Keep `inline_assembly_safety.rs` true: it names `debug_assert` as the fallback today.
- A check in `just ci` that fails when a safe `low` function's only guard before an `unsafe` block is a `debug_assert!` would keep the next import from reopening this. Add it if it stays simple.

Benchmark against `main` and against aws-lc-rs on x86_64 and aarch64. The symmetric and hash wrappers run per record, so measure those too if they change.

## Related

- [BINSEC checks RSA's private operation and ChaCha20's AVX2 kernel](/quest/m2/confidence/binsec.md) - the other mechanical check on the same boundary, for timing rather than memory
