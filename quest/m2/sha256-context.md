# [M] SHA-256's streaming context costs no more than one-shot on short inputs

## Goal

`digest::Context::new`, `update`, and `finish` for SHA-256 run within noise of one-shot `digest::digest` at 16 B and 64 B on x86_64 and aarch64, and `hmac::Context` within noise of one-shot `hmac::sign`.

## Plan

Found on 2026-11-12, benchmarking pyca/verified-garbage against rind on a Ryzen 9 9950X: SHA-256 through the context took about 36 ns at 16 to 64 B, against 19 ns one-shot. Decided with the maintainer the same day: ✅ a quest in m2. TLS and QUIC hash many short transcripts through the context.

[kixel-ai/rind#764](https://github.com/kixel-ai/rind/pull/764) removed a store-to-load forwarding stall in `finish`. [kixel-ai/rind#864](https://github.com/kixel-ai/rind/pull/864) made a new context 16 bytes (`Fresh`, started in place by the first update), aligned it to 16 rather than 64 bytes, made a clone one copy, and inlined the buffered update into the start, which closed the `Box`ed and cloned rows. What remains, in user cycles per iteration on x86_64 (`perf stat`, pinned, averaged over four stack offsets, since a cloned context's cost swings by up to 70 cycles with the stack's alignment) and in ns on the M4 (best of five, unpinned), measured on 2026-11-17:

| | one-shot | context | `Box`ed context | HMAC one-shot | HMAC context |
|---|---:|---:|---:|---:|---:|
| Zen 5, 16 B | 112 | 114 | 129 | 290 | 416 |
| Zen 5, 64 B | 198 | 220 | 235 | 410 | 547 |
| Arrow Lake, 16 B | 66 | 81 | 93 | 178 | 354 |
| Arrow Lake, 64 B | 123 | 130 | 142 | 246 | 404 |
| Apple M4, 16 B | 56.1 ns | 61.1 ns | 80.8 ns | 88.1 ns | 111.1 ns |
| Apple M4, 64 B | 74.9 ns | 80.1 ns | 100.6 ns | 105.4 ns | 131.6 ns |

- The plain context's last 15 cycles on Arrow Lake and 5 ns on the M4: about 97 more instructions than one-shot at 16 B, from copying the message into the block buffer and finishing from it, and reaching the hash through `ops` and the backend's dispatch. A streaming API pays the buffer copy, so what is left to win is the dispatch, which the no-std quest's atomics change too.
- The M4's `Box`ed row is about 20 ns over the plain context: macOS's `malloc` and `free`, which `Box` pays whatever the context's layout.
- HMAC's context runs 130 to 180 cycles over one-shot on x86_64. Most of it, about 157 of Arrow Lake's 176 cycles at 16 B, is `hmac::Context::sign(self)` moving the 320-byte keyed state and wiping it on drop. Closing it needs a `sign` that does not move the context, which changes the API (see #864's Waiting); rind-rustls' `sign_concat` could instead hash `first`, `middle`, and `last` into one buffer and call `hmac::sign`.
- Keep one consuming `finish`, decided with the maintainer on 2026-11-15: ✅ one consuming `finish` (rejected: a non-consuming `finish(&self)`).
- Prove nothing is lost: the digest proofs in `proofs/` cover the context path, so a change there keeps `admin/prove` passing.
