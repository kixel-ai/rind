// generated source. do not edit.
#![allow(non_upper_case_globals, unused_macros, unused_imports)]
use crate::low::macros::*;

// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT

// ----------------------------------------------------------------------------
// Forward number-theoretic transform for ML-DSA
// Input a[256], zetas (all signed 32-bit words); output a[256] (signed 32-bit words)
//
// The transform is in-place with input and output a[256], with the output
// in bitreversed order. Computes the forward NTT of a polynomial in place,
// transforming from coefficient representation to NTT representation. The input
// polynomial a is a 256-element array of signed 32-bit integers representing
// coefficients in normal order, assumed to be coefficient-wise bound by MLDSA_Q
// (8380417) in absolute value. The zetas parameter points to precomputed twiddle
// factors (roots of unity and their Montgomery inverses) required for the NTT
// computation. The output polynomial is in bitreversed order and coefficient-wise
// bound by 42035261 (just over 5*Q) in absolute value. Output coefficients are
// congruent to the mathematical NTT result modulo Q but are not fully reduced.
//
// The implementation uses Montgomery arithmetic for efficient modular reduction
// modulo Q = 8380417, maintaining constant-time execution for side-channel
// resistance. The transform operates in the ring R_Q = Z_Q[x]/(x^256 + 1).
//
// extern void mldsa_ntt(int32_t a[static 256], const int32_t zetas[static 624]);
//
// Standard x86-64 ABI: RDI = a, RSI = zetas
// Microsoft x64 ABI:   RCX = a, RDX = zetas
// ----------------------------------------------------------------------------

