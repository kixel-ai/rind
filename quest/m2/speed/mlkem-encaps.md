# [M] ML-KEM-768 encapsulation as fast as the fastest source

## Goal

ML-KEM-768 encapsulation and key generation match the fastest source on armv7, where libcrux-ml-kem trails aws-lc-rs by 1.05x and 1.03x, and on aarch64, where rind's construction trails by 1.04x and 1.04x.

## Plan

Planned with the maintainer on 2026-11-02 from the speed audit ([moq-dev/rind#191](https://github.com/moq-dev/rind/pull/191)); ratios are rind's time over the fastest baseline in bench run [41400124007](https://github.com/moq-dev/rind/actions/runs/41400124007) of [moq-dev/rind#233](https://github.com/moq-dev/rind/pull/233). Ranked by MoQ impact (armv7 first: it is MoQ's Android target). Measure on the GitHub bench runners, not the shared local host.

- armv7: move to rind's own ML-KEM construction. It runs libcrux's portable ML-KEM whole, while aws-lc runs mlkem-native's portable C, which rind already ports for x86_64 without AVX2, where it measured 1.3x faster than libcrux. That needs a portable Keccak-f and the port built for 32-bit ARM. Keep libcrux unless the new code is more than 2% faster on the armv7 runner.
- aarch64: #233 cut the Keccak-f count to aws-lc's, taking encapsulation from 1.12x to 1.04x on the Neoverse-N2. Step through the rest against aws-lc's mlkem-native per step (matrix expansion, NTT, sampling, compression), as #233 did on Zen 3.
- x86_64: run 41400124007 put rind at 0.79x on a Zen 4 with every feature and 0.92x on Zen 3 without AVX2, but timed no Zen 3 with AVX2, where #233 started at 1.22x (a local Zen 3 pass put it at 0.94x). If a nightly's EPYC 7763 shows it above about 1.02x, that path rejoins this quest.
