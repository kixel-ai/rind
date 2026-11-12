// generated source. do not edit.
#![allow(non_upper_case_globals, unused_macros, unused_imports)]
use crate::low::macros::*;

// Copyright (c) The mldsa-native project authors
// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT

// ----------------------------------------------------------------------------
// Coefficient decomposition for ML-DSA (parameter sets 65 and 87, GAMMA2 = (Q-1)/32)
// For each coefficient a in [0,Q), computes (a1, a0) with a = a1*2*GAMMA2 + a0.
// Input a[256] (signed 32-bit words); outputs r1[256] (high parts) and, in
// place of a, the low parts a0.
//
// extern void mldsa_decompose_32(int32_t a1[static 256], int32_t a0[static 256]);
//
// Standard ARM ABI: X0 = r1, X1 = a
// ----------------------------------------------------------------------------

// Transliterated from s2n-bignum's arm/mldsa/mldsa_decompose_32.S.
/// Coefficient decomposition for ML-DSA (parameter sets 65 and 87, GAMMA2 = (Q-1)/32)
///
/// For each coefficient a in [0,Q), computes (a1, a0) with a = a1*2*GAMMA2 + a0.
/// Input a[256] (signed 32-bit words); outputs r1[256] (high parts) and, in
/// place of a, the low parts a0.
#[inline(never)]
pub(crate) fn mldsa_decompose_32(a1: &mut [i32; 256], a0: &mut [i32; 256]) {
    // SAFETY: inline assembly. see [crate::low::inline_assembly_safety] for safety info.
    unsafe {
        core::arch::asm!(

        Q!("    mov             " "w4, #0xe001"),
        Q!("    movk            " "w4, #0x7f, lsl #16"),
        Q!("    dup             " "v20.4s, w4"),
        Q!("    mov             " "w5, #0xe100"),
        Q!("    movk            " "w5, #0x7b, lsl #16"),
        Q!("    dup             " "v21.4s, w5"),
        Q!("    mov             " "w7, #0xfe00"),
        Q!("    movk            " "w7, #0x7, lsl #16"),
        Q!("    dup             " "v22.4s, w7"),
        Q!("    mov             " "w11, #0x401"),
        Q!("    movk            " "w11, #0x4010, lsl #16"),
        Q!("    dup             " "v23.4s, w11"),
        Q!("    mov             " "x3, #0x10"),

        Q!(Label!("Lmldsa_decompose_32_loop", 2) ":"),
        Q!("    ldr             " "q0, [x1]"),
        Q!("    ldr             " "q1, [x1, #0x10]"),
        Q!("    ldr             " "q2, [x1, #0x20]"),
        Q!("    ldr             " "q3, [x1, #0x30]"),
        Q!("    sqdmulh         " "v5.4s, v1.4s, v23.4s"),
        Q!("    srshr           " "v5.4s, v5.4s, #0x12"),
        Q!("    cmgt            " "v24.4s, v1.4s, v21.4s"),
        Q!("    mls             " "v1.4s, v5.4s, v22.4s"),
        Q!("    bic             " "v5.16b, v5.16b, v24.16b"),
        Q!("    add             " "v1.4s, v1.4s, v24.4s"),
        Q!("    sqdmulh         " "v6.4s, v2.4s, v23.4s"),
        Q!("    srshr           " "v6.4s, v6.4s, #0x12"),
        Q!("    cmgt            " "v24.4s, v2.4s, v21.4s"),
        Q!("    mls             " "v2.4s, v6.4s, v22.4s"),
        Q!("    bic             " "v6.16b, v6.16b, v24.16b"),
        Q!("    add             " "v2.4s, v2.4s, v24.4s"),
        Q!("    sqdmulh         " "v7.4s, v3.4s, v23.4s"),
        Q!("    srshr           " "v7.4s, v7.4s, #0x12"),
        Q!("    cmgt            " "v24.4s, v3.4s, v21.4s"),
        Q!("    mls             " "v3.4s, v7.4s, v22.4s"),
        Q!("    bic             " "v7.16b, v7.16b, v24.16b"),
        Q!("    add             " "v3.4s, v3.4s, v24.4s"),
        Q!("    sqdmulh         " "v4.4s, v0.4s, v23.4s"),
        Q!("    srshr           " "v4.4s, v4.4s, #0x12"),
        Q!("    cmgt            " "v24.4s, v0.4s, v21.4s"),
        Q!("    mls             " "v0.4s, v4.4s, v22.4s"),
        Q!("    bic             " "v4.16b, v4.16b, v24.16b"),
        Q!("    add             " "v0.4s, v0.4s, v24.4s"),
        Q!("    str             " "q5, [x0, #0x10]"),
        Q!("    str             " "q6, [x0, #0x20]"),
        Q!("    str             " "q7, [x0, #0x30]"),
        Q!("    str             " "q4, [x0], #0x40"),
        Q!("    str             " "q1, [x1, #0x10]"),
        Q!("    str             " "q2, [x1, #0x20]"),
        Q!("    str             " "q3, [x1, #0x30]"),
        Q!("    str             " "q0, [x1], #0x40"),
        Q!("    subs            " "x3, x3, #0x1"),
        Q!("    b.ne            " Label!("Lmldsa_decompose_32_loop", 2, Before)),
        inout("x0") a1.as_mut_ptr() => _,
        inout("x1") a0.as_mut_ptr() => _,
        // clobbers
        out("v0") _,
        out("v1") _,
        out("v2") _,
        out("v20") _,
        out("v21") _,
        out("v22") _,
        out("v23") _,
        out("v24") _,
        out("v3") _,
        out("v4") _,
        out("v5") _,
        out("v6") _,
        out("v7") _,
        out("x11") _,
        out("x3") _,
        out("x4") _,
        out("x5") _,
        out("x7") _,
            )
    };
}

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
#[test]
fn abi() {
    crate::low::abi::call!(
        mldsa_decompose_32,
        &mut crate::low::abi::Aligned([0; 256]).0,
        &mut crate::low::abi::Aligned([0; 256]).0
    );
}
