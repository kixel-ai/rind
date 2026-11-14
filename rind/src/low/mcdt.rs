// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! Intel's mitigation for MXCSR configuration dependent timing (MCDT).
//!
//! On Intel's cores from Skylake to Alder Lake, some vector integer
//! multiplies, such as `pmuludq`, `vpmullw`, and `vpmadd52luq`, may retire a
//! cycle later for some operand values unless MXCSR holds `0x1FBF`, as
//! Intel's "MXCSR Configuration Dependent Timing" describes:
//! <https://www.intel.com/content/www/us/en/developer/articles/technical/software-security-guidance/best-practices/mxcsr-configuration-dependent-timing.html>.
//! Neither aws-lc nor BoringSSL mitigates it.
//!
//! [`Mcdt`] runs Intel's sequence on every CPU that does not report
//! `MCDT_NO`: it saves MXCSR, loads `0x1FBF`, and runs `lfence`, then on drop
//! runs `lfence` and restores the saved value. `0x1FBF` is MXCSR's default
//! with every exception flag already set, so it changes nothing rind computes:
//! rind does no floating-point arithmetic, as `admin/ct-vartime` checks, which
//! also checks that every instruction Intel lists runs under an `Mcdt`.

use core::sync::atomic::{AtomicU8, Ordering};

#[cfg(target_arch = "x86")]
use core::arch::x86::{__cpuid, __cpuid_count};
#[cfg(target_arch = "x86_64")]
use core::arch::x86_64::{__cpuid, __cpuid_count};

/// What Intel's mitigation loads: every exception masked and flagged.
const MITIGATED: u32 = 0x1fbf;

/// Holds MXCSR at Intel's mitigating value until dropped.
///
/// One already held, by an outer guard or the caller, is left to it.
#[must_use]
pub(crate) struct Mcdt(Option<u32>);

impl Mcdt {
    /// Loads the mitigating value, where the CPU needs it.
    #[inline]
    pub(crate) fn enter() -> Self {
        Self(if needed() { enter() } else { None })
    }
}

impl Drop for Mcdt {
    #[inline]
    fn drop(&mut self) {
        if let Some(saved) = self.0 {
            leave(saved);
        }
    }
}

/// Loads the mitigating value, unless MXCSR already holds it, returning what
/// it replaced. `admin/ct-vartime` finds the functions that call this by
/// name, so it is never inlined.
#[inline(never)]
fn enter() -> Option<u32> {
    let saved = mxcsr();
    if saved == MITIGATED {
        return None;
    }
    // SAFETY: loads MXCSR from a valid value. No `nomem`, so the compiler
    // moves no memory access across it.
    unsafe {
        core::arch::asm!(
            "ldmxcsr dword ptr [{value}]",
            "lfence",
            value = in(reg) &MITIGATED,
            options(nostack),
        );
    }
    Some(saved)
}

/// Restores what [`enter`] replaced.
#[inline(never)]
fn leave(saved: u32) {
    // SAFETY: loads MXCSR from the value `stmxcsr` stored.
    unsafe {
        core::arch::asm!(
            "lfence",
            "ldmxcsr dword ptr [{saved}]",
            saved = in(reg) &saved,
            options(nostack),
        );
    }
}

/// This thread's MXCSR.
fn mxcsr() -> u32 {
    let mut value = 0u32;
    // SAFETY: stores MXCSR to `value`.
    unsafe {
        core::arch::asm!(
            "stmxcsr dword ptr [{value}]",
            value = in(reg) &mut value,
            options(nostack, preserves_flags),
        );
    }
    value
}

/// Whether this CPU may need the mitigation: it does not report `MCDT_NO`.
/// Intel's cores before Skylake and its Atoms do not either, but need none;
/// rind mitigates there too rather than keep a list of models.
#[inline]
fn needed() -> bool {
    match NEEDED.load(Ordering::Relaxed) {
        UNKNOWN => detect_once(),
        state => state == YES,
    }
}

const UNKNOWN: u8 = 0;
const YES: u8 = 1;
const NO: u8 = 2;

static NEEDED: AtomicU8 = AtomicU8::new(UNKNOWN);

#[cold]
#[inline(never)]
fn detect_once() -> bool {
    let needed = !reports_mcdt_no();
    NEEDED.store(if needed { YES } else { NO }, Ordering::Relaxed);
    needed
}

/// Whether `cpuid` reports `MCDT_NO`, leaf 7, subleaf 2, EDX bit 5.
fn reports_mcdt_no() -> bool {
    // `__cpuid` is safe from Rust 1.94 but `unsafe` on the 1.90 MSRV.
    #[allow(unused_unsafe)]
    // SAFETY: every CPU that runs SSE2 has `cpuid`, and leaves past the
    // highest it reports are not read.
    let mcdt_no = unsafe {
        __cpuid(0).eax >= 7 && __cpuid_count(7, 0).eax >= 2 && __cpuid_count(7, 2).edx & 1 << 5 != 0
    };
    mcdt_no && !denied()
}

/// Lets a debug build, or a release one with `--cfg rind_cpu_disable`,
/// ignore `MCDT_NO` with `RIND_CPU_DISABLE_mcdt_no`, so a CPU that reports
/// it also runs and times the mitigation.
fn denied() -> bool {
    cfg!(any(debug_assertions, rind_cpu_disable))
        && std::env::var_os("RIND_CPU_DISABLE_mcdt_no").is_some()
}

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
mod tests {
    use super::*;

    #[test]
    fn holds_and_restores() {
        let before = mxcsr();
        assert_ne!(before, MITIGATED);
        let saved = enter();
        assert_eq!(saved, Some(before));
        assert_eq!(mxcsr(), MITIGATED);
        // An inner guard leaves the outer one's value alone.
        assert_eq!(enter(), None);
        assert_eq!(mxcsr(), MITIGATED);
        leave(before);
        assert_eq!(mxcsr(), before);
    }

    #[test]
    fn guard_follows_cpuid() {
        let before = mxcsr();
        let guard = Mcdt::enter();
        assert_eq!(guard.0.is_some(), !reports_mcdt_no());
        assert_eq!(mxcsr() == MITIGATED, !reports_mcdt_no());
        drop(guard);
        assert_eq!(mxcsr(), before);
    }
}
