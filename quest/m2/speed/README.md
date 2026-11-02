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

- [RSA at every key size as fast as aws-lc-rs](/quest/m2/speed/rsa-sizes.md) - x86_64 signing's exponentiation beyond the Karatsuba sizes, as aws-lc's windows and `bn_power5` run it
- [armv7 P-256 as fast as the fastest source](/quest/m2/speed/armv7-p256.md) - signing 2.63x, ES256 2.04x today
- [armv7 RSA as fast as the fastest source](/quest/m2/speed/armv7-rsa.md) - signing 2.3-2.6x, key loading 6.4x today
- [One-block hashes, HMAC, and HKDF as fast as the fastest source](/quest/m2/speed/armv7-hmac-hkdf.md) - up to 1.59x on armv7 today
- [AES-GCM key setup as fast as the fastest source](/quest/m2/speed/aes-gcm-key-setup.md) - 1.30-1.48x today
- [aarch64 SHA-256 as fast as the fastest source](/quest/m2/speed/aarch64-sha256.md) - 1.26-1.30x today
- [aarch64 RSA as fast as ring](/quest/m2/speed/aarch64-rsa-ring.md) - signing 1.56x at 2048 bits today
- [ML-KEM-768 encapsulation as fast as the fastest source](/quest/m2/speed/mlkem-encaps.md) - 1.05-1.22x today
- [SHA-256 fed 1-byte updates as fast as the fastest source](/quest/m2/speed/sha256-small-updates.md) - up to 1.34x today
- [x86_64 P-256 key generation as fast as the fastest source](/quest/m2/speed/x86-p256-keygen.md) - 1.11-1.17x today
- [x86_64 RSA with AVX-512 IFMA](/quest/m2/speed/x86-rsa-ifma.md) - aws-lc's AVX-512 RSA is up to 3.56x faster
- [aarch64 RSA on a 5-bit exponent window](/quest/m2/speed/aarch64-rsa-window.md) - the window x86_64 gained in #224
- [x86_64 SHA-256 picks its path once](/quest/m2/speed/sha256-dispatch-once.md) - no per-block feature checks without SHA-NI
