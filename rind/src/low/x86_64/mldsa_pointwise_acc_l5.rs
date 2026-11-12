// generated source. do not edit.
#![allow(non_upper_case_globals, unused_macros, unused_imports)]
use crate::low::macros::*;

// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT

// ----------------------------------------------------------------------------
// Pointwise multiplication with accumulation for ML-DSA L5
// Inputs c[256], a[5*256], b[5*256], qdata (all signed 32-bit words); output c[256]
//
// Performs pointwise multiplication with accumulation across five polynomial
// vectors in NTT domain with Montgomery reduction. Given five pairs of
// polynomials (a0,b0), (a1,b1), (a2,b2), (a3,b3), (a4,b4) each with 256
// coefficients in NTT representation, computes
// c = a0*b0 + a1*b1 + a2*b2 + a3*b3 + a4*b4
// (coefficient-wise) in NTT domain. Each coefficient multiplication and
// accumulation is followed by Montgomery reduction modulo Q = 8380417.
//
// This function is specifically optimized for ML-DSA Level 5 parameter set
// (ML-DSA-65) which requires accumulating 5 polynomial products (l=5).
// The input polynomials a and b are laid out sequentially with a stride
// of 1024 bytes (256 * 4).
//
// Input bounds (per coefficient, absolute value):
//   |a[i]| < Q
//   |b[i]| < 9*Q
// The output polynomial c will have coefficients bounded by Q in absolute
// value after Montgomery reduction.
//
// The qdata parameter points to precomputed constants required for Montgomery
// arithmetic:
//   - 8xQINV: Eight copies of Q^(-1) mod 2^32 for Montgomery multiplication
//   - 8xQ: Eight copies of Q for the reduction step
//
// extern void mldsa_pointwise_acc_l5_x86(
//     int32_t c[static 256],
//     const int32_t a[static 1280],
//     const int32_t b[static 1280],
//     const int32_t qdata[static 16]
// );
//
// Standard x86-64 ABI: RDI = c, RSI = a, RDX = b, RCX = qdata
// Microsoft x64 ABI:   RCX = c, RDX = a, R8 = b, R9 = qdata
// ----------------------------------------------------------------------------

macro_rules! c {
    () => {
        "rdi"
    };
}
macro_rules! a {
    () => {
        "rsi"
    };
}
macro_rules! b {
    () => {
        "rdx"
    };
}
macro_rules! qdata {
    () => {
        "rcx"
    };
}

macro_rules! MLD_AVX2_BACKEND_DATA_OFFSET_8XQ {
    () => {
        "0"
    };
}
macro_rules! MLD_AVX2_BACKEND_DATA_OFFSET_8XQINV {
    () => {
        "8"
    };
}

