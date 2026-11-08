# armv7 SHA-256 source comparison

Keep Graviola's SHA-256 when armv7 lacks the crypto extension. Its latency
is 28.5% lower at 64 B and 30.2% lower at 1350 B than HACL*'s, exceeding the
about 10% advantage required to choose unverified code over verified code.

Measured on 2026-11-08 on GitHub's `ubuntu-24.04-arm` Neoverse-N2 runner,
running `armv7-unknown-linux-gnueabihf` binaries natively with `setarch
linux32`. Both executables were ELF 32-bit ARM EABI5; the job checked that
no QEMU binfmt handler was registered. These are measurements of AArch32
on this runner, not of an older ARMv7 board.

| Message | Graviola, first | HACL*, first | HACL*, second | Graviola, second |
|---|---:|---:|---:|---:|
| 64 B | 689.01 ns | 964.21 ns | 964.33 ns | 689.23 ns |
| 1350 B | 7.0130 µs | 10.048 µs | 10.047 µs | 7.0205 µs |

Values are Criterion's central latency estimates, with 100 samples, 3 s
warmup and 5 s measurement per row. Graviola's advantage uses the mean of
each variant's two estimates. The interleaved order was Graviola, HACL*,
HACL*, Graviola, on one runner. aws-lc-rs ran alongside each variant:
159.58–159.99 ns at 64 B and 755.90–756.46 ns at 1350 B. Its small drift
supports the comparison, but this experiment selects between the two Rust
sources; it does not establish parity with aws-lc's assembly.

Both variants use rind's digest context, streaming, dispatch and padding.
The HACL* variant replaces only `None` in armv7's SHA-256 compression
selection with `libcrux_sha2::hacl::sha256_update_nblocks` from
libcrux-sha2 0.0.9, exposing HACL* through its existing dependency feature.
The chunk wrapper bounds its byte length to a block-aligned `u32`.
Graviola is rind's existing `low::generic::sha256` implementation.
Both use Rust 1.99.1, the bench profile, and `--cfg rind_cpu_disable`;
`RIND_CPU_DISABLE_sha2=1` disables rind's crypto extension and
`OPENSSL_armcap=~0x10` disables aws-lc's SHA-256 instructions.

The [successful run](https://github.com/moq-dev/rind/actions/runs/42496769936)
contains the full logs and Criterion artifact, including the candidate
patch. The [experiment workflow](https://github.com/moq-dev/rind/blob/c2a9a1edb43d454d9a275fbb8d98a6274c23d91c/.github/workflows/bench.yml)
records the exact build and invocation. It was restored after measurement,
so the nightly benchmark matrix remains unchanged. No new cryptographic
implementation is shipped by this decision.
