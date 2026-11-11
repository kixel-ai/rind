# [S] The ctgrind nightly passes on main

## Goal

Every row of `ctgrind.yml`'s nightly passes on `main`. Today all ten unit rows and the armv7 adapters row fail ([run 42916803474](https://github.com/moq-dev/rind/actions/runs/42916803474)), for three causes none of which is a constant-time violation in shipped code. While it is red, a real violation would go unnoticed.

## Plan

Planned with the maintainer on 2026-11-10 after triaging main's nightlies: ✅ m0, since m0 owns a failing `main`; ✅ one quest per workflow (rejected: one quest for every nightly).

- **Caller's key marked secret.** `cipher::ChaCha20::new` (`rind/src/mid/chacha20.rs:20`) calls `secret_slice` on the caller's `key` and never marks it public again. The `guard_pages::ciphers` test passes `&[7; 32]`, a constant in read-only data, which the `digests` test's `hmac::Key::new(&HMAC_SHA256, &[7; 32])` then reads, so its tag counts as secret and the test's `==` is flagged at `guard_pages.rs:233`. Fix it in the library: mark rind's own copy (`Self { key: into_secret(*key) }`), as `aes_kw.rs` and `aes_cbc.rs` do. `mid/ed25519.rs:26` (`secret_slice(seed)`) has the same pattern; fix it too, and check for any other `secret_slice` on a caller-owned argument. The bug dates to [moq-dev/rind#6](https://github.com/moq-dev/rind/pull/6); [moq-dev/rind#568](https://github.com/moq-dev/rind/pull/568)'s tests exposed it.
- **Guard-page test under valgrind.** `guard_pages::planted_over_read_faults` fails on the ARM rows (`reading before the buffer did not fault`): valgrind does not fault the child's read of the guard page there. ✅ Leave the `guard_pages` module out of `__ctgrind` builds, since it is a bounds test, not a constant-time one, and plain `cargo test` still runs it (rejected: skip only on ARM; detect valgrind and accept its report). Caused by #568.
- **armv7 PEM suppressions.** `admin/ctgrind.supp` silences rind-rcgen's PEM framing (`rind-rcgen-pem-utf8-index`, `read_until`) only as `Memcheck:Cond`/`Value8`; 32-bit ARM reports `Value4`. Add the `Value4` forms. Caused by [moq-dev/rind#515](https://github.com/moq-dev/rind/pull/515); it surfaced once the adapters row stopped dying at its `-lpython3.11` link step.
- The `definitely lost` lines in the logs also appear in passing runs and never count toward `admin/ctgrind`'s exit code; ignore them.
