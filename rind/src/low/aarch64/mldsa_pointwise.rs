// generated source. do not edit.
#![allow(non_upper_case_globals, unused_macros, unused_imports)]
use crate::low::macros::*;

// Copyright (c) The mldsa-native project authors
// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT

// ----------------------------------------------------------------------------
// Pointwise multiplication of polynomials in NTT domain (Montgomery form)
// Inputs a[256], b[256] (signed 32-bit words); output r[256] (signed 32-bit words)
//
// Performs pointwise multiplication of two polynomials in NTT domain using
// Montgomery arithmetic. The polynomials are represented as arrays of 256
// signed 32-bit coefficients.
//
// This computes r[i] = montgomery_reduce(a[i] * b[i]) for i = 0..255
//
// The Montgomery reduction is performed with:
//   Q = 8380417 (MLDSA prime modulus)
//   QINV = 58728449 (negative inverse of Q mod 2^32)
//   R = 2^32 (Montgomery parameter)
//
// extern void mldsa_pointwise
//      (int32_t r[static 256], const int32_t a[static 256],
//       const int32_t b[static 256]);
//
// Standard ARM ABI: X0 = r, X1 = a, X2 = b
// ----------------------------------------------------------------------------

// Transliterated from s2n-bignum's arm/mldsa/mldsa_pointwise.S.
/// Pointwise multiplication of polynomials in NTT domain (Montgomery form)
///
/// Inputs a[256], b[256] (signed 32-bit words); output r[256] (signed 32-bit words)
///
/// Performs pointwise multiplication of two polynomials in NTT domain using
/// Montgomery arithmetic. The polynomials are represented as arrays of 256
/// signed 32-bit coefficients.
///
/// This computes r[i] = montgomery_reduce(a[i] * b[i]) for i = 0..255
///
/// The Montgomery reduction is performed with:
///   Q = 8380417 (MLDSA prime modulus)
///   QINV = 58728449 (negative inverse of Q mod 2^32)
///   R = 2^32 (Montgomery parameter)
#[inline(never)]
pub(crate) fn mldsa_pointwise(c: &mut [i32; 256], a: &[i32; 256], b: &[i32; 256]) {
    // SAFETY: inline assembly. see [crate::low::inline_assembly_safety] for safety info.
    unsafe {
        core::arch::asm!(

        // This matches the code in the mldsa-native repository
        // https://github.com/pq-code-package/mldsa-native/blob/main/mldsa/src/native/aarch64/src/pointwise_montgomery.S

        // Load Q = 8380417 = 0x7fe001 into v0.4s
        // This is the MLDSA prime modulus
        Q!("    mov             " "w3, #0xe001"),
        Q!("    movk            " "w3, #0x7f, lsl #16"),
        Q!("    dup             " "v0.4s, w3"),

        // Load QINV = 58728449 = 0x3802001 into v1.4s
        // This is the negative inverse of Q modulo 2^32
        Q!("    mov             " "w3, #0x2001"),
        Q!("    movk            " "w3, #0x380, lsl #16"),
        Q!("    dup             " "v1.4s, w3"),

        // Loop counter: 64 iterations, processing 4 coefficients per iteration
        // 64 * 4 = 256 total coefficients
        Q!("    mov             " "x3, #0x40"),

        Q!(Label!("Lmldsa_pointwise_loop", 2) ":"),
        // Load 16 coefficients (4 vectors of 4 int32s) from a
        Q!("    ldr             " "q17, [x1, #0x10]"),
        Q!("    ldr             " "q18, [x1, #0x20]"),
        Q!("    ldr             " "q19, [x1, #0x30]"),
        Q!("    ldr             " "q16, [x1], #0x40"),

        // Load 16 coefficients (4 vectors of 4 int32s) from b
        Q!("    ldr             " "q21, [x2, #0x10]"),
        Q!("    ldr             " "q22, [x2, #0x20]"),
        Q!("    ldr             " "q23, [x2, #0x30]"),
        Q!("    ldr             " "q20, [x2], #0x40"),

        // Multiply a[i] * b[i] to get 64-bit products
        // smull extends 32-bit to 64-bit signed multiply (lower half)
        // smull2 extends 32-bit to 64-bit signed multiply (upper half)
        Q!("    smull           " "v24.2d, v16.2s, v20.2s"),
        Q!("    smull2          " "v25.2d, v16.4s, v20.4s"),
        Q!("    smull           " "v26.2d, v17.2s, v21.2s"),
        Q!("    smull2          " "v27.2d, v17.4s, v21.4s"),
        Q!("    smull           " "v28.2d, v18.2s, v22.2s"),
        Q!("    smull2          " "v29.2d, v18.4s, v22.4s"),
        Q!("    smull           " "v30.2d, v19.2s, v23.2s"),
        Q!("    smull2          " "v31.2d, v19.4s, v23.4s"),

        // Montgomery reduction for v16/v24-v25
        // Extract lower 32 bits, multiply by QINV
        Q!("    uzp1            " "v16.4s, v24.4s, v25.4s"),
        Q!("    mul             " "v16.4s, v16.4s, v1.4s"),
        // Subtract (lower_bits * QINV) * Q from 64-bit product
        Q!("    smlsl           " "v24.2d, v16.2s, v0.2s"),
        Q!("    smlsl2          " "v25.2d, v16.4s, v0.4s"),
        // Extract upper 32 bits (the reduced result)
        Q!("    uzp2            " "v16.4s, v24.4s, v25.4s"),

        // Montgomery reduction for v17/v26-v27
        Q!("    uzp1            " "v17.4s, v26.4s, v27.4s"),
        Q!("    mul             " "v17.4s, v17.4s, v1.4s"),
        Q!("    smlsl           " "v26.2d, v17.2s, v0.2s"),
        Q!("    smlsl2          " "v27.2d, v17.4s, v0.4s"),
        Q!("    uzp2            " "v17.4s, v26.4s, v27.4s"),

        // Montgomery reduction for v18/v28-v29
        Q!("    uzp1            " "v18.4s, v28.4s, v29.4s"),
        Q!("    mul             " "v18.4s, v18.4s, v1.4s"),
        Q!("    smlsl           " "v28.2d, v18.2s, v0.2s"),
        Q!("    smlsl2          " "v29.2d, v18.4s, v0.4s"),
        Q!("    uzp2            " "v18.4s, v28.4s, v29.4s"),

        // Montgomery reduction for v19/v30-v31
        Q!("    uzp1            " "v19.4s, v30.4s, v31.4s"),
        Q!("    mul             " "v19.4s, v19.4s, v1.4s"),
        Q!("    smlsl           " "v30.2d, v19.2s, v0.2s"),
        Q!("    smlsl2          " "v31.2d, v19.4s, v0.4s"),
        Q!("    uzp2            " "v19.4s, v30.4s, v31.4s"),

        // Store 16 reduced coefficients to output
        Q!("    str             " "q17, [x0, #0x10]"),
        Q!("    str             " "q18, [x0, #0x20]"),
        Q!("    str             " "q19, [x0, #0x30]"),
        Q!("    str             " "q16, [x0], #0x40"),

        // Decrement loop counter and continue if not zero
        Q!("    subs            " "x3, x3, #0x4"),
        Q!("    cbnz            " "x3, " Label!("Lmldsa_pointwise_loop", 2, Before)),

        inout("x0") c.as_mut_ptr() => _,
        inout("x1") a.as_ptr() => _,
        inout("x2") b.as_ptr() => _,
        // clobbers
        out("v0") _,
        out("v1") _,
        out("v16") _,
        out("v17") _,
        out("v18") _,
        out("v19") _,
        out("v20") _,
        out("v21") _,
        out("v22") _,
        out("v23") _,
        out("v24") _,
        out("v25") _,
        out("v26") _,
        out("v27") _,
        out("v28") _,
        out("v29") _,
        out("v30") _,
        out("v31") _,
        out("x3") _,
            )
    };
}

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
#[test]
fn abi() {
    crate::low::abi::call!(
        mldsa_pointwise,
        &mut crate::low::abi::Aligned([0; 256]).0,
        &crate::low::abi::Aligned([0; 256]).0,
        &crate::low::abi::Aligned([0; 256]).0
    );
}
