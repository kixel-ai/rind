# [S] x86_64 SHA-256 finishing in two blocks and PBKDF2-HMAC-SHA1 as fast as the fastest source

## Goal

On x86_64 with SHA-NI, rind matches the fastest source on two rows:

- SHA-256 on a message that finishes in two blocks, against ring: today 1.08x at 64 B on an EPYC 7763 (rind 128 ns, ring 118 ns), and 1.07-1.29x across the runner pool's other CPUs, while 32 B is 0.84x and 8 KB level.
- PBKDF2-HMAC-SHA1, against aws-lc-rs: today 1.02x on an EPYC 7763 (rind 136.0 µs, aws-lc-rs 133.6 µs), where the audit measured 0.94x (125.3 µs). Every run on that CPU lands near 125 µs or near 137 µs, including on `main`'s hash code, so the goal is landing in the fast one every build.

## Plan

Planned with the maintainer on 2026-11-02 from the speed audit ([moq-dev/rind#191](https://github.com/moq-dev/rind/pull/191)); [moq-dev/rind#230](https://github.com/moq-dev/rind/pull/230) then brought every other one-block hash, HMAC, and HKDF row within noise. Ratios are rind's time over the fastest baseline in bench runs [41398664891](https://github.com/moq-dev/rind/actions/runs/41398664891) (SHA-256) and [41464027605](https://github.com/moq-dev/rind/actions/runs/41464027605) (PBKDF2), and the CPU range from the nightly runs on `main` the same day. Measure on the GitHub bench runners, not the shared local host.

- The second block costs rind about 47 ns and ring about 22 ns, while bulk throughput is level, which points at the cost per call to Graviola's SHA-NI routine: `Sha256State::finish_with` compresses the message block and the padding block in two calls. Compare one call over both blocks, and the routine's entry and exit with ring's.
- PBKDF2-HMAC-SHA1 on the EPYC 7763 measured 125.3, 125.9, and 126.2 µs in runs [41378010740](https://github.com/moq-dev/rind/actions/runs/41378010740), [41401089431](https://github.com/moq-dev/rind/actions/runs/41401089431), and [41400956876](https://github.com/moq-dev/rind/actions/runs/41400956876), but 136.9 µs in [41460380716](https://github.com/moq-dev/rind/actions/runs/41460380716), whose branch changed only RSA, and 137.1 and 136.0 µs on the heads of [moq-dev/rind#230](https://github.com/moq-dev/rind/pull/230). The four `main`-based runs share their hash code, so suspect where the linker places the SHA-1 SHA-NI loop or the HMAC iteration loop: compare their alignment in a fast and a slow binary before changing code.
