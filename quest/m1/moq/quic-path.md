# [M] MoQ's QUIC packet path is as fast as rind can make it

## Goal

Every change in rind, rind-rustls, or moq-quic that measurably speeds up MoQ's QUIC packet path is found, measured, and planned as its own quest. The path covers per-packet AES-GCM seal and open, header protection, key dispatch, key updates, and handshakes. Each quest goes to the maintainer for approval before it's created.

## Plan

Planned with the maintainer on 2026-11-05, from zshenker's independent Zen 2 numbers on [moq-dev/moq#7873](https://github.com/moq-dev/moq/pull/7873#issuecomment-6670951461). With rind 0.1.12 on an EPYC 7662, pinned:
- AES-128-GCM: seal 1.54x and open 1.41x aws-lc-rs's throughput at 64 B, and 1.06-1.09x at 1200-1280 B.
- Header protection: level.
- TLS 1.3 handshakes: 1.65x.

Decisions (✅ chosen):
- Scope: rind and rind-rustls, plus changes in moq-quic itself ✅ / rind's primitives only / rind and rind-rustls only.
- CPUs: relay servers first ✅ (x86_64 Zen 2 to 5 and Intel Xeon, with and without VAES, plus aarch64 Graviton/Neoverse), then clients (Apple M, Android aarch64 and armv7) / every tier equally / x86_64 only.
- Structure: this quest investigates. rind and rind-rustls fixes become rind quests, and moq-quic fixes become quests in [moq-dev/moq](https://github.com/moq-dev/moq)'s perf epic ✅ / separate investigations in each repo.
- New API: a new public QUIC API in rind is allowed if it measures a clear end-to-end win ✅ / none. One example is a packet key that seals and applies header protection in one call; another seals a GSO batch. It would be additive, so a patch release, and its shape goes to the maintainer.

For bulk encryption (packet AES-GCM, ChaCha20-Poly1305, and header protection), performance beats verification (maintainer, 2026-11-05): the fastest source wins even when a verified one is within 10%, so the Vale tier stays only if it measures fastest. Elsewhere on the path, such as handshakes, AGENTS.md's ~10% rule applies.

Where the path is today:
- moq-quic (`rs/moq-quic/src/crypto/rustls.rs`) reaches rind through rustls's `quic::PacketKey` and `HeaderProtectionKey` traits, which rind-rustls implements. Each packet passes through two `Box<dyn PacketKey>` layers, and header protection is a separate AES call.
- Since 0.1.13, x86_64 CPUs with AVX and MOVBE but no VAES, such as Zen 2 and Intel through Cascade Lake, run Vale's verified AES-GCM ([moq-dev/rind#329](https://github.com/moq-dev/rind/pull/329)) at every length. CPUs with VAES, such as Zen 3 to 5 and Arrow Lake, run rind's VAES kernels from 256 B and its SSE `by8` loop below that.

Investigated in [moq-dev/rind#387](https://github.com/moq-dev/rind/pull/387) (2026-11-05), which has the numbers. On current main, rind leads aws-lc-rs at 1200-1452 B on every runner measured: AES-128-GCM by 1.1-1.2x on Neoverse N2, 1.4-1.6x on Zen 5, 1.5-1.8x on Arrow Lake, and 1.6-2.1x on Zen 3 and 4. ChaCha20-Poly1305 is even, and handshakes run 1.4-1.9x faster. Crypto is about 20% of moq's CPU in `echo_quic`. The gaps it found, each a proposed quest for the maintainer to approve:
- AES-GCM opens under 256 B on VAES CPUs run rind's `by8` loop, which hashes the tail through the generic GHASH path. Vale's kernel opens them 13-61% faster.
- AES-128 header protection is 0.83-0.91x aws-lc-rs on AMD: `AesKey::encrypt_block` builds a 3.8 KB frame and decodes a 128-bit niche discriminant before `aes128_block`.
- On aarch64, rind sets and clears DIT on every call, which aws-lc-rs never does. Since main detects DIT on Neoverse N2 under Hyper-V, header protection through rustls dropped from 1.00x to 0.87x there.
- On aarch64, ACK-sized sends (a 3-35 B payload plus header protection) are 0.90-0.94x aws-lc-rs on Neoverse N2.

What remains: plan each gap the maintainer approves through `/quest-plan`, then delete this quest.
