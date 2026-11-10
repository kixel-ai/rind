// Written for Graviola by Joe Birr-Pixton, 2024.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

use core::sync::atomic::{AtomicU8, Ordering};

pub(crate) fn enter_cpu_state() -> u32 {
    #[cfg(target_vendor = "apple")]
    return dit::maybe_enable();
    #[cfg(not(target_vendor = "apple"))]
    0
}

pub(crate) fn leave_cpu_state(old: u32) {
    #[cfg(target_vendor = "apple")]
    dit::maybe_disable(old);
    #[cfg(not(target_vendor = "apple"))]
    let _ = old;
}

/// Effectively memset(ptr, 0, len), but not visible to optimiser
///
/// # Safety:
/// There must be `len` writable bytes at `ptr`; with no alignment
/// requirement.
pub(in crate::low) unsafe fn zero_bytes(ptr: *mut u8, len: usize) {
    // SAFETY: inline assembly.
    unsafe {
        core::arch::asm!(
            "       eor {zero}.16b, {zero}.16b, {zero}.16b",
            // by-16 loop
            "   2:  cmp {len}, #16",
            "       blt 3f",
            "       st1 {{{zero}.16b}}, [{ptr}]",
            "       add {ptr}, {ptr}, #16",
            "       sub {len}, {len}, #16",
            "       b 2b",
            // by-8 loop
            "   3:  cmp {len}, #8",
            "       blt 4f",
            "       str xzr, [{ptr}], #8",
            "       sub {len}, {len}, #8",
            "       b 3b",
            // by-1 loop
            "   4:  subs {len}, {len}, #1",
            "       blt 5f",
            "       strb wzr, [{ptr}], #1",
            "       b 4b",
            "   5:  ",

            ptr = inout(reg) ptr => _,
            len = inout(reg) len => _,

            // clobbers
            zero = out(vreg) _,
        )
    }
}

/// Effectively memcmp(a, b, len), but guaranteed to visit every element
/// of a and b.
///
/// The return value does not follow memcmp semantics: it is zero if
/// `a == b`, otherwise it is non-zero.
///
/// # Safety
/// The caller must ensure that there are `len` bytes readable at `a` and `b`,
pub(in crate::low) unsafe fn ct_compare_bytes(a: *const u8, b: *const u8, len: usize) -> u8 {
    // SAFETY: inline assembly.
    unsafe {
        let mut acc = 0u8;
        core::arch::asm!(
            "   2: cmp  {len}, 0",
            "      beq  3f",
            "      ldrb {tmpa:w}, [{a}]",
            "      ldrb {tmpb:w}, [{b}]",
            "      eor  {tmpa:w}, {tmpa:w}, {tmpb:w}",
            "      orr  {acc:w}, {acc:w}, {tmpa:w}",
            "      add  {a}, {a}, 1",
            "      add  {b}, {b}, 1",
            "      sub  {len}, {len}, 1",
            "      b    2b",
            "   3:  ",
            a = inout(reg) a => _,
            b = inout(reg) b => _,
            len = inout(reg) len => _,
            tmpa = inout(reg) 0u8 => _,
            tmpb = inout(reg) 0u8 => _,
            acc = inout(reg) acc,
        );
        acc
    }
}

/// Compares two 16-byte blocks, such as AEAD tags, in constant time.
///
/// Returns zero if `a == b`, otherwise non-zero. The words are combined in
/// assembly so the compiler cannot split the test into early exits.
pub(in crate::low) fn ct_compare_16(a: &[u8; 16], b: &[u8; 16]) -> usize {
    let (a, b) = (u128::from_ne_bytes(*a), u128::from_ne_bytes(*b));
    let mut diff = a as u64;
    // SAFETY: register-only arithmetic.
    unsafe {
        core::arch::asm!(
            "eor {diff}, {diff}, {b0}",
            "eor {a1}, {a1}, {b1}",
            "orr {diff}, {diff}, {a1}",
            diff = inout(reg) diff,
            a1 = inout(reg) (a >> 64) as u64 => _,
            b0 = in(reg) b as u64,
            b1 = in(reg) (b >> 64) as u64,
            options(pure, nomem, nostack, preserves_flags),
        );
    }
    diff as usize
}

/// Proof that the CPU has the crypto extension: AES, PMULL, SHA-1, and
/// SHA-256.
///
/// Cores without it (such as the Raspberry Pi 4's Cortex-A72) lack all of it,
/// so one token covers it.
#[derive(Clone, Copy, Debug)]
pub(crate) struct HaveCryptoExt(());

impl HaveCryptoExt {
    /// Detects the extension once, then answers from the cached result.
    pub(crate) fn check() -> Option<Self> {
        (features() & CRYPTO_EXT != 0).then_some(Self(()))
    }
}

/// Token type reflecting the check for the SHA3 CPU feature
///
/// A value of this type is proof that the CPU dynamic feature check has happened.
#[derive(Clone, Copy, Debug)]
pub(crate) struct HaveSha3(());

