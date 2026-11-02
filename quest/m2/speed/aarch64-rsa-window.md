# [S] aarch64 RSA on a 5-bit exponent window

## Goal

RSA private-key operations on aarch64 use a 5-bit exponent window (or aws-lc's equivalent) where it beats the 4-bit window by more than noise, as x86_64 does since [moq-dev/rind#224](https://github.com/moq-dev/rind/pull/224).

## Plan

Planned with the maintainer on 2026-11-02 from #224 and [#227](https://github.com/moq-dev/rind/pull/227).

- #224 measured 3-5% on x86_64 wherever the table lookup has a fast vector path; ring uses a 5-bit window on aarch64 too.
- Time it per width on the GitHub arm64 bench runner against the current 4-bit window and ring; keep it only where it wins.
- Constant time with aarch64 ctgrind coverage.
