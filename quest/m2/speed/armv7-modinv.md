# [M] armv7 inverts mod an RSA modulus as fast as RustCrypto

## Goal

On armv7, rind's constant-time inverse mod an odd modulus is no slower than RustCrypto's, so Blind RSA's `blind`, which inverts its blinding factor mod n once per message, is within 10% of RustCrypto's `blind-rsa-signatures` on the weekly bench's armv7 tier.

## Plan

Found by [kixel-ai/rind#964](https://github.com/kixel-ai/rind/pull/964), whose weekly RustCrypto baselines first timed it: in [run 44996218659](https://github.com/kixel-ai/rind/actions/runs/44996218659) on a Neoverse N2 in 32-bit mode, rind's `blind-rsa2048-blind` took 2.39 ms against RustCrypto's 1.50 ms (1.60×), about as long as rind's own blind signing (2.52 ms), while on aarch64 it took 0.13× RustCrypto's time.

- x86_64 and aarch64 run s2n-bignum's `bignum_modinv` in assembly; armv7 runs the generic Rust transliteration in `rind/src/low/generic/bignum.rs`, over 64-bit words that a 32-bit core emulates. `PosInt::mod_inverse` (`rind/src/low/posint.rs`) is the caller; RSA key generation's CRT coefficient takes the same path.
- Candidates, fastest measured wins under AGENTS.md's source rule: crypto-bigint's Bernstein-Yang safegcd inverse, which RustCrypto's `rsa` runs, over 32-bit limbs; or the generic routine rewritten over `u32` words. State where the new arithmetic's correctness argument comes from.
- The blinding factor is secret, so the inverse stays constant time: add a ctgrind row for it (`admin/ctgrind`), and test it against the generic routine and aws-lc-rs on random odd moduli.
- Benchmark with `gh workflow run bench --ref <branch> -f benches='blind_rsa rsa_gen'`, and drop the `gaps.toml` entry for this gap once the weekly bench shows it closed.

## Related

- [Record the weekly bench's first RustCrypto-baseline gaps](/quest/m2/bench/rustcrypto-weekly-gaps.md)
