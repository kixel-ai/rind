// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

use core::fmt;
use core::marker::PhantomData;

use crate::ffi;

/// A CPU feature the module requires that this CPU lacks.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct MissingFeature(&'static str);

impl fmt::Display for MissingFeature {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "rind requires {} CPU support on {}",
            self.0,
            std::env::consts::ARCH
        )
    }
}

impl core::error::Error for MissingFeature {}

/// Checks that this CPU has every feature the module requires, naming the
/// first one missing.
///
/// The module checks as it loads, and aborts naming the feature, so a
/// running program has passed already.
pub fn check() -> Result<(), MissingFeature> {
    let mut len = 0;
    // SAFETY: `len` is writable.
    let name = unsafe { ffi::rind_fips_cpu_check(&mut len) };
    if name.is_null() {
        return Ok(());
    }
    // SAFETY: the module's name for the feature, `len` bytes that live as
    // long as the module, which is never unloaded.
    let name = unsafe { core::slice::from_raw_parts(name, len) };
    Err(MissingFeature(
        core::str::from_utf8(name).expect("the module's feature names are UTF-8"),
    ))
}

/// Reports whether the module runs AES on CPU instructions, as aws-lc's
/// `EVP_has_aes_hardware` does: it always does, since it requires them.
#[must_use]
pub fn has_aes_hardware() -> bool {
    // SAFETY: no arguments.
    unsafe { ffi::rind_fips_has_aes_hardware() }
}

/// Holds data-independent timing (DIT) on for this thread until dropped.
///
/// The module sets DIT around each call on an aarch64 CPU that has it, as
/// `rind::cpu::Dit` describes, and the guard holds it across a batch of
/// calls; on x86_64 it does nothing.
///
/// ```compile_fail,E0277
/// let dit = rind_fips::cpu::Dit::hold();
/// std::thread::spawn(move || drop(dit));
/// ```
#[must_use = "DIT turns back off when the guard drops"]
#[derive(Debug)]
pub struct Dit {
    // Neither `Send` nor `Sync`: the module counts holds per thread.
    _thread: PhantomData<*const ()>,
}

impl Dit {
    /// Turns DIT on for this thread, if rind sets it here, until the guard drops.
    pub fn hold() -> Self {
        // SAFETY: no arguments.
        unsafe { ffi::rind_fips_dit_hold() };
        Self {
            _thread: PhantomData,
        }
    }
}

impl Drop for Dit {
    fn drop(&mut self) {
        // SAFETY: this guard's hold, on the thread that made it.
        unsafe { ffi::rind_fips_dit_release() };
    }
}

#[cfg(all(test, target_arch = "aarch64"))]
mod tests {
    /// PSTATE.DIT, which only a core with DIT may read.
    fn dit() -> bool {
        let pstate: u64;
        // SAFETY: the caller checked that the core has DIT.
        unsafe { core::arch::asm!("mrs {}, S3_3_C4_C2_5", out(reg) pstate) };
        pstate & (1 << 24) != 0
    }

    // The module holds DIT until the last of this thread's guards drops, in
    // whatever order.
    #[test]
    fn dit_hold_holds_dit() {
        if !std::arch::is_aarch64_feature_detected!("dit") {
            drop(super::Dit::hold());
            return;
        }
        assert!(!dit());
        let first = super::Dit::hold();
        let second = super::Dit::hold();
        assert!(dit());
        drop(first);
        assert!(dit());
        drop(second);
        assert!(!dit());
    }
}
