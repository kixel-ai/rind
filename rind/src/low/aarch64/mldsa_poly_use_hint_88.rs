// generated source. do not edit.
#![allow(non_upper_case_globals, unused_macros, unused_imports)]
use crate::low::macros::*;

// Copyright (c) The mldsa-native project authors
// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT

// ----------------------------------------------------------------------------
// Use hint to correct high bits of decomposition (parameter set 44)
// Inputs a[256] (unsigned 32-bit, in [0,Q)), h[256] (hint bits, 0 or 1)
// Output b[256] (unsigned 32-bit, in [0,44))
//
// Implements mld_use_hint for ML-DSA parameter set 44:
//   GAMMA2 = (Q-1)/88 = 95232
//   2*GAMMA2 = 190464
//   Output range: [0, 43]
//
// Algorithm per coefficient:
//   1. Decompose: a1 = round_down(a / 190464), a0 = a - a1*190464
//      If a > 87*GAMMA2 = 8285184, wrap: a1=0, a0=a-Q
//   2. delta = (a0 <= 0) ? -1 : 1
//   3. b = min((a1 + delta * h) & ~mask_gt_43, 43)
//      where mask_gt_43 clears values > 43 and umin clamps to 43
//
// extern void mldsa_poly_use_hint_88
//      (int32_t b[static 256], const int32_t a[static 256],
//       const int32_t h[static 256]);
//
// Standard ARM ABI: X0 = b, X1 = a, X2 = h
// ----------------------------------------------------------------------------

