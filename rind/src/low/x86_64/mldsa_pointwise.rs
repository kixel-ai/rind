// generated source. do not edit.
#![allow(non_upper_case_globals, unused_macros, unused_imports)]
use crate::low::macros::*;

// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT

// ----------------------------------------------------------------------------
// Pointwise multiplication of polynomials in NTT domain for ML-DSA
// Inputs c[256], a[256], b[256], qdata (all signed 32-bit words); output c[256]
//
// Performs pointwise multiplication of two polynomials in NTT domain with
// Montgomery reduction. Given two polynomials a and b in NTT representation
// (256 coefficients each), computes c = a * b (coefficient-wise) in NTT domain.
// Each coefficient multiplication is followed by Montgomery reduction modulo
// Q = 8380417.
//
// The input polynomials a and b are assumed to have coefficients bounded by
// 9*Q in absolute value. The output polynomial c will have coefficients bounded
// by Q in absolute value after Montgomery reduction.
//
// The qdata parameter points to precomputed constants required for Montgomery
// arithmetic:
//   - 8xQINV: Eight copies of Q^(-1) mod 2^32 for Montgomery multiplication
//   - 8xQ: Eight copies of Q for the reduction step
//
// extern void mldsa_pointwise_x86(
//     int32_t c[static 256],
//     const int32_t a[static 256],
//     const int32_t b[static 256],
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

macro_rules! MLD_AVX2_BACKEND_DATA_OFFSET_8XQINV {
    () => {
        "0"
    };
}
macro_rules! MLD_AVX2_BACKEND_DATA_OFFSET_8XQ {
    () => {
        "8"
    };
}

