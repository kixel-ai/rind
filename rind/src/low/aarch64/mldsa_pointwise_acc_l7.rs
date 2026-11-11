// generated source. do not edit.
#![allow(non_upper_case_globals, unused_macros, unused_imports)]
use crate::low::macros::*;

// Copyright (c) The mldsa-native project authors
// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT

// ----------------------------------------------------------------------------
// Pointwise multiplication and accumulation of polynomials in ML-DSA NTT
// Inputs a[1792], b[1792] (signed 32-bit words); output r[256] (signed 32-bit words)
//
// Performs pointwise multiply-accumulate of 7 polynomial pairs in NTT domain
// using Montgomery arithmetic:
//   r[i] = montgomery_reduce(sum_{k=0}^{6} a[i + 256*k] * b[i + 256*k])
// for i = 0..255
//
// The Montgomery reduction is performed with:
//   Q = 8380417 (MLDSA prime modulus)
//   QINV = 58728449 (negative inverse of Q mod 2^32)
//   R = 2^32 (Montgomery parameter)
//
// Input bounds (per coefficient, absolute value):
//   |a[i]| < Q
//   |b[i]| < 9*Q
// Output coefficients are bounded by Q in absolute value.
//
// extern void mldsa_pointwise_acc_l7
//      (int32_t r[static 256], const int32_t a[static 1792],
//       const int32_t b[static 1792]);
//
// Standard ARM ABI: X0 = r, X1 = a, X2 = b
// ----------------------------------------------------------------------------