macro_rules! a {
    () => {
        "rdi"
    };
}
macro_rules! zetas {
    () => {
        "rsi"
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
macro_rules! MLD_AVX2_BACKEND_DATA_OFFSET_8XDIV_QINV {
    () => {
        "16"
    };
}
macro_rules! MLD_AVX2_BACKEND_DATA_OFFSET_8XDIV {
    () => {
        "24"
    };
}
macro_rules! MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV {
    () => {
        "32"
    };
}
macro_rules! MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS {
    () => {
        "328"
    };
}

// Transliterated from s2n-bignum's x86/mldsa/mldsa_ntt.S.
/// Forward number-theoretic transform for ML-DSA
///
/// Input a[256], zetas (all signed 32-bit words); output a[256] (signed 32-bit words)
///
/// The transform is in-place with input and output a[256], with the output
/// in bitreversed order. Computes the forward NTT of a polynomial in place,
/// transforming from coefficient representation to NTT representation. The input
/// polynomial a is a 256-element array of signed 32-bit integers representing
/// coefficients in normal order, assumed to be coefficient-wise bound by MLDSA_Q
/// (8380417) in absolute value. The zetas parameter points to precomputed twiddle
/// factors (roots of unity and their Montgomery inverses) required for the NTT
/// computation. The output polynomial is in bitreversed order and coefficient-wise
/// bound by 42035261 (just over 5*Q) in absolute value. Output coefficients are
/// congruent to the mathematical NTT result modulo Q but are not fully reduced.
///
/// The implementation uses Montgomery arithmetic for efficient modular reduction
/// modulo Q = 8380417, maintaining constant-time execution for side-channel
/// resistance. The transform operates in the ring R_Q = Z_Q[x]/(x^256 + 1).
#[inline(never)]
pub(crate) fn mldsa_ntt(a: &mut [i32; 256], qdata: &[i32; 624]) {
    assert!((a.as_mut_ptr() as usize).is_multiple_of(32));
    assert!((qdata.as_ptr() as usize).is_multiple_of(32));
    // SAFETY: inline assembly. see [crate::low::inline_assembly_safety] for safety info.
    unsafe {
        core::arch::asm!(

        Q!("    endbr64         " ),

        Q!("    vmovdqa         " "ymm0, [rsi + " MLD_AVX2_BACKEND_DATA_OFFSET_8XQ!() "* 4]"),

        // level 0
        Q!("    vpbroadcastd    " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 1))]"),
        Q!("    vpbroadcastd    " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 1))]"),

        Q!("    vmovdqa         " "ymm4, [rdi + 0 + 32 * 0]"),
        Q!("    vmovdqa         " "ymm5, [rdi + 128 + 32 * 0]"),
        Q!("    vmovdqa         " "ymm6, [rdi + 256 + 32 * 0]"),
        Q!("    vmovdqa         " "ymm7, [rdi + 384 + 32 * 0]"),
        Q!("    vmovdqa         " "ymm8, [rdi + 512 + 32 * 0]"),
        Q!("    vmovdqa         " "ymm9, [rdi + 640 + 32 * 0]"),
        Q!("    vmovdqa         " "ymm10, [rdi + 768 + 32 * 0]"),
        Q!("    vmovdqa         " "ymm11, [rdi + 896 + 32 * 0]"),

        Q!("    vpmuldq         " "ymm13, ymm8, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm8"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm8, ymm8"),
        Q!("    vpblendd        " "ymm8, ymm8, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm4, ymm8"),
        Q!("    vpaddd          " "ymm4, ymm4, ymm8"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm8, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm4, ymm4, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm9, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm9"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm9, ymm9, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm9, ymm9"),
        Q!("    vpblendd        " "ymm9, ymm9, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm5, ymm9"),
        Q!("    vpaddd          " "ymm5, ymm5, ymm9"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm9, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm10, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm10"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm10, ymm10, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm10, ymm10"),
        Q!("    vpblendd        " "ymm10, ymm10, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm6, ymm10"),
        Q!("    vpaddd          " "ymm6, ymm6, ymm10"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm10, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm6, ymm6, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm11, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm11"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm11, ymm11"),
        Q!("    vpblendd        " "ymm11, ymm11, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm7, ymm11"),
        Q!("    vpaddd          " "ymm7, ymm7, ymm11"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm11, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm13"),

        // level 1
        Q!("    vpbroadcastd    " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 2))]"),
        Q!("    vpbroadcastd    " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 2))]"),
        Q!("    vpmuldq         " "ymm13, ymm6, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm6"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm6, ymm6, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm6, ymm6"),
        Q!("    vpblendd        " "ymm6, ymm6, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm4, ymm6"),
        Q!("    vpaddd          " "ymm4, ymm4, ymm6"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm6, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm4, ymm4, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm7, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm7"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm7, ymm7, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm7, ymm7"),
        Q!("    vpblendd        " "ymm7, ymm7, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm5, ymm7"),
        Q!("    vpaddd          " "ymm5, ymm5, ymm7"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm7, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm13"),

        Q!("    vpbroadcastd    " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 3))]"),
        Q!("    vpbroadcastd    " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 3))]"),
        Q!("    vpmuldq         " "ymm13, ymm10, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm10"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm10, ymm10, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm10, ymm10"),
        Q!("    vpblendd        " "ymm10, ymm10, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm8, ymm10"),
        Q!("    vpaddd          " "ymm8, ymm8, ymm10"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm10, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm11, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm11"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm11, ymm11"),
        Q!("    vpblendd        " "ymm11, ymm11, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm9, ymm11"),
        Q!("    vpaddd          " "ymm9, ymm9, ymm11"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm11, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm13"),

        Q!("    vmovdqa         " "[rdi + 0 + 32 * 0], ymm4"),
        Q!("    vmovdqa         " "[rdi + 128 + 32 * 0], ymm5"),
        Q!("    vmovdqa         " "[rdi + 256 + 32 * 0], ymm6"),
        Q!("    vmovdqa         " "[rdi + 384 + 32 * 0], ymm7"),
        Q!("    vmovdqa         " "[rdi + 512 + 32 * 0], ymm8"),
        Q!("    vmovdqa         " "[rdi + 640 + 32 * 0], ymm9"),
        Q!("    vmovdqa         " "[rdi + 768 + 32 * 0], ymm10"),
        Q!("    vmovdqa         " "[rdi + 896 + 32 * 0], ymm11"),
        // level 0
        Q!("    vpbroadcastd    " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 1))]"),
        Q!("    vpbroadcastd    " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 1))]"),

        Q!("    vmovdqa         " "ymm4, [rdi + 0 + 32 * 1]"),
        Q!("    vmovdqa         " "ymm5, [rdi + 128 + 32 * 1]"),
        Q!("    vmovdqa         " "ymm6, [rdi + 256 + 32 * 1]"),
        Q!("    vmovdqa         " "ymm7, [rdi + 384 + 32 * 1]"),
        Q!("    vmovdqa         " "ymm8, [rdi + 512 + 32 * 1]"),
        Q!("    vmovdqa         " "ymm9, [rdi + 640 + 32 * 1]"),
        Q!("    vmovdqa         " "ymm10, [rdi + 768 + 32 * 1]"),
        Q!("    vmovdqa         " "ymm11, [rdi + 896 + 32 * 1]"),

        Q!("    vpmuldq         " "ymm13, ymm8, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm8"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm8, ymm8"),
        Q!("    vpblendd        " "ymm8, ymm8, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm4, ymm8"),
        Q!("    vpaddd          " "ymm4, ymm4, ymm8"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm8, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm4, ymm4, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm9, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm9"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm9, ymm9, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm9, ymm9"),
        Q!("    vpblendd        " "ymm9, ymm9, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm5, ymm9"),
        Q!("    vpaddd          " "ymm5, ymm5, ymm9"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm9, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm10, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm10"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm10, ymm10, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm10, ymm10"),
        Q!("    vpblendd        " "ymm10, ymm10, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm6, ymm10"),
        Q!("    vpaddd          " "ymm6, ymm6, ymm10"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm10, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm6, ymm6, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm11, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm11"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm11, ymm11"),
        Q!("    vpblendd        " "ymm11, ymm11, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm7, ymm11"),
        Q!("    vpaddd          " "ymm7, ymm7, ymm11"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm11, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm13"),

        // level 1
        Q!("    vpbroadcastd    " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 2))]"),
        Q!("    vpbroadcastd    " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 2))]"),
        Q!("    vpmuldq         " "ymm13, ymm6, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm6"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm6, ymm6, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm6, ymm6"),
        Q!("    vpblendd        " "ymm6, ymm6, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm4, ymm6"),
        Q!("    vpaddd          " "ymm4, ymm4, ymm6"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm6, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm4, ymm4, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm7, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm7"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm7, ymm7, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm7, ymm7"),
        Q!("    vpblendd        " "ymm7, ymm7, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm5, ymm7"),
        Q!("    vpaddd          " "ymm5, ymm5, ymm7"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm7, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm13"),

        Q!("    vpbroadcastd    " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 3))]"),
        Q!("    vpbroadcastd    " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 3))]"),
        Q!("    vpmuldq         " "ymm13, ymm10, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm10"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm10, ymm10, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm10, ymm10"),
        Q!("    vpblendd        " "ymm10, ymm10, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm8, ymm10"),
        Q!("    vpaddd          " "ymm8, ymm8, ymm10"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm10, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm11, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm11"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm11, ymm11"),
        Q!("    vpblendd        " "ymm11, ymm11, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm9, ymm11"),
        Q!("    vpaddd          " "ymm9, ymm9, ymm11"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm11, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm13"),

        Q!("    vmovdqa         " "[rdi + 0 + 32 * 1], ymm4"),
        Q!("    vmovdqa         " "[rdi + 128 + 32 * 1], ymm5"),
        Q!("    vmovdqa         " "[rdi + 256 + 32 * 1], ymm6"),
        Q!("    vmovdqa         " "[rdi + 384 + 32 * 1], ymm7"),
        Q!("    vmovdqa         " "[rdi + 512 + 32 * 1], ymm8"),
        Q!("    vmovdqa         " "[rdi + 640 + 32 * 1], ymm9"),
        Q!("    vmovdqa         " "[rdi + 768 + 32 * 1], ymm10"),
        Q!("    vmovdqa         " "[rdi + 896 + 32 * 1], ymm11"),
        // level 0
        Q!("    vpbroadcastd    " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 1))]"),
        Q!("    vpbroadcastd    " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 1))]"),

        Q!("    vmovdqa         " "ymm4, [rdi + 0 + 32 * 2]"),
        Q!("    vmovdqa         " "ymm5, [rdi + 128 + 32 * 2]"),
        Q!("    vmovdqa         " "ymm6, [rdi + 256 + 32 * 2]"),
        Q!("    vmovdqa         " "ymm7, [rdi + 384 + 32 * 2]"),
        Q!("    vmovdqa         " "ymm8, [rdi + 512 + 32 * 2]"),
        Q!("    vmovdqa         " "ymm9, [rdi + 640 + 32 * 2]"),
        Q!("    vmovdqa         " "ymm10, [rdi + 768 + 32 * 2]"),
        Q!("    vmovdqa         " "ymm11, [rdi + 896 + 32 * 2]"),

        Q!("    vpmuldq         " "ymm13, ymm8, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm8"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm8, ymm8"),
        Q!("    vpblendd        " "ymm8, ymm8, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm4, ymm8"),
        Q!("    vpaddd          " "ymm4, ymm4, ymm8"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm8, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm4, ymm4, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm9, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm9"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm9, ymm9, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm9, ymm9"),
        Q!("    vpblendd        " "ymm9, ymm9, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm5, ymm9"),
        Q!("    vpaddd          " "ymm5, ymm5, ymm9"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm9, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm10, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm10"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm10, ymm10, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm10, ymm10"),
        Q!("    vpblendd        " "ymm10, ymm10, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm6, ymm10"),
        Q!("    vpaddd          " "ymm6, ymm6, ymm10"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm10, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm6, ymm6, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm11, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm11"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm11, ymm11"),
        Q!("    vpblendd        " "ymm11, ymm11, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm7, ymm11"),
        Q!("    vpaddd          " "ymm7, ymm7, ymm11"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm11, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm13"),

        // level 1
        Q!("    vpbroadcastd    " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 2))]"),
        Q!("    vpbroadcastd    " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 2))]"),
        Q!("    vpmuldq         " "ymm13, ymm6, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm6"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm6, ymm6, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm6, ymm6"),
        Q!("    vpblendd        " "ymm6, ymm6, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm4, ymm6"),
        Q!("    vpaddd          " "ymm4, ymm4, ymm6"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm6, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm4, ymm4, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm7, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm7"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm7, ymm7, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm7, ymm7"),
        Q!("    vpblendd        " "ymm7, ymm7, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm5, ymm7"),
        Q!("    vpaddd          " "ymm5, ymm5, ymm7"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm7, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm13"),

        Q!("    vpbroadcastd    " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 3))]"),
        Q!("    vpbroadcastd    " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 3))]"),
        Q!("    vpmuldq         " "ymm13, ymm10, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm10"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm10, ymm10, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm10, ymm10"),
        Q!("    vpblendd        " "ymm10, ymm10, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm8, ymm10"),
        Q!("    vpaddd          " "ymm8, ymm8, ymm10"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm10, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm11, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm11"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm11, ymm11"),
        Q!("    vpblendd        " "ymm11, ymm11, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm9, ymm11"),
        Q!("    vpaddd          " "ymm9, ymm9, ymm11"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm11, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm13"),

        Q!("    vmovdqa         " "[rdi + 0 + 32 * 2], ymm4"),
        Q!("    vmovdqa         " "[rdi + 128 + 32 * 2], ymm5"),
        Q!("    vmovdqa         " "[rdi + 256 + 32 * 2], ymm6"),
        Q!("    vmovdqa         " "[rdi + 384 + 32 * 2], ymm7"),
        Q!("    vmovdqa         " "[rdi + 512 + 32 * 2], ymm8"),
        Q!("    vmovdqa         " "[rdi + 640 + 32 * 2], ymm9"),
        Q!("    vmovdqa         " "[rdi + 768 + 32 * 2], ymm10"),
        Q!("    vmovdqa         " "[rdi + 896 + 32 * 2], ymm11"),
        // level 0
        Q!("    vpbroadcastd    " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 1))]"),
        Q!("    vpbroadcastd    " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 1))]"),

        Q!("    vmovdqa         " "ymm4, [rdi + 0 + 32 * 3]"),
        Q!("    vmovdqa         " "ymm5, [rdi + 128 + 32 * 3]"),
        Q!("    vmovdqa         " "ymm6, [rdi + 256 + 32 * 3]"),
        Q!("    vmovdqa         " "ymm7, [rdi + 384 + 32 * 3]"),
        Q!("    vmovdqa         " "ymm8, [rdi + 512 + 32 * 3]"),
        Q!("    vmovdqa         " "ymm9, [rdi + 640 + 32 * 3]"),
        Q!("    vmovdqa         " "ymm10, [rdi + 768 + 32 * 3]"),
        Q!("    vmovdqa         " "ymm11, [rdi + 896 + 32 * 3]"),

        Q!("    vpmuldq         " "ymm13, ymm8, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm8"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm8, ymm8"),
        Q!("    vpblendd        " "ymm8, ymm8, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm4, ymm8"),
        Q!("    vpaddd          " "ymm4, ymm4, ymm8"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm8, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm4, ymm4, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm9, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm9"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm9, ymm9, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm9, ymm9"),
        Q!("    vpblendd        " "ymm9, ymm9, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm5, ymm9"),
        Q!("    vpaddd          " "ymm5, ymm5, ymm9"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm9, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm10, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm10"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm10, ymm10, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm10, ymm10"),
        Q!("    vpblendd        " "ymm10, ymm10, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm6, ymm10"),
        Q!("    vpaddd          " "ymm6, ymm6, ymm10"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm10, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm6, ymm6, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm11, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm11"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm11, ymm11"),
        Q!("    vpblendd        " "ymm11, ymm11, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm7, ymm11"),
        Q!("    vpaddd          " "ymm7, ymm7, ymm11"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm11, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm13"),

        // level 1
        Q!("    vpbroadcastd    " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 2))]"),
        Q!("    vpbroadcastd    " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 2))]"),
        Q!("    vpmuldq         " "ymm13, ymm6, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm6"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm6, ymm6, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm6, ymm6"),
        Q!("    vpblendd        " "ymm6, ymm6, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm4, ymm6"),
        Q!("    vpaddd          " "ymm4, ymm4, ymm6"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm6, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm4, ymm4, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm7, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm7"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm7, ymm7, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm7, ymm7"),
        Q!("    vpblendd        " "ymm7, ymm7, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm5, ymm7"),
        Q!("    vpaddd          " "ymm5, ymm5, ymm7"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm7, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm13"),

        Q!("    vpbroadcastd    " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 3))]"),
        Q!("    vpbroadcastd    " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 3))]"),
        Q!("    vpmuldq         " "ymm13, ymm10, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm10"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm10, ymm10, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm10, ymm10"),
        Q!("    vpblendd        " "ymm10, ymm10, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm8, ymm10"),
        Q!("    vpaddd          " "ymm8, ymm8, ymm10"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm10, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm11, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm11"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm11, ymm11"),
        Q!("    vpblendd        " "ymm11, ymm11, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm9, ymm11"),
        Q!("    vpaddd          " "ymm9, ymm9, ymm11"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm11, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm13"),

        Q!("    vmovdqa         " "[rdi + 0 + 32 * 3], ymm4"),
        Q!("    vmovdqa         " "[rdi + 128 + 32 * 3], ymm5"),
        Q!("    vmovdqa         " "[rdi + 256 + 32 * 3], ymm6"),
        Q!("    vmovdqa         " "[rdi + 384 + 32 * 3], ymm7"),
        Q!("    vmovdqa         " "[rdi + 512 + 32 * 3], ymm8"),
        Q!("    vmovdqa         " "[rdi + 640 + 32 * 3], ymm9"),
        Q!("    vmovdqa         " "[rdi + 768 + 32 * 3], ymm10"),
        Q!("    vmovdqa         " "[rdi + 896 + 32 * 3], ymm11"),

        // level 2
        Q!("    vmovdqa         " "ymm4, [rdi + 0 + 256 * 0]"),
        Q!("    vmovdqa         " "ymm5, [rdi + 32 + 256 * 0]"),
        Q!("    vmovdqa         " "ymm6, [rdi + 64 + 256 * 0]"),
        Q!("    vmovdqa         " "ymm7, [rdi + 96 + 256 * 0]"),
        Q!("    vmovdqa         " "ymm8, [rdi + 128 + 256 * 0]"),
        Q!("    vmovdqa         " "ymm9, [rdi + 160 + 256 * 0]"),
        Q!("    vmovdqa         " "ymm10, [rdi + 192 + 256 * 0]"),
        Q!("    vmovdqa         " "ymm11, [rdi + 224 + 256 * 0]"),
        Q!("    vpbroadcastd    " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 4 + 0))]"),
        Q!("    vpbroadcastd    " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 4 + 0))]"),

        Q!("    vpmuldq         " "ymm13, ymm8, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm8"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm8, ymm8"),
        Q!("    vpblendd        " "ymm8, ymm8, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm4, ymm8"),
        Q!("    vpaddd          " "ymm4, ymm4, ymm8"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm8, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm4, ymm4, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm9, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm9"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm9, ymm9, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm9, ymm9"),
        Q!("    vpblendd        " "ymm9, ymm9, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm5, ymm9"),
        Q!("    vpaddd          " "ymm5, ymm5, ymm9"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm9, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm10, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm10"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm10, ymm10, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm10, ymm10"),
        Q!("    vpblendd        " "ymm10, ymm10, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm6, ymm10"),
        Q!("    vpaddd          " "ymm6, ymm6, ymm10"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm10, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm6, ymm6, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm11, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm11"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm11, ymm11"),
        Q!("    vpblendd        " "ymm11, ymm11, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm7, ymm11"),
        Q!("    vpaddd          " "ymm7, ymm7, ymm11"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm11, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm13"),

        Q!("    vperm2i128      " "ymm3, ymm4, ymm8, 0x20"),
        Q!("    vperm2i128      " "ymm8, ymm4, ymm8, 0x31"),
        Q!("    vperm2i128      " "ymm4, ymm5, ymm9, 0x20"),
        Q!("    vperm2i128      " "ymm9, ymm5, ymm9, 0x31"),
        Q!("    vperm2i128      " "ymm5, ymm6, ymm10, 0x20"),
        Q!("    vperm2i128      " "ymm10, ymm6, ymm10, 0x31"),
        Q!("    vperm2i128      " "ymm6, ymm7, ymm11, 0x20"),
        Q!("    vperm2i128      " "ymm11, ymm7, ymm11, 0x31"),

        // level 3
        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 8 + 8 * 0))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 8 + 8 * 0))]"),

        Q!("    vpmuldq         " "ymm13, ymm5, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm5"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm5, ymm5, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm5, ymm5"),
        Q!("    vpblendd        " "ymm5, ymm5, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm3, ymm5"),
        Q!("    vpaddd          " "ymm3, ymm3, ymm5"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm5, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm3, ymm3, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm10, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm10"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm10, ymm10, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm10, ymm10"),
        Q!("    vpblendd        " "ymm10, ymm10, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm8, ymm10"),
        Q!("    vpaddd          " "ymm8, ymm8, ymm10"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm10, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm6, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm6"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm6, ymm6, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm6, ymm6"),
        Q!("    vpblendd        " "ymm6, ymm6, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm4, ymm6"),
        Q!("    vpaddd          " "ymm4, ymm4, ymm6"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm6, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm4, ymm4, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm11, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm11"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm11, ymm11"),
        Q!("    vpblendd        " "ymm11, ymm11, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm9, ymm11"),
        Q!("    vpaddd          " "ymm9, ymm9, ymm11"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm11, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm13"),

        Q!("    vpunpcklqdq     " "ymm7, ymm3, ymm5"),
        Q!("    vpunpckhqdq     " "ymm5, ymm3, ymm5"),
        Q!("    vpunpcklqdq     " "ymm3, ymm8, ymm10"),
        Q!("    vpunpckhqdq     " "ymm10, ymm8, ymm10"),
        Q!("    vpunpcklqdq     " "ymm8, ymm4, ymm6"),
        Q!("    vpunpckhqdq     " "ymm6, ymm4, ymm6"),
        Q!("    vpunpcklqdq     " "ymm4, ymm9, ymm11"),
        Q!("    vpunpckhqdq     " "ymm11, ymm9, ymm11"),

        // level 4
        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 40 + 8 * 0))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 40 + 8 * 0))]"),

        Q!("    vpmuldq         " "ymm13, ymm8, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm8"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm8, ymm8"),
        Q!("    vpblendd        " "ymm8, ymm8, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm7, ymm8"),
        Q!("    vpaddd          " "ymm7, ymm7, ymm8"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm8, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm6, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm6"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm6, ymm6, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm6, ymm6"),
        Q!("    vpblendd        " "ymm6, ymm6, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm5, ymm6"),
        Q!("    vpaddd          " "ymm5, ymm5, ymm6"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm6, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm4, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm4"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm4, ymm4, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm4, ymm4"),
        Q!("    vpblendd        " "ymm4, ymm4, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm3, ymm4"),
        Q!("    vpaddd          " "ymm3, ymm3, ymm4"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm4, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm3, ymm3, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm11, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm11"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm11, ymm11"),
        Q!("    vpblendd        " "ymm11, ymm11, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm10, ymm11"),
        Q!("    vpaddd          " "ymm10, ymm10, ymm11"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm11, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm10, ymm10, ymm13"),

        Q!("    vmovsldup       " "ymm9, ymm8"),
        Q!("    vpblendd        " "ymm9, ymm7, ymm9, 0xAA"),
        Q!("    vpsrlq          " "ymm7, ymm7, 32"),
        Q!("    vpblendd        " "ymm8, ymm7, ymm8, 0xAA"),
        Q!("    vmovsldup       " "ymm7, ymm6"),
        Q!("    vpblendd        " "ymm7, ymm5, ymm7, 0xAA"),
        Q!("    vpsrlq          " "ymm5, ymm5, 32"),
        Q!("    vpblendd        " "ymm6, ymm5, ymm6, 0xAA"),
        Q!("    vmovsldup       " "ymm5, ymm4"),
        Q!("    vpblendd        " "ymm5, ymm3, ymm5, 0xAA"),
        Q!("    vpsrlq          " "ymm3, ymm3, 32"),
        Q!("    vpblendd        " "ymm4, ymm3, ymm4, 0xAA"),
        Q!("    vmovsldup       " "ymm3, ymm11"),
        Q!("    vpblendd        " "ymm3, ymm10, ymm3, 0xAA"),
        Q!("    vpsrlq          " "ymm10, ymm10, 32"),
        Q!("    vpblendd        " "ymm11, ymm10, ymm11, 0xAA"),

        // level 5
        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 72 + 8 * 0))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 72 + 8 * 0))]"),
        Q!("    vpsrlq          " "ymm10, ymm1, 32"),
        Q!("    vmovshdup       " "ymm15, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm5, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm5"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm5, ymm5, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm5, ymm5"),
        Q!("    vpblendd        " "ymm5, ymm5, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm9, ymm5"),
        Q!("    vpaddd          " "ymm9, ymm9, ymm5"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm5, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm4, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm4"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm4, ymm4, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm4, ymm4"),
        Q!("    vpblendd        " "ymm4, ymm4, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm8, ymm4"),
        Q!("    vpaddd          " "ymm8, ymm8, ymm4"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm4, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm3, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm3"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm3, ymm3, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm3, ymm3"),
        Q!("    vpblendd        " "ymm3, ymm3, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm7, ymm3"),
        Q!("    vpaddd          " "ymm7, ymm7, ymm3"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm3, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm11, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm11"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm11, ymm11"),
        Q!("    vpblendd        " "ymm11, ymm11, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm6, ymm11"),
        Q!("    vpaddd          " "ymm6, ymm6, ymm11"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm11, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm6, ymm6, ymm13"),

        // level 6
        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 104 + 8 * 0))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 104 + 8 * 0))]"),
        Q!("    vpsrlq          " "ymm10, ymm1, 32"),
        Q!("    vmovshdup       " "ymm15, ymm2"),
        Q!("    vpmuldq         " "ymm13, ymm7, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm7"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm7, ymm7, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm7, ymm7"),
        Q!("    vpblendd        " "ymm7, ymm7, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm9, ymm7"),
        Q!("    vpaddd          " "ymm9, ymm9, ymm7"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm7, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm6, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm6"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm6, ymm6, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm6, ymm6"),
        Q!("    vpblendd        " "ymm6, ymm6, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm8, ymm6"),
        Q!("    vpaddd          " "ymm8, ymm8, ymm6"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm6, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm13"),

        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 104 + 8 * 0 + 32))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 104 + 8 * 0 + 32))]"),
        Q!("    vpsrlq          " "ymm10, ymm1, 32"),
        Q!("    vmovshdup       " "ymm15, ymm2"),
        Q!("    vpmuldq         " "ymm13, ymm3, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm3"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm3, ymm3, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm3, ymm3"),
        Q!("    vpblendd        " "ymm3, ymm3, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm5, ymm3"),
        Q!("    vpaddd          " "ymm5, ymm5, ymm3"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm3, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm11, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm11"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm11, ymm11"),
        Q!("    vpblendd        " "ymm11, ymm11, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm4, ymm11"),
        Q!("    vpaddd          " "ymm4, ymm4, ymm11"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm11, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm4, ymm4, ymm13"),

        // level 7
        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 168 + 8 * 0))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 168 + 8 * 0))]"),
        Q!("    vpsrlq          " "ymm10, ymm1, 32"),
        Q!("    vmovshdup       " "ymm15, ymm2"),
        Q!("    vpmuldq         " "ymm13, ymm8, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm8"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm8, ymm8"),
        Q!("    vpblendd        " "ymm8, ymm8, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm9, ymm8"),
        Q!("    vpaddd          " "ymm9, ymm9, ymm8"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm8, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm13"),

        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 168 + 8 * 0 + 32))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 168 + 8 * 0 + 32))]"),
        Q!("    vpsrlq          " "ymm10, ymm1, 32"),
        Q!("    vmovshdup       " "ymm15, ymm2"),
        Q!("    vpmuldq         " "ymm13, ymm6, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm6"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm6, ymm6, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm6, ymm6"),
        Q!("    vpblendd        " "ymm6, ymm6, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm7, ymm6"),
        Q!("    vpaddd          " "ymm7, ymm7, ymm6"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm6, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm13"),

        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 168 + 8 * 0 + 64))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 168 + 8 * 0 + 64))]"),
        Q!("    vpsrlq          " "ymm10, ymm1, 32"),
        Q!("    vmovshdup       " "ymm15, ymm2"),
        Q!("    vpmuldq         " "ymm13, ymm4, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm4"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm4, ymm4, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm4, ymm4"),
        Q!("    vpblendd        " "ymm4, ymm4, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm5, ymm4"),
        Q!("    vpaddd          " "ymm5, ymm5, ymm4"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm4, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm13"),

        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 168 + 8 * 0 + 96))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 168 + 8 * 0 + 96))]"),
        Q!("    vpsrlq          " "ymm10, ymm1, 32"),
        Q!("    vmovshdup       " "ymm15, ymm2"),
        Q!("    vpmuldq         " "ymm13, ymm11, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm11"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm11, ymm11"),
        Q!("    vpblendd        " "ymm11, ymm11, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm3, ymm11"),
        Q!("    vpaddd          " "ymm3, ymm3, ymm11"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm11, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm3, ymm3, ymm13"),

        Q!("    vmovdqa         " "[rdi + 0 + 256 * 0], ymm9"),
        Q!("    vmovdqa         " "[rdi + 32 + 256 * 0], ymm8"),
        Q!("    vmovdqa         " "[rdi + 64 + 256 * 0], ymm7"),
        Q!("    vmovdqa         " "[rdi + 96 + 256 * 0], ymm6"),
        Q!("    vmovdqa         " "[rdi + 128 + 256 * 0], ymm5"),
        Q!("    vmovdqa         " "[rdi + 160 + 256 * 0], ymm4"),
        Q!("    vmovdqa         " "[rdi + 192 + 256 * 0], ymm3"),
        Q!("    vmovdqa         " "[rdi + 224 + 256 * 0], ymm11"),
        // level 2
        Q!("    vmovdqa         " "ymm4, [rdi + 0 + 256 * 1]"),
        Q!("    vmovdqa         " "ymm5, [rdi + 32 + 256 * 1]"),
        Q!("    vmovdqa         " "ymm6, [rdi + 64 + 256 * 1]"),
        Q!("    vmovdqa         " "ymm7, [rdi + 96 + 256 * 1]"),
        Q!("    vmovdqa         " "ymm8, [rdi + 128 + 256 * 1]"),
        Q!("    vmovdqa         " "ymm9, [rdi + 160 + 256 * 1]"),
        Q!("    vmovdqa         " "ymm10, [rdi + 192 + 256 * 1]"),
        Q!("    vmovdqa         " "ymm11, [rdi + 224 + 256 * 1]"),
        Q!("    vpbroadcastd    " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 4 + 1))]"),
        Q!("    vpbroadcastd    " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 4 + 1))]"),

        Q!("    vpmuldq         " "ymm13, ymm8, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm8"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm8, ymm8"),
        Q!("    vpblendd        " "ymm8, ymm8, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm4, ymm8"),
        Q!("    vpaddd          " "ymm4, ymm4, ymm8"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm8, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm4, ymm4, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm9, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm9"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm9, ymm9, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm9, ymm9"),
        Q!("    vpblendd        " "ymm9, ymm9, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm5, ymm9"),
        Q!("    vpaddd          " "ymm5, ymm5, ymm9"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm9, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm10, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm10"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm10, ymm10, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm10, ymm10"),
        Q!("    vpblendd        " "ymm10, ymm10, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm6, ymm10"),
        Q!("    vpaddd          " "ymm6, ymm6, ymm10"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm10, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm6, ymm6, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm11, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm11"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm11, ymm11"),
        Q!("    vpblendd        " "ymm11, ymm11, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm7, ymm11"),
        Q!("    vpaddd          " "ymm7, ymm7, ymm11"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm11, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm13"),

        Q!("    vperm2i128      " "ymm3, ymm4, ymm8, 0x20"),
        Q!("    vperm2i128      " "ymm8, ymm4, ymm8, 0x31"),
        Q!("    vperm2i128      " "ymm4, ymm5, ymm9, 0x20"),
        Q!("    vperm2i128      " "ymm9, ymm5, ymm9, 0x31"),
        Q!("    vperm2i128      " "ymm5, ymm6, ymm10, 0x20"),
        Q!("    vperm2i128      " "ymm10, ymm6, ymm10, 0x31"),
        Q!("    vperm2i128      " "ymm6, ymm7, ymm11, 0x20"),
        Q!("    vperm2i128      " "ymm11, ymm7, ymm11, 0x31"),

        // level 3
        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 8 + 8 * 1))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 8 + 8 * 1))]"),

        Q!("    vpmuldq         " "ymm13, ymm5, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm5"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm5, ymm5, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm5, ymm5"),
        Q!("    vpblendd        " "ymm5, ymm5, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm3, ymm5"),
        Q!("    vpaddd          " "ymm3, ymm3, ymm5"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm5, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm3, ymm3, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm10, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm10"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm10, ymm10, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm10, ymm10"),
        Q!("    vpblendd        " "ymm10, ymm10, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm8, ymm10"),
        Q!("    vpaddd          " "ymm8, ymm8, ymm10"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm10, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm6, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm6"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm6, ymm6, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm6, ymm6"),
        Q!("    vpblendd        " "ymm6, ymm6, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm4, ymm6"),
        Q!("    vpaddd          " "ymm4, ymm4, ymm6"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm6, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm4, ymm4, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm11, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm11"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm11, ymm11"),
        Q!("    vpblendd        " "ymm11, ymm11, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm9, ymm11"),
        Q!("    vpaddd          " "ymm9, ymm9, ymm11"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm11, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm13"),

        Q!("    vpunpcklqdq     " "ymm7, ymm3, ymm5"),
        Q!("    vpunpckhqdq     " "ymm5, ymm3, ymm5"),
        Q!("    vpunpcklqdq     " "ymm3, ymm8, ymm10"),
        Q!("    vpunpckhqdq     " "ymm10, ymm8, ymm10"),
        Q!("    vpunpcklqdq     " "ymm8, ymm4, ymm6"),
        Q!("    vpunpckhqdq     " "ymm6, ymm4, ymm6"),
        Q!("    vpunpcklqdq     " "ymm4, ymm9, ymm11"),
        Q!("    vpunpckhqdq     " "ymm11, ymm9, ymm11"),

        // level 4
        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 40 + 8 * 1))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 40 + 8 * 1))]"),

        Q!("    vpmuldq         " "ymm13, ymm8, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm8"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm8, ymm8"),
        Q!("    vpblendd        " "ymm8, ymm8, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm7, ymm8"),
        Q!("    vpaddd          " "ymm7, ymm7, ymm8"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm8, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm6, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm6"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm6, ymm6, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm6, ymm6"),
        Q!("    vpblendd        " "ymm6, ymm6, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm5, ymm6"),
        Q!("    vpaddd          " "ymm5, ymm5, ymm6"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm6, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm4, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm4"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm4, ymm4, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm4, ymm4"),
        Q!("    vpblendd        " "ymm4, ymm4, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm3, ymm4"),
        Q!("    vpaddd          " "ymm3, ymm3, ymm4"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm4, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm3, ymm3, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm11, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm11"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm11, ymm11"),
        Q!("    vpblendd        " "ymm11, ymm11, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm10, ymm11"),
        Q!("    vpaddd          " "ymm10, ymm10, ymm11"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm11, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm10, ymm10, ymm13"),

        Q!("    vmovsldup       " "ymm9, ymm8"),
        Q!("    vpblendd        " "ymm9, ymm7, ymm9, 0xAA"),
        Q!("    vpsrlq          " "ymm7, ymm7, 32"),
        Q!("    vpblendd        " "ymm8, ymm7, ymm8, 0xAA"),
        Q!("    vmovsldup       " "ymm7, ymm6"),
        Q!("    vpblendd        " "ymm7, ymm5, ymm7, 0xAA"),
        Q!("    vpsrlq          " "ymm5, ymm5, 32"),
        Q!("    vpblendd        " "ymm6, ymm5, ymm6, 0xAA"),
        Q!("    vmovsldup       " "ymm5, ymm4"),
        Q!("    vpblendd        " "ymm5, ymm3, ymm5, 0xAA"),
        Q!("    vpsrlq          " "ymm3, ymm3, 32"),
        Q!("    vpblendd        " "ymm4, ymm3, ymm4, 0xAA"),
        Q!("    vmovsldup       " "ymm3, ymm11"),
        Q!("    vpblendd        " "ymm3, ymm10, ymm3, 0xAA"),
        Q!("    vpsrlq          " "ymm10, ymm10, 32"),
        Q!("    vpblendd        " "ymm11, ymm10, ymm11, 0xAA"),

        // level 5
        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 72 + 8 * 1))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 72 + 8 * 1))]"),
        Q!("    vpsrlq          " "ymm10, ymm1, 32"),
        Q!("    vmovshdup       " "ymm15, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm5, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm5"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm5, ymm5, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm5, ymm5"),
        Q!("    vpblendd        " "ymm5, ymm5, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm9, ymm5"),
        Q!("    vpaddd          " "ymm9, ymm9, ymm5"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm5, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm4, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm4"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm4, ymm4, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm4, ymm4"),
        Q!("    vpblendd        " "ymm4, ymm4, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm8, ymm4"),
        Q!("    vpaddd          " "ymm8, ymm8, ymm4"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm4, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm3, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm3"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm3, ymm3, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm3, ymm3"),
        Q!("    vpblendd        " "ymm3, ymm3, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm7, ymm3"),
        Q!("    vpaddd          " "ymm7, ymm7, ymm3"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm3, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm11, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm11"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm11, ymm11"),
        Q!("    vpblendd        " "ymm11, ymm11, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm6, ymm11"),
        Q!("    vpaddd          " "ymm6, ymm6, ymm11"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm11, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm6, ymm6, ymm13"),

        // level 6
        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 104 + 8 * 1))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 104 + 8 * 1))]"),
        Q!("    vpsrlq          " "ymm10, ymm1, 32"),
        Q!("    vmovshdup       " "ymm15, ymm2"),
        Q!("    vpmuldq         " "ymm13, ymm7, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm7"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm7, ymm7, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm7, ymm7"),
        Q!("    vpblendd        " "ymm7, ymm7, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm9, ymm7"),
        Q!("    vpaddd          " "ymm9, ymm9, ymm7"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm7, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm6, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm6"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm6, ymm6, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm6, ymm6"),
        Q!("    vpblendd        " "ymm6, ymm6, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm8, ymm6"),
        Q!("    vpaddd          " "ymm8, ymm8, ymm6"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm6, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm13"),

        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 104 + 8 * 1 + 32))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 104 + 8 * 1 + 32))]"),
        Q!("    vpsrlq          " "ymm10, ymm1, 32"),
        Q!("    vmovshdup       " "ymm15, ymm2"),
        Q!("    vpmuldq         " "ymm13, ymm3, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm3"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm3, ymm3, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm3, ymm3"),
        Q!("    vpblendd        " "ymm3, ymm3, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm5, ymm3"),
        Q!("    vpaddd          " "ymm5, ymm5, ymm3"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm3, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm11, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm11"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm11, ymm11"),
        Q!("    vpblendd        " "ymm11, ymm11, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm4, ymm11"),
        Q!("    vpaddd          " "ymm4, ymm4, ymm11"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm11, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm4, ymm4, ymm13"),

        // level 7
        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 168 + 8 * 1))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 168 + 8 * 1))]"),
        Q!("    vpsrlq          " "ymm10, ymm1, 32"),
        Q!("    vmovshdup       " "ymm15, ymm2"),
        Q!("    vpmuldq         " "ymm13, ymm8, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm8"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm8, ymm8"),
        Q!("    vpblendd        " "ymm8, ymm8, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm9, ymm8"),
        Q!("    vpaddd          " "ymm9, ymm9, ymm8"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm8, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm13"),

        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 168 + 8 * 1 + 32))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 168 + 8 * 1 + 32))]"),
        Q!("    vpsrlq          " "ymm10, ymm1, 32"),
        Q!("    vmovshdup       " "ymm15, ymm2"),
        Q!("    vpmuldq         " "ymm13, ymm6, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm6"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm6, ymm6, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm6, ymm6"),
        Q!("    vpblendd        " "ymm6, ymm6, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm7, ymm6"),
        Q!("    vpaddd          " "ymm7, ymm7, ymm6"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm6, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm13"),

        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 168 + 8 * 1 + 64))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 168 + 8 * 1 + 64))]"),
        Q!("    vpsrlq          " "ymm10, ymm1, 32"),
        Q!("    vmovshdup       " "ymm15, ymm2"),
        Q!("    vpmuldq         " "ymm13, ymm4, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm4"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm4, ymm4, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm4, ymm4"),
        Q!("    vpblendd        " "ymm4, ymm4, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm5, ymm4"),
        Q!("    vpaddd          " "ymm5, ymm5, ymm4"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm4, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm13"),

        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 168 + 8 * 1 + 96))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 168 + 8 * 1 + 96))]"),
        Q!("    vpsrlq          " "ymm10, ymm1, 32"),
        Q!("    vmovshdup       " "ymm15, ymm2"),
        Q!("    vpmuldq         " "ymm13, ymm11, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm11"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm11, ymm11"),
        Q!("    vpblendd        " "ymm11, ymm11, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm3, ymm11"),
        Q!("    vpaddd          " "ymm3, ymm3, ymm11"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm11, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm3, ymm3, ymm13"),

        Q!("    vmovdqa         " "[rdi + 0 + 256 * 1], ymm9"),
        Q!("    vmovdqa         " "[rdi + 32 + 256 * 1], ymm8"),
        Q!("    vmovdqa         " "[rdi + 64 + 256 * 1], ymm7"),
        Q!("    vmovdqa         " "[rdi + 96 + 256 * 1], ymm6"),
        Q!("    vmovdqa         " "[rdi + 128 + 256 * 1], ymm5"),
        Q!("    vmovdqa         " "[rdi + 160 + 256 * 1], ymm4"),
        Q!("    vmovdqa         " "[rdi + 192 + 256 * 1], ymm3"),
        Q!("    vmovdqa         " "[rdi + 224 + 256 * 1], ymm11"),
        // level 2
        Q!("    vmovdqa         " "ymm4, [rdi + 0 + 256 * 2]"),
        Q!("    vmovdqa         " "ymm5, [rdi + 32 + 256 * 2]"),
        Q!("    vmovdqa         " "ymm6, [rdi + 64 + 256 * 2]"),
        Q!("    vmovdqa         " "ymm7, [rdi + 96 + 256 * 2]"),
        Q!("    vmovdqa         " "ymm8, [rdi + 128 + 256 * 2]"),
        Q!("    vmovdqa         " "ymm9, [rdi + 160 + 256 * 2]"),
        Q!("    vmovdqa         " "ymm10, [rdi + 192 + 256 * 2]"),
        Q!("    vmovdqa         " "ymm11, [rdi + 224 + 256 * 2]"),
        Q!("    vpbroadcastd    " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 4 + 2))]"),
        Q!("    vpbroadcastd    " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 4 + 2))]"),

        Q!("    vpmuldq         " "ymm13, ymm8, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm8"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm8, ymm8"),
        Q!("    vpblendd        " "ymm8, ymm8, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm4, ymm8"),
        Q!("    vpaddd          " "ymm4, ymm4, ymm8"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm8, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm4, ymm4, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm9, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm9"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm9, ymm9, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm9, ymm9"),
        Q!("    vpblendd        " "ymm9, ymm9, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm5, ymm9"),
        Q!("    vpaddd          " "ymm5, ymm5, ymm9"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm9, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm10, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm10"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm10, ymm10, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm10, ymm10"),
        Q!("    vpblendd        " "ymm10, ymm10, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm6, ymm10"),
        Q!("    vpaddd          " "ymm6, ymm6, ymm10"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm10, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm6, ymm6, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm11, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm11"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm11, ymm11"),
        Q!("    vpblendd        " "ymm11, ymm11, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm7, ymm11"),
        Q!("    vpaddd          " "ymm7, ymm7, ymm11"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm11, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm13"),

        Q!("    vperm2i128      " "ymm3, ymm4, ymm8, 0x20"),
        Q!("    vperm2i128      " "ymm8, ymm4, ymm8, 0x31"),
        Q!("    vperm2i128      " "ymm4, ymm5, ymm9, 0x20"),
        Q!("    vperm2i128      " "ymm9, ymm5, ymm9, 0x31"),
        Q!("    vperm2i128      " "ymm5, ymm6, ymm10, 0x20"),
        Q!("    vperm2i128      " "ymm10, ymm6, ymm10, 0x31"),
        Q!("    vperm2i128      " "ymm6, ymm7, ymm11, 0x20"),
        Q!("    vperm2i128      " "ymm11, ymm7, ymm11, 0x31"),

        // level 3
        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 8 + 8 * 2))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 8 + 8 * 2))]"),

        Q!("    vpmuldq         " "ymm13, ymm5, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm5"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm5, ymm5, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm5, ymm5"),
        Q!("    vpblendd        " "ymm5, ymm5, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm3, ymm5"),
        Q!("    vpaddd          " "ymm3, ymm3, ymm5"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm5, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm3, ymm3, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm10, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm10"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm10, ymm10, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm10, ymm10"),
        Q!("    vpblendd        " "ymm10, ymm10, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm8, ymm10"),
        Q!("    vpaddd          " "ymm8, ymm8, ymm10"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm10, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm6, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm6"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm6, ymm6, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm6, ymm6"),
        Q!("    vpblendd        " "ymm6, ymm6, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm4, ymm6"),
        Q!("    vpaddd          " "ymm4, ymm4, ymm6"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm6, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm4, ymm4, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm11, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm11"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm11, ymm11"),
        Q!("    vpblendd        " "ymm11, ymm11, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm9, ymm11"),
        Q!("    vpaddd          " "ymm9, ymm9, ymm11"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm11, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm13"),

        Q!("    vpunpcklqdq     " "ymm7, ymm3, ymm5"),
        Q!("    vpunpckhqdq     " "ymm5, ymm3, ymm5"),
        Q!("    vpunpcklqdq     " "ymm3, ymm8, ymm10"),
        Q!("    vpunpckhqdq     " "ymm10, ymm8, ymm10"),
        Q!("    vpunpcklqdq     " "ymm8, ymm4, ymm6"),
        Q!("    vpunpckhqdq     " "ymm6, ymm4, ymm6"),
        Q!("    vpunpcklqdq     " "ymm4, ymm9, ymm11"),
        Q!("    vpunpckhqdq     " "ymm11, ymm9, ymm11"),

        // level 4
        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 40 + 8 * 2))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 40 + 8 * 2))]"),

        Q!("    vpmuldq         " "ymm13, ymm8, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm8"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm8, ymm8"),
        Q!("    vpblendd        " "ymm8, ymm8, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm7, ymm8"),
        Q!("    vpaddd          " "ymm7, ymm7, ymm8"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm8, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm6, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm6"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm6, ymm6, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm6, ymm6"),
        Q!("    vpblendd        " "ymm6, ymm6, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm5, ymm6"),
        Q!("    vpaddd          " "ymm5, ymm5, ymm6"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm6, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm4, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm4"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm4, ymm4, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm4, ymm4"),
        Q!("    vpblendd        " "ymm4, ymm4, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm3, ymm4"),
        Q!("    vpaddd          " "ymm3, ymm3, ymm4"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm4, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm3, ymm3, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm11, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm11"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm11, ymm11"),
        Q!("    vpblendd        " "ymm11, ymm11, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm10, ymm11"),
        Q!("    vpaddd          " "ymm10, ymm10, ymm11"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm11, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm10, ymm10, ymm13"),

        Q!("    vmovsldup       " "ymm9, ymm8"),
        Q!("    vpblendd        " "ymm9, ymm7, ymm9, 0xAA"),
        Q!("    vpsrlq          " "ymm7, ymm7, 32"),
        Q!("    vpblendd        " "ymm8, ymm7, ymm8, 0xAA"),
        Q!("    vmovsldup       " "ymm7, ymm6"),
        Q!("    vpblendd        " "ymm7, ymm5, ymm7, 0xAA"),
        Q!("    vpsrlq          " "ymm5, ymm5, 32"),
        Q!("    vpblendd        " "ymm6, ymm5, ymm6, 0xAA"),
        Q!("    vmovsldup       " "ymm5, ymm4"),
        Q!("    vpblendd        " "ymm5, ymm3, ymm5, 0xAA"),
        Q!("    vpsrlq          " "ymm3, ymm3, 32"),
        Q!("    vpblendd        " "ymm4, ymm3, ymm4, 0xAA"),
        Q!("    vmovsldup       " "ymm3, ymm11"),
        Q!("    vpblendd        " "ymm3, ymm10, ymm3, 0xAA"),
        Q!("    vpsrlq          " "ymm10, ymm10, 32"),
        Q!("    vpblendd        " "ymm11, ymm10, ymm11, 0xAA"),

        // level 5
        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 72 + 8 * 2))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 72 + 8 * 2))]"),
        Q!("    vpsrlq          " "ymm10, ymm1, 32"),
        Q!("    vmovshdup       " "ymm15, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm5, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm5"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm5, ymm5, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm5, ymm5"),
        Q!("    vpblendd        " "ymm5, ymm5, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm9, ymm5"),
        Q!("    vpaddd          " "ymm9, ymm9, ymm5"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm5, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm4, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm4"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm4, ymm4, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm4, ymm4"),
        Q!("    vpblendd        " "ymm4, ymm4, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm8, ymm4"),
        Q!("    vpaddd          " "ymm8, ymm8, ymm4"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm4, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm3, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm3"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm3, ymm3, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm3, ymm3"),
        Q!("    vpblendd        " "ymm3, ymm3, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm7, ymm3"),
        Q!("    vpaddd          " "ymm7, ymm7, ymm3"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm3, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm11, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm11"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm11, ymm11"),
        Q!("    vpblendd        " "ymm11, ymm11, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm6, ymm11"),
        Q!("    vpaddd          " "ymm6, ymm6, ymm11"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm11, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm6, ymm6, ymm13"),

        // level 6
        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 104 + 8 * 2))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 104 + 8 * 2))]"),
        Q!("    vpsrlq          " "ymm10, ymm1, 32"),
        Q!("    vmovshdup       " "ymm15, ymm2"),
        Q!("    vpmuldq         " "ymm13, ymm7, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm7"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm7, ymm7, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm7, ymm7"),
        Q!("    vpblendd        " "ymm7, ymm7, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm9, ymm7"),
        Q!("    vpaddd          " "ymm9, ymm9, ymm7"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm7, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm6, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm6"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm6, ymm6, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm6, ymm6"),
        Q!("    vpblendd        " "ymm6, ymm6, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm8, ymm6"),
        Q!("    vpaddd          " "ymm8, ymm8, ymm6"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm6, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm13"),

        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 104 + 8 * 2 + 32))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 104 + 8 * 2 + 32))]"),
        Q!("    vpsrlq          " "ymm10, ymm1, 32"),
        Q!("    vmovshdup       " "ymm15, ymm2"),
        Q!("    vpmuldq         " "ymm13, ymm3, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm3"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm3, ymm3, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm3, ymm3"),
        Q!("    vpblendd        " "ymm3, ymm3, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm5, ymm3"),
        Q!("    vpaddd          " "ymm5, ymm5, ymm3"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm3, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm11, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm11"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm11, ymm11"),
        Q!("    vpblendd        " "ymm11, ymm11, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm4, ymm11"),
        Q!("    vpaddd          " "ymm4, ymm4, ymm11"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm11, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm4, ymm4, ymm13"),

        // level 7
        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 168 + 8 * 2))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 168 + 8 * 2))]"),
        Q!("    vpsrlq          " "ymm10, ymm1, 32"),
        Q!("    vmovshdup       " "ymm15, ymm2"),
        Q!("    vpmuldq         " "ymm13, ymm8, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm8"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm8, ymm8"),
        Q!("    vpblendd        " "ymm8, ymm8, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm9, ymm8"),
        Q!("    vpaddd          " "ymm9, ymm9, ymm8"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm8, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm13"),

        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 168 + 8 * 2 + 32))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 168 + 8 * 2 + 32))]"),
        Q!("    vpsrlq          " "ymm10, ymm1, 32"),
        Q!("    vmovshdup       " "ymm15, ymm2"),
        Q!("    vpmuldq         " "ymm13, ymm6, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm6"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm6, ymm6, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm6, ymm6"),
        Q!("    vpblendd        " "ymm6, ymm6, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm7, ymm6"),
        Q!("    vpaddd          " "ymm7, ymm7, ymm6"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm6, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm13"),

        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 168 + 8 * 2 + 64))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 168 + 8 * 2 + 64))]"),
        Q!("    vpsrlq          " "ymm10, ymm1, 32"),
        Q!("    vmovshdup       " "ymm15, ymm2"),
        Q!("    vpmuldq         " "ymm13, ymm4, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm4"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm4, ymm4, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm4, ymm4"),
        Q!("    vpblendd        " "ymm4, ymm4, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm5, ymm4"),
        Q!("    vpaddd          " "ymm5, ymm5, ymm4"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm4, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm13"),

        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 168 + 8 * 2 + 96))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 168 + 8 * 2 + 96))]"),
        Q!("    vpsrlq          " "ymm10, ymm1, 32"),
        Q!("    vmovshdup       " "ymm15, ymm2"),
        Q!("    vpmuldq         " "ymm13, ymm11, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm11"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm11, ymm11"),
        Q!("    vpblendd        " "ymm11, ymm11, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm3, ymm11"),
        Q!("    vpaddd          " "ymm3, ymm3, ymm11"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm11, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm3, ymm3, ymm13"),

        Q!("    vmovdqa         " "[rdi + 0 + 256 * 2], ymm9"),
        Q!("    vmovdqa         " "[rdi + 32 + 256 * 2], ymm8"),
        Q!("    vmovdqa         " "[rdi + 64 + 256 * 2], ymm7"),
        Q!("    vmovdqa         " "[rdi + 96 + 256 * 2], ymm6"),
        Q!("    vmovdqa         " "[rdi + 128 + 256 * 2], ymm5"),
        Q!("    vmovdqa         " "[rdi + 160 + 256 * 2], ymm4"),
        Q!("    vmovdqa         " "[rdi + 192 + 256 * 2], ymm3"),
        Q!("    vmovdqa         " "[rdi + 224 + 256 * 2], ymm11"),
        // level 2
        Q!("    vmovdqa         " "ymm4, [rdi + 0 + 256 * 3]"),
        Q!("    vmovdqa         " "ymm5, [rdi + 32 + 256 * 3]"),
        Q!("    vmovdqa         " "ymm6, [rdi + 64 + 256 * 3]"),
        Q!("    vmovdqa         " "ymm7, [rdi + 96 + 256 * 3]"),
        Q!("    vmovdqa         " "ymm8, [rdi + 128 + 256 * 3]"),
        Q!("    vmovdqa         " "ymm9, [rdi + 160 + 256 * 3]"),
        Q!("    vmovdqa         " "ymm10, [rdi + 192 + 256 * 3]"),
        Q!("    vmovdqa         " "ymm11, [rdi + 224 + 256 * 3]"),
        Q!("    vpbroadcastd    " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 4 + 3))]"),
        Q!("    vpbroadcastd    " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 4 + 3))]"),

        Q!("    vpmuldq         " "ymm13, ymm8, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm8"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm8, ymm8"),
        Q!("    vpblendd        " "ymm8, ymm8, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm4, ymm8"),
        Q!("    vpaddd          " "ymm4, ymm4, ymm8"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm8, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm4, ymm4, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm9, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm9"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm9, ymm9, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm9, ymm9"),
        Q!("    vpblendd        " "ymm9, ymm9, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm5, ymm9"),
        Q!("    vpaddd          " "ymm5, ymm5, ymm9"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm9, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm10, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm10"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm10, ymm10, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm10, ymm10"),
        Q!("    vpblendd        " "ymm10, ymm10, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm6, ymm10"),
        Q!("    vpaddd          " "ymm6, ymm6, ymm10"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm10, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm6, ymm6, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm11, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm11"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm11, ymm11"),
        Q!("    vpblendd        " "ymm11, ymm11, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm7, ymm11"),
        Q!("    vpaddd          " "ymm7, ymm7, ymm11"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm11, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm13"),

        Q!("    vperm2i128      " "ymm3, ymm4, ymm8, 0x20"),
        Q!("    vperm2i128      " "ymm8, ymm4, ymm8, 0x31"),
        Q!("    vperm2i128      " "ymm4, ymm5, ymm9, 0x20"),
        Q!("    vperm2i128      " "ymm9, ymm5, ymm9, 0x31"),
        Q!("    vperm2i128      " "ymm5, ymm6, ymm10, 0x20"),
        Q!("    vperm2i128      " "ymm10, ymm6, ymm10, 0x31"),
        Q!("    vperm2i128      " "ymm6, ymm7, ymm11, 0x20"),
        Q!("    vperm2i128      " "ymm11, ymm7, ymm11, 0x31"),

        // level 3
        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 8 + 8 * 3))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 8 + 8 * 3))]"),

        Q!("    vpmuldq         " "ymm13, ymm5, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm5"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm5, ymm5, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm5, ymm5"),
        Q!("    vpblendd        " "ymm5, ymm5, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm3, ymm5"),
        Q!("    vpaddd          " "ymm3, ymm3, ymm5"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm5, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm3, ymm3, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm10, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm10"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm10, ymm10, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm10, ymm10"),
        Q!("    vpblendd        " "ymm10, ymm10, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm8, ymm10"),
        Q!("    vpaddd          " "ymm8, ymm8, ymm10"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm10, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm6, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm6"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm6, ymm6, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm6, ymm6"),
        Q!("    vpblendd        " "ymm6, ymm6, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm4, ymm6"),
        Q!("    vpaddd          " "ymm4, ymm4, ymm6"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm6, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm4, ymm4, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm11, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm11"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm11, ymm11"),
        Q!("    vpblendd        " "ymm11, ymm11, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm9, ymm11"),
        Q!("    vpaddd          " "ymm9, ymm9, ymm11"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm11, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm13"),

        Q!("    vpunpcklqdq     " "ymm7, ymm3, ymm5"),
        Q!("    vpunpckhqdq     " "ymm5, ymm3, ymm5"),
        Q!("    vpunpcklqdq     " "ymm3, ymm8, ymm10"),
        Q!("    vpunpckhqdq     " "ymm10, ymm8, ymm10"),
        Q!("    vpunpcklqdq     " "ymm8, ymm4, ymm6"),
        Q!("    vpunpckhqdq     " "ymm6, ymm4, ymm6"),
        Q!("    vpunpcklqdq     " "ymm4, ymm9, ymm11"),
        Q!("    vpunpckhqdq     " "ymm11, ymm9, ymm11"),

        // level 4
        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 40 + 8 * 3))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 40 + 8 * 3))]"),

        Q!("    vpmuldq         " "ymm13, ymm8, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm8"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm8, ymm8"),
        Q!("    vpblendd        " "ymm8, ymm8, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm7, ymm8"),
        Q!("    vpaddd          " "ymm7, ymm7, ymm8"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm8, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm6, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm6"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm6, ymm6, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm6, ymm6"),
        Q!("    vpblendd        " "ymm6, ymm6, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm5, ymm6"),
        Q!("    vpaddd          " "ymm5, ymm5, ymm6"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm6, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm4, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm4"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm4, ymm4, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm4, ymm4"),
        Q!("    vpblendd        " "ymm4, ymm4, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm3, ymm4"),
        Q!("    vpaddd          " "ymm3, ymm3, ymm4"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm4, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm3, ymm3, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm11, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm11"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm1"),

        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm11, ymm11"),
        Q!("    vpblendd        " "ymm11, ymm11, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm10, ymm11"),
        Q!("    vpaddd          " "ymm10, ymm10, ymm11"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm11, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm10, ymm10, ymm13"),

        Q!("    vmovsldup       " "ymm9, ymm8"),
        Q!("    vpblendd        " "ymm9, ymm7, ymm9, 0xAA"),
        Q!("    vpsrlq          " "ymm7, ymm7, 32"),
        Q!("    vpblendd        " "ymm8, ymm7, ymm8, 0xAA"),
        Q!("    vmovsldup       " "ymm7, ymm6"),
        Q!("    vpblendd        " "ymm7, ymm5, ymm7, 0xAA"),
        Q!("    vpsrlq          " "ymm5, ymm5, 32"),
        Q!("    vpblendd        " "ymm6, ymm5, ymm6, 0xAA"),
        Q!("    vmovsldup       " "ymm5, ymm4"),
        Q!("    vpblendd        " "ymm5, ymm3, ymm5, 0xAA"),
        Q!("    vpsrlq          " "ymm3, ymm3, 32"),
        Q!("    vpblendd        " "ymm4, ymm3, ymm4, 0xAA"),
        Q!("    vmovsldup       " "ymm3, ymm11"),
        Q!("    vpblendd        " "ymm3, ymm10, ymm3, 0xAA"),
        Q!("    vpsrlq          " "ymm10, ymm10, 32"),
        Q!("    vpblendd        " "ymm11, ymm10, ymm11, 0xAA"),

        // level 5
        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 72 + 8 * 3))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 72 + 8 * 3))]"),
        Q!("    vpsrlq          " "ymm10, ymm1, 32"),
        Q!("    vmovshdup       " "ymm15, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm5, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm5"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm5, ymm5, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm5, ymm5"),
        Q!("    vpblendd        " "ymm5, ymm5, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm9, ymm5"),
        Q!("    vpaddd          " "ymm9, ymm9, ymm5"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm5, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm4, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm4"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm4, ymm4, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm4, ymm4"),
        Q!("    vpblendd        " "ymm4, ymm4, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm8, ymm4"),
        Q!("    vpaddd          " "ymm8, ymm8, ymm4"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm4, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm3, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm3"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm3, ymm3, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm3, ymm3"),
        Q!("    vpblendd        " "ymm3, ymm3, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm7, ymm3"),
        Q!("    vpaddd          " "ymm7, ymm7, ymm3"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm3, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm11, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm11"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm11, ymm11"),
        Q!("    vpblendd        " "ymm11, ymm11, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm6, ymm11"),
        Q!("    vpaddd          " "ymm6, ymm6, ymm11"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm11, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm6, ymm6, ymm13"),

        // level 6
        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 104 + 8 * 3))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 104 + 8 * 3))]"),
        Q!("    vpsrlq          " "ymm10, ymm1, 32"),
        Q!("    vmovshdup       " "ymm15, ymm2"),
        Q!("    vpmuldq         " "ymm13, ymm7, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm7"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm7, ymm7, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm7, ymm7"),
        Q!("    vpblendd        " "ymm7, ymm7, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm9, ymm7"),
        Q!("    vpaddd          " "ymm9, ymm9, ymm7"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm7, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm6, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm6"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm6, ymm6, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm6, ymm6"),
        Q!("    vpblendd        " "ymm6, ymm6, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm8, ymm6"),
        Q!("    vpaddd          " "ymm8, ymm8, ymm6"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm6, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm13"),

        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 104 + 8 * 3 + 32))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 104 + 8 * 3 + 32))]"),
        Q!("    vpsrlq          " "ymm10, ymm1, 32"),
        Q!("    vmovshdup       " "ymm15, ymm2"),
        Q!("    vpmuldq         " "ymm13, ymm3, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm3"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm3, ymm3, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm3, ymm3"),
        Q!("    vpblendd        " "ymm3, ymm3, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm5, ymm3"),
        Q!("    vpaddd          " "ymm5, ymm5, ymm3"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm3, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm13"),
        Q!("    vpmuldq         " "ymm13, ymm11, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm11"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm11, ymm11"),
        Q!("    vpblendd        " "ymm11, ymm11, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm4, ymm11"),
        Q!("    vpaddd          " "ymm4, ymm4, ymm11"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm11, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm4, ymm4, ymm13"),

        // level 7
        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 168 + 8 * 3))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 168 + 8 * 3))]"),
        Q!("    vpsrlq          " "ymm10, ymm1, 32"),
        Q!("    vmovshdup       " "ymm15, ymm2"),
        Q!("    vpmuldq         " "ymm13, ymm8, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm8"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm8, ymm8"),
        Q!("    vpblendd        " "ymm8, ymm8, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm9, ymm8"),
        Q!("    vpaddd          " "ymm9, ymm9, ymm8"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm8, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm13"),

        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 168 + 8 * 3 + 32))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 168 + 8 * 3 + 32))]"),
        Q!("    vpsrlq          " "ymm10, ymm1, 32"),
        Q!("    vmovshdup       " "ymm15, ymm2"),
        Q!("    vpmuldq         " "ymm13, ymm6, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm6"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm6, ymm6, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm6, ymm6"),
        Q!("    vpblendd        " "ymm6, ymm6, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm7, ymm6"),
        Q!("    vpaddd          " "ymm7, ymm7, ymm6"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm6, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm13"),

        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 168 + 8 * 3 + 64))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 168 + 8 * 3 + 64))]"),
        Q!("    vpsrlq          " "ymm10, ymm1, 32"),
        Q!("    vmovshdup       " "ymm15, ymm2"),
        Q!("    vpmuldq         " "ymm13, ymm4, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm4"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm4, ymm4, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm4, ymm4"),
        Q!("    vpblendd        " "ymm4, ymm4, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm5, ymm4"),
        Q!("    vpaddd          " "ymm5, ymm5, ymm4"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm4, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm13"),

        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 168 + 8 * 3 + 96))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 168 + 8 * 3 + 96))]"),
        Q!("    vpsrlq          " "ymm10, ymm1, 32"),
        Q!("    vmovshdup       " "ymm15, ymm2"),
        Q!("    vpmuldq         " "ymm13, ymm11, ymm1"),
        Q!("    vmovshdup       " "ymm12, ymm11"),
        Q!("    vpmuldq         " "ymm14, ymm12, ymm10"),

        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vmovshdup       " "ymm11, ymm11"),
        Q!("    vpblendd        " "ymm11, ymm11, ymm12, 0xAA"),

        Q!("    vpsubd          " "ymm12, ymm3, ymm11"),
        Q!("    vpaddd          " "ymm3, ymm3, ymm11"),

        Q!("    vmovshdup       " "ymm13, ymm13"),
        Q!("    vpblendd        " "ymm13, ymm13, ymm14, 0xAA"),

        Q!("    vpaddd          " "ymm11, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm3, ymm3, ymm13"),

        Q!("    vmovdqa         " "[rdi + 0 + 256 * 3], ymm9"),
        Q!("    vmovdqa         " "[rdi + 32 + 256 * 3], ymm8"),
        Q!("    vmovdqa         " "[rdi + 64 + 256 * 3], ymm7"),
        Q!("    vmovdqa         " "[rdi + 96 + 256 * 3], ymm6"),
        Q!("    vmovdqa         " "[rdi + 128 + 256 * 3], ymm5"),
        Q!("    vmovdqa         " "[rdi + 160 + 256 * 3], ymm4"),
        Q!("    vmovdqa         " "[rdi + 192 + 256 * 3], ymm3"),
        Q!("    vmovdqa         " "[rdi + 224 + 256 * 3], ymm11"),

        Q!("    vzeroupper      " ),
        inout("rdi") a.as_mut_ptr() => _,
        inout("rsi") qdata.as_ptr() => _,
        // clobbers
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
        mldsa_ntt,
        &mut crate::low::abi::Aligned([0; 256]).0,
        &crate::low::abi::Aligned([0; 624]).0
    );
}
