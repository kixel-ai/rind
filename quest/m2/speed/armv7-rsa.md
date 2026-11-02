# [S] armv7 RSA as fast as the fastest source

## Goal

RSA on armv7 runs at least as fast as the fastest permissively licensed source: signing, verification, key loading, JWT RS256 signing and verification, and RSA handshakes. Nightly run [41378010740](https://github.com/moq-dev/rind/actions/runs/41378010740) had them at 2.28-2.62x, 2.84x, 6.42x, 2.72x and 2.91x, and 2.21-2.50x, on HACL\*'s bignum.

## Plan

Planned with the maintainer on 2026-11-02 from the speed audit ([moq-dev/rind#191](https://github.com/moq-dev/rind/pull/191)). Ranked by MoQ impact (armv7 first: it is MoQ's Android target, and ES256 is MoQ's auth). Measure on the GitHub bench runners, not the shared local host.

[moq-dev/rind#227](https://github.com/moq-dev/rind/pull/227) moved armv7 onto the shared RSA code over aws-lc's `armv4-mont` Montgomery multiplication, the routines ring and aws-lc run there. What remains:

- Read the armv7 RSA, JWT RS256, and RSA handshake rows of the first bench run that includes it, and refresh README's armv7 RSA and handshake cells.
- Close any gap left. Candidates: the shared exponentiation's 4-bit window (aws-lc uses 6 bits for 1024-bit exponents, and ring 5), and key loading's bit-serial `reduce_even`.
- Key generation is outside the ratios, but check it did not regress: `bignum_coprime` is now a constant-time binary gcd of 64 steps per word, run on every candidate prime. If it costs too much, Pornin's optimized binary gcd ([eprint 2020/972](https://eprint.iacr.org/2020/972)) does ~31 steps per pass over the words.
