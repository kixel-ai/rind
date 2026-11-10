# [S] Guard pages catch assembly that reads or writes past a buffer

## Goal

Every kernel that takes a caller's buffer runs with that buffer placed against a `PROT_NONE` page, at every length and alignment, so a load or store outside the buffer faults instead of passing. The tests run on every backend and CPU tier, and a planted over-read fails them.

## Plan

Planned from the 2026-11-09 tooling audit. Nothing checks the assembly's buffer bounds on the fastest tiers today:

- No test maps a guard page: `mprotect` and `PROT_NONE` appear nowhere in the tree. The only alignment sweep is `zero_bytes` over four offsets (`rind/src/low/tests.rs:22`).
- Valgrind's memcheck, through `admin/ctgrind`, sees heap overruns only on the paths it decodes. It hides AVX-512, VAES, VPCLMULQDQ, the SHA extensions, and armv7's crypto extension (`admin/ctgrind:11-22`).
- AddressSanitizer (`asan.yml`, and the fuzz targets) instruments Rust, not `asm!` or naked routines.

The kernels in scope are those handed a slice whose length the caller picks: AES-GCM, AES-CBC, AES-CTR, ChaCha20, ChaCha20-Poly1305, Poly1305, GHASH, the SHA-1 and SHA-2 block functions, the constant-time compare and copy, `zero_bytes`, and any other the PR finds. The bignum and curve routines take fixed-size arrays and are out of scope.

- Two placements per buffer: its end against a guard page, which catches a read or write past it, and its start just after one, which catches a tail load that backs up before it. The second also lets the start alignment vary independently of the length.
- Each buffer of a call gets its own placement: input, output, AAD, and the in-place case.
- Lengths run from zero past each kernel's widest stride and every short-message threshold, bounded so the SDE and qemu runs stay inside their jobs.
- Most kernels are reachable through the public API, which passes the caller's slice straight down. Where the API copies first, as a digest's partial block does, test the `low` routine directly.
- Unix targets suffice: Windows runs the same routines, behind `extern "sysv64"`. `libc` as a dev-dependency, or two `extern "C"` declarations, maps the pages.
- They are ordinary tests, so `just ci` runs them on the host's tier, and `build.yml`'s denied tiers, `x86-cpu.yml`'s SDE models, `just armv7`, and `just portable` inherit them with no workflow change. Confirm each tier's run reaches its kernel with the existing `RIND_TEST_*` assertions.
- Add the check to [TESTING.md](/TESTING.md).

## Related

- [BINSEC checks the secret paths no proof covers](/quest/m2/confidence/binsec.md) - explores the same binaries symbolically, for timing rather than bounds