impl HaveSha3 {
    pub(crate) fn check() -> Option<Self> {
        (features() & SHA3 != 0).then_some(Self(()))
    }
}

/// Returns the first CPU feature we require unconditionally that this CPU lacks.
pub(crate) fn missing_cpu_feature() -> Option<&'static str> {
    (features() & NEON == 0).then_some("neon")
}

const NEON: u8 = 1 << 0;
const CRYPTO_EXT: u8 = 1 << 1;
const SHA3: u8 = 1 << 2;
#[cfg(target_vendor = "apple")]
const DIT: u8 = 1 << 3;
const DETECTED: u8 = 1 << 7;

static FEATURES: AtomicU8 = AtomicU8::new(0);

/// The detected features, read once. Inlined, so a check is a load and a
/// test, with the first call's detection out of line.
#[inline]
fn features() -> u8 {
    match FEATURES.load(Ordering::Relaxed) {
        0 => detect_once(),
        features => features,
    }
}

#[cold]
#[inline(never)]
fn detect_once() -> u8 {
    let features = detect() | DETECTED;
    FEATURES.store(features, Ordering::Relaxed);
    features
}

fn detect() -> u8 {
    use std::arch::is_aarch64_feature_detected as detected;

    let neon = test_toggle("neon", detected!("neon"));
    let crypto_ext = test_toggle("aes", detected!("aes"))
        && test_toggle("pmull", detected!("pmull"))
        // Rust's `sha2` covers the SHA-1 instructions too.
        && test_toggle("sha2", detected!("sha2"));
    let sha3 = test_toggle("sha3", detected!("sha3"));
    let features = (if neon { NEON } else { 0 })
        | (if crypto_ext { CRYPTO_EXT } else { 0 })
        | (if sha3 { SHA3 } else { 0 });
    #[cfg(target_vendor = "apple")]
    let features = features
        | if test_toggle("dit", detected!("dit")) {
            DIT
        } else {
            0
        };
    features
}

// DIT changes what runs only on Apple's cores, where from the M3 it turns off
// the data memory-dependent prefetcher that GoFetch reads secrets through. Arm
// says it has no effect on any current Arm core, so elsewhere rind skips the
// cost of setting it.
#[cfg(target_vendor = "apple")]
mod dit {
    pub(super) fn maybe_enable() -> u32 {
        if super::features() & super::DIT != 0 {
            // SAFETY: in this branch, we verified `dit` cpu feature is supported
            match unsafe { read() } {
                0 => {
                    // SAFETY: in this branch, we verified `dit` cpu feature is supported
                    unsafe {
                        write(1);
                    };
                    1
                }
                _ => 0,
            }
        } else {
            0
        }
    }

    pub(super) fn maybe_disable(we_enabled: u32) {
        if we_enabled > 0 {
            // SAFETY: `we_enabled > 0` implies `dit` cpu feature was supported earlier
            unsafe { write(0) }
        }
    }

    #[target_feature(enable = "dit")]
    pub(super) fn read() -> u32 {
        let mut out: u64;
        // SAFETY: `mrs _, DIT` is defined only if `dit` cpu feature is supported
        unsafe {
            core::arch::asm!(
                "mrs {r}, DIT",
                r = out(reg) out,
            );
        }

        const DIT: u64 = 0x01000000;
        (out & DIT == DIT) as u32
    }

    #[target_feature(enable = "dit")]
    pub(super) fn write(on: u32) {
        if on > 0 {
            // SAFETY: `msr DIT, _` is defined only if `dit` cpu feature is supported
            unsafe { core::arch::asm!("msr DIT, #1") }
        } else {
            // SAFETY: `msr DIT, _` is defined only if `dit` cpu feature is supported
            unsafe { core::arch::asm!("msr DIT, #0") }
        }
    }
}

#[cfg(not(any(debug_assertions, rind_cpu_disable)))]
fn test_toggle(_id: &str, detected: bool) -> bool {
    detected
}

/// Lets a debug build, or a release one with `--cfg rind_cpu_disable`, deny a
/// feature with `RIND_CPU_DISABLE_<id>`, as on x86_64, so a CPU with the
/// crypto extension also tests the code for one without.
#[cfg(any(debug_assertions, rind_cpu_disable))]
fn test_toggle(id: &str, detected: bool) -> bool {
    if std::env::var(format!("RIND_CPU_DISABLE_{id}")).is_ok() {
        println!("DEBUG: denying cpuid {id:?}");
        false
    } else {
        detected
    }
}

/// Read-only prefetch hint.
pub(in crate::low) fn prefetch_ro<T>(ptr: *const T) {
    // SAFETY: inline assembly
    unsafe {
        core::arch::asm!(
            "prfm pldl1strm, [{ptr}]",
            ptr = in(reg) ptr,
            options(readonly, nostack)
        );
    }
}

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
mod tests {
    use super::*;

