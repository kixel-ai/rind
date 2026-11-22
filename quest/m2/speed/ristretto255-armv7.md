# [S] ristretto255 on armv7 multiplies with curve25519-dalek's 32-bit backend

## Goal

On armv7, OPRF blinding and evaluation over ristretto255 are within 10% of RustCrypto's `voprf` on the weekly bench's armv7 tier, by running the variable-base multiplication on curve25519-dalek's serial 32-bit backend, which rind already links there for X25519's public key.

## Plan

Found by [kixel-ai/rind#964](https://github.com/kixel-ai/rind/pull/964), whose weekly RustCrypto baselines first timed it: in [run 44996218659](https://github.com/kixel-ai/rind/actions/runs/44996218659) on a Neoverse N2 in 32-bit mode, rind's `oprf-ristretto255-evaluate` took 151 µs against `voprf`'s 131 µs (1.16×), with blinding at 1.07× and finalizing at 1.06×. On aarch64 rind took 0.93× `voprf`'s time.

- `mid/ristretto255.rs`'s `Element::mul` runs a four-bit fixed window over the field arithmetic each backend gives it. On armv7 that is the generic 64-bit-limb code, while `voprf` runs dalek's 32-bit field (`rind/src/low/arm/curve25519.rs` explains why rind keeps dalek's serial 32-bit backend there).
- Route the constant-time variable-base multiplication to dalek's `RistrettoPoint` multiplication on the backends that already depend on dalek, keeping rind's code wherever it measures faster. Check whether ECVRF over edwards25519 (`vrf-edwards25519-*`) moves too.
- [The AVX2 quest](/quest/m2/speed/ristretto255-avx2.md), in [kixel-ai/rind#943](https://github.com/kixel-ai/rind/pull/943), covers x86_64 only, and this one leaves that tier alone.
- Benchmark with `gh workflow run bench --ref <branch> -f benches='oprf vrf'`, and drop the `gaps.toml` entry for this gap once the weekly bench shows it closed.

## Related

- [Record the weekly bench's first RustCrypto-baseline gaps](/quest/m2/bench/rustcrypto-weekly-gaps.md)
