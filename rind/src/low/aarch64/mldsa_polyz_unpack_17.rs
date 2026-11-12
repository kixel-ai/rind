// generated source. do not edit.
#![allow(non_upper_case_globals, unused_macros, unused_imports)]
use crate::low::macros::*;

// Copyright (c) The mldsa-native project authors
// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT

// ----------------------------------------------------------------------------
// Unpack the packed z polynomial for ML-DSA (GAMMA1 = 2^17, parameter set 44)
// Reads 18-bit packed coefficients from the byte buffer b and produces
// r[256] = GAMMA1 - coeff (signed 32-bit words), using the shuffle table t.
//
// extern void mldsa_polyz_unpack_17_arm(int32_t r[static 256], const uint8_t b[static 576], const uint8_t t[static 64]);
//
// Standard ARM ABI: X0 = r, X1 = b, X2 = t
// ----------------------------------------------------------------------------

// Transliterated from s2n-bignum's arm/mldsa/mldsa_polyz_unpack_17.S.
/// Unpack the packed z polynomial for ML-DSA (GAMMA1 = 2^17, parameter set 44)
///
/// Reads 18-bit packed coefficients from the byte buffer b and produces
/// r[256] = GAMMA1 - coeff (signed 32-bit words), using the shuffle table t.
#[inline(never)]
pub(crate) fn mldsa_polyz_unpack_17(r: &mut [i32; 256], b: &[u8; 576], t: &[u8; 64]) {
    // SAFETY: inline assembly. see [crate::low::inline_assembly_safety] for safety info.
    unsafe {
        core::arch::asm!(

        Q!("    ldr             " "q24, [x2]"),
        Q!("    ldr             " "q25, [x2, #0x10]"),
        Q!("    ldr             " "q26, [x2, #0x20]"),
        Q!("    ldr             " "q27, [x2, #0x30]"),
        Q!("    mov             " "x3, #0xfe00000000"),
        Q!("    mov             " "v28.d[0], x3"),
        Q!("    mov             " "x3, #0xfc"),
        Q!("    movk            " "x3, #0xfa, lsl #32"),
        Q!("    mov             " "v28.d[1], x3"),
        Q!("    movi            " "v29.4s, #0x3, msl #16"),
        Q!("    movi            " "v30.4s, #0x2, lsl #16"),
        Q!("    mov             " "x9, #0x10"),

        Q!(Label!("Lmldsa_polyz_unpack_17_loop", 2) ":"),
        Q!("    ld1             " "{{ v0.16b, v1.16b }}, [x1]"),
        Q!("    add             " "x1, x1, #0x14"),
        Q!("    ld1             " "{{ v2.16b }}, [x1], #16"),
        Q!("    tbl             " "v4.16b, {{ v0.16b }}, v24.16b"),
        Q!("    tbl             " "v5.16b, {{ v0.16b, v1.16b }}, v25.16b"),
        Q!("    tbl             " "v6.16b, {{ v1.16b }}, v26.16b"),
        Q!("    tbl             " "v7.16b, {{ v1.16b, v2.16b }}, v27.16b"),
        Q!("    ushl            " "v4.4s, v4.4s, v28.4s"),
        Q!("    and             " "v4.16b, v4.16b, v29.16b"),
        Q!("    sub             " "v4.4s, v30.4s, v4.4s"),
        Q!("    ushl            " "v5.4s, v5.4s, v28.4s"),
        Q!("    and             " "v5.16b, v5.16b, v29.16b"),
        Q!("    sub             " "v5.4s, v30.4s, v5.4s"),
        Q!("    ushl            " "v6.4s, v6.4s, v28.4s"),
        Q!("    and             " "v6.16b, v6.16b, v29.16b"),
        Q!("    sub             " "v6.4s, v30.4s, v6.4s"),
        Q!("    ushl            " "v7.4s, v7.4s, v28.4s"),
        Q!("    and             " "v7.16b, v7.16b, v29.16b"),
        Q!("    sub             " "v7.4s, v30.4s, v7.4s"),
        Q!("    str             " "q5, [x0, #0x10]"),
        Q!("    str             " "q6, [x0, #0x20]"),
        Q!("    str             " "q7, [x0, #0x30]"),
        Q!("    str             " "q4, [x0], #0x40"),
        Q!("    subs            " "x9, x9, #0x1"),
        Q!("    b.ne            " Label!("Lmldsa_polyz_unpack_17_loop", 2, Before)),
        inout("x0") r.as_mut_ptr() => _,
        inout("x1") b.as_ptr() => _,
        inout("x2") t.as_ptr() => _,
        // clobbers
        out("v0") _,
        out("v1") _,
        out("v2") _,
        out("v24") _,
        out("v25") _,
        out("v26") _,
        out("v27") _,
        out("v28") _,
        out("v29") _,
        out("v30") _,
        out("v4") _,
        out("v5") _,
        out("v6") _,
        out("v7") _,
        out("x3") _,
        out("x9") _,
            )
    };
}

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
#[test]
fn abi() {
    crate::low::abi::call!(
        mldsa_polyz_unpack_17,
        &mut crate::low::abi::Aligned([0; 256]).0,
        &crate::low::abi::Aligned([0; 576]).0,
        &crate::low::abi::Aligned([0; 64]).0
    );
}
