# Upstream workarounds

Every place rind works around a bug or gap in a tool or dependency it doesn't own.
Each entry says what breaks, how to see it, the workaround and where it lives, whether it is reported upstream, and what lets the workaround go.
Each workaround's comment names its entry by heading, as [CONTRIBUTING.md](CONTRIBUTING.md#upstream) asks.

rind's own bugs, deliberate choices, and plain version pins are not listed.
"Reported" names an upstream issue rind filed or found; "no" means none is linked yet.

## Compilers and linkers

### rust-lld cannot link ELFv1

- **Breaks:** Rust links `powerpc64-unknown-linux-gnu` with its bundled rust-lld, which supports only ELFv2, so every link fails with `ABI version 1 is not supported` on glibc's `Scrt1.o`.
- **Reproduce:** `cargo build --target powerpc64-unknown-linux-gnu` of any binary with Rust 1.98 in `nix develop .#powerpc64`, without the flag below.
- **Workaround:** the `powerpc64` shell in `flake.nix` passes `-C link-arg=-fuse-ld=bfd`, which gcc obeys over rustc's own `-fuse-ld`, so GNU ld links. Found in [moq-dev/rind#554](https://github.com/moq-dev/rind/pull/554).
- **Reported:** no (rust-lang/rust, for the target's default linker).
- **Goes when:** Rust's powerpc64 target links with the system linker by default, or lld supports ELFv1.

### lld links BSS-PLT objects into a crashing ppc32 binary

- **Breaks:** nixpkgs' `pkgsCross.ppc32` gcc is built without `--enable-secureplt`, so its objects, its `crtbeginS.o` included, use the BSS PLT. lld supports only the Secure PLT, yet links those objects without error into a binary that crashes. GNU ld detects them and copes.
- **Reproduce:** `int main(void) { return 0; }` built with that gcc and `-fuse-ld=lld` crashes at exit under qemu-ppc, and runs with GNU ld.
- **Workaround:** the `powerpc` shell in `flake.nix` passes `-C link-arg=-fuse-ld=bfd`, as for powerpc64. Diagnosed in [moq-dev/rind#580](https://github.com/moq-dev/rind/pull/580).
- **Reported:** no (llvm/llvm-project, for lld to refuse BSS-PLT objects; NixOS/nixpkgs, for a Secure PLT gcc).
- **Goes when:** lld refuses or handles BSS-PLT objects and nixpkgs' ppc32 gcc emits the Secure PLT, or Rust links powerpc with the system linker.

### Build scripts cannot see ARM's `v7` target feature

- **Breaks:** stable Rust leaves the unstable `v7` feature out of `CARGO_CFG_TARGET_FEATURE`, so a build script cannot tell an ARMv7 target from an earlier one by feature.
- **Reproduce:** `rustc --print cfg --target armv7-unknown-linux-gnueabihf` on stable names no `v7`, which is what a build script sees.
- **Workaround:** `rind/build.rs` reads the version from the target triple.
- **Reported:** no.
- **Goes when:** the `v7` target feature is stable.

### No AddressSanitizer for 32-bit ARM Linux

- **Breaks:** rustc has no AddressSanitizer for `armv7-unknown-linux-gnueabihf`.
- **Workaround:** `fuzz.yml`'s armv7 replay row runs with `sanitizer: none`.
- **Reported:** no.
- **Goes when:** rustc supports `-Zsanitizer=address` there.

## Constant-time analysis

### Valgrind hides ADX from `cpuid`

- **Breaks:** valgrind runs ADX instructions but clears ADX from the `cpuid` it reports, so `admin/ctgrind` would check only s2n-bignum's `_alt` routines.
- **Reproduce:** `is_x86_feature_detected!("adx")` prints `true` natively and `false` under valgrind on a CPU with ADX.
- **Workaround:** `admin/ctgrind` sets `VALGRIND_BUG_494162`, which `rind/src/low/x86_64/cpu.rs` reads to take the ADX routines anyway.
- **Reported:** [KDE bug 494162](https://bugs.kde.org/show_bug.cgi?id=494162).
- **Goes when:** the flake's valgrind reports ADX.

### Valgrind cannot run x86_64's newest extensions

- **Breaks:** valgrind (through 3.27) decodes no AVX-512, VAES, VPCLMULQDQ, or SHA instruction and hides them from `cpuid`, so ctgrind never reaches the code that uses them.
- **Workaround:** `admin/ct-sde` compares Intel SDE traces of those paths for two secrets, through the `ct_sde` tests (`rind/src/low/x86_64/ct_sde.rs`), in `ctgrind.yml`'s `x86_64-sde` job. Unlike ctgrind it sees only addresses, not variable-time instructions.
- **Reported:** no.
- **Goes when:** valgrind decodes them; `admin/ct-sde` then duplicates ctgrind.

### Valgrind hides the ARM crypto extension and SHA3

- **Breaks:** valgrind passes `AT_HWCAP2` only to ppc64 programs (3.22 through 3.28), so the armv7 build never sees its ARMv8 crypto extension; on aarch64 it hides SHA3 and the SHA-512 instructions. ctgrind never reaches the code that uses them.
- **Reproduce:** `getauxval(AT_HWCAP2)` is nonzero natively and zero under an armhf valgrind on an arm64 host.
- **Workaround:** `admin/ct-qemu` and `admin/ct-qemu-plugin.c` compare qemu traces of those paths for two secrets, through the `ct_qemu` tests (`rind/src/low/arm/ct_qemu.rs`), in `ctgrind.yml`'s `armv7-qemu` and `aarch64-qemu` jobs.
- **Reported:** no.
- **Goes when:** valgrind passes `AT_HWCAP2` on ARM and runs SHA3 on aarch64.

### Memcheck blames a public flag on a secret carry

- **Breaks:** on armv7 without NEON, memcheck flags the `beq` at `sha512_block_data_order_nohw+460` in aws-lc's integer SHA-512, which reads only the Z flag of a `tst` on the public round-constant pointer. The `tst` keeps the carry of the secret `adds` before it, and memcheck counts that carry against the branch when a superblock boundary falls between them, which the caller's code layout decides.
- **Reproduce:** the `no-neon` armv7 ctgrind row with `--vex-guest-max-insns=1` flags it, along with every branch on a `tst` of a public value.
- **Workaround:** the `aws-lc-sha512-armv4-nohw-flags` suppression in `admin/ctgrind.supp`.
- **Reported:** no.
- **Goes when:** memcheck tracks the Z flag apart from the carry.

### Valgrind on ARM does not fault guard pages

- **Breaks:** under valgrind on ARM, reading a `PROT_NONE` guard page does not fault, so `low::guard_pages`'s `planted_over_read_faults` fails.
- **Workaround:** [moq-dev/rind#607](https://github.com/moq-dev/rind/pull/607) (open) leaves the `low::guard_pages` tests out of `__ctgrind` builds; plain `cargo test` still runs them.
- **Reported:** no.
- **Goes when:** valgrind faults the read on ARM, if the bounds tests are ever wanted under ctgrind.

### libcrux branches on an undeclassified tag check

- **Breaks:** libcrux's AES-GCM decryption branches on whether the tag verified (`aes_gcm.rs:99`). The outcome is public, but libcrux does not declassify it, so memcheck flags the branch.
- **Workaround:** the `libcrux-aes-gcm-decrypt-outcome` suppression in `admin/ctgrind.supp`.
- **Reported:** no.
- **Goes when:** libcrux marks the outcome public for valgrind.

### BINSEC cannot decode much of what rind runs

- **Breaks:** BINSEC 0.11.3 stops at instructions it cannot decode: on x86_64, AES-NI, VAES, the SHA512 instructions, every EVEX encoding, and the `vinsertf128` LLVM emits for the AVX2 ChaCha20 kernel; on aarch64, the crypto extension's AES, PMULL, and SHA instructions, SHA3's, the `msr` that sets DIT, `tbl` (vpaes and NEON ChaCha20), and the `mrs` of `tpidr_el0` in glibc's `malloc`; on armv7, the NEON table lookups and the crypto extension.
- **Workaround:** `admin/ct-binsec`'s `UNDECODED` denies those features, leaving their paths to `admin/ctgrind`, `admin/ct-sde`, and `admin/ct-qemu`; `ct_binsec_chacha20` (`rind/src/test/binsec.rs`) checks one block; `ctgrind.yml`'s aarch64 `binsec` row runs only the harnesses BINSEC decodes, and armv7 has none. [The BINSEC quest](/quest/m2/confidence/binsec.md) plans stubs for some.
- **Reported:** no.
- **Goes when:** a BINSEC release decodes each, feature by feature.

### BINSEC cannot decode `stc`, `clc`, or `movmskps`

- **Breaks:** BINSEC 0.11.3 stops at the `stc` that s2n-bignum's P-521 code sets the carry with, and at the `movmskps` LLVM tests the portable P-256 and P-384 for zero with.
- **Workaround:** `admin/ct-binsec`'s `STUBS` gives each its effect in BINSEC's script language.
- **Reported:** no.
- **Goes when:** a BINSEC release decodes them.

### BINSEC cannot decode glibc's string functions

- **Breaks:** glibc picks `memcpy` and friends for the CPU: EVEX ones with AVX-512, TSX ones that run `xtest`, and on aarch64 SVE ones, none of which BINSEC 0.11.3 decodes.
- **Workaround:** `admin/ct-binsec` sets `GLIBC_TUNABLES` to hide AVX-512 from glibc. [moq-dev/rind#604](https://github.com/moq-dev/rind/pull/604) (open) replaces that with byte loops in place of glibc's `memcpy`, `memmove`, `memset`, `memcmp`, and `bcmp`, as valgrind replaces them, which also covers the TSX and SVE ones.
- **Reported:** no.
- **Goes when:** BINSEC decodes them; the byte loops then only shorten the search.

### gdb dumps a guarded thread stack empty

- **Breaks:** glibc marks a thread stack's guard pages with `MADV_GUARD_INSTALL`, inside the stack's own mapping, so gdb fails to read the mapping and its core dump holds the stack empty.
- **Reproduce:** `generate-core-file` in a thread of any Rust test on a kernel and glibc that install guard regions; BINSEC then finds the stack unmapped.
- **Workaround:** `admin/ct-binsec` calls `madvise(MADV_GUARD_REMOVE)` on the stack's mapping before dumping.
- **Reported:** no.
- **Goes when:** gdb's core dumps skip or read through guard regions.

## Proofs

### Aeneas cannot translate several kinds of Rust

- **Breaks:** Aeneas cannot translate function pointers, `&dyn` calls, `'static` and nested borrows, raw-pointer loads, atomics, and some standard-library impls, so the Rust that uses them stays untranslated.
- **Workaround:** `proofs/` models that Rust by hand, quote-checked against the source by `admin/prove`. [Its quest](/quest/m4/verified/aeneas-fn-pointers.md) lists each model with the Aeneas issue that blocks it.
- **Reported:** per limitation, in that quest.
- **Goes when:** each limitation lifts, model by model.

### Aeneas emits a duplicate `markerCopyInst` field

- **Breaks:** Aeneas names both of `ZeroablePrimitive`'s `Copy` clauses, which `NonZeroU32::get` brings in, `markerCopyInst`, and Lean refuses the duplicate field.
- **Reproduce:** `admin/prove lean`'s KDF translation without the rename fails in `Kdf/Types.lean`.
- **Workaround:** `admin/prove` renames the second to `markerCopyInst1` with `sed`.
- **Reported:** no.
- **Goes when:** Aeneas names the clauses apart.

## Mutation testing

### cargo-mutants cannot see into `cfg_if!`

- **Breaks:** cargo-mutants finds no module declared inside a `cfg_if!` invocation, so it mutates none of that module's code.
- **Workaround:** `rind/src/low/mod.rs` declares the backend modules outside `cfg_if!`, and `rind/src/mid/mod.rs` swaps its portable modules with `#[cfg_attr(..., path = ...)]`.
- **Reported:** no.
- **Goes when:** cargo-mutants expands `cfg_if!`, or rind stops using it.

### cargo-mutants misses compound `cfg(test)`s

- **Breaks:** cargo-mutants skips code under a bare `#[cfg(test)]`, but not under one that also names an architecture, such as `cfg(all(test, rind_backend = "x86_64"))`, so it mutates test helpers.
- **Workaround:** `.cargo/mutants.toml` excludes `rind/src/low/tests.rs` by glob and `\btests::` by regex.
- **Reported:** no.
- **Goes when:** cargo-mutants treats any `cfg` that requires `test` as test-only.

## Emulators

### cross's i686 Android image cannot run its binaries natively

- **Breaks:** run natively in cross's `i686-linux-android` container, rind's test binaries die of `SIGSYS` before the first test.
- **Workaround:** `Cross.toml` leaves that target on cross's qemu runner, whose Atom N270 model serves the portable backend.
- **Reported:** no.
- **Goes when:** the image runs i686 binaries natively, as its x86_64 one does.

### Flutter's debug JIT crashes under the Android emulator's ARM translation

- **Breaks:** the x86_64 Android emulator runs armv7 apps through its ARM translation, in which Flutter's debug JIT crashes.
- **Workaround:** `rind-dart/integration/android-arm.sh` runs the armv7 integration test as a release build and reads its result from the test reporter's log, since release builds leave out `integration_test`'s plugin.
- **Reported:** no.
- **Goes when:** the debug JIT runs under the translation.

## Dependencies

### libcrux-platform calls `__cpuid` outside `unsafe`

- **Breaks:** libcrux-platform 0.0.4, which libcrux-aes pulls in, calls `__cpuid` outside `unsafe`, which compiles only since `__cpuid` became safe in Rust 1.94, so rind needs 1.94 on 32-bit x86 rather than its 1.90 MSRV.
- **Reproduce:** `cargo +1.90 check -p rind --target i686-unknown-linux-gnu`.
- **Workaround:** README.md and PLATFORMS.md state the exception, and CI checks i686 only on stable.
- **Reported:** [celabshq/libcrux#1646](https://github.com/celabshq/libcrux/issues/1646). [The x86 quest](/quest/m2/adoption/targets/x86.md) drops the exception.
- **Goes when:** a fixed libcrux-platform is released.

### aws-lc cannot deny 32-bit ARM features at run time

- **Breaks:** aws-lc reads `OPENSSL_armcap` to deny CPU features on aarch64, but its 32-bit ARM detection has no such variable.
- **Workaround:** `bench.yml`'s armv7 `no-crypto` row builds aws-lc with `-DOPENSSL_STATIC_ARMCAP -DOPENSSL_STATIC_ARMCAP_NEON`, fixing its capabilities to NEON alone.
- **Reported:** no.
- **Goes when:** aws-lc reads `OPENSSL_armcap` on 32-bit ARM.

### aws-lc-sys targets the SDK's iOS version

- **Breaks:** aws-lc-sys builds its C for the iOS SDK's own deployment target unless told otherwise, and that code then needs symbols missing at rustc's default iOS version, so the device tests fail to link.
- **Workaround:** `build.yml`'s iOS job exports `rustc --print deployment-target` before building.
- **Reported:** no.
- **Goes when:** aws-lc-sys builds for the deployment target rustc uses.

### nixpkgs' Rust crashes cargo-llvm-cov's tests

- **Breaks:** cargo-llvm-cov's tests build with nixpkgs' rustc, whose instrumented binaries crash on exit, so cache.nixos.org has no build of it.
- **Workaround:** `flake.nix`'s `coverage` shell overrides cargo-llvm-cov with `doCheck = false`; rind's coverage builds with the pinned toolchain, not nixpkgs'.
- **Reported:** no.
- **Goes when:** nixpkgs builds cargo-llvm-cov.

### nixpkgs' Lean cannot read Mathlib's cache

- **Breaks:** Mathlib's prebuilt cache is read by the `leantar` bundled with the Lean toolchain, which nixpkgs' Lean lacks.
- **Workaround:** `flake.nix`'s `prove` shell takes `elan`, which fetches the toolchain `proofs/lean-toolchain` names.
- **Reported:** no.
- **Goes when:** nixpkgs' Lean reads Mathlib's cache.

### nixpkgs marks release-plz broken on Darwin

- **Breaks:** nixpkgs marks release-plz broken on Darwin, so the default shell cannot evaluate with it there.
- **Workaround:** `flake.nix`'s default shell adds release-plz only off Darwin.
- **Reported:** no.
- **Goes when:** nixpkgs builds release-plz on Darwin.

## CI runner images

### Ubuntu's AppArmor denies Intel SDE's sandbox

- **Breaks:** the flake's `sde` runs Intel's unmodified binaries in a bubblewrap sandbox, which needs the unprivileged user namespaces Ubuntu's AppArmor denies a program it has no profile for.
- **Workaround:** each job that runs `sde` (`coverage.yml`, `ctgrind.yml`, `fuzz.yml`, `mutants.yml`, `x86-cpu.yml`) first sets `kernel.apparmor_restrict_unprivileged_userns=0`.
- **Reported:** no.
- **Goes when:** the runner image allows the Nix store's bubblewrap a user namespace.