// Transliterated from s2n-bignum's arm/mldsa/mldsa_poly_use_hint_88.S.
/// Use hint to correct high bits of decomposition (parameter set 44)
///
/// Inputs a[256] (unsigned 32-bit, in [0,Q)), h[256] (hint bits, 0 or 1)
/// Output b[256] (unsigned 32-bit, in [0,44))
///
/// Implements mld_use_hint for ML-DSA parameter set 44:
///   GAMMA2 = (Q-1)/88 = 95232
///   2*GAMMA2 = 190464
///   Output range: [0, 43]
///
/// Algorithm per coefficient:
///   1. Decompose: a1 = round_down(a / 190464), a0 = a - a1*190464
///      If a > 87*GAMMA2 = 8285184, wrap: a1=0, a0=a-Q
///   2. delta = (a0 <= 0) ? -1 : 1
///   3. b = min((a1 + delta * h) & ~mask_gt_43, 43)
///      where mask_gt_43 clears values > 43 and umin clamps to 43
#[inline(never)]
pub(crate) fn mldsa_poly_use_hint_88(b: &mut [i32; 256], a: &[i32; 256], h: &[i32; 256]) {
    // SAFETY: inline assembly. see [crate::low::inline_assembly_safety] for safety info.
    unsafe {
        core::arch::asm!(

        // This matches the code in the mldsa-native repository
        // https://github.com/pq-code-package/mldsa-native/blob/main/mldsa/src/native/aarch64/src/poly_use_hint_88_aarch64_asm.S

        // Load constants into SIMD registers

        // v20 = Q = 8380417 = 0x7fe001
        Q!("    mov             " "w4, #0xe001"),
        Q!("    movk            " "w4, #0x7f, lsl #16"),
        Q!("    dup             " "v20.4s, w4"),

        // v21 = 87*GAMMA2 = 8285184 = 0x7e6c00 (wraparound threshold)
        Q!("    mov             " "w5, #0x6c00"),
        Q!("    movk            " "w5, #0x7e, lsl #16"),
        Q!("    dup             " "v21.4s, w5"),

        // v22 = 2*GAMMA2 = 190464 = 0x2e800 (decompose multiplier)
        Q!("    mov             " "w7, #0xe800"),
        Q!("    movk            " "w7, #0x2, lsl #16"),
        Q!("    dup             " "v22.4s, w7"),

        // v23 = Barrett constant = 0x58160581 = 1477837185
        // Used for SQDMULH-based Barrett reduction: a1 ~= (2*a*c) >> 48
        Q!("    mov             " "w11, #0x0581"),
        Q!("    movk            " "w11, #0x5816, lsl #16"),
        Q!("    dup             " "v23.4s, w11"),

        // v24 = 43 = 0x0000002b (for clamping with umin)
        Q!("    movi            " "v24.4s, #0x2b"),

        // Loop counter: 16 iterations, processing 16 coefficients per iteration
        // 16 * 16 = 256 total coefficients
        Q!("    mov             " "x3, #0x10"),

        Q!(Label!("Lmldsa_poly_use_hint_88_loop", 2) ":"),
        // Load 16 coefficients from a (4 vectors of 4 int32s)
        Q!("    ldr             " "q1, [x1, #0x10]"),
        Q!("    ldr             " "q2, [x1, #0x20]"),
        Q!("    ldr             " "q3, [x1, #0x30]"),
        Q!("    ldr             " "q0, [x1], #0x40"),

        // Load 16 hint bits from h (4 vectors of 4 int32s)
        Q!("    ldr             " "q5, [x2, #0x10]"),
        Q!("    ldr             " "q6, [x2, #0x20]"),
        Q!("    ldr             " "q7, [x2, #0x30]"),
        Q!("    ldr             " "q4, [x2], #0x40"),

        // --- Process v1 (coefficients at offset +16) ---
        // Decompose: a1 = sqdmulh(a, barrett_const) >> 17
        Q!("    sqdmulh         " "v17.4s, v1.4s, v23.4s"),
        Q!("    srshr           " "v17.4s, v17.4s, #0x11"),
        // Check wraparound: mask = (a > 87*GAMMA2) ? all_ones : 0
        Q!("    cmgt            " "v25.4s, v1.4s, v21.4s"),
        // a0 = a - a1 * 2*GAMMA2
        Q!("    mls             " "v1.4s, v17.4s, v22.4s"),
        // If wraparound: a1 = 0 (clear a1 where mask is set)
        Q!("    bic             " "v17.16b, v17.16b, v25.16b"),
        // If wraparound: a0 -= 1 (add all_ones = -1)
        Q!("    add             " "v1.4s, v1.4s, v25.4s"),
        // delta = (a0 <= 0) ? all_ones : 0
        Q!("    cmle            " "v1.4s, v1.4s, #0"),
        // delta = (a0 <= 0) ? -1 : 1 (set bit 0)
        Q!("    orr             " "v1.4s, #0x1"),
        // b = a1 + delta * hint
        Q!("    mla             " "v17.4s, v1.4s, v5.4s"),
        // Clamp to [0, 43]: clear if > 43, then min with 43
        Q!("    cmgt            " "v25.4s, v17.4s, v24.4s"),
        Q!("    bic             " "v17.16b, v17.16b, v25.16b"),
        Q!("    umin            " "v17.4s, v17.4s, v24.4s"),

        // --- Process v2 (coefficients at offset +32) ---
        Q!("    sqdmulh         " "v18.4s, v2.4s, v23.4s"),
        Q!("    srshr           " "v18.4s, v18.4s, #0x11"),
        Q!("    cmgt            " "v25.4s, v2.4s, v21.4s"),
        Q!("    mls             " "v2.4s, v18.4s, v22.4s"),
        Q!("    bic             " "v18.16b, v18.16b, v25.16b"),
        Q!("    add             " "v2.4s, v2.4s, v25.4s"),
        Q!("    cmle            " "v2.4s, v2.4s, #0"),
        Q!("    orr             " "v2.4s, #0x1"),
        Q!("    mla             " "v18.4s, v2.4s, v6.4s"),
        Q!("    cmgt            " "v25.4s, v18.4s, v24.4s"),
        Q!("    bic             " "v18.16b, v18.16b, v25.16b"),
        Q!("    umin            " "v18.4s, v18.4s, v24.4s"),

        // --- Process v3 (coefficients at offset +48) ---
        Q!("    sqdmulh         " "v19.4s, v3.4s, v23.4s"),
        Q!("    srshr           " "v19.4s, v19.4s, #0x11"),
        Q!("    cmgt            " "v25.4s, v3.4s, v21.4s"),
        Q!("    mls             " "v3.4s, v19.4s, v22.4s"),
        Q!("    bic             " "v19.16b, v19.16b, v25.16b"),
        Q!("    add             " "v3.4s, v3.4s, v25.4s"),
        Q!("    cmle            " "v3.4s, v3.4s, #0"),
        Q!("    orr             " "v3.4s, #0x1"),
        Q!("    mla             " "v19.4s, v3.4s, v7.4s"),
        Q!("    cmgt            " "v25.4s, v19.4s, v24.4s"),
        Q!("    bic             " "v19.16b, v19.16b, v25.16b"),
        Q!("    umin            " "v19.4s, v19.4s, v24.4s"),

        // --- Process v0 (coefficients at offset +0, loaded last for post-increment) ---
        Q!("    sqdmulh         " "v16.4s, v0.4s, v23.4s"),
        Q!("    srshr           " "v16.4s, v16.4s, #0x11"),
        Q!("    cmgt            " "v25.4s, v0.4s, v21.4s"),
        Q!("    mls             " "v0.4s, v16.4s, v22.4s"),
        Q!("    bic             " "v16.16b, v16.16b, v25.16b"),
        Q!("    add             " "v0.4s, v0.4s, v25.4s"),
        Q!("    cmle            " "v0.4s, v0.4s, #0"),
        Q!("    orr             " "v0.4s, #0x1"),
        Q!("    mla             " "v16.4s, v0.4s, v4.4s"),
        Q!("    cmgt            " "v25.4s, v16.4s, v24.4s"),
        Q!("    bic             " "v16.16b, v16.16b, v25.16b"),
        Q!("    umin            " "v16.4s, v16.4s, v24.4s"),

        // Store 16 output coefficients
        Q!("    str             " "q17, [x0, #0x10]"),
        Q!("    str             " "q18, [x0, #0x20]"),
        Q!("    str             " "q19, [x0, #0x30]"),
        Q!("    str             " "q16, [x0], #0x40"),

        // Decrement loop counter and branch
        Q!("    subs            " "x3, x3, #0x1"),
        Q!("    b.ne            " Label!("Lmldsa_poly_use_hint_88_loop", 2, Before)),

        inout("x0") b.as_mut_ptr() => _,
        inout("x1") a.as_ptr() => _,
        inout("x2") h.as_ptr() => _,
        // clobbers
        out("v0") _,
        out("v1") _,
        out("v16") _,
        out("v17") _,
        out("v18") _,
        out("v19") _,
        out("v2") _,
        out("v20") _,
        out("v21") _,
        out("v22") _,
        out("v23") _,
        out("v24") _,
        out("v25") _,
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
        mldsa_poly_use_hint_88,
        &mut crate::low::abi::Aligned([0; 256]).0,
        &crate::low::abi::Aligned([0; 256]).0,
        &crate::low::abi::Aligned([0; 256]).0
    );
}
