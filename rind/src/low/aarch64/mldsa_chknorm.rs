// generated source. do not edit.
#![allow(non_upper_case_globals, unused_macros, unused_imports)]
use crate::low::macros::*;

// Copyright (c) The mldsa-native project authors
// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT

// ----------------------------------------------------------------------------
// Infinity-norm check of polynomial coefficients for ML-DSA
// Returns 1 if any coefficient has absolute value >= bound, 0 otherwise.
// Input a[256] (signed 32-bit words), bound (unsigned 32-bit).
//
// extern uint64_t mldsa_chknorm(const int32_t a[static 256], uint64_t bound);
//
// Standard ARM ABI: X0 = a, W1 = bound; result in W0
// ----------------------------------------------------------------------------

// Transliterated from s2n-bignum's arm/mldsa/mldsa_chknorm.S.
/// Infinity-norm check of polynomial coefficients for ML-DSA
///
/// Returns 1 if any coefficient has absolute value >= bound, 0 otherwise.
/// Input a[256] (signed 32-bit words), bound (unsigned 32-bit).
#[inline(never)]
pub(crate) fn mldsa_chknorm(a: &[i32; 256], bound: u64) -> u64 {
    let ret: u64;
    // SAFETY: inline assembly. see [crate::low::inline_assembly_safety] for safety info.
    unsafe {
        core::arch::asm!(

        Q!("    dup             " "v20.4s, w1"),
        Q!("    eor             " "v21.16b, v21.16b, v21.16b"),
        Q!("    mov             " "x2, #0x10"),

        Q!(Label!("Lmldsa_chknorm_loop", 2) ":"),
        Q!("    ldr             " "q1, [x0, #0x10]"),
        Q!("    ldr             " "q2, [x0, #0x20]"),
        Q!("    ldr             " "q3, [x0, #0x30]"),
        Q!("    ldr             " "q0, [x0], #0x40"),
        Q!("    abs             " "v1.4s, v1.4s"),
        Q!("    cmge            " "v1.4s, v1.4s, v20.4s"),
        Q!("    orr             " "v21.16b, v21.16b, v1.16b"),
        Q!("    abs             " "v2.4s, v2.4s"),
        Q!("    cmge            " "v2.4s, v2.4s, v20.4s"),
        Q!("    orr             " "v21.16b, v21.16b, v2.16b"),
        Q!("    abs             " "v3.4s, v3.4s"),
        Q!("    cmge            " "v3.4s, v3.4s, v20.4s"),
        Q!("    orr             " "v21.16b, v21.16b, v3.16b"),
        Q!("    abs             " "v0.4s, v0.4s"),
        Q!("    cmge            " "v0.4s, v0.4s, v20.4s"),
        Q!("    orr             " "v21.16b, v21.16b, v0.16b"),
        Q!("    subs            " "x2, x2, #0x1"),
        Q!("    b.ne            " Label!("Lmldsa_chknorm_loop", 2, Before)),
        Q!("    umaxv           " "s21, v21.4s"),
        Q!("    fmov            " "w0, s21"),
        Q!("    and             " "w0, w0, #0x1"),
        inout("x0") a.as_ptr() => ret,
        inout("x1") bound => _,
        // clobbers
        out("v0") _,
        out("v1") _,
        out("v2") _,
        out("v20") _,
        out("v21") _,
        out("v3") _,
        out("x2") _,
            )
    };
    ret
}

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
#[test]
fn abi() {
    crate::low::abi::call!(mldsa_chknorm, &crate::low::abi::Aligned([0; 256]).0, 0);
}
