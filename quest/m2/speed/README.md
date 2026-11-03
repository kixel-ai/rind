# Fastest at every algorithm

## Goal

Every algorithm rind exports, on every path it runs (x86_64's fast path and
its no-ADX, no-AVX2, no-AES-NI, and SSE2 tiers; aarch64 with and without the
crypto extensions; armv7), is at least as fast as the fastest permissively
licensed source usable from Rust, or the gap is recorded with its reason.
README's Algorithms table shows where each stands.

## Plan

Decided with the maintainer on 2026-11-01, in a planning interview. These are
settled; don't ask them again. The chosen option is marked ✅.

- Bar: the fastest of any Rust-usable source (aws-lc-rs, ring, RustCrypto,
  libcrux, graviola, BoringSSL, s2n-bignum, ...) ✅ / the faster of aws-lc-rs
  and ring / aws-lc-rs only.
- Paths: every tier, each against its baselines held to the same CPU
  features ✅ / default paths plus the Pi tier / default fast paths only.
- Structure: an audit that measures everything and recommends one quest per
  gap, which the maintainer plans from its report ✅ / an epic per algorithm
  family / one big quest.
- Milestone: m2 ✅ / m1.
- Licenses: permissive only (Apache-2.0, ISC, MIT, BSD, CC0); copyleft code
  such as the Linux kernel's assembly is out ✅ / permissive, plus asking
  per case.
- Hardware: the nightly bench's GitHub x86_64 and arm64 runners (armv7 in
  32-bit mode on arm64, x86_64 tiers forced), plus interleaved runs on the
  maintainer's i7-8700; real Pi 4 and older x86 hardware stay unmeasured and
  noted ✅ / also rented cloud instances.
- The existing speed quests join this epic ✅ / stay separate.
- Nightly baselines: aws-lc-rs and ring, so regressions show; other sources
  are measured once by the audit ✅ / every source nightly / aws-lc-rs only.
- Verification breaks ties: a verified source wins unless another is more
  than about 10% faster ✅ (maintainer, 2026-11-02: raised from about 2% to
  prefer verified code over chasing benchmark noise) / within 2% / never.
- Scope: every exported primitive, plus rind-rustls full and resumed
  handshakes and bulk transfer against aws-lc-rs's and ring's providers ✅ /
  primitives only / also every adapter.
- Symmetric sizes: 32 B, 1200 B, 1350 B, and 16 KB, plus 64 B and 8 KB for
  hashes; a gap at any size counts ✅ / a full power-of-two sweep.
- Scoreboard: README's Algorithms table gains each path's ratio to the
  fastest baseline, refreshed by the audit and each gap quest; the nightly
  job's summary keeps the live numbers ✅ / nightly summary only / a separate
  BENCHMARKS.md.

## Required

- [AES-GCM key setup as fast as the fastest source](/quest/m2/speed/aes-gcm-key-setup.md) - 1.13-1.66x today
- [ML-KEM-768 encapsulation as fast as the fastest source](/quest/m2/speed/mlkem-encaps.md) - armv7 1.05x and aarch64 1.04x today
- [x86_64 RSA with AVX-512 IFMA](/quest/m2/speed/x86-rsa-ifma.md) - aws-lc's AVX-512 RSA is up to 3.56x faster
- [armv7 P-384 multiply without carry-flag spills](/quest/m2/speed/armv7-p384-mul.md) - only if more than ~10% faster than fiat-crypto
- [Imported routines start at aws-lc's alignment](/quest/m2/speed/import-entry-alignment.md) - top-level entries aligned like aws-lc, if it measures faster
- [AES-128-GCM 16 KB bench measures the cipher](/quest/m2/speed/aes128-16k-bench.md) - the bench's 3x AES-128 anomaly on the EPYC 7763