    /// Whether std detects every feature named, less those `test_toggle`
    /// denies.
    macro_rules! available {
        ($($name:tt),+) => {
            true $(&& std::arch::is_aarch64_feature_detected!($name) && !denied($name))+
        };
    }

    fn denied(name: &str) -> bool {
        cfg!(any(debug_assertions, rind_cpu_disable))
            && std::env::var(format!("RIND_CPU_DISABLE_{name}")).is_ok()
    }

    // Each check names the features its kernels need, which the OS reports
    // independently of the bits `detect` packs them into.
    #[test]
    fn checks_need_their_features() {
        assert_eq!(missing_cpu_feature().is_none(), available!("neon"));
        assert_eq!(
            HaveCryptoExt::check().is_some(),
            available!("aes", "pmull", "sha2")
        );
        assert_eq!(HaveSha3::check().is_some(), available!("sha3"));
    }

    // CI runs the aarch64 suite on a CPU with the crypto extension, then
    // again with it denied, and names which, so neither run silently tests
    // only one path.
    #[test]
    fn detects_the_expected_cpu() {
        if let Some(expected) = std::env::var_os("RIND_TEST_ARM_CRYPTO_EXT") {
            assert_eq!(HaveCryptoExt::check().is_some(), expected == "1");
        }
    }

    // A core that runs `mrs DIT` has DIT, whatever the OS reports, so a child
    // process runs it.
    #[cfg(target_vendor = "apple")]
    #[test]
    fn enables_dit_whenever_the_cpu_has_it() {
        let has_dit = child_reads_dit();

        let expected = test_toggle("dit", has_dit);
        assert_eq!(features() & DIT != 0, expected);
        // A denied DIT is left alone, as under `admin/ctgrind`, whose
        // valgrind runs no DIT instruction.
        if expected {
            // SAFETY: this core has DIT. Cleared, so only an `Entry` can set
            // it.
            unsafe { dit::write(0) };
            let outer = crate::low::Entry::new_secret();
            // SAFETY: as above.
            assert_eq!(unsafe { dit::read() }, expected as u32);
            // A nested `Entry` leaves DIT to the outer one.
            drop(crate::low::Entry::new_secret());
            // SAFETY: as above.
            assert_eq!(unsafe { dit::read() }, expected as u32);
            drop(outer);
            // SAFETY: as above.
            assert_eq!(unsafe { dit::read() }, 0);
        }
    }

    #[cfg(target_vendor = "apple")]
    #[test]
    fn dit_hold_keeps_dit_on_across_calls() {
        if features() & DIT == 0 {
            // Nothing to hold, and nothing to read DIT with.
            drop(crate::cpu::Dit::hold());
            return;
        }
        // SAFETY: this core has DIT. Cleared, so only the guard can set it.
        unsafe { dit::write(0) };
        let first = crate::cpu::Dit::hold();
        // A call under the guard, and a nested guard, leave DIT to it.
        drop(crate::low::Entry::new_secret());
        drop(crate::cpu::Dit::hold());
        // SAFETY: as above.
        assert_eq!(unsafe { dit::read() }, 1);
        // Guards may drop out of order: DIT waits for the last.
        let second = crate::cpu::Dit::hold();
        drop(first);
        // SAFETY: as above.
        assert_eq!(unsafe { dit::read() }, 1);
        drop(second);
        // SAFETY: as above.
        assert_eq!(unsafe { dit::read() }, 0);
    }

    #[cfg(target_vendor = "apple")]
    fn child_reads_dit() -> bool {
        let test = concat!(module_path!(), "::reads_dit");
        let test = test.split_once("::").unwrap().1;
        let out = std::process::Command::new(std::env::current_exe().unwrap())
            .args([test, "--exact", "--nocapture"])
            .env("RIND_TEST_READ_DIT", "1")
            .output()
            .unwrap();
        let stdout = String::from_utf8_lossy(&out.stdout);
        if out.status.success() {
            assert!(stdout.contains("read DIT"), "{test} did not run:\n{stdout}");
            return true;
        }
        let illegal = std::os::unix::process::ExitStatusExt::signal(&out.status) == Some(4);
        assert!(illegal, "{test} failed with {}:\n{stdout}", out.status);
        false
    }

    /// Runs `mrs DIT` for `child_reads_dit`, which an illegal instruction
    /// kills on a core without DIT.
    #[cfg(target_vendor = "apple")]
    #[test]
    fn reads_dit() {
        if std::env::var_os("RIND_TEST_READ_DIT").is_some() {
            let pstate: u64;
            // SAFETY: on a core without DIT this raises an illegal
            // instruction, which is the answer the parent wants.
            unsafe { core::arch::asm!("mrs {}, S3_3_C4_C2_5", out(reg) pstate) };
            println!("read DIT: {pstate:#x}");
        }
    }
}
