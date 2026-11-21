# [S] RSA public-key setup runs pyca/verified-garbage's precompute where it is faster

## Goal

Loading an RSA public key, which every verification with a key used once pays (a TLS certificate's, for one), costs no more than pyca/verified-garbage's (VG) setup on the tiers where VG's routine runs: rind computes `R² mod n` with VG's `vg_rsa_public_precompute` wherever that measures faster than `PosInt::pub_montifier`.

## Plan

Decided 2026-11-21 (orchestrator, for the maintainer, in [kixel-ai/rind#949](https://github.com/kixel-ai/rind/pull/949)'s merge pick): ✅ keep this quest (rejected: drop it and record a reason in `benchmarks/gaps.toml`).

- Found by `fedora`'s first report run (Ryzen 9 9950X, Zen 5): RSA-2048 PKCS#1 and PSS verification took 1.18 to 1.23× VG's time in two quiet runs (5.9 against 4.8 µs). A probe on `fedora` at [`fbdc801e`](https://github.com/kixel-ai/rind/commit/fbdc801e090ec1d476a01ca8c24be688baed5a7f) split it: with the key parsed once (`rsa2048-pkcs1-sha256-verify-parsed`) rind took 4.45 µs against VG's 4.25 (1.05×), so the verification itself is level, since rind already runs VG's IFMA public operation ([kixel-ai/rind#814](https://github.com/kixel-ai/rind/pull/814)). Key setup is the gap: 1.47 µs for rind's `PublicKey::new` (DER parse, `RsaPublicKey::new`'s checks, `pub_montifier`, `mont_neg_inverse`) against 0.57 µs for VG's from parsed components.
- Profile first: which of the DER parse and `pub_montifier` (k + 1 calls of `mul_word_mod` over the shifted modulus, `low/posint.rs`) takes the 0.9 µs is unmeasured. If it is the parse, fix the parse in place and drop the VG switch from this quest.
- VG's candidates at `0aa40d6c`: `vg_rsa_public_precompute_adx` and its `_auto` dispatcher. Measure rind's setup against it on the weekly bench's x86_64 tiers with ADX (with and without IFMA), `fedora`, and an aarch64 tier if VG has a routine there, at every key size rind-bench times (2048 to 8192 bits), and switch where it holds at every size.
- Take VG's lowest routine that leaves rind's API and behavior intact, and keep rind's checks on `n` and `e`, as [the epic](/quest/m2/verified-garbage/README.md)'s Plan settles. Vendor it with `admin/import-vg`.
- `R² mod n` is public, so this adds no ctgrind test. The RSA Wycheproof and aws-lc-rs differential tests cover the result.
- Drop `benchmarks/gaps.toml`'s `fedora` RSA entry once the next `fedora` run shows the gap closed.