// Transliterated from s2n-bignum's arm/mldsa/mldsa_pointwise_acc_l7.S.
/// Pointwise multiplication and accumulation of polynomials in ML-DSA NTT
///
/// Inputs a[1792], b[1792] (signed 32-bit words); output r[256] (signed 32-bit words)
///
/// Performs pointwise multiply-accumulate of 7 polynomial pairs in NTT domain
/// using Montgomery arithmetic:
///   r[i] = montgomery_reduce(sum_{k=0}^{6} a[i + 256*k] * b[i + 256*k])
/// for i = 0..255
///
/// The Montgomery reduction is performed with:
///   Q = 8380417 (MLDSA prime modulus)
///   QINV = 58728449 (negative inverse of Q mod 2^32)
///   R = 2^32 (Montgomery parameter)
///
/// Input bounds (per coefficient, absolute value):
///   |a[i]| < Q
///   |b[i]| < 9*Q
/// Output coefficients are bounded by Q in absolute value.
#[inline(never)]
pub(crate) fn mldsa_pointwise_acc_l7(c: &mut [i32; 256], a: &[[i32; 256]; 7], b: &[[i32; 256]; 7]) {
    // SAFETY: inline assembly. see [crate::low::inline_assembly_safety] for safety info.
    unsafe {
        core::arch::asm!(

        // This matches the code in the mldsa-native repository
        // https://github.com/pq-code-package/mldsa-native/blob/main/mldsa/src/native/aarch64/src/mld_polyvecl_pointwise_acc_montgomery_l7.S

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

        Q!(Label!("Lmldsa_pointwise_acc_l7_loop", 2) ":"),

        // ---- Polynomial pair 0: a[i]*b[i] (smull = initial multiply) ----
        Q!("    ldr             " "q17, [x1, #0x10]"),
        Q!("    ldr             " "q18, [x1, #0x20]"),
        Q!("    ldr             " "q19, [x1, #0x30]"),
        Q!("    ldr             " "q16, [x1], #0x40"),
        Q!("    ldr             " "q21, [x2, #0x10]"),
        Q!("    ldr             " "q22, [x2, #0x20]"),
        Q!("    ldr             " "q23, [x2, #0x30]"),
        Q!("    ldr             " "q20, [x2], #0x40"),

        Q!("    smull           " "v24.2d, v16.2s, v20.2s"),
        Q!("    smull2          " "v25.2d, v16.4s, v20.4s"),
        Q!("    smull           " "v26.2d, v17.2s, v21.2s"),
        Q!("    smull2          " "v27.2d, v17.4s, v21.4s"),
        Q!("    smull           " "v28.2d, v18.2s, v22.2s"),
        Q!("    smull2          " "v29.2d, v18.4s, v22.4s"),
        Q!("    smull           " "v30.2d, v19.2s, v23.2s"),
        Q!("    smull2          " "v31.2d, v19.4s, v23.4s"),

        // ---- Polynomial pair 1: accumulate a[i+256]*b[i+256] ----
        // Offset 0x3c0 = 1024 - 64 (since x1 already advanced by 0x40)
        Q!("    ldr             " "q16, [x1, #0x3c0]"),
        Q!("    ldr             " "q17, [x1, #0x3d0]"),
        Q!("    ldr             " "q18, [x1, #0x3e0]"),
        Q!("    ldr             " "q19, [x1, #0x3f0]"),
        Q!("    ldr             " "q20, [x2, #0x3c0]"),
        Q!("    ldr             " "q21, [x2, #0x3d0]"),
        Q!("    ldr             " "q22, [x2, #0x3e0]"),
        Q!("    ldr             " "q23, [x2, #0x3f0]"),

        Q!("    smlal           " "v24.2d, v16.2s, v20.2s"),
        Q!("    smlal2          " "v25.2d, v16.4s, v20.4s"),
        Q!("    smlal           " "v26.2d, v17.2s, v21.2s"),
        Q!("    smlal2          " "v27.2d, v17.4s, v21.4s"),
        Q!("    smlal           " "v28.2d, v18.2s, v22.2s"),
        Q!("    smlal2          " "v29.2d, v18.4s, v22.4s"),
        Q!("    smlal           " "v30.2d, v19.2s, v23.2s"),
        Q!("    smlal2          " "v31.2d, v19.4s, v23.4s"),

        // ---- Polynomial pair 2: accumulate a[i+512]*b[i+512] ----
        // Offset 0x7c0 = 2048 - 64
        Q!("    ldr             " "q16, [x1, #0x7c0]"),
        Q!("    ldr             " "q17, [x1, #0x7d0]"),
        Q!("    ldr             " "q18, [x1, #0x7e0]"),
        Q!("    ldr             " "q19, [x1, #0x7f0]"),
        Q!("    ldr             " "q20, [x2, #0x7c0]"),
        Q!("    ldr             " "q21, [x2, #0x7d0]"),
        Q!("    ldr             " "q22, [x2, #0x7e0]"),
        Q!("    ldr             " "q23, [x2, #0x7f0]"),

        Q!("    smlal           " "v24.2d, v16.2s, v20.2s"),
        Q!("    smlal2          " "v25.2d, v16.4s, v20.4s"),
        Q!("    smlal           " "v26.2d, v17.2s, v21.2s"),
        Q!("    smlal2          " "v27.2d, v17.4s, v21.4s"),
        Q!("    smlal           " "v28.2d, v18.2s, v22.2s"),
        Q!("    smlal2          " "v29.2d, v18.4s, v22.4s"),
        Q!("    smlal           " "v30.2d, v19.2s, v23.2s"),
        Q!("    smlal2          " "v31.2d, v19.4s, v23.4s"),

        // ---- Polynomial pair 3: accumulate a[i+768]*b[i+768] ----
        // Offset 0xbc0 = 3072 - 64
        Q!("    ldr             " "q16, [x1, #0xbc0]"),
        Q!("    ldr             " "q17, [x1, #0xbd0]"),
        Q!("    ldr             " "q18, [x1, #0xbe0]"),
        Q!("    ldr             " "q19, [x1, #0xbf0]"),
        Q!("    ldr             " "q20, [x2, #0xbc0]"),
        Q!("    ldr             " "q21, [x2, #0xbd0]"),
        Q!("    ldr             " "q22, [x2, #0xbe0]"),
        Q!("    ldr             " "q23, [x2, #0xbf0]"),

        Q!("    smlal           " "v24.2d, v16.2s, v20.2s"),
        Q!("    smlal2          " "v25.2d, v16.4s, v20.4s"),
        Q!("    smlal           " "v26.2d, v17.2s, v21.2s"),
        Q!("    smlal2          " "v27.2d, v17.4s, v21.4s"),
        Q!("    smlal           " "v28.2d, v18.2s, v22.2s"),
        Q!("    smlal2          " "v29.2d, v18.4s, v22.4s"),
        Q!("    smlal           " "v30.2d, v19.2s, v23.2s"),
        Q!("    smlal2          " "v31.2d, v19.4s, v23.4s"),

        // ---- Polynomial pair 4: accumulate a[i+1024]*b[i+1024] ----
        // Offset 0xfc0 = 4096 - 64
        Q!("    ldr             " "q16, [x1, #0xfc0]"),
        Q!("    ldr             " "q17, [x1, #0xfd0]"),
        Q!("    ldr             " "q18, [x1, #0xfe0]"),
        Q!("    ldr             " "q19, [x1, #0xff0]"),
        Q!("    ldr             " "q20, [x2, #0xfc0]"),
        Q!("    ldr             " "q21, [x2, #0xfd0]"),
        Q!("    ldr             " "q22, [x2, #0xfe0]"),
        Q!("    ldr             " "q23, [x2, #0xff0]"),

        Q!("    smlal           " "v24.2d, v16.2s, v20.2s"),
        Q!("    smlal2          " "v25.2d, v16.4s, v20.4s"),
        Q!("    smlal           " "v26.2d, v17.2s, v21.2s"),
        Q!("    smlal2          " "v27.2d, v17.4s, v21.4s"),
        Q!("    smlal           " "v28.2d, v18.2s, v22.2s"),
        Q!("    smlal2          " "v29.2d, v18.4s, v22.4s"),
        Q!("    smlal           " "v30.2d, v19.2s, v23.2s"),
        Q!("    smlal2          " "v31.2d, v19.4s, v23.4s"),

        // ---- Polynomial pair 5: accumulate a[i+1280]*b[i+1280] ----
        // Offset 0x13c0 = 5120 - 64
        Q!("    ldr             " "q16, [x1, #0x13c0]"),
        Q!("    ldr             " "q17, [x1, #0x13d0]"),
        Q!("    ldr             " "q18, [x1, #0x13e0]"),
        Q!("    ldr             " "q19, [x1, #0x13f0]"),
        Q!("    ldr             " "q20, [x2, #0x13c0]"),
        Q!("    ldr             " "q21, [x2, #0x13d0]"),
        Q!("    ldr             " "q22, [x2, #0x13e0]"),
        Q!("    ldr             " "q23, [x2, #0x13f0]"),

        Q!("    smlal           " "v24.2d, v16.2s, v20.2s"),
        Q!("    smlal2          " "v25.2d, v16.4s, v20.4s"),
        Q!("    smlal           " "v26.2d, v17.2s, v21.2s"),
        Q!("    smlal2          " "v27.2d, v17.4s, v21.4s"),
        Q!("    smlal           " "v28.2d, v18.2s, v22.2s"),
        Q!("    smlal2          " "v29.2d, v18.4s, v22.4s"),
        Q!("    smlal           " "v30.2d, v19.2s, v23.2s"),
        Q!("    smlal2          " "v31.2d, v19.4s, v23.4s"),

        // ---- Polynomial pair 6: accumulate a[i+1536]*b[i+1536] ----
        // Offset 0x17c0 = 6144 - 64
        Q!("    ldr             " "q16, [x1, #0x17c0]"),
        Q!("    ldr             " "q17, [x1, #0x17d0]"),
        Q!("    ldr             " "q18, [x1, #0x17e0]"),
        Q!("    ldr             " "q19, [x1, #0x17f0]"),
        Q!("    ldr             " "q20, [x2, #0x17c0]"),
        Q!("    ldr             " "q21, [x2, #0x17d0]"),
        Q!("    ldr             " "q22, [x2, #0x17e0]"),
        Q!("    ldr             " "q23, [x2, #0x17f0]"),

        Q!("    smlal           " "v24.2d, v16.2s, v20.2s"),
        Q!("    smlal2          " "v25.2d, v16.4s, v20.4s"),
        Q!("    smlal           " "v26.2d, v17.2s, v21.2s"),
        Q!("    smlal2          " "v27.2d, v17.4s, v21.4s"),
        Q!("    smlal           " "v28.2d, v18.2s, v22.2s"),
        Q!("    smlal2          " "v29.2d, v18.4s, v22.4s"),
        Q!("    smlal           " "v30.2d, v19.2s, v23.2s"),
        Q!("    smlal2          " "v31.2d, v19.4s, v23.4s"),

        // ---- Montgomery reduction ----
        // For each group: extract low 32 bits, multiply by QINV,
        // subtract (low * QINV) * Q from 64-bit accumulator,
        // extract upper 32 bits as result

        // Montgomery reduction for v24-v25 -> v16
        Q!("    uzp1            " "v16.4s, v24.4s, v25.4s"),
        Q!("    mul             " "v16.4s, v16.4s, v1.4s"),
        Q!("    smlsl           " "v24.2d, v16.2s, v0.2s"),
        Q!("    smlsl2          " "v25.2d, v16.4s, v0.4s"),
        Q!("    uzp2            " "v16.4s, v24.4s, v25.4s"),

        // Montgomery reduction for v26-v27 -> v17
        Q!("    uzp1            " "v17.4s, v26.4s, v27.4s"),
        Q!("    mul             " "v17.4s, v17.4s, v1.4s"),
        Q!("    smlsl           " "v26.2d, v17.2s, v0.2s"),
        Q!("    smlsl2          " "v27.2d, v17.4s, v0.4s"),
        Q!("    uzp2            " "v17.4s, v26.4s, v27.4s"),

        // Montgomery reduction for v28-v29 -> v18
        Q!("    uzp1            " "v18.4s, v28.4s, v29.4s"),
        Q!("    mul             " "v18.4s, v18.4s, v1.4s"),
        Q!("    smlsl           " "v28.2d, v18.2s, v0.2s"),
        Q!("    smlsl2          " "v29.2d, v18.4s, v0.4s"),
        Q!("    uzp2            " "v18.4s, v28.4s, v29.4s"),

        // Montgomery reduction for v30-v31 -> v19
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
        Q!("    cbnz            " "x3, " Label!("Lmldsa_pointwise_acc_l7_loop", 2, Before)),

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
        mldsa_pointwise_acc_l7,
        &mut crate::low::abi::Aligned([0; 256]).0,
        &crate::low::abi::Aligned([[0; 256]; 7]).0,
        &crate::low::abi::Aligned([[0; 256]; 7]).0
    );
}
