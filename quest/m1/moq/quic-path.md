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

Where the path is today:
- moq-quic (`rs/moq-quic/src/crypto/rustls.rs`) reaches rind through rustls's `quic::PacketKey` and `HeaderProtectionKey` traits, which rind-rustls implements. Each packet passes through two `Box<dyn PacketKey>` layers, and header protection is a separate AES call.
- Since 0.1.13, x86_64 CPUs with AVX and MOVBE but no VAES, such as Zen 2 and 3, run Vale's verified AES-GCM ([moq-dev/rind#329](https://github.com/moq-dev/rind/pull/329)), which was 6-11% slower than aws-lc's at 32 B.

How to investigate:
- Re-measure zshenker's rows on the current release and main, with and without the Vale tier, on the report's hosts and on GitHub's runners, comparing only matching CPUs.
- Profile moq-uring's `echo_quic` bench, and a relay fan-out if one exists, to find where packet crypto's time goes: copies, dispatch, nonce and AAD setup, header-protection masks, key updates.
- Read rind-rustls's `PacketKey` and `HeaderProtectionKey` implementations for per-call waste.
- For each gap, write up the expected win with numbers and a recommendation, then plan it through `/quest-plan` once the maintainer approves.
- For bulk encryption (packet AES-GCM, ChaCha20-Poly1305, and header protection), performance beats verification (maintainer, 2026-11-05): the fastest source wins even when a verified one is within 10%, so the Vale tier stays only if it measures fastest. Elsewhere on the path, such as handshakes, AGENTS.md's ~10% rule applies.
