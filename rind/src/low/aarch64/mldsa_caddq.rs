// generated source. do not edit.
#![allow(non_upper_case_globals, unused_macros, unused_imports)]
use crate::low::macros::*;

// Copyright (c) The mldsa-native project authors
// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT

// ----------------------------------------------------------------------------
// Conditional addition of q to each coefficient for ML-DSA
// For each coefficient, add Q = 8380417 if the coefficient is negative.
// Input/output a[256] (signed 32-bit words), reduced in place.
//
// extern void mldsa_caddq(int32_t a[static 256]);
//
// Standard ARM ABI: X0 = a
// ----------------------------------------------------------------------------

// Transliterated from s2n-bignum's arm/mldsa/mldsa_caddq.S.
/// Conditional addition of q to each coefficient for ML-DSA
///
/// For each coefficient, add Q = 8380417 if the coefficient is negative.
/// Input/output a[256] (signed 32-bit words), reduced in place.
#[inline(never)]
pub(crate) fn mldsa_caddq(a: &mut [i32; 256]) {
    // SAFETY: inline assembly. see [crate::low::inline_assembly_safety] for safety info.
    unsafe {
        core::arch::asm!(

        Q!("    mov             " "w9, #0xe001"),
        Q!("    movk            " "w9, #0x7f, lsl #16"),
        Q!("    dup             " "v4.4s, w9"),
        Q!("    mov             " "x1, #0x10"),

        Q!(Label!("Lmldsa_caddq_loop", 2) ":"),
        Q!("    ldr             " "q0, [x0]"),
        Q!("    ldr             " "q1, [x0, #0x10]"),
        Q!("    ldr             " "q2, [x0, #0x20]"),
        Q!("    ldr             " "q3, [x0, #0x30]"),
        Q!("    ushr            " "v5.4s, v0.4s, #0x1f"),
        Q!("    mla             " "v0.4s, v5.4s, v4.4s"),
        Q!("    ushr            " "v5.4s, v1.4s, #0x1f"),
        Q!("    mla             " "v1.4s, v5.4s, v4.4s"),
        Q!("    ushr            " "v5.4s, v2.4s, #0x1f"),
        Q!("    mla             " "v2.4s, v5.4s, v4.4s"),
        Q!("    ushr            " "v5.4s, v3.4s, #0x1f"),
        Q!("    mla             " "v3.4s, v5.4s, v4.4s"),
        Q!("    str             " "q1, [x0, #0x10]"),
        Q!("    str             " "q2, [x0, #0x20]"),
        Q!("    str             " "q3, [x0, #0x30]"),
        Q!("    str             " "q0, [x0], #0x40"),
        Q!("    subs            " "x1, x1, #0x1"),
        Q!("    b.ne            " Label!("Lmldsa_caddq_loop", 2, Before)),
        inout("x0") a.as_mut_ptr() => _,
        // clobbers
        out("v0") _,
        out("v1") _,
        out("v2") _,
        out("v3") _,
        out("v4") _,
        out("v5") _,
        out("x1") _,
        out("x9") _,
            )
    };
}

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
#[test]
fn abi() {
    crate::low::abi::call!(mldsa_caddq, &mut crate::low::abi::Aligned([0; 256]).0);
}
