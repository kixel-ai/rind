# [S] Resolve the Android SHA-512 16 KiB benchmark gap

## Goal

Determine whether rind’s SHA-512 at 16 KiB is measurably slower than ring on the Samsung Galaxy A16 5G (SM-A166U1, Exynos 1330, Android 16). If it is, close the gap without regressing the 64 B and 1350 B rows or weakening the implementation’s correctness and constant-time guarantees.

## Plan

The v15 devbench quick run flagged this as the only row behind ring on the phone. It measured 33,399.27 ns for rind and 33,397.40 ns for ring. A separate quick run on the same phone reversed their order at 33,317.87 ns and 33,350.96 ns. The app ranks by raw median, which gives close results a strict order.

Three follow-up runs each timed just this pair over three rounds on the same phone. Their medians were:

| Run | rind | ring |
|---|---:|---:|
| 1 | 33,365.87 ns | 33,342.56 ns |
| 2 | 33,339.05 ns | 33,399.85 ns |
| 3 | 33,364.49 ns | 33,376.01 ns |

rind led in two of three runs. The per-run median differences were all under 0.2%, and the order changed between runs. Run 1's per-round ranges overlapped. These runs used the same registration order within the SHA-512 benchmark, so the next measurement should alternate it before attributing any difference to the backend.

- Reproduce the comparison with the same APK, phone temperature range, inputs, and versions of rind, ring and aws-lc-rs. Collect at least five paired measurements at 16 KiB and alternate the measurement order within each pair. Record the full per-round medians, ranges and CPU features. Use the 64 B and 1350 B rows as controls. Establish the usual spread by repeating the unchanged control before claiming a regression.
- If there is a stable gap outside the control spread, compare the public digest operation and the backend’s compression separately. This phone reports SHA-2 without SHA-512 acceleration. Inspect `rind/src/mid/sha2.rs` and `rind/src/low/aarch64/sha512.rs` to distinguish buffering or dispatch overhead from the scalar compression routine. Compare like-for-like workloads with ring and aws-lc-rs.
- Keep a change only if paired before-and-after runs show a repeatable gain at 16 KiB and no regression outside the measured spread at the two control sizes. Run the SHA-512 vectors and differential tests. Preserve the scalar routine’s proof and byte-check relationship, or account for it explicitly if the winning change reaches that routine.
- If the difference stays within the repeat-measurement spread, record the results and finish the quest without changing the cryptography. Displaying sub-spread differences as ties is a separate app scoring change and would leave the raw timings available.

## Related

- [Benchmark harness improvements](/quest/m2/bench/harness.md) - how measurements are gathered and reported