// Transliterated from s2n-bignum's x86/mldsa/mldsa_pointwise_acc_l5.S.
/// Pointwise multiplication with accumulation for ML-DSA L5
///
/// Inputs c[256], a[5*256], b[5*256], qdata (all signed 32-bit words); output c[256]
///
/// Performs pointwise multiplication with accumulation across five polynomial
/// vectors in NTT domain with Montgomery reduction. Given five pairs of
/// polynomials (a0,b0), (a1,b1), (a2,b2), (a3,b3), (a4,b4) each with 256
/// coefficients in NTT representation, computes
/// c = a0*b0 + a1*b1 + a2*b2 + a3*b3 + a4*b4
/// (coefficient-wise) in NTT domain. Each coefficient multiplication and
/// accumulation is followed by Montgomery reduction modulo Q = 8380417.
///
/// This function is specifically optimized for ML-DSA Level 5 parameter set
/// (ML-DSA-65) which requires accumulating 5 polynomial products (l=5).
/// The input polynomials a and b are laid out sequentially with a stride
/// of 1024 bytes (256 * 4).
///
/// Input bounds (per coefficient, absolute value):
///   |a[i]| < Q
///   |b[i]| < 9*Q
/// The output polynomial c will have coefficients bounded by Q in absolute
/// value after Montgomery reduction.
///
/// The qdata parameter points to precomputed constants required for Montgomery
/// arithmetic:
///   - 8xQINV: Eight copies of Q^(-1) mod 2^32 for Montgomery multiplication
///   - 8xQ: Eight copies of Q for the reduction step
#[inline(never)]
pub(crate) fn mldsa_pointwise_acc_l5(
    c: &mut [i32; 256],
    a: &[[i32; 256]; 5],
    b: &[[i32; 256]; 5],
    qdata: &[i32; 624],
) {
    assert!((c.as_mut_ptr() as usize).is_multiple_of(32));
    assert!((a.as_ptr() as usize).is_multiple_of(32));
    assert!((b.as_ptr() as usize).is_multiple_of(32));
    assert!((qdata.as_ptr() as usize).is_multiple_of(32));
    // SAFETY: inline assembly. see [crate::low::inline_assembly_safety] for safety info.
    unsafe {
        core::arch::asm!(

        Q!("    endbr64         " ),

        // Load constants from qdata
        Q!("    vmovdqa         " "ymm0, [" qdata!() "+ (" MLD_AVX2_BACKEND_DATA_OFFSET_8XQINV!() ") * 4]"),
        Q!("    vmovdqa         " "ymm1, [" qdata!() "+ (" MLD_AVX2_BACKEND_DATA_OFFSET_8XQ!() ") * 4]"),

        Q!("    xor             " "eax, eax"),
        Q!(Label!("Lpointwise_acc_l5_looptop", 2) ":"),
        // Load a's coefficients
        Q!("    vmovdqa         " "ymm6, [" a!() "+ 0]"),
        Q!("    vmovdqa         " "ymm8, [" a!() "+ 0 + 32]"),
        // Load b's coefficients
        Q!("    vmovdqa         " "ymm10, [" b!() "+ 0]"),
        Q!("    vmovdqa         " "ymm12, [" b!() "+ 0 + 32]"),
        // Extract high 32-bit parts for Montgomery multiplication
        Q!("    vpsrlq          " "ymm7, ymm6, 32"),
        Q!("    vpsrlq          " "ymm9, ymm8, 32"),
        Q!("    vmovshdup       " "ymm11, ymm10"),
        Q!("    vmovshdup       " "ymm13, ymm12"),
        //
        // ymm{i} stores a's coefficients for i in 6...9, and b's coefficients
        // for i in 10...13.
        //
        // Bounds: |ymm{i}| < q  for i in 6...9
        // < 9q for i in 10...13
        //

        // Multiply coefficients
        Q!("    vpmuldq         " "ymm6, ymm6, ymm10"),
        Q!("    vpmuldq         " "ymm7, ymm7, ymm11"),
        Q!("    vpmuldq         " "ymm8, ymm8, ymm12"),
        Q!("    vpmuldq         " "ymm9, ymm9, ymm13"),
        // Bounds: |ymm{i}| < 9q^2 for i in 6...9

        // Move first product
        Q!("    vmovdqa         " "ymm2, ymm6"),
        Q!("    vmovdqa         " "ymm3, ymm7"),
        Q!("    vmovdqa         " "ymm4, ymm8"),
        Q!("    vmovdqa         " "ymm5, ymm9"),
        // Bounds: |ymm{i}| < 9q^2

        // Load a's coefficients
        Q!("    vmovdqa         " "ymm6, [" a!() "+ 1024]"),
        Q!("    vmovdqa         " "ymm8, [" a!() "+ 1024 + 32]"),
        // Load b's coefficients
        Q!("    vmovdqa         " "ymm10, [" b!() "+ 1024]"),
        Q!("    vmovdqa         " "ymm12, [" b!() "+ 1024 + 32]"),
        // Extract high 32-bit parts for Montgomery multiplication
        Q!("    vpsrlq          " "ymm7, ymm6, 32"),
        Q!("    vpsrlq          " "ymm9, ymm8, 32"),
        Q!("    vmovshdup       " "ymm11, ymm10"),
        Q!("    vmovshdup       " "ymm13, ymm12"),
        //
        // ymm{i} stores a's coefficients for i in 6...9, and b's coefficients
        // for i in 10...13.
        //
        // Bounds: |ymm{i}| < q  for i in 6...9
        // < 9q for i in 10...13
        //

        // Multiply coefficients
        Q!("    vpmuldq         " "ymm6, ymm6, ymm10"),
        Q!("    vpmuldq         " "ymm7, ymm7, ymm11"),
        Q!("    vpmuldq         " "ymm8, ymm8, ymm12"),
        Q!("    vpmuldq         " "ymm9, ymm9, ymm13"),
        // Bounds: |ymm{i}| < 9q^2 for i in 6...9
        Q!("    vpaddq          " "ymm2, ymm6, ymm2"),
        Q!("    vpaddq          " "ymm3, ymm7, ymm3"),
        Q!("    vpaddq          " "ymm4, ymm8, ymm4"),
        Q!("    vpaddq          " "ymm5, ymm9, ymm5"),
        // Bounds: |ymm{i}| < 18q^2

        // Load a's coefficients
        Q!("    vmovdqa         " "ymm6, [" a!() "+ 2048]"),
        Q!("    vmovdqa         " "ymm8, [" a!() "+ 2048 + 32]"),
        // Load b's coefficients
        Q!("    vmovdqa         " "ymm10, [" b!() "+ 2048]"),
        Q!("    vmovdqa         " "ymm12, [" b!() "+ 2048 + 32]"),
        // Extract high 32-bit parts for Montgomery multiplication
        Q!("    vpsrlq          " "ymm7, ymm6, 32"),
        Q!("    vpsrlq          " "ymm9, ymm8, 32"),
        Q!("    vmovshdup       " "ymm11, ymm10"),
        Q!("    vmovshdup       " "ymm13, ymm12"),
        //
        // ymm{i} stores a's coefficients for i in 6...9, and b's coefficients
        // for i in 10...13.
        //
        // Bounds: |ymm{i}| < q  for i in 6...9
        // < 9q for i in 10...13
        //

        // Multiply coefficients
        Q!("    vpmuldq         " "ymm6, ymm6, ymm10"),
        Q!("    vpmuldq         " "ymm7, ymm7, ymm11"),
        Q!("    vpmuldq         " "ymm8, ymm8, ymm12"),
        Q!("    vpmuldq         " "ymm9, ymm9, ymm13"),
        // Bounds: |ymm{i}| < 9q^2 for i in 6...9
        Q!("    vpaddq          " "ymm2, ymm6, ymm2"),
        Q!("    vpaddq          " "ymm3, ymm7, ymm3"),
        Q!("    vpaddq          " "ymm4, ymm8, ymm4"),
        Q!("    vpaddq          " "ymm5, ymm9, ymm5"),
        // Bounds: |ymm{i}| < 27q^2

        // Load a's coefficients
        Q!("    vmovdqa         " "ymm6, [" a!() "+ 3072]"),
        Q!("    vmovdqa         " "ymm8, [" a!() "+ 3072 + 32]"),
        // Load b's coefficients
        Q!("    vmovdqa         " "ymm10, [" b!() "+ 3072]"),
        Q!("    vmovdqa         " "ymm12, [" b!() "+ 3072 + 32]"),
        // Extract high 32-bit parts for Montgomery multiplication
        Q!("    vpsrlq          " "ymm7, ymm6, 32"),
        Q!("    vpsrlq          " "ymm9, ymm8, 32"),
        Q!("    vmovshdup       " "ymm11, ymm10"),
        Q!("    vmovshdup       " "ymm13, ymm12"),
        //
        // ymm{i} stores a's coefficients for i in 6...9, and b's coefficients
        // for i in 10...13.
        //
        // Bounds: |ymm{i}| < q  for i in 6...9
        // < 9q for i in 10...13
        //

        // Multiply coefficients
        Q!("    vpmuldq         " "ymm6, ymm6, ymm10"),
        Q!("    vpmuldq         " "ymm7, ymm7, ymm11"),
        Q!("    vpmuldq         " "ymm8, ymm8, ymm12"),
        Q!("    vpmuldq         " "ymm9, ymm9, ymm13"),
        // Bounds: |ymm{i}| < 9q^2 for i in 6...9
        Q!("    vpaddq          " "ymm2, ymm6, ymm2"),
        Q!("    vpaddq          " "ymm3, ymm7, ymm3"),
        Q!("    vpaddq          " "ymm4, ymm8, ymm4"),
        Q!("    vpaddq          " "ymm5, ymm9, ymm5"),
        // Bounds: |ymm{i}| < 36q^2

        // Load a's coefficients
        Q!("    vmovdqa         " "ymm6, [" a!() "+ 4096]"),
        Q!("    vmovdqa         " "ymm8, [" a!() "+ 4096 + 32]"),
        // Load b's coefficients
        Q!("    vmovdqa         " "ymm10, [" b!() "+ 4096]"),
        Q!("    vmovdqa         " "ymm12, [" b!() "+ 4096 + 32]"),
        // Extract high 32-bit parts for Montgomery multiplication
        Q!("    vpsrlq          " "ymm7, ymm6, 32"),
        Q!("    vpsrlq          " "ymm9, ymm8, 32"),
        Q!("    vmovshdup       " "ymm11, ymm10"),
        Q!("    vmovshdup       " "ymm13, ymm12"),
        //
        // ymm{i} stores a's coefficients for i in 6...9, and b's coefficients
        // for i in 10...13.
        //
        // Bounds: |ymm{i}| < q  for i in 6...9
        // < 9q for i in 10...13
        //

        // Multiply coefficients
        Q!("    vpmuldq         " "ymm6, ymm6, ymm10"),
        Q!("    vpmuldq         " "ymm7, ymm7, ymm11"),
        Q!("    vpmuldq         " "ymm8, ymm8, ymm12"),
        Q!("    vpmuldq         " "ymm9, ymm9, ymm13"),
        // Bounds: |ymm{i}| < 9q^2 for i in 6...9
        Q!("    vpaddq          " "ymm2, ymm6, ymm2"),
        Q!("    vpaddq          " "ymm3, ymm7, ymm3"),
        Q!("    vpaddq          " "ymm4, ymm8, ymm4"),
        Q!("    vpaddq          " "ymm5, ymm9, ymm5"),
        // Bounds: |ymm{i}| < 45q^2 < MONTGOMERY_REDUCE_STRONG_DOMAIN_MAX

        // Montgomery reduction
        Q!("    vpmuldq         " "ymm6, ymm0, ymm2"),
        Q!("    vpmuldq         " "ymm7, ymm0, ymm3"),
        Q!("    vpmuldq         " "ymm8, ymm0, ymm4"),
        Q!("    vpmuldq         " "ymm9, ymm0, ymm5"),
        Q!("    vpmuldq         " "ymm6, ymm1, ymm6"),
        Q!("    vpmuldq         " "ymm7, ymm1, ymm7"),
        Q!("    vpmuldq         " "ymm8, ymm1, ymm8"),
        Q!("    vpmuldq         " "ymm9, ymm1, ymm9"),
        Q!("    vpsubq          " "ymm2, ymm2, ymm6"),
        Q!("    vpsubq          " "ymm3, ymm3, ymm7"),
        Q!("    vpsubq          " "ymm4, ymm4, ymm8"),
        Q!("    vpsubq          " "ymm5, ymm5, ymm9"),
        //
        // All coefficients are Montgomery-reduced, resulting in
        //
        // Bounds: |ymm{i}| < q for i in 2...5
        //
        // See description of mld_montgomery_reduce() in mldsa/src/reduce.h.
        //

        // Repack and store results
        Q!("    vpsrlq          " "ymm2, ymm2, 32"),
        Q!("    vmovshdup       " "ymm4, ymm4"),
        Q!("    vpblendd        " "ymm2, ymm2, ymm3, 0xAA"),
        Q!("    vpblendd        " "ymm4, ymm4, ymm5, 0xAA"),

        Q!("    vmovdqa         " "[" c!() "], ymm2"),
        Q!("    vmovdqa         " "[" c!() "+ 32], ymm4"),

        Q!("    add             " a!() ", 64"),
        Q!("    add             " b!() ", 64"),
        Q!("    add             " c!() ", 64"),
        Q!("    add             " "eax, 1"),
        Q!("    cmp             " "eax, 16"),
        Q!("    jb              " Label!("Lpointwise_acc_l5_looptop", 2, Before)),

        Q!("    vzeroupper      " ),
        inout("rdi") c.as_mut_ptr() => _,
        inout("rsi") a.as_ptr() => _,
        inout("rdx") b.as_ptr() => _,
        inout("rcx") qdata.as_ptr() => _,
        // clobbers
        out("rax") _,
        out("zmm0") _,
        out("zmm1") _,
        out("zmm10") _,
        out("zmm11") _,
        out("zmm12") _,
        out("zmm13") _,
        out("zmm14") _,
        out("zmm15") _,
        out("zmm2") _,
        out("zmm3") _,
        out("zmm4") _,
        out("zmm5") _,
        out("zmm6") _,
        out("zmm7") _,
        out("zmm8") _,
        out("zmm9") _,
            )
    };
}

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
#[test]
fn abi() {
    if !std::arch::is_x86_feature_detected!("avx2") {
        return;
    }
    crate::low::abi::call!(
        mldsa_pointwise_acc_l5,
        &mut crate::low::abi::Aligned([0; 256]).0,
        &crate::low::abi::Aligned([[0; 256]; 5]).0,
        &crate::low::abi::Aligned([[0; 256]; 5]).0,
        &crate::low::abi::Aligned([0; 624]).0
    );
}