// Transliterated from s2n-bignum's x86/mldsa/mldsa_pointwise.S.
/// Pointwise multiplication of polynomials in NTT domain for ML-DSA
///
/// Inputs c[256], a[256], b[256], qdata (all signed 32-bit words); output c[256]
///
/// Performs pointwise multiplication of two polynomials in NTT domain with
/// Montgomery reduction. Given two polynomials a and b in NTT representation
/// (256 coefficients each), computes c = a * b (coefficient-wise) in NTT domain.
/// Each coefficient multiplication is followed by Montgomery reduction modulo
/// Q = 8380417.
///
/// The input polynomials a and b are assumed to have coefficients bounded by
/// 9*Q in absolute value. The output polynomial c will have coefficients bounded
/// by Q in absolute value after Montgomery reduction.
///
/// The qdata parameter points to precomputed constants required for Montgomery
/// arithmetic:
///   - 8xQINV: Eight copies of Q^(-1) mod 2^32 for Montgomery multiplication
///   - 8xQ: Eight copies of Q for the reduction step
#[inline(never)]
pub(crate) fn mldsa_pointwise(
    c: &mut [i32; 256],
    a: &[i32; 256],
    b: &[i32; 256],
    qdata: &[i32; 16],
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
        Q!(Label!("Lpointwise_looptop1", 2) ":"),
        // Handle 24 = 3*8 coefficients per iteration

        // Load a's coefficients
        Q!("    vmovdqa         " "ymm2, [" a!() "]"),
        Q!("    vmovdqa         " "ymm4, [" a!() "+ 32]"),
        Q!("    vmovdqa         " "ymm6, [" a!() "+ 64]"),
        // Load b's coefficients
        Q!("    vmovdqa         " "ymm10, [" b!() "]"),
        Q!("    vmovdqa         " "ymm12, [" b!() "+ 32]"),
        Q!("    vmovdqa         " "ymm14, [" b!() "+ 64]"),

        // Extract high 32-bit parts for Montgomery multiplication
        Q!("    vpsrlq          " "ymm3, ymm2, 32"),
        Q!("    vpsrlq          " "ymm5, ymm4, 32"),
        Q!("    vmovshdup       " "ymm7, ymm6"),
        Q!("    vpsrlq          " "ymm11, ymm10, 32"),
        Q!("    vpsrlq          " "ymm13, ymm12, 32"),
        Q!("    vmovshdup       " "ymm15, ymm14"),
        //
        // ymm{i} stores a's coefficients for i in 2...7, and b's coefficients
        // for i in 10...15.
        //
        // Bounds: |ymm{i}| < 9q for i in 2...7, 10...15
        //

        // Multiply coefficients
        Q!("    vpmuldq         " "ymm2, ymm2, ymm10"),
        Q!("    vpmuldq         " "ymm3, ymm3, ymm11"),
        Q!("    vpmuldq         " "ymm4, ymm4, ymm12"),
        Q!("    vpmuldq         " "ymm5, ymm5, ymm13"),
        Q!("    vpmuldq         " "ymm6, ymm6, ymm14"),
        Q!("    vpmuldq         " "ymm7, ymm7, ymm15"),
        //
        // Bounds: |ymm{i}| < 81q^2 < MONTGOMERY_REDUCE_STRONG_DOMAIN_MAX
        // for i in 2...7
        //

        // Montgomery reduction
        Q!("    vpmuldq         " "ymm10, ymm0, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm0, ymm3"),
        Q!("    vpmuldq         " "ymm12, ymm0, ymm4"),
        Q!("    vpmuldq         " "ymm13, ymm0, ymm5"),
        Q!("    vpmuldq         " "ymm14, ymm0, ymm6"),
        Q!("    vpmuldq         " "ymm15, ymm0, ymm7"),
        Q!("    vpmuldq         " "ymm10, ymm1, ymm10"),
        Q!("    vpmuldq         " "ymm11, ymm1, ymm11"),
        Q!("    vpmuldq         " "ymm12, ymm1, ymm12"),
        Q!("    vpmuldq         " "ymm13, ymm1, ymm13"),
        Q!("    vpmuldq         " "ymm14, ymm1, ymm14"),
        Q!("    vpmuldq         " "ymm15, ymm1, ymm15"),
        Q!("    vpsubq          " "ymm2, ymm2, ymm10"),
        Q!("    vpsubq          " "ymm3, ymm3, ymm11"),
        Q!("    vpsubq          " "ymm4, ymm4, ymm12"),
        Q!("    vpsubq          " "ymm5, ymm5, ymm13"),
        Q!("    vpsubq          " "ymm6, ymm6, ymm14"),
        Q!("    vpsubq          " "ymm7, ymm7, ymm15"),
        //
        // All coefficients are Montgomery-reduced, resulting in
        //
        // Bounds: |ymm{i}| < q for i in 2...7
        //
        // See description of mld_montgomery_reduce() in mldsa/src/reduce.h.
        //

        // Repack and store results
        Q!("    vpsrlq          " "ymm2, ymm2, 32"),
        Q!("    vpsrlq          " "ymm4, ymm4, 32"),
        Q!("    vmovshdup       " "ymm6, ymm6"),
        Q!("    vpblendd        " "ymm2, ymm2, ymm3, 0xAA"),
        Q!("    vpblendd        " "ymm4, ymm4, ymm5, 0xAA"),
        Q!("    vpblendd        " "ymm6, ymm6, ymm7, 0xAA"),
        Q!("    vmovdqa         " "[" c!() "], ymm2"),
        Q!("    vmovdqa         " "[" c!() "+ 32], ymm4"),
        Q!("    vmovdqa         " "[" c!() "+ 64], ymm6"),

        Q!("    add             " c!() ", 96"),
        Q!("    add             " a!() ", 96"),
        Q!("    add             " b!() ", 96"),
        Q!("    add             " "eax, 1"),
        Q!("    cmp             " "eax, 10"),
        Q!("    jb              " Label!("Lpointwise_looptop1", 2, Before)),

        // Handle the last 256 % 24 = 16 = 2*8 coefficients, left over by the loop

        // Load remaining a's coefficients
        Q!("    vmovdqa         " "ymm2, [" a!() "]"),
        Q!("    vmovdqa         " "ymm4, [" a!() "+ 32]"),
        // Load remaining b's coefficients
        Q!("    vmovdqa         " "ymm10, [" b!() "]"),
        Q!("    vmovdqa         " "ymm12, [" b!() "+ 32]"),

        // Extract high 32-bit parts
        Q!("    vpsrlq          " "ymm3, ymm2, 32"),
        Q!("    vpsrlq          " "ymm5, ymm4, 32"),
        Q!("    vmovshdup       " "ymm11, ymm10"),
        Q!("    vmovshdup       " "ymm13, ymm12"),
        //
        // ymm{i} stores a's coefficients for i in 2...5, and b's coefficients
        // for i in 10...13.
        //
        // Bounds: |ymm{i}| < 9q for i in 2...5, 10...13
        //

        // Multiply remaining coefficients
        Q!("    vpmuldq         " "ymm2, ymm2, ymm10"),
        Q!("    vpmuldq         " "ymm3, ymm3, ymm11"),
        Q!("    vpmuldq         " "ymm4, ymm4, ymm12"),
        Q!("    vpmuldq         " "ymm5, ymm5, ymm13"),
        //
        // Bounds: |ymm{i}| < 81q^2 < MONTGOMERY_REDUCE_STRONG_DOMAIN_MAX
        // for i in 2...5
        //

        // Montgomery reduction for remaining coefficients
        Q!("    vpmuldq         " "ymm10, ymm0, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm0, ymm3"),
        Q!("    vpmuldq         " "ymm12, ymm0, ymm4"),
        Q!("    vpmuldq         " "ymm13, ymm0, ymm5"),
        Q!("    vpmuldq         " "ymm10, ymm1, ymm10"),
        Q!("    vpmuldq         " "ymm11, ymm1, ymm11"),
        Q!("    vpmuldq         " "ymm12, ymm1, ymm12"),
        Q!("    vpmuldq         " "ymm13, ymm1, ymm13"),
        Q!("    vpsubq          " "ymm2, ymm2, ymm10"),
        Q!("    vpsubq          " "ymm3, ymm3, ymm11"),
        Q!("    vpsubq          " "ymm4, ymm4, ymm12"),
        Q!("    vpsubq          " "ymm5, ymm5, ymm13"),
        //
        // As explained in the loop.
        //
        // Bounds: |ymm{i}| < q for i in 2...5
        //

        // Repack and store final results
        Q!("    vpsrlq          " "ymm2, ymm2, 32"),
        Q!("    vmovshdup       " "ymm4, ymm4"),
        Q!("    vpblendd        " "ymm2, ymm3, ymm2, 0x55"),
        Q!("    vpblendd        " "ymm4, ymm5, ymm4, 0x55"),
        Q!("    vmovdqa         " "[" c!() "], ymm2"),
        Q!("    vmovdqa         " "[" c!() "+ 32], ymm4"),

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
        mldsa_pointwise,
        &mut crate::low::abi::Aligned([0; 256]).0,
        &crate::low::abi::Aligned([0; 256]).0,
        &crate::low::abi::Aligned([0; 256]).0,
        &crate::low::abi::Aligned([0; 16]).0
    );
}
