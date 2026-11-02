# [S] x86_64 SHA-256 finishing in two blocks as fast as ring

## Goal

SHA-256 on x86_64 with SHA-NI matches ring on a message that finishes in two blocks: today 1.08x at 64 B on an EPYC 7763 (rind 128 ns, ring 118 ns), and 1.07-1.29x across the runner pool's other CPUs, while 32 B is 0.84x and 8 KB level.

## Plan

Planned with the maintainer on 2026-11-02 from the speed audit ([moq-dev/rind#191](https://github.com/moq-dev/rind/pull/191)); [moq-dev/rind#230](https://github.com/moq-dev/rind/pull/230) then brought every other one-block hash, HMAC, and HKDF row within noise. Ratios are rind's time over the fastest baseline in bench run [41398664891](https://github.com/moq-dev/rind/actions/runs/41398664891), and the CPU range from the nightly runs on `main` the same day. Measure on the GitHub bench runners, not the shared local host.

- The second block costs rind about 47 ns and ring about 22 ns, while bulk throughput is level, which points at the cost per call to Graviola's SHA-NI routine: `Sha256State::finish_with` compresses the message block and the padding block in two calls. Compare one call over both blocks, and the routine's entry and exit with ring's.
