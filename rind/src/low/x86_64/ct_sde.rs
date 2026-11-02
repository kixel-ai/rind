// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! The constant-time check for code valgrind cannot run, such as AVX-512:
//! `admin/ct-sde` runs each test named `ct_sde` twice under Intel SDE, with
//! a different [`seed`] each time, and compares the addresses of every
//! instruction and memory access in the [`traced`] region.

/// The seed `admin/ct-sde` sets for this run, from which the test derives
/// every secret it passes to the traced code.
pub(crate) fn seed() -> u64 {
    let seed = std::env::var("RIND_CT_SDE_SEED").expect("run by admin/ct-sde");
    u64::from_str_radix(&seed, 16).unwrap()
}

/// Runs `f` between the SSC marks that start and stop SDE's trace.
pub(crate) fn traced<T>(f: impl FnOnce() -> T) -> T {
    mark::<0x5243_0001>();
    let r = core::hint::black_box(f());
    mark::<0x5243_0002>();
    r
}

/// SDE's SSC mark `M`, which runs as a no-op elsewhere. It clobbers `ebx`,
/// which Rust reserves, so this saves `rbx` around it.
#[inline(always)]
fn mark<const M: u32>() {
    // SAFETY: restores `rbx`, and touches no memory.
    unsafe {
        core::arch::asm!(
            "mov {saved}, rbx",
            "mov ebx, {m}",
            ".byte 0x64, 0x67, 0x90",
            "mov rbx, {saved}",
            saved = out(reg) _,
            m = const M,
            options(nostack, preserves_flags),
        )
    };
}

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
mod tests {
    use super::*;

    // `admin/ct-sde` requires these to differ between seeds, so that a
    // harness that traces nothing, or strips the addresses it compares,
    // fails.

    #[test]
    #[ignore = "admin/ct-sde runs it under Intel SDE"]
    fn ct_sde_planted_branch() {
        let secret = core::hint::black_box(seed());
        traced(|| {
            if secret & 1 == 1 {
                core::hint::black_box(0);
            }
        });
    }

    #[test]
    #[ignore = "admin/ct-sde runs it under Intel SDE"]
    fn ct_sde_planted_index() {
        let secret = core::hint::black_box(seed());
        let table = core::hint::black_box([0u8; 64]);
        traced(|| core::hint::black_box(&table)[secret as usize % 64]);
    }
}
