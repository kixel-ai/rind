# [S] AES-GCM key setup as fast as the fastest source

## Goal

Creating and dropping an AES-GCM key runs at least as fast as the fastest source, or its gap is within noise and recorded. Bench run [41472308771](https://github.com/moq-dev/rind/actions/runs/41472308771) timed it (`aes{128,256}-gcm/*/key`) at 1.20x ring on x86_64 (Zen 3, VAES), 1.47x aws-lc-rs without AVX, 1.13x without AES-NI, 1.55x aws-lc-rs on aarch64, 1.28x without the crypto extension, and 1.66x on armv7. After HKDF, as rustls makes one, rind's faster expansion hides most of it on x86_64 (1.02x) but not on aarch64 (1.11x).

## Plan

Planned with the maintainer on 2026-11-02 from the speed audit ([moq-dev/rind#191](https://github.com/moq-dev/rind/pull/191)). Ranked by MoQ impact (armv7 first: it is MoQ's Android target). Measure on the GitHub bench runners or by callgrind counts, not the shared local host. The maintainer (2026-11-02): don't chase a gap within noise; close the quest with the numbers.

[moq-dev/rind#239](https://github.com/moq-dev/rind/pull/239) shortened the x86_64 and aarch64 key schedules and GHASH power chains and wiped each key once. [moq-dev/rind#260](https://github.com/moq-dev/rind/pull/260) stopped `aead::Key::new` copying the key, read CPU features inline, and dropped aarch64's second copy of the GHASH powers: under callgrind an x86_64 AES-128-GCM key on AVX (i7-8700) took 1121 instructions to set up and drop, from 1801, against aws-lc-rs's 1250. Without AVX, run [41515086051](https://github.com/moq-dev/rind/actions/runs/41515086051) timed main at 1.44x aws-lc-rs (136 ns against 94), and rind was already faster without AES-NI (0.85x) and SSSE3 (0.88x).

- First read the `key` rows of run [41519474246](https://github.com/moq-dev/rind/actions/runs/41519474246), #260's head, against run [41515086051](https://github.com/moq-dev/rind/actions/runs/41515086051), main after [moq-dev/rind#230](https://github.com/moq-dev/rind/pull/230)'s armv7 wipes. Close the quest, updating README's AES-GCM cells, wherever the gap is within noise.
- `AesGcm::new` still moves its AES key and GHASH table once each into place (about 140 instructions on x86_64): `key` stays a local because H is its encryption of zero. Building them in place needs `unsafe` field writes, which `mid` forbids, so a low-level constructor would own both.
- Every x86_64 key is 1 KB to wipe, sized by the AVX-512 variant: its and the VAES variant's `ClmulTable` repeats powers their kernel's table holds. The AVX2 kernel's table also holds every Karatsuba term, so the PCLMULQDQ path could read it; the AVX-512 one holds none.
- armv7 runs aws-lc's own key schedule and GHASH setup, so its remaining gap is the work around them.
- Without AVX, aws-lc-rs sets up a key faster (118 ns) than with it (142 ns on another core); compare its `aeskeygenassist` schedule with rind's `aesenclast` one there.
