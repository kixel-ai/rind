# [M] Pick the macOS random source: getentropy, CommonCrypto, or a userspace DRBG

## Goal

`rind::mid::rng` on macOS either keeps `getentropy` per draw, as aws-lc-rs does, or switches to a faster source the maintainer picked below; every other target keeps `getrandom::fill` per draw.

## Plan

Planned with the maintainer on 2026-11-21 (`/quest-plan`): ✅ benchmark-gate first and land a fork-safe thread-local userspace DRBG (non-FIPS `std` only, wiped on drop) only where it wins by at least 5% on hedged ECDSA or handshakes (rejected: unconditional userspace DRBG; dropping the idea without measuring).

Measured 2026-11-24 ([kixel-ai/rind#1010](https://github.com/kixel-ai/rind/pull/1010) has the tables and the prototype): a thread-local ChaCha20 fast-key-erasure DRBG over `low::chacha20`, reseeded every 2^16 draws, against today's `getrandom::fill`, on the rind rows of the `p256`, `p384`, `x25519`, `mlkem`, and `rustls` benches.

- Linux misses the gate everywhere. With glibc 2.41+ on kernel 6.11+, `getrandom` already runs in the vDSO (45 ns for 32 bytes; the DRBG 11 ns): P-256 signing 1.4% faster, handshakes within noise. Through the system call (164 ns, as on glibc before 2.41 or older kernels): P-256 signing 3.0%, handshakes 1.2-1.8%. A `getpid()` fork check costs 46 ns there, so a fork-checked DRBG is no faster than the vDSO. Untested: Intel hosts with KPTI, whose system calls cost more.
- macOS (Apple M4) passes only on P-256 signing. `getentropy` costs 680 ns for 32 bytes, and a TLS handshake draws about 12 times. libSystem caches `getpid()`, so a check that catches a raw `fork` system call needs `syscall(SYS_getpid)`, 68 ns, through an API Apple deprecates.

  | change vs. `getentropy` | P-256 sign | P-384 sign | handshakes (3 rows) |
  |---|---|---|---|
  | DRBG, no fork check | -7.1% | -2.1% | -4.6% to -5.2% |
  | DRBG + `syscall(SYS_getpid)` | -6.7% | -1.9% | -3.6% to -4.4% |
  | `CCRandomGenerateBytes` (196 ns) | -5.2% | -2.1% | -3.3% to -3.9% |

- aws-lc-rs reseeds its thread-local DRBG from `getentropy` on every call on macOS, because it has no fork or VM-snapshot detection there (`crypto/ube/fork_ube_detect.c`); on Linux it buffers behind `MADV_WIPEONFORK` and vmgenid. A rind DRBG on macOS would catch every fork through the `getpid` check but not a VM snapshot restored twice, which aws-lc-rs's per-call reseed covers.
- rind has no `std` feature; a thread-local needs `extern crate std` on macOS, and the main thread's thread-local destructors may not run at exit, so its state may go unwiped then.

## Waiting

- Maintainer: pick macOS's random source.
  1. **Keep `getentropy` (recommended)**: matches aws-lc-rs, adds nothing; the only row that passes is P-256 signing, about 0.45 µs per signature on a client platform. Delete this quest.
  2. **`CCRandomGenerateBytes`**: about ten lines calling CommonCrypto's generator, which aws-lc already uses on iOS; P-256 signing 5.2% faster, just over the gate, handshakes 3.5%; fork and VM-snapshot handling become Apple's.
  3. **The fork-checked DRBG**: P-256 signing 6.7% faster, handshakes 4%; about 150 lines with fork, zeroing, and ThreadSanitizer tests, a deprecated `syscall(2)` call, and weaker VM-snapshot safety than aws-lc-rs.
