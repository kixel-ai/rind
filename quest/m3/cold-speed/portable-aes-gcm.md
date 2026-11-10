# [S] Portable AES-GCM keeps its expanded key and seals in place

## Goal

AES-GCM on the portable backend, and on armv7 without the crypto extension, expands its key and builds its GHASH table once, when the key is made, and seals and opens in place without allocating. The nightly's portable row shows the gain, and `benchmarks/gaps.toml` records what remains against aws-lc's C.

## Plan

Planned from the 2026-11-09 speed and API audits; the maintainer accepted it that day, with portable speed in scope ✅ (rejected: no portable speed work, correctness only) and cold-tier speed work in m3 ✅ (rejected: m2 beside the targets, m4).

Evidence, read in `rind/src/mid/portable/aes_gcm.rs`:

- `Portable` holds the raw key bytes (`:184`). libcrux's AES-GCM expands them on every call, and reads and writes separate buffers, so `encrypt` (`:211`) and `decrypt` (`:238`) copy the whole message into a `Vec` first.
- `composed()` (`:257`), which serves AES-192, IVs that are not 12 bytes, and truncated tags, builds the bitsliced key schedule and the GHASH table for each call too ("Built for each call", `:256`). It already works in place.
- armv7 without the crypto extension takes the same path (`AesGcm::new`, `:28`).

Measured, on the portable row of [run 42526977036](https://github.com/moq-dev/rind/actions/runs/42526977036), x86_64 under `--cfg rind_portable` against aws-lc's C: AES-128 and AES-256-GCM at 2.5 to 3.5× aws-lc-rs's time at 32 B and 64 B, and 6.2 to 7.8× from 1200 B to 16 KB; AES-192-GCM, the composed path, at 4.7 to 5.3×; rustls's 1 MB transfer at 6.9 to 7.5×.

Two caveats on those ratios:

- aws-lc's build without assembly still uses SSE2 on x86_64: `OPENSSL_SSE2` follows `__SSE2__` (`crypto/internal.h:101` at aws-lc `bab562f6ad16`), and `aes_nohw.c:52` then bitslices 8 blocks a batch in `__m128i`, against 4 in `uint64_t` on other 64-bit targets (`aes_nohw.c:97`) and 2 on 32-bit ones. So the row overstates the AES gap a riscv64 or s390x build would see, by up to 2× (estimated). Its GHASH is `uint128_t` C on any 64-bit target (`gcm_nohw.c:23`).
- Raw AES-CTR trails by 7.5 to 8.9× on the same row with no per-call setup, so at 1200 B and above most of the gap is the block cipher's throughput, which this quest does not change. The expected gain is the per-call key expansion and allocation, largest at 32 B. It is unmeasured.

Guidance:

- Recommend holding `Composed`'s `AesKey` and `NohwTable` in `Portable` and running it for every key length: it is in place already, rind owns the code, and libcrux's AES-GCM entry points go. The row suggests it is no slower per byte: AES-192 on it trails aws-lc by less than AES-128 does on libcrux's. That is inferred from ratios, so first compare the absolute times of `aes128-gcm/rind`, `aes192-gcm/rind`, and `aes256-gcm/rind` there.
- The alternative is a libcrux key state that expands once and takes one buffer, if libcrux-aes has one or grows one; [armv7 raw ciphers from libcrux](/quest/m3/libcrux-ciphers.md) already waits on its exports.
- The expanded key and table are keyed state: wipe them on drop through `low::zeroise`, as `Portable` wipes its key bytes today.
- A changed secret path gets its ctgrind test, on the portable build and on armv7 with the crypto extension denied.
- Source and proof: rind's copy of libcrux-aes's bitsliced block cipher (Apache-2.0, which libcrux marks pre-verification) and rind's port of aws-lc's `gcm_nohw.c`; neither is proven. [armv7 runs the Rust proofs](/quest/m5/verified-armv7/prove.md) plans to prove both paths, and has one fewer to prove if `Composed` serves every key.
- If the block cipher still trails by more than 1.10× afterwards, the PR suggests its follow-up, measured against a 64-bit port of aws-lc's `aes_nohw.c`, which rind already ports for SSE2 (`rind/src/low/x86_64/aes_nohw.rs`). rind-rustls prefers ChaCha20-Poly1305 on these targets, so that matters only where a peer or protocol requires AES.

## Related

- [64-bit portable targets use 64-bit limbs](/quest/m3/cold-speed/portable-limbs.md) - the portable row's other large gap
- [armv7 raw ciphers from libcrux](/quest/m3/libcrux-ciphers.md) - replaces the block cipher copy this builds on, once libcrux exports it
- [armv7 runs the Rust proofs](/quest/m5/verified-armv7/prove.md) - proves the AES-GCM paths this changes
