// generated source. do not edit.
#![allow(non_upper_case_globals, unused_macros, unused_imports)]
use crate::low::macros::*;

// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT

// ----------------------------------------------------------------------------
// Inverse number-theoretic transform for ML-DSA
// Input a[256], zetas (all signed 32-bit words); output a[256] (signed 32-bit words)
//
// The transform is in-place with input and output a[256]. Computes the inverse
// NTT of a polynomial in place, transforming from NTT representation to coefficient
// representation. The input polynomial a is a 256-element array of signed 32-bit
// integers representing coefficients in NTT domain, with each coefficient bounded
// by |a[i]| < Q. The zetas parameter points to precomputed twiddle factors
// (roots of unity and their Montgomery inverses) required for the inverse NTT
// computation.
//
// The output polynomial is in coefficient representation (normal order) with
// coefficients in Montgomery form, each bounded by |a[i]| < Q.
// The inverse NTT includes the division by 256 (the transform size) and maps the
// result to Montgomery domain via multiplication by 2^32/256 = 2^24.
//
// The implementation uses Montgomery arithmetic for efficient modular reduction
// modulo Q = 8380417, maintaining constant-time execution for side-channel
// resistance. The transform operates in the ring R_Q = Z_Q[x]/(x^256 + 1).
//
// extern void mldsa_intt(int32_t a[static 256], const int32_t zetas[static 624]);
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

//
// Compute l' = l + h, h' = montmul(h - l, zh)
//
// Bounds: |l'| <= |l| + |h|
// |h'| < MONTMUL_BOUND
// (See the end of this file for the exact value of MONTMUL_BOUND)
//
// The flip parameter controls VEX encoding optimization for platform-independent
// code. Set flip=1 when h is in ymm0-7 and l is in ymm8-15 to enable the 2-byte
// VEX encoding; otherwise set flip=0.
//
// VEX Encoding Optimization for Platform-Independent Code
//
// Some assemblers (notably clang) will automatically swap operands of
// commutative instructions like VPADDD to use shorter encodings, while others
// (like gcc) may not. This causes different machine code across platforms.
//
// VEX prefixes come in two forms:
// - 2-byte VEX (0xC5): Can only be used when the ModR/M.rm operand is ymm0-7
// - 3-byte VEX (0xC4): Required when ModR/M.rm operand is ymm8-15
//
// When one operand is in ymm0-7 and another is in ymm8-15, we explicitly
// place the lower-numbered register (ymm0-7) as the second source operand
// to enable the 2-byte VEX encoding. Since VPADDD is commutative, this
// produces identical results while ensuring consistent machine code across
// different assemblers.
//
// Example:
// VPADDD ymm4, ymm4, ymm8  -> 3-byte VEX (0xC4 0xC1 0x5D 0xFE 0xE0)
// VPADDD ymm4, ymm8, ymm4  -> 2-byte VEX (0xC5 0xBD 0xFE 0xE4) preferred
//

// Transliterated from s2n-bignum's x86/mldsa/mldsa_intt.S.
/// Inverse number-theoretic transform for ML-DSA
///
/// Input a[256], zetas (all signed 32-bit words); output a[256] (signed 32-bit words)
///
/// The transform is in-place with input and output a[256]. Computes the inverse
/// NTT of a polynomial in place, transforming from NTT representation to coefficient
/// representation. The input polynomial a is a 256-element array of signed 32-bit
/// integers representing coefficients in NTT domain, with each coefficient bounded
/// by |a[i]| < Q. The zetas parameter points to precomputed twiddle factors
/// (roots of unity and their Montgomery inverses) required for the inverse NTT
/// computation.
///
/// The output polynomial is in coefficient representation (normal order) with
/// coefficients in Montgomery form, each bounded by |a[i]| < Q.
/// The inverse NTT includes the division by 256 (the transform size) and maps the
/// result to Montgomery domain via multiplication by 2^32/256 = 2^24.
///
/// The implementation uses Montgomery arithmetic for efficient modular reduction
/// modulo Q = 8380417, maintaining constant-time execution for side-channel
/// resistance. The transform operates in the ring R_Q = Z_Q[x]/(x^256 + 1).
#[inline(never)]
pub(crate) fn mldsa_intt(a: &mut [i32; 256], qdata: &[i32; 624]) {
    assert!((a.as_mut_ptr() as usize).is_multiple_of(32));
    assert!((qdata.as_ptr() as usize).is_multiple_of(32));
    // SAFETY: inline assembly. see [crate::low::inline_assembly_safety] for safety info.
    unsafe {
        core::arch::asm!(

        Q!("    endbr64         " ),

        Q!("    vmovdqa         " "ymm0, [rsi + " MLD_AVX2_BACKEND_DATA_OFFSET_8XQ!() "* 4]"),

        Q!("    vmovdqa         " "ymm4, [rdi + 256 * 0 + 0]"),
        Q!("    vmovdqa         " "ymm5, [rdi + 256 * 0 + 32]"),
        Q!("    vmovdqa         " "ymm6, [rdi + 256 * 0 + 64]"),
        Q!("    vmovdqa         " "ymm7, [rdi + 256 * 0 + 96]"),
        Q!("    vmovdqa         " "ymm8, [rdi + 256 * 0 + 128]"),
        Q!("    vmovdqa         " "ymm9, [rdi + 256 * 0 + 160]"),
        Q!("    vmovdqa         " "ymm10, [rdi + 256 * 0 + 192]"),
        Q!("    vmovdqa         " "ymm11, [rdi + 256 * 0 + 224]"),

        // Bounds: |ymm{i}| < q for i in 4...11

        // level 0
        Q!("    vpermq          " "ymm3, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 296 -8 * 0 -8))], 0x1B"),
        Q!("    vpermq          " "ymm15, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 296 -8 * 0 -8))], 0x1B"),
        Q!("    vmovshdup       " "ymm1, ymm3"),
        Q!("    vmovshdup       " "ymm2, ymm15"),
        Q!("    vpsubd          " "ymm12, ymm5, ymm4"),
        Q!("    vpaddd          " "ymm4, ymm5, ymm4"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm5, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm5, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm5, ymm5, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm5, ymm12, ymm5, 0xAA"),

        Q!("    vpermq          " "ymm3, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 296 -8 * 0 -40))], 0x1B"),
        Q!("    vpermq          " "ymm15, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 296 -8 * 0 -40))], 0x1B"),
        Q!("    vmovshdup       " "ymm1, ymm3"),
        Q!("    vmovshdup       " "ymm2, ymm15"),
        Q!("    vpsubd          " "ymm12, ymm7, ymm6"),
        Q!("    vpaddd          " "ymm6, ymm7, ymm6"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm7, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm7, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm7, ymm7, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm7, ymm12, ymm7, 0xAA"),

        Q!("    vpermq          " "ymm3, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 296 -8 * 0 -72))], 0x1B"),
        Q!("    vpermq          " "ymm15, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 296 -8 * 0 -72))], 0x1B"),
        Q!("    vmovshdup       " "ymm1, ymm3"),
        Q!("    vmovshdup       " "ymm2, ymm15"),
        Q!("    vpsubd          " "ymm12, ymm9, ymm8"),
        Q!("    vpaddd          " "ymm8, ymm9, ymm8"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm9, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm9, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm9, ymm9, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm9, ymm12, ymm9, 0xAA"),

        Q!("    vpermq          " "ymm3, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 296 -8 * 0 -104))], 0x1B"),
        Q!("    vpermq          " "ymm15, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 296 -8 * 0 -104))], 0x1B"),
        Q!("    vmovshdup       " "ymm1, ymm3"),
        Q!("    vmovshdup       " "ymm2, ymm15"),
        Q!("    vpsubd          " "ymm12, ymm11, ymm10"),
        Q!("    vpaddd          " "ymm10, ymm11, ymm10"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm11, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm11, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm11, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm11, ymm12, ymm11, 0xAA"),

        //
        // Bounds: |ymm{i}| < 2q            for i in 4, 6, 8, 10
        // < MONTMUL_BOUND for i in 5, 7, 9, 11
        //
        // Note that since 2^31 / q > 256, the sum of all 256 coefficients does not
        // overflow. This allows us to greatly simplify the range analysis by relaxing
        // and unifying the bounds of all coefficients on the same layer. As a concrete
        // example, here we relax the bounds on 5, 7, 9, 11 and conclude that (for all
        // relevant i)
        //
        // Bounds: |ymm{i}| < 2q
        //
        // In all but last of the following levels of butterflies, we do the same
        // relaxation without explicit mention.
        //

        // level 1
        Q!("    vpermq          " "ymm3, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 168 -8 * 0 -8))], 0x1B"),
        Q!("    vpermq          " "ymm15, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 168 -8 * 0 -8))], 0x1B"),
        Q!("    vmovshdup       " "ymm1, ymm3"),
        Q!("    vmovshdup       " "ymm2, ymm15"),
        Q!("    vpsubd          " "ymm12, ymm6, ymm4"),
        Q!("    vpaddd          " "ymm4, ymm6, ymm4"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm6, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm6, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm6, ymm6, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm6, ymm6, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm6, ymm12, ymm6, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm7, ymm5"),
        Q!("    vpaddd          " "ymm5, ymm7, ymm5"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm7, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm7, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm7, ymm7, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm7, ymm12, ymm7, 0xAA"),

        Q!("    vpermq          " "ymm3, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 168 -8 * 0 -40))], 0x1B"),
        Q!("    vpermq          " "ymm15, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 168 -8 * 0 -40))], 0x1B"),
        Q!("    vmovshdup       " "ymm1, ymm3"),
        Q!("    vmovshdup       " "ymm2, ymm15"),
        Q!("    vpsubd          " "ymm12, ymm10, ymm8"),
        Q!("    vpaddd          " "ymm8, ymm10, ymm8"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm10, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm10, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm10, ymm10, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm10, ymm10, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm10, ymm12, ymm10, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm11, ymm9"),
        Q!("    vpaddd          " "ymm9, ymm11, ymm9"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm11, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm11, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm11, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm11, ymm12, ymm11, 0xAA"),

        // Bounds: |ymm{i}| < 4q

        // level 2
        Q!("    vpermq          " "ymm3, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 104 -8 * 0 -8))], 0x1B"),
        Q!("    vpermq          " "ymm15, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 104 -8 * 0 -8))], 0x1B"),
        Q!("    vmovshdup       " "ymm1, ymm3"),
        Q!("    vmovshdup       " "ymm2, ymm15"),
        Q!("    vpsubd          " "ymm12, ymm8, ymm4"),
        Q!("    vpaddd          " "ymm4, ymm8, ymm4"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm8, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm8, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm8, ymm8, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm8, ymm12, ymm8, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm9, ymm5"),
        Q!("    vpaddd          " "ymm5, ymm9, ymm5"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm9, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm9, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm9, ymm9, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm9, ymm12, ymm9, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm10, ymm6"),
        Q!("    vpaddd          " "ymm6, ymm10, ymm6"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm10, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm10, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm10, ymm10, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm10, ymm10, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm10, ymm12, ymm10, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm11, ymm7"),
        Q!("    vpaddd          " "ymm7, ymm11, ymm7"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm11, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm11, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm11, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm11, ymm12, ymm11, 0xAA"),

        // Bounds: |ymm{i}| < 8q

        // level 3
        Q!("    vmovsldup       " "ymm3, ymm5"),
        Q!("    vpblendd        " "ymm3, ymm4, ymm3, 0xAA"),
        Q!("    vpsrlq          " "ymm4, ymm4, 32"),
        Q!("    vpblendd        " "ymm5, ymm4, ymm5, 0xAA"),
        Q!("    vmovsldup       " "ymm4, ymm7"),
        Q!("    vpblendd        " "ymm4, ymm6, ymm4, 0xAA"),
        Q!("    vpsrlq          " "ymm6, ymm6, 32"),
        Q!("    vpblendd        " "ymm7, ymm6, ymm7, 0xAA"),
        Q!("    vmovsldup       " "ymm6, ymm9"),
        Q!("    vpblendd        " "ymm6, ymm8, ymm6, 0xAA"),
        Q!("    vpsrlq          " "ymm8, ymm8, 32"),
        Q!("    vpblendd        " "ymm9, ymm8, ymm9, 0xAA"),
        Q!("    vmovsldup       " "ymm8, ymm11"),
        Q!("    vpblendd        " "ymm8, ymm10, ymm8, 0xAA"),
        Q!("    vpsrlq          " "ymm10, ymm10, 32"),
        Q!("    vpblendd        " "ymm11, ymm10, ymm11, 0xAA"),

        Q!("    vpermq          " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 72 -8 * 0 -8))], 0x1B"),
        Q!("    vpermq          " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 72 -8 * 0 -8))], 0x1B"),
        Q!("    vpsubd          " "ymm12, ymm5, ymm3"),
        Q!("    vpaddd          " "ymm3, ymm5, ymm3"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm5, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm5, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm5, ymm5, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm5, ymm12, ymm5, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm7, ymm4"),
        Q!("    vpaddd          " "ymm4, ymm7, ymm4"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm7, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm7, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm7, ymm7, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm7, ymm12, ymm7, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm9, ymm6"),
        Q!("    vpaddd          " "ymm6, ymm9, ymm6"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm9, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm9, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm9, ymm9, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm9, ymm12, ymm9, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm11, ymm8"),
        Q!("    vpaddd          " "ymm8, ymm11, ymm8"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm11, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm11, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm11, ymm12, ymm11, 0xAA"),

        // Bounds: |ymm{i}| < 16q

        // level 4
        Q!("    vpunpcklqdq     " "ymm10, ymm3, ymm4"),
        Q!("    vpunpckhqdq     " "ymm4, ymm3, ymm4"),
        Q!("    vpunpcklqdq     " "ymm3, ymm6, ymm8"),
        Q!("    vpunpckhqdq     " "ymm8, ymm6, ymm8"),
        Q!("    vpunpcklqdq     " "ymm6, ymm5, ymm7"),
        Q!("    vpunpckhqdq     " "ymm7, ymm5, ymm7"),
        Q!("    vpunpcklqdq     " "ymm5, ymm9, ymm11"),
        Q!("    vpunpckhqdq     " "ymm11, ymm9, ymm11"),

        Q!("    vpermq          " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 40 -8 * 0 -8))], 0x1B"),
        Q!("    vpermq          " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 40 -8 * 0 -8))], 0x1B"),
        Q!("    vpsubd          " "ymm12, ymm4, ymm10"),
        Q!("    vpaddd          " "ymm10, ymm10, ymm4"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm4, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm4, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm4, ymm4, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm4, ymm4, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm4, ymm12, ymm4, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm8, ymm3"),
        Q!("    vpaddd          " "ymm3, ymm8, ymm3"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm8, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm8, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm8, ymm12, ymm8, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm7, ymm6"),
        Q!("    vpaddd          " "ymm6, ymm7, ymm6"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm7, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm7, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm7, ymm7, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm7, ymm12, ymm7, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm11, ymm5"),
        Q!("    vpaddd          " "ymm5, ymm11, ymm5"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm11, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm11, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm11, ymm12, ymm11, 0xAA"),

        // Bounds: |ymm{i}| < 32q

        // level 5
        Q!("    vperm2i128      " "ymm9, ymm10, ymm3, 0x20"),
        Q!("    vperm2i128      " "ymm3, ymm10, ymm3, 0x31"),
        Q!("    vperm2i128      " "ymm10, ymm6, ymm5, 0x20"),
        Q!("    vperm2i128      " "ymm5, ymm6, ymm5, 0x31"),
        Q!("    vperm2i128      " "ymm6, ymm4, ymm8, 0x20"),
        Q!("    vperm2i128      " "ymm8, ymm4, ymm8, 0x31"),
        Q!("    vperm2i128      " "ymm4, ymm7, ymm11, 0x20"),
        Q!("    vperm2i128      " "ymm11, ymm7, ymm11, 0x31"),

        Q!("    vpbroadcastd    " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 7 -0))]"),
        Q!("    vpbroadcastd    " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 7 -0))]"),
        Q!("    vpsubd          " "ymm12, ymm3, ymm9"),
        Q!("    vpaddd          " "ymm9, ymm9, ymm3"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm3, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm3, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm3, ymm3, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm3, ymm3, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm3, ymm12, ymm3, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm5, ymm10"),
        Q!("    vpaddd          " "ymm10, ymm10, ymm5"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm5, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm5, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm5, ymm5, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm5, ymm12, ymm5, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm8, ymm6"),
        Q!("    vpaddd          " "ymm6, ymm8, ymm6"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm8, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm8, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm8, ymm12, ymm8, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm11, ymm4"),
        Q!("    vpaddd          " "ymm4, ymm11, ymm4"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm11, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm11, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm11, ymm12, ymm11, 0xAA"),

        // Bounds: |ymm{i}| < 64q

        Q!("    vmovdqa         " "[rdi + 256 * 0 + 0], ymm9"),
        Q!("    vmovdqa         " "[rdi + 256 * 0 + 32], ymm10"),
        Q!("    vmovdqa         " "[rdi + 256 * 0 + 64], ymm6"),
        Q!("    vmovdqa         " "[rdi + 256 * 0 + 96], ymm4"),
        Q!("    vmovdqa         " "[rdi + 256 * 0 + 128], ymm3"),
        Q!("    vmovdqa         " "[rdi + 256 * 0 + 160], ymm5"),
        Q!("    vmovdqa         " "[rdi + 256 * 0 + 192], ymm8"),
        Q!("    vmovdqa         " "[rdi + 256 * 0 + 224], ymm11"),
        Q!("    vmovdqa         " "ymm4, [rdi + 256 * 1 + 0]"),
        Q!("    vmovdqa         " "ymm5, [rdi + 256 * 1 + 32]"),
        Q!("    vmovdqa         " "ymm6, [rdi + 256 * 1 + 64]"),
        Q!("    vmovdqa         " "ymm7, [rdi + 256 * 1 + 96]"),
        Q!("    vmovdqa         " "ymm8, [rdi + 256 * 1 + 128]"),
        Q!("    vmovdqa         " "ymm9, [rdi + 256 * 1 + 160]"),
        Q!("    vmovdqa         " "ymm10, [rdi + 256 * 1 + 192]"),
        Q!("    vmovdqa         " "ymm11, [rdi + 256 * 1 + 224]"),

        // Bounds: |ymm{i}| < q for i in 4...11

        // level 0
        Q!("    vpermq          " "ymm3, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 296 -8 * 1 -8))], 0x1B"),
        Q!("    vpermq          " "ymm15, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 296 -8 * 1 -8))], 0x1B"),
        Q!("    vmovshdup       " "ymm1, ymm3"),
        Q!("    vmovshdup       " "ymm2, ymm15"),
        Q!("    vpsubd          " "ymm12, ymm5, ymm4"),
        Q!("    vpaddd          " "ymm4, ymm5, ymm4"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm5, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm5, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm5, ymm5, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm5, ymm12, ymm5, 0xAA"),

        Q!("    vpermq          " "ymm3, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 296 -8 * 1 -40))], 0x1B"),
        Q!("    vpermq          " "ymm15, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 296 -8 * 1 -40))], 0x1B"),
        Q!("    vmovshdup       " "ymm1, ymm3"),
        Q!("    vmovshdup       " "ymm2, ymm15"),
        Q!("    vpsubd          " "ymm12, ymm7, ymm6"),
        Q!("    vpaddd          " "ymm6, ymm7, ymm6"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm7, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm7, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm7, ymm7, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm7, ymm12, ymm7, 0xAA"),

        Q!("    vpermq          " "ymm3, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 296 -8 * 1 -72))], 0x1B"),
        Q!("    vpermq          " "ymm15, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 296 -8 * 1 -72))], 0x1B"),
        Q!("    vmovshdup       " "ymm1, ymm3"),
        Q!("    vmovshdup       " "ymm2, ymm15"),
        Q!("    vpsubd          " "ymm12, ymm9, ymm8"),
        Q!("    vpaddd          " "ymm8, ymm9, ymm8"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm9, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm9, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm9, ymm9, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm9, ymm12, ymm9, 0xAA"),

        Q!("    vpermq          " "ymm3, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 296 -8 * 1 -104))], 0x1B"),
        Q!("    vpermq          " "ymm15, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 296 -8 * 1 -104))], 0x1B"),
        Q!("    vmovshdup       " "ymm1, ymm3"),
        Q!("    vmovshdup       " "ymm2, ymm15"),
        Q!("    vpsubd          " "ymm12, ymm11, ymm10"),
        Q!("    vpaddd          " "ymm10, ymm11, ymm10"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm11, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm11, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm11, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm11, ymm12, ymm11, 0xAA"),

        //
        // Bounds: |ymm{i}| < 2q            for i in 4, 6, 8, 10
        // < MONTMUL_BOUND for i in 5, 7, 9, 11
        //
        // Note that since 2^31 / q > 256, the sum of all 256 coefficients does not
        // overflow. This allows us to greatly simplify the range analysis by relaxing
        // and unifying the bounds of all coefficients on the same layer. As a concrete
        // example, here we relax the bounds on 5, 7, 9, 11 and conclude that (for all
        // relevant i)
        //
        // Bounds: |ymm{i}| < 2q
        //
        // In all but last of the following levels of butterflies, we do the same
        // relaxation without explicit mention.
        //

        // level 1
        Q!("    vpermq          " "ymm3, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 168 -8 * 1 -8))], 0x1B"),
        Q!("    vpermq          " "ymm15, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 168 -8 * 1 -8))], 0x1B"),
        Q!("    vmovshdup       " "ymm1, ymm3"),
        Q!("    vmovshdup       " "ymm2, ymm15"),
        Q!("    vpsubd          " "ymm12, ymm6, ymm4"),
        Q!("    vpaddd          " "ymm4, ymm6, ymm4"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm6, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm6, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm6, ymm6, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm6, ymm6, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm6, ymm12, ymm6, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm7, ymm5"),
        Q!("    vpaddd          " "ymm5, ymm7, ymm5"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm7, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm7, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm7, ymm7, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm7, ymm12, ymm7, 0xAA"),

        Q!("    vpermq          " "ymm3, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 168 -8 * 1 -40))], 0x1B"),
        Q!("    vpermq          " "ymm15, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 168 -8 * 1 -40))], 0x1B"),
        Q!("    vmovshdup       " "ymm1, ymm3"),
        Q!("    vmovshdup       " "ymm2, ymm15"),
        Q!("    vpsubd          " "ymm12, ymm10, ymm8"),
        Q!("    vpaddd          " "ymm8, ymm10, ymm8"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm10, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm10, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm10, ymm10, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm10, ymm10, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm10, ymm12, ymm10, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm11, ymm9"),
        Q!("    vpaddd          " "ymm9, ymm11, ymm9"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm11, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm11, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm11, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm11, ymm12, ymm11, 0xAA"),

        // Bounds: |ymm{i}| < 4q

        // level 2
        Q!("    vpermq          " "ymm3, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 104 -8 * 1 -8))], 0x1B"),
        Q!("    vpermq          " "ymm15, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 104 -8 * 1 -8))], 0x1B"),
        Q!("    vmovshdup       " "ymm1, ymm3"),
        Q!("    vmovshdup       " "ymm2, ymm15"),
        Q!("    vpsubd          " "ymm12, ymm8, ymm4"),
        Q!("    vpaddd          " "ymm4, ymm8, ymm4"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm8, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm8, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm8, ymm8, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm8, ymm12, ymm8, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm9, ymm5"),
        Q!("    vpaddd          " "ymm5, ymm9, ymm5"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm9, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm9, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm9, ymm9, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm9, ymm12, ymm9, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm10, ymm6"),
        Q!("    vpaddd          " "ymm6, ymm10, ymm6"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm10, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm10, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm10, ymm10, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm10, ymm10, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm10, ymm12, ymm10, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm11, ymm7"),
        Q!("    vpaddd          " "ymm7, ymm11, ymm7"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm11, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm11, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm11, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm11, ymm12, ymm11, 0xAA"),

        // Bounds: |ymm{i}| < 8q

        // level 3
        Q!("    vmovsldup       " "ymm3, ymm5"),
        Q!("    vpblendd        " "ymm3, ymm4, ymm3, 0xAA"),
        Q!("    vpsrlq          " "ymm4, ymm4, 32"),
        Q!("    vpblendd        " "ymm5, ymm4, ymm5, 0xAA"),
        Q!("    vmovsldup       " "ymm4, ymm7"),
        Q!("    vpblendd        " "ymm4, ymm6, ymm4, 0xAA"),
        Q!("    vpsrlq          " "ymm6, ymm6, 32"),
        Q!("    vpblendd        " "ymm7, ymm6, ymm7, 0xAA"),
        Q!("    vmovsldup       " "ymm6, ymm9"),
        Q!("    vpblendd        " "ymm6, ymm8, ymm6, 0xAA"),
        Q!("    vpsrlq          " "ymm8, ymm8, 32"),
        Q!("    vpblendd        " "ymm9, ymm8, ymm9, 0xAA"),
        Q!("    vmovsldup       " "ymm8, ymm11"),
        Q!("    vpblendd        " "ymm8, ymm10, ymm8, 0xAA"),
        Q!("    vpsrlq          " "ymm10, ymm10, 32"),
        Q!("    vpblendd        " "ymm11, ymm10, ymm11, 0xAA"),

        Q!("    vpermq          " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 72 -8 * 1 -8))], 0x1B"),
        Q!("    vpermq          " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 72 -8 * 1 -8))], 0x1B"),
        Q!("    vpsubd          " "ymm12, ymm5, ymm3"),
        Q!("    vpaddd          " "ymm3, ymm5, ymm3"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm5, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm5, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm5, ymm5, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm5, ymm12, ymm5, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm7, ymm4"),
        Q!("    vpaddd          " "ymm4, ymm7, ymm4"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm7, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm7, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm7, ymm7, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm7, ymm12, ymm7, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm9, ymm6"),
        Q!("    vpaddd          " "ymm6, ymm9, ymm6"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm9, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm9, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm9, ymm9, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm9, ymm12, ymm9, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm11, ymm8"),
        Q!("    vpaddd          " "ymm8, ymm11, ymm8"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm11, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm11, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm11, ymm12, ymm11, 0xAA"),

        // Bounds: |ymm{i}| < 16q

        // level 4
        Q!("    vpunpcklqdq     " "ymm10, ymm3, ymm4"),
        Q!("    vpunpckhqdq     " "ymm4, ymm3, ymm4"),
        Q!("    vpunpcklqdq     " "ymm3, ymm6, ymm8"),
        Q!("    vpunpckhqdq     " "ymm8, ymm6, ymm8"),
        Q!("    vpunpcklqdq     " "ymm6, ymm5, ymm7"),
        Q!("    vpunpckhqdq     " "ymm7, ymm5, ymm7"),
        Q!("    vpunpcklqdq     " "ymm5, ymm9, ymm11"),
        Q!("    vpunpckhqdq     " "ymm11, ymm9, ymm11"),

        Q!("    vpermq          " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 40 -8 * 1 -8))], 0x1B"),
        Q!("    vpermq          " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 40 -8 * 1 -8))], 0x1B"),
        Q!("    vpsubd          " "ymm12, ymm4, ymm10"),
        Q!("    vpaddd          " "ymm10, ymm10, ymm4"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm4, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm4, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm4, ymm4, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm4, ymm4, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm4, ymm12, ymm4, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm8, ymm3"),
        Q!("    vpaddd          " "ymm3, ymm8, ymm3"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm8, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm8, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm8, ymm12, ymm8, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm7, ymm6"),
        Q!("    vpaddd          " "ymm6, ymm7, ymm6"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm7, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm7, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm7, ymm7, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm7, ymm12, ymm7, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm11, ymm5"),
        Q!("    vpaddd          " "ymm5, ymm11, ymm5"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm11, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm11, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm11, ymm12, ymm11, 0xAA"),

        // Bounds: |ymm{i}| < 32q

        // level 5
        Q!("    vperm2i128      " "ymm9, ymm10, ymm3, 0x20"),
        Q!("    vperm2i128      " "ymm3, ymm10, ymm3, 0x31"),
        Q!("    vperm2i128      " "ymm10, ymm6, ymm5, 0x20"),
        Q!("    vperm2i128      " "ymm5, ymm6, ymm5, 0x31"),
        Q!("    vperm2i128      " "ymm6, ymm4, ymm8, 0x20"),
        Q!("    vperm2i128      " "ymm8, ymm4, ymm8, 0x31"),
        Q!("    vperm2i128      " "ymm4, ymm7, ymm11, 0x20"),
        Q!("    vperm2i128      " "ymm11, ymm7, ymm11, 0x31"),

        Q!("    vpbroadcastd    " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 7 -1))]"),
        Q!("    vpbroadcastd    " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 7 -1))]"),
        Q!("    vpsubd          " "ymm12, ymm3, ymm9"),
        Q!("    vpaddd          " "ymm9, ymm9, ymm3"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm3, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm3, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm3, ymm3, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm3, ymm3, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm3, ymm12, ymm3, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm5, ymm10"),
        Q!("    vpaddd          " "ymm10, ymm10, ymm5"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm5, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm5, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm5, ymm5, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm5, ymm12, ymm5, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm8, ymm6"),
        Q!("    vpaddd          " "ymm6, ymm8, ymm6"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm8, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm8, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm8, ymm12, ymm8, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm11, ymm4"),
        Q!("    vpaddd          " "ymm4, ymm11, ymm4"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm11, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm11, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm11, ymm12, ymm11, 0xAA"),

        // Bounds: |ymm{i}| < 64q

        Q!("    vmovdqa         " "[rdi + 256 * 1 + 0], ymm9"),
        Q!("    vmovdqa         " "[rdi + 256 * 1 + 32], ymm10"),
        Q!("    vmovdqa         " "[rdi + 256 * 1 + 64], ymm6"),
        Q!("    vmovdqa         " "[rdi + 256 * 1 + 96], ymm4"),
        Q!("    vmovdqa         " "[rdi + 256 * 1 + 128], ymm3"),
        Q!("    vmovdqa         " "[rdi + 256 * 1 + 160], ymm5"),
        Q!("    vmovdqa         " "[rdi + 256 * 1 + 192], ymm8"),
        Q!("    vmovdqa         " "[rdi + 256 * 1 + 224], ymm11"),
        Q!("    vmovdqa         " "ymm4, [rdi + 256 * 2 + 0]"),
        Q!("    vmovdqa         " "ymm5, [rdi + 256 * 2 + 32]"),
        Q!("    vmovdqa         " "ymm6, [rdi + 256 * 2 + 64]"),
        Q!("    vmovdqa         " "ymm7, [rdi + 256 * 2 + 96]"),
        Q!("    vmovdqa         " "ymm8, [rdi + 256 * 2 + 128]"),
        Q!("    vmovdqa         " "ymm9, [rdi + 256 * 2 + 160]"),
        Q!("    vmovdqa         " "ymm10, [rdi + 256 * 2 + 192]"),
        Q!("    vmovdqa         " "ymm11, [rdi + 256 * 2 + 224]"),

        // Bounds: |ymm{i}| < q for i in 4...11

        // level 0
        Q!("    vpermq          " "ymm3, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 296 -8 * 2 -8))], 0x1B"),
        Q!("    vpermq          " "ymm15, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 296 -8 * 2 -8))], 0x1B"),
        Q!("    vmovshdup       " "ymm1, ymm3"),
        Q!("    vmovshdup       " "ymm2, ymm15"),
        Q!("    vpsubd          " "ymm12, ymm5, ymm4"),
        Q!("    vpaddd          " "ymm4, ymm5, ymm4"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm5, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm5, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm5, ymm5, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm5, ymm12, ymm5, 0xAA"),

        Q!("    vpermq          " "ymm3, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 296 -8 * 2 -40))], 0x1B"),
        Q!("    vpermq          " "ymm15, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 296 -8 * 2 -40))], 0x1B"),
        Q!("    vmovshdup       " "ymm1, ymm3"),
        Q!("    vmovshdup       " "ymm2, ymm15"),
        Q!("    vpsubd          " "ymm12, ymm7, ymm6"),
        Q!("    vpaddd          " "ymm6, ymm7, ymm6"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm7, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm7, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm7, ymm7, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm7, ymm12, ymm7, 0xAA"),

        Q!("    vpermq          " "ymm3, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 296 -8 * 2 -72))], 0x1B"),
        Q!("    vpermq          " "ymm15, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 296 -8 * 2 -72))], 0x1B"),
        Q!("    vmovshdup       " "ymm1, ymm3"),
        Q!("    vmovshdup       " "ymm2, ymm15"),
        Q!("    vpsubd          " "ymm12, ymm9, ymm8"),
        Q!("    vpaddd          " "ymm8, ymm9, ymm8"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm9, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm9, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm9, ymm9, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm9, ymm12, ymm9, 0xAA"),

        Q!("    vpermq          " "ymm3, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 296 -8 * 2 -104))], 0x1B"),
        Q!("    vpermq          " "ymm15, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 296 -8 * 2 -104))], 0x1B"),
        Q!("    vmovshdup       " "ymm1, ymm3"),
        Q!("    vmovshdup       " "ymm2, ymm15"),
        Q!("    vpsubd          " "ymm12, ymm11, ymm10"),
        Q!("    vpaddd          " "ymm10, ymm11, ymm10"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm11, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm11, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm11, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm11, ymm12, ymm11, 0xAA"),

        //
        // Bounds: |ymm{i}| < 2q            for i in 4, 6, 8, 10
        // < MONTMUL_BOUND for i in 5, 7, 9, 11
        //
        // Note that since 2^31 / q > 256, the sum of all 256 coefficients does not
        // overflow. This allows us to greatly simplify the range analysis by relaxing
        // and unifying the bounds of all coefficients on the same layer. As a concrete
        // example, here we relax the bounds on 5, 7, 9, 11 and conclude that (for all
        // relevant i)
        //
        // Bounds: |ymm{i}| < 2q
        //
        // In all but last of the following levels of butterflies, we do the same
        // relaxation without explicit mention.
        //

        // level 1
        Q!("    vpermq          " "ymm3, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 168 -8 * 2 -8))], 0x1B"),
        Q!("    vpermq          " "ymm15, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 168 -8 * 2 -8))], 0x1B"),
        Q!("    vmovshdup       " "ymm1, ymm3"),
        Q!("    vmovshdup       " "ymm2, ymm15"),
        Q!("    vpsubd          " "ymm12, ymm6, ymm4"),
        Q!("    vpaddd          " "ymm4, ymm6, ymm4"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm6, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm6, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm6, ymm6, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm6, ymm6, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm6, ymm12, ymm6, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm7, ymm5"),
        Q!("    vpaddd          " "ymm5, ymm7, ymm5"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm7, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm7, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm7, ymm7, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm7, ymm12, ymm7, 0xAA"),

        Q!("    vpermq          " "ymm3, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 168 -8 * 2 -40))], 0x1B"),
        Q!("    vpermq          " "ymm15, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 168 -8 * 2 -40))], 0x1B"),
        Q!("    vmovshdup       " "ymm1, ymm3"),
        Q!("    vmovshdup       " "ymm2, ymm15"),
        Q!("    vpsubd          " "ymm12, ymm10, ymm8"),
        Q!("    vpaddd          " "ymm8, ymm10, ymm8"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm10, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm10, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm10, ymm10, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm10, ymm10, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm10, ymm12, ymm10, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm11, ymm9"),
        Q!("    vpaddd          " "ymm9, ymm11, ymm9"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm11, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm11, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm11, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm11, ymm12, ymm11, 0xAA"),

        // Bounds: |ymm{i}| < 4q

        // level 2
        Q!("    vpermq          " "ymm3, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 104 -8 * 2 -8))], 0x1B"),
        Q!("    vpermq          " "ymm15, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 104 -8 * 2 -8))], 0x1B"),
        Q!("    vmovshdup       " "ymm1, ymm3"),
        Q!("    vmovshdup       " "ymm2, ymm15"),
        Q!("    vpsubd          " "ymm12, ymm8, ymm4"),
        Q!("    vpaddd          " "ymm4, ymm8, ymm4"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm8, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm8, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm8, ymm8, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm8, ymm12, ymm8, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm9, ymm5"),
        Q!("    vpaddd          " "ymm5, ymm9, ymm5"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm9, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm9, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm9, ymm9, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm9, ymm12, ymm9, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm10, ymm6"),
        Q!("    vpaddd          " "ymm6, ymm10, ymm6"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm10, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm10, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm10, ymm10, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm10, ymm10, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm10, ymm12, ymm10, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm11, ymm7"),
        Q!("    vpaddd          " "ymm7, ymm11, ymm7"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm11, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm11, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm11, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm11, ymm12, ymm11, 0xAA"),

        // Bounds: |ymm{i}| < 8q

        // level 3
        Q!("    vmovsldup       " "ymm3, ymm5"),
        Q!("    vpblendd        " "ymm3, ymm4, ymm3, 0xAA"),
        Q!("    vpsrlq          " "ymm4, ymm4, 32"),
        Q!("    vpblendd        " "ymm5, ymm4, ymm5, 0xAA"),
        Q!("    vmovsldup       " "ymm4, ymm7"),
        Q!("    vpblendd        " "ymm4, ymm6, ymm4, 0xAA"),
        Q!("    vpsrlq          " "ymm6, ymm6, 32"),
        Q!("    vpblendd        " "ymm7, ymm6, ymm7, 0xAA"),
        Q!("    vmovsldup       " "ymm6, ymm9"),
        Q!("    vpblendd        " "ymm6, ymm8, ymm6, 0xAA"),
        Q!("    vpsrlq          " "ymm8, ymm8, 32"),
        Q!("    vpblendd        " "ymm9, ymm8, ymm9, 0xAA"),
        Q!("    vmovsldup       " "ymm8, ymm11"),
        Q!("    vpblendd        " "ymm8, ymm10, ymm8, 0xAA"),
        Q!("    vpsrlq          " "ymm10, ymm10, 32"),
        Q!("    vpblendd        " "ymm11, ymm10, ymm11, 0xAA"),

        Q!("    vpermq          " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 72 -8 * 2 -8))], 0x1B"),
        Q!("    vpermq          " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 72 -8 * 2 -8))], 0x1B"),
        Q!("    vpsubd          " "ymm12, ymm5, ymm3"),
        Q!("    vpaddd          " "ymm3, ymm5, ymm3"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm5, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm5, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm5, ymm5, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm5, ymm12, ymm5, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm7, ymm4"),
        Q!("    vpaddd          " "ymm4, ymm7, ymm4"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm7, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm7, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm7, ymm7, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm7, ymm12, ymm7, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm9, ymm6"),
        Q!("    vpaddd          " "ymm6, ymm9, ymm6"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm9, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm9, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm9, ymm9, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm9, ymm12, ymm9, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm11, ymm8"),
        Q!("    vpaddd          " "ymm8, ymm11, ymm8"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm11, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm11, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm11, ymm12, ymm11, 0xAA"),

        // Bounds: |ymm{i}| < 16q

        // level 4
        Q!("    vpunpcklqdq     " "ymm10, ymm3, ymm4"),
        Q!("    vpunpckhqdq     " "ymm4, ymm3, ymm4"),
        Q!("    vpunpcklqdq     " "ymm3, ymm6, ymm8"),
        Q!("    vpunpckhqdq     " "ymm8, ymm6, ymm8"),
        Q!("    vpunpcklqdq     " "ymm6, ymm5, ymm7"),
        Q!("    vpunpckhqdq     " "ymm7, ymm5, ymm7"),
        Q!("    vpunpcklqdq     " "ymm5, ymm9, ymm11"),
        Q!("    vpunpckhqdq     " "ymm11, ymm9, ymm11"),

        Q!("    vpermq          " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 40 -8 * 2 -8))], 0x1B"),
        Q!("    vpermq          " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 40 -8 * 2 -8))], 0x1B"),
        Q!("    vpsubd          " "ymm12, ymm4, ymm10"),
        Q!("    vpaddd          " "ymm10, ymm10, ymm4"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm4, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm4, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm4, ymm4, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm4, ymm4, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm4, ymm12, ymm4, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm8, ymm3"),
        Q!("    vpaddd          " "ymm3, ymm8, ymm3"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm8, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm8, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm8, ymm12, ymm8, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm7, ymm6"),
        Q!("    vpaddd          " "ymm6, ymm7, ymm6"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm7, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm7, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm7, ymm7, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm7, ymm12, ymm7, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm11, ymm5"),
        Q!("    vpaddd          " "ymm5, ymm11, ymm5"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm11, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm11, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm11, ymm12, ymm11, 0xAA"),

        // Bounds: |ymm{i}| < 32q

        // level 5
        Q!("    vperm2i128      " "ymm9, ymm10, ymm3, 0x20"),
        Q!("    vperm2i128      " "ymm3, ymm10, ymm3, 0x31"),
        Q!("    vperm2i128      " "ymm10, ymm6, ymm5, 0x20"),
        Q!("    vperm2i128      " "ymm5, ymm6, ymm5, 0x31"),
        Q!("    vperm2i128      " "ymm6, ymm4, ymm8, 0x20"),
        Q!("    vperm2i128      " "ymm8, ymm4, ymm8, 0x31"),
        Q!("    vperm2i128      " "ymm4, ymm7, ymm11, 0x20"),
        Q!("    vperm2i128      " "ymm11, ymm7, ymm11, 0x31"),

        Q!("    vpbroadcastd    " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 7 -2))]"),
        Q!("    vpbroadcastd    " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 7 -2))]"),
        Q!("    vpsubd          " "ymm12, ymm3, ymm9"),
        Q!("    vpaddd          " "ymm9, ymm9, ymm3"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm3, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm3, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm3, ymm3, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm3, ymm3, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm3, ymm12, ymm3, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm5, ymm10"),
        Q!("    vpaddd          " "ymm10, ymm10, ymm5"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm5, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm5, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm5, ymm5, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm5, ymm12, ymm5, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm8, ymm6"),
        Q!("    vpaddd          " "ymm6, ymm8, ymm6"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm8, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm8, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm8, ymm12, ymm8, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm11, ymm4"),
        Q!("    vpaddd          " "ymm4, ymm11, ymm4"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm11, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm11, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm11, ymm12, ymm11, 0xAA"),

        // Bounds: |ymm{i}| < 64q

        Q!("    vmovdqa         " "[rdi + 256 * 2 + 0], ymm9"),
        Q!("    vmovdqa         " "[rdi + 256 * 2 + 32], ymm10"),
        Q!("    vmovdqa         " "[rdi + 256 * 2 + 64], ymm6"),
        Q!("    vmovdqa         " "[rdi + 256 * 2 + 96], ymm4"),
        Q!("    vmovdqa         " "[rdi + 256 * 2 + 128], ymm3"),
        Q!("    vmovdqa         " "[rdi + 256 * 2 + 160], ymm5"),
        Q!("    vmovdqa         " "[rdi + 256 * 2 + 192], ymm8"),
        Q!("    vmovdqa         " "[rdi + 256 * 2 + 224], ymm11"),
        Q!("    vmovdqa         " "ymm4, [rdi + 256 * 3 + 0]"),
        Q!("    vmovdqa         " "ymm5, [rdi + 256 * 3 + 32]"),
        Q!("    vmovdqa         " "ymm6, [rdi + 256 * 3 + 64]"),
        Q!("    vmovdqa         " "ymm7, [rdi + 256 * 3 + 96]"),
        Q!("    vmovdqa         " "ymm8, [rdi + 256 * 3 + 128]"),
        Q!("    vmovdqa         " "ymm9, [rdi + 256 * 3 + 160]"),
        Q!("    vmovdqa         " "ymm10, [rdi + 256 * 3 + 192]"),
        Q!("    vmovdqa         " "ymm11, [rdi + 256 * 3 + 224]"),

        // Bounds: |ymm{i}| < q for i in 4...11

        // level 0
        Q!("    vpermq          " "ymm3, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 296 -8 * 3 -8))], 0x1B"),
        Q!("    vpermq          " "ymm15, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 296 -8 * 3 -8))], 0x1B"),
        Q!("    vmovshdup       " "ymm1, ymm3"),
        Q!("    vmovshdup       " "ymm2, ymm15"),
        Q!("    vpsubd          " "ymm12, ymm5, ymm4"),
        Q!("    vpaddd          " "ymm4, ymm5, ymm4"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm5, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm5, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm5, ymm5, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm5, ymm12, ymm5, 0xAA"),

        Q!("    vpermq          " "ymm3, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 296 -8 * 3 -40))], 0x1B"),
        Q!("    vpermq          " "ymm15, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 296 -8 * 3 -40))], 0x1B"),
        Q!("    vmovshdup       " "ymm1, ymm3"),
        Q!("    vmovshdup       " "ymm2, ymm15"),
        Q!("    vpsubd          " "ymm12, ymm7, ymm6"),
        Q!("    vpaddd          " "ymm6, ymm7, ymm6"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm7, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm7, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm7, ymm7, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm7, ymm12, ymm7, 0xAA"),

        Q!("    vpermq          " "ymm3, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 296 -8 * 3 -72))], 0x1B"),
        Q!("    vpermq          " "ymm15, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 296 -8 * 3 -72))], 0x1B"),
        Q!("    vmovshdup       " "ymm1, ymm3"),
        Q!("    vmovshdup       " "ymm2, ymm15"),
        Q!("    vpsubd          " "ymm12, ymm9, ymm8"),
        Q!("    vpaddd          " "ymm8, ymm9, ymm8"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm9, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm9, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm9, ymm9, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm9, ymm12, ymm9, 0xAA"),

        Q!("    vpermq          " "ymm3, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 296 -8 * 3 -104))], 0x1B"),
        Q!("    vpermq          " "ymm15, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 296 -8 * 3 -104))], 0x1B"),
        Q!("    vmovshdup       " "ymm1, ymm3"),
        Q!("    vmovshdup       " "ymm2, ymm15"),
        Q!("    vpsubd          " "ymm12, ymm11, ymm10"),
        Q!("    vpaddd          " "ymm10, ymm11, ymm10"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm11, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm11, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm11, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm11, ymm12, ymm11, 0xAA"),

        //
        // Bounds: |ymm{i}| < 2q            for i in 4, 6, 8, 10
        // < MONTMUL_BOUND for i in 5, 7, 9, 11
        //
        // Note that since 2^31 / q > 256, the sum of all 256 coefficients does not
        // overflow. This allows us to greatly simplify the range analysis by relaxing
        // and unifying the bounds of all coefficients on the same layer. As a concrete
        // example, here we relax the bounds on 5, 7, 9, 11 and conclude that (for all
        // relevant i)
        //
        // Bounds: |ymm{i}| < 2q
        //
        // In all but last of the following levels of butterflies, we do the same
        // relaxation without explicit mention.
        //

        // level 1
        Q!("    vpermq          " "ymm3, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 168 -8 * 3 -8))], 0x1B"),
        Q!("    vpermq          " "ymm15, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 168 -8 * 3 -8))], 0x1B"),
        Q!("    vmovshdup       " "ymm1, ymm3"),
        Q!("    vmovshdup       " "ymm2, ymm15"),
        Q!("    vpsubd          " "ymm12, ymm6, ymm4"),
        Q!("    vpaddd          " "ymm4, ymm6, ymm4"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm6, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm6, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm6, ymm6, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm6, ymm6, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm6, ymm12, ymm6, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm7, ymm5"),
        Q!("    vpaddd          " "ymm5, ymm7, ymm5"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm7, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm7, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm7, ymm7, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm7, ymm12, ymm7, 0xAA"),

        Q!("    vpermq          " "ymm3, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 168 -8 * 3 -40))], 0x1B"),
        Q!("    vpermq          " "ymm15, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 168 -8 * 3 -40))], 0x1B"),
        Q!("    vmovshdup       " "ymm1, ymm3"),
        Q!("    vmovshdup       " "ymm2, ymm15"),
        Q!("    vpsubd          " "ymm12, ymm10, ymm8"),
        Q!("    vpaddd          " "ymm8, ymm10, ymm8"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm10, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm10, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm10, ymm10, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm10, ymm10, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm10, ymm12, ymm10, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm11, ymm9"),
        Q!("    vpaddd          " "ymm9, ymm11, ymm9"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm11, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm11, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm11, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm11, ymm12, ymm11, 0xAA"),

        // Bounds: |ymm{i}| < 4q

        // level 2
        Q!("    vpermq          " "ymm3, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 104 -8 * 3 -8))], 0x1B"),
        Q!("    vpermq          " "ymm15, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 104 -8 * 3 -8))], 0x1B"),
        Q!("    vmovshdup       " "ymm1, ymm3"),
        Q!("    vmovshdup       " "ymm2, ymm15"),
        Q!("    vpsubd          " "ymm12, ymm8, ymm4"),
        Q!("    vpaddd          " "ymm4, ymm8, ymm4"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm8, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm8, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm8, ymm8, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm8, ymm12, ymm8, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm9, ymm5"),
        Q!("    vpaddd          " "ymm5, ymm9, ymm5"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm9, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm9, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm9, ymm9, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm9, ymm12, ymm9, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm10, ymm6"),
        Q!("    vpaddd          " "ymm6, ymm10, ymm6"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm10, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm10, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm10, ymm10, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm10, ymm10, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm10, ymm12, ymm10, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm11, ymm7"),
        Q!("    vpaddd          " "ymm7, ymm11, ymm7"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm11, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm11, ymm3"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm11, ymm15"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm11, ymm12, ymm11, 0xAA"),

        // Bounds: |ymm{i}| < 8q

        // level 3
        Q!("    vmovsldup       " "ymm3, ymm5"),
        Q!("    vpblendd        " "ymm3, ymm4, ymm3, 0xAA"),
        Q!("    vpsrlq          " "ymm4, ymm4, 32"),
        Q!("    vpblendd        " "ymm5, ymm4, ymm5, 0xAA"),
        Q!("    vmovsldup       " "ymm4, ymm7"),
        Q!("    vpblendd        " "ymm4, ymm6, ymm4, 0xAA"),
        Q!("    vpsrlq          " "ymm6, ymm6, 32"),
        Q!("    vpblendd        " "ymm7, ymm6, ymm7, 0xAA"),
        Q!("    vmovsldup       " "ymm6, ymm9"),
        Q!("    vpblendd        " "ymm6, ymm8, ymm6, 0xAA"),
        Q!("    vpsrlq          " "ymm8, ymm8, 32"),
        Q!("    vpblendd        " "ymm9, ymm8, ymm9, 0xAA"),
        Q!("    vmovsldup       " "ymm8, ymm11"),
        Q!("    vpblendd        " "ymm8, ymm10, ymm8, 0xAA"),
        Q!("    vpsrlq          " "ymm10, ymm10, 32"),
        Q!("    vpblendd        " "ymm11, ymm10, ymm11, 0xAA"),

        Q!("    vpermq          " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 72 -8 * 3 -8))], 0x1B"),
        Q!("    vpermq          " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 72 -8 * 3 -8))], 0x1B"),
        Q!("    vpsubd          " "ymm12, ymm5, ymm3"),
        Q!("    vpaddd          " "ymm3, ymm5, ymm3"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm5, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm5, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm5, ymm5, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm5, ymm12, ymm5, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm7, ymm4"),
        Q!("    vpaddd          " "ymm4, ymm7, ymm4"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm7, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm7, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm7, ymm7, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm7, ymm12, ymm7, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm9, ymm6"),
        Q!("    vpaddd          " "ymm6, ymm9, ymm6"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm9, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm9, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm9, ymm9, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm9, ymm12, ymm9, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm11, ymm8"),
        Q!("    vpaddd          " "ymm8, ymm11, ymm8"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm11, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm11, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm11, ymm12, ymm11, 0xAA"),

        // Bounds: |ymm{i}| < 16q

        // level 4
        Q!("    vpunpcklqdq     " "ymm10, ymm3, ymm4"),
        Q!("    vpunpckhqdq     " "ymm4, ymm3, ymm4"),
        Q!("    vpunpcklqdq     " "ymm3, ymm6, ymm8"),
        Q!("    vpunpckhqdq     " "ymm8, ymm6, ymm8"),
        Q!("    vpunpcklqdq     " "ymm6, ymm5, ymm7"),
        Q!("    vpunpckhqdq     " "ymm7, ymm5, ymm7"),
        Q!("    vpunpcklqdq     " "ymm5, ymm9, ymm11"),
        Q!("    vpunpckhqdq     " "ymm11, ymm9, ymm11"),

        Q!("    vpermq          " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 40 -8 * 3 -8))], 0x1B"),
        Q!("    vpermq          " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 40 -8 * 3 -8))], 0x1B"),
        Q!("    vpsubd          " "ymm12, ymm4, ymm10"),
        Q!("    vpaddd          " "ymm10, ymm10, ymm4"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm4, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm4, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm4, ymm4, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm4, ymm4, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm4, ymm12, ymm4, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm8, ymm3"),
        Q!("    vpaddd          " "ymm3, ymm8, ymm3"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm8, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm8, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm8, ymm12, ymm8, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm7, ymm6"),
        Q!("    vpaddd          " "ymm6, ymm7, ymm6"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm7, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm7, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm7, ymm7, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm7, ymm12, ymm7, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm11, ymm5"),
        Q!("    vpaddd          " "ymm5, ymm11, ymm5"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm11, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm11, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm11, ymm12, ymm11, 0xAA"),

        // Bounds: |ymm{i}| < 32q

        // level 5
        Q!("    vperm2i128      " "ymm9, ymm10, ymm3, 0x20"),
        Q!("    vperm2i128      " "ymm3, ymm10, ymm3, 0x31"),
        Q!("    vperm2i128      " "ymm10, ymm6, ymm5, 0x20"),
        Q!("    vperm2i128      " "ymm5, ymm6, ymm5, 0x31"),
        Q!("    vperm2i128      " "ymm6, ymm4, ymm8, 0x20"),
        Q!("    vperm2i128      " "ymm8, ymm4, ymm8, 0x31"),
        Q!("    vperm2i128      " "ymm4, ymm7, ymm11, 0x20"),
        Q!("    vperm2i128      " "ymm11, ymm7, ymm11, 0x31"),

        Q!("    vpbroadcastd    " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 7 -3))]"),
        Q!("    vpbroadcastd    " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 7 -3))]"),
        Q!("    vpsubd          " "ymm12, ymm3, ymm9"),
        Q!("    vpaddd          " "ymm9, ymm9, ymm3"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm3, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm3, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm3, ymm3, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm3, ymm3, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm3, ymm12, ymm3, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm5, ymm10"),
        Q!("    vpaddd          " "ymm10, ymm10, ymm5"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm5, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm5, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm5, ymm5, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm5, ymm12, ymm5, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm8, ymm6"),
        Q!("    vpaddd          " "ymm6, ymm8, ymm6"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm8, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm8, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm8, ymm12, ymm8, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm11, ymm4"),
        Q!("    vpaddd          " "ymm4, ymm11, ymm4"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm11, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm11, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm11, ymm12, ymm11, 0xAA"),

        // Bounds: |ymm{i}| < 64q

        Q!("    vmovdqa         " "[rdi + 256 * 3 + 0], ymm9"),
        Q!("    vmovdqa         " "[rdi + 256 * 3 + 32], ymm10"),
        Q!("    vmovdqa         " "[rdi + 256 * 3 + 64], ymm6"),
        Q!("    vmovdqa         " "[rdi + 256 * 3 + 96], ymm4"),
        Q!("    vmovdqa         " "[rdi + 256 * 3 + 128], ymm3"),
        Q!("    vmovdqa         " "[rdi + 256 * 3 + 160], ymm5"),
        Q!("    vmovdqa         " "[rdi + 256 * 3 + 192], ymm8"),
        Q!("    vmovdqa         " "[rdi + 256 * 3 + 224], ymm11"),

        Q!("    vmovdqa         " "ymm4, [rdi + 0 + 32 * 0]"),
        Q!("    vmovdqa         " "ymm5, [rdi + 128 + 32 * 0]"),
        Q!("    vmovdqa         " "ymm6, [rdi + 256 + 32 * 0]"),
        Q!("    vmovdqa         " "ymm7, [rdi + 384 + 32 * 0]"),
        Q!("    vmovdqa         " "ymm8, [rdi + 512 + 32 * 0]"),
        Q!("    vmovdqa         " "ymm9, [rdi + 640 + 32 * 0]"),
        Q!("    vmovdqa         " "ymm10, [rdi + 768 + 32 * 0]"),
        Q!("    vmovdqa         " "ymm11, [rdi + 896 + 32 * 0]"),

        // level 6
        Q!("    vpbroadcastd    " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 3))]"),
        Q!("    vpbroadcastd    " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 3))]"),
        Q!("    vpsubd          " "ymm12, ymm6, ymm4"),
        Q!("    vpaddd          " "ymm4, ymm6, ymm4"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm6, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm6, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm6, ymm6, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm6, ymm6, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm6, ymm12, ymm6, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm7, ymm5"),
        Q!("    vpaddd          " "ymm5, ymm7, ymm5"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm7, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm7, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm7, ymm7, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm7, ymm12, ymm7, 0xAA"),

        Q!("    vpbroadcastd    " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 2))]"),
        Q!("    vpbroadcastd    " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 2))]"),
        Q!("    vpsubd          " "ymm12, ymm10, ymm8"),
        Q!("    vpaddd          " "ymm8, ymm10, ymm8"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm10, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm10, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm10, ymm10, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm10, ymm10, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm10, ymm12, ymm10, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm11, ymm9"),
        Q!("    vpaddd          " "ymm9, ymm11, ymm9"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm11, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm11, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm11, ymm12, ymm11, 0xAA"),

        // Bounds: |ymm{i}| < 128q

        // level 7
        Q!("    vpbroadcastd    " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 0))]"),
        Q!("    vpbroadcastd    " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 0))]"),

        Q!("    vpsubd          " "ymm12, ymm8, ymm4"),
        Q!("    vpaddd          " "ymm4, ymm8, ymm4"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm8, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm8, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm8, ymm12, ymm8, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm9, ymm5"),
        Q!("    vpaddd          " "ymm5, ymm9, ymm5"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm9, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm9, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm9, ymm9, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm9, ymm12, ymm9, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm10, ymm6"),
        Q!("    vpaddd          " "ymm6, ymm10, ymm6"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm10, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm10, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm10, ymm10, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm10, ymm10, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm10, ymm12, ymm10, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm11, ymm7"),
        Q!("    vpaddd          " "ymm7, ymm11, ymm7"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm11, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm11, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm11, ymm12, ymm11, 0xAA"),

        //
        // Bounds: |ymm{i}| < 256q          for i in 4...7
        // < MONTMUL_BOUND for i in 8...11
        //

        Q!("    vmovdqa         " "[rdi + 512 + 32 * 0], ymm8"),
        Q!("    vmovdqa         " "[rdi + 640 + 32 * 0], ymm9"),
        Q!("    vmovdqa         " "[rdi + 768 + 32 * 0], ymm10"),
        Q!("    vmovdqa         " "[rdi + 896 + 32 * 0], ymm11"),

        //
        // In order to (a) remove the factor of 256 arising from the 256-point INTT
        // butterflies and (b) transform the output into Montgomery domain, we need to
        // multiply all coefficients by 2^32/256.
        //
        // For ymm{8,9,10,11}, the scaling has been merged into the last butterfly, so
        // only ymm{4,5,6,7} need to be scaled explicitly.
        //
        // The scaling is achieved by computing montmul(-, MLD_AVX2_DIV).
        //
        // Bounds: |ymm{i}| < 256q for i in 4...7
        //

        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_8XDIV_QINV!() "))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_8XDIV!() "))]"),
        Q!("    vpmuldq         " "ymm12, ymm4, ymm1"),
        Q!("    vpmuldq         " "ymm13, ymm5, ymm1"),
        Q!("    vmovshdup       " "ymm8, ymm4"),
        Q!("    vmovshdup       " "ymm9, ymm5"),
        Q!("    vpmuldq         " "ymm14, ymm8, ymm1"),
        Q!("    vpmuldq         " "ymm15, ymm9, ymm1"),
        Q!("    vpmuldq         " "ymm4, ymm4, ymm2"),
        Q!("    vpmuldq         " "ymm5, ymm5, ymm2"),
        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),
        Q!("    vpmuldq         " "ymm9, ymm9, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm0"),
        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),
        Q!("    vpmuldq         " "ymm15, ymm15, ymm0"),
        Q!("    vpsubd          " "ymm4, ymm4, ymm12"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm14"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm15"),
        Q!("    vmovshdup       " "ymm4, ymm4"),
        Q!("    vmovshdup       " "ymm5, ymm5"),
        Q!("    vpblendd        " "ymm4, ymm4, ymm8, 0xAA"),
        Q!("    vpblendd        " "ymm5, ymm5, ymm9, 0xAA"),

        Q!("    vpmuldq         " "ymm12, ymm6, ymm1"),
        Q!("    vpmuldq         " "ymm13, ymm7, ymm1"),
        Q!("    vmovshdup       " "ymm8, ymm6"),
        Q!("    vmovshdup       " "ymm9, ymm7"),
        Q!("    vpmuldq         " "ymm14, ymm8, ymm1"),
        Q!("    vpmuldq         " "ymm15, ymm9, ymm1"),
        Q!("    vpmuldq         " "ymm6, ymm6, ymm2"),
        Q!("    vpmuldq         " "ymm7, ymm7, ymm2"),
        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),
        Q!("    vpmuldq         " "ymm9, ymm9, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm0"),
        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),
        Q!("    vpmuldq         " "ymm15, ymm15, ymm0"),
        Q!("    vpsubd          " "ymm6, ymm6, ymm12"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm14"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm15"),
        Q!("    vmovshdup       " "ymm6, ymm6"),
        Q!("    vmovshdup       " "ymm7, ymm7"),
        Q!("    vpblendd        " "ymm6, ymm6, ymm8, 0xAA"),
        Q!("    vpblendd        " "ymm7, ymm7, ymm9, 0xAA"),

        // Bounds: |ymm{i}| < MONTMUL_BOUND for i in 4...7

        //
        // In the following we show that |montmul(a, b)| < MONTMUL_BOUND := ceil(3q/4),
        // given that a fits inside int32_t (thus |a| <= R/2) and b is signed canonical
        // (in the range -(Q-1)/2...(Q-1)/2).
        //
        // In Section 2.2 of https://eprint.iacr.org/2023/1962, they showed that b being
        // signed canonical implies:
        //
        // |montmul(a, b)| <= (|a| (q/2) + (R/2) q) / R = (q/2) (1 + |a|/R).
        //
        // From this, simple computation gives |montmul(a, b)| <= 3q/4 < ceil(3q/4).
        //
        // See test/test_bounds.py for more empirical evidence (and some minor technical
        // details).
        //
        // TODO: Use proper citation. Currently, citations within asm can cause linter
        // to complain about unused citation, because comments are not preserved
        // after simpasm.
        //

        Q!("    vmovdqa         " "[rdi + 0 + 32 * 0], ymm4"),
        Q!("    vmovdqa         " "[rdi + 128 + 32 * 0], ymm5"),
        Q!("    vmovdqa         " "[rdi + 256 + 32 * 0], ymm6"),
        Q!("    vmovdqa         " "[rdi + 384 + 32 * 0], ymm7"),
        Q!("    vmovdqa         " "ymm4, [rdi + 0 + 32 * 1]"),
        Q!("    vmovdqa         " "ymm5, [rdi + 128 + 32 * 1]"),
        Q!("    vmovdqa         " "ymm6, [rdi + 256 + 32 * 1]"),
        Q!("    vmovdqa         " "ymm7, [rdi + 384 + 32 * 1]"),
        Q!("    vmovdqa         " "ymm8, [rdi + 512 + 32 * 1]"),
        Q!("    vmovdqa         " "ymm9, [rdi + 640 + 32 * 1]"),
        Q!("    vmovdqa         " "ymm10, [rdi + 768 + 32 * 1]"),
        Q!("    vmovdqa         " "ymm11, [rdi + 896 + 32 * 1]"),

        // level 6
        Q!("    vpbroadcastd    " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 3))]"),
        Q!("    vpbroadcastd    " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 3))]"),
        Q!("    vpsubd          " "ymm12, ymm6, ymm4"),
        Q!("    vpaddd          " "ymm4, ymm6, ymm4"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm6, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm6, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm6, ymm6, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm6, ymm6, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm6, ymm12, ymm6, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm7, ymm5"),
        Q!("    vpaddd          " "ymm5, ymm7, ymm5"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm7, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm7, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm7, ymm7, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm7, ymm12, ymm7, 0xAA"),

        Q!("    vpbroadcastd    " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 2))]"),
        Q!("    vpbroadcastd    " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 2))]"),
        Q!("    vpsubd          " "ymm12, ymm10, ymm8"),
        Q!("    vpaddd          " "ymm8, ymm10, ymm8"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm10, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm10, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm10, ymm10, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm10, ymm10, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm10, ymm12, ymm10, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm11, ymm9"),
        Q!("    vpaddd          " "ymm9, ymm11, ymm9"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm11, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm11, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm11, ymm12, ymm11, 0xAA"),

        // Bounds: |ymm{i}| < 128q

        // level 7
        Q!("    vpbroadcastd    " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 0))]"),
        Q!("    vpbroadcastd    " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 0))]"),

        Q!("    vpsubd          " "ymm12, ymm8, ymm4"),
        Q!("    vpaddd          " "ymm4, ymm8, ymm4"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm8, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm8, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm8, ymm12, ymm8, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm9, ymm5"),
        Q!("    vpaddd          " "ymm5, ymm9, ymm5"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm9, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm9, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm9, ymm9, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm9, ymm12, ymm9, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm10, ymm6"),
        Q!("    vpaddd          " "ymm6, ymm10, ymm6"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm10, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm10, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm10, ymm10, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm10, ymm10, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm10, ymm12, ymm10, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm11, ymm7"),
        Q!("    vpaddd          " "ymm7, ymm11, ymm7"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm11, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm11, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm11, ymm12, ymm11, 0xAA"),

        //
        // Bounds: |ymm{i}| < 256q          for i in 4...7
        // < MONTMUL_BOUND for i in 8...11
        //

        Q!("    vmovdqa         " "[rdi + 512 + 32 * 1], ymm8"),
        Q!("    vmovdqa         " "[rdi + 640 + 32 * 1], ymm9"),
        Q!("    vmovdqa         " "[rdi + 768 + 32 * 1], ymm10"),
        Q!("    vmovdqa         " "[rdi + 896 + 32 * 1], ymm11"),

        //
        // In order to (a) remove the factor of 256 arising from the 256-point INTT
        // butterflies and (b) transform the output into Montgomery domain, we need to
        // multiply all coefficients by 2^32/256.
        //
        // For ymm{8,9,10,11}, the scaling has been merged into the last butterfly, so
        // only ymm{4,5,6,7} need to be scaled explicitly.
        //
        // The scaling is achieved by computing montmul(-, MLD_AVX2_DIV).
        //
        // Bounds: |ymm{i}| < 256q for i in 4...7
        //

        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_8XDIV_QINV!() "))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_8XDIV!() "))]"),
        Q!("    vpmuldq         " "ymm12, ymm4, ymm1"),
        Q!("    vpmuldq         " "ymm13, ymm5, ymm1"),
        Q!("    vmovshdup       " "ymm8, ymm4"),
        Q!("    vmovshdup       " "ymm9, ymm5"),
        Q!("    vpmuldq         " "ymm14, ymm8, ymm1"),
        Q!("    vpmuldq         " "ymm15, ymm9, ymm1"),
        Q!("    vpmuldq         " "ymm4, ymm4, ymm2"),
        Q!("    vpmuldq         " "ymm5, ymm5, ymm2"),
        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),
        Q!("    vpmuldq         " "ymm9, ymm9, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm0"),
        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),
        Q!("    vpmuldq         " "ymm15, ymm15, ymm0"),
        Q!("    vpsubd          " "ymm4, ymm4, ymm12"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm14"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm15"),
        Q!("    vmovshdup       " "ymm4, ymm4"),
        Q!("    vmovshdup       " "ymm5, ymm5"),
        Q!("    vpblendd        " "ymm4, ymm4, ymm8, 0xAA"),
        Q!("    vpblendd        " "ymm5, ymm5, ymm9, 0xAA"),

        Q!("    vpmuldq         " "ymm12, ymm6, ymm1"),
        Q!("    vpmuldq         " "ymm13, ymm7, ymm1"),
        Q!("    vmovshdup       " "ymm8, ymm6"),
        Q!("    vmovshdup       " "ymm9, ymm7"),
        Q!("    vpmuldq         " "ymm14, ymm8, ymm1"),
        Q!("    vpmuldq         " "ymm15, ymm9, ymm1"),
        Q!("    vpmuldq         " "ymm6, ymm6, ymm2"),
        Q!("    vpmuldq         " "ymm7, ymm7, ymm2"),
        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),
        Q!("    vpmuldq         " "ymm9, ymm9, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm0"),
        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),
        Q!("    vpmuldq         " "ymm15, ymm15, ymm0"),
        Q!("    vpsubd          " "ymm6, ymm6, ymm12"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm14"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm15"),
        Q!("    vmovshdup       " "ymm6, ymm6"),
        Q!("    vmovshdup       " "ymm7, ymm7"),
        Q!("    vpblendd        " "ymm6, ymm6, ymm8, 0xAA"),
        Q!("    vpblendd        " "ymm7, ymm7, ymm9, 0xAA"),

        // Bounds: |ymm{i}| < MONTMUL_BOUND for i in 4...7

        //
        // In the following we show that |montmul(a, b)| < MONTMUL_BOUND := ceil(3q/4),
        // given that a fits inside int32_t (thus |a| <= R/2) and b is signed canonical
        // (in the range -(Q-1)/2...(Q-1)/2).
        //
        // In Section 2.2 of https://eprint.iacr.org/2023/1962, they showed that b being
        // signed canonical implies:
        //
        // |montmul(a, b)| <= (|a| (q/2) + (R/2) q) / R = (q/2) (1 + |a|/R).
        //
        // From this, simple computation gives |montmul(a, b)| <= 3q/4 < ceil(3q/4).
        //
        // See test/test_bounds.py for more empirical evidence (and some minor technical
        // details).
        //
        // TODO: Use proper citation. Currently, citations within asm can cause linter
        // to complain about unused citation, because comments are not preserved
        // after simpasm.
        //

        Q!("    vmovdqa         " "[rdi + 0 + 32 * 1], ymm4"),
        Q!("    vmovdqa         " "[rdi + 128 + 32 * 1], ymm5"),
        Q!("    vmovdqa         " "[rdi + 256 + 32 * 1], ymm6"),
        Q!("    vmovdqa         " "[rdi + 384 + 32 * 1], ymm7"),
        Q!("    vmovdqa         " "ymm4, [rdi + 0 + 32 * 2]"),
        Q!("    vmovdqa         " "ymm5, [rdi + 128 + 32 * 2]"),
        Q!("    vmovdqa         " "ymm6, [rdi + 256 + 32 * 2]"),
        Q!("    vmovdqa         " "ymm7, [rdi + 384 + 32 * 2]"),
        Q!("    vmovdqa         " "ymm8, [rdi + 512 + 32 * 2]"),
        Q!("    vmovdqa         " "ymm9, [rdi + 640 + 32 * 2]"),
        Q!("    vmovdqa         " "ymm10, [rdi + 768 + 32 * 2]"),
        Q!("    vmovdqa         " "ymm11, [rdi + 896 + 32 * 2]"),

        // level 6
        Q!("    vpbroadcastd    " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 3))]"),
        Q!("    vpbroadcastd    " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 3))]"),
        Q!("    vpsubd          " "ymm12, ymm6, ymm4"),
        Q!("    vpaddd          " "ymm4, ymm6, ymm4"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm6, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm6, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm6, ymm6, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm6, ymm6, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm6, ymm12, ymm6, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm7, ymm5"),
        Q!("    vpaddd          " "ymm5, ymm7, ymm5"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm7, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm7, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm7, ymm7, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm7, ymm12, ymm7, 0xAA"),

        Q!("    vpbroadcastd    " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 2))]"),
        Q!("    vpbroadcastd    " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 2))]"),
        Q!("    vpsubd          " "ymm12, ymm10, ymm8"),
        Q!("    vpaddd          " "ymm8, ymm10, ymm8"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm10, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm10, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm10, ymm10, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm10, ymm10, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm10, ymm12, ymm10, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm11, ymm9"),
        Q!("    vpaddd          " "ymm9, ymm11, ymm9"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm11, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm11, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm11, ymm12, ymm11, 0xAA"),

        // Bounds: |ymm{i}| < 128q

        // level 7
        Q!("    vpbroadcastd    " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 0))]"),
        Q!("    vpbroadcastd    " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 0))]"),

        Q!("    vpsubd          " "ymm12, ymm8, ymm4"),
        Q!("    vpaddd          " "ymm4, ymm8, ymm4"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm8, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm8, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm8, ymm12, ymm8, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm9, ymm5"),
        Q!("    vpaddd          " "ymm5, ymm9, ymm5"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm9, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm9, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm9, ymm9, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm9, ymm12, ymm9, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm10, ymm6"),
        Q!("    vpaddd          " "ymm6, ymm10, ymm6"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm10, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm10, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm10, ymm10, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm10, ymm10, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm10, ymm12, ymm10, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm11, ymm7"),
        Q!("    vpaddd          " "ymm7, ymm11, ymm7"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm11, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm11, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm11, ymm12, ymm11, 0xAA"),

        //
        // Bounds: |ymm{i}| < 256q          for i in 4...7
        // < MONTMUL_BOUND for i in 8...11
        //

        Q!("    vmovdqa         " "[rdi + 512 + 32 * 2], ymm8"),
        Q!("    vmovdqa         " "[rdi + 640 + 32 * 2], ymm9"),
        Q!("    vmovdqa         " "[rdi + 768 + 32 * 2], ymm10"),
        Q!("    vmovdqa         " "[rdi + 896 + 32 * 2], ymm11"),

        //
        // In order to (a) remove the factor of 256 arising from the 256-point INTT
        // butterflies and (b) transform the output into Montgomery domain, we need to
        // multiply all coefficients by 2^32/256.
        //
        // For ymm{8,9,10,11}, the scaling has been merged into the last butterfly, so
        // only ymm{4,5,6,7} need to be scaled explicitly.
        //
        // The scaling is achieved by computing montmul(-, MLD_AVX2_DIV).
        //
        // Bounds: |ymm{i}| < 256q for i in 4...7
        //

        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_8XDIV_QINV!() "))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_8XDIV!() "))]"),
        Q!("    vpmuldq         " "ymm12, ymm4, ymm1"),
        Q!("    vpmuldq         " "ymm13, ymm5, ymm1"),
        Q!("    vmovshdup       " "ymm8, ymm4"),
        Q!("    vmovshdup       " "ymm9, ymm5"),
        Q!("    vpmuldq         " "ymm14, ymm8, ymm1"),
        Q!("    vpmuldq         " "ymm15, ymm9, ymm1"),
        Q!("    vpmuldq         " "ymm4, ymm4, ymm2"),
        Q!("    vpmuldq         " "ymm5, ymm5, ymm2"),
        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),
        Q!("    vpmuldq         " "ymm9, ymm9, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm0"),
        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),
        Q!("    vpmuldq         " "ymm15, ymm15, ymm0"),
        Q!("    vpsubd          " "ymm4, ymm4, ymm12"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm14"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm15"),
        Q!("    vmovshdup       " "ymm4, ymm4"),
        Q!("    vmovshdup       " "ymm5, ymm5"),
        Q!("    vpblendd        " "ymm4, ymm4, ymm8, 0xAA"),
        Q!("    vpblendd        " "ymm5, ymm5, ymm9, 0xAA"),

        Q!("    vpmuldq         " "ymm12, ymm6, ymm1"),
        Q!("    vpmuldq         " "ymm13, ymm7, ymm1"),
        Q!("    vmovshdup       " "ymm8, ymm6"),
        Q!("    vmovshdup       " "ymm9, ymm7"),
        Q!("    vpmuldq         " "ymm14, ymm8, ymm1"),
        Q!("    vpmuldq         " "ymm15, ymm9, ymm1"),
        Q!("    vpmuldq         " "ymm6, ymm6, ymm2"),
        Q!("    vpmuldq         " "ymm7, ymm7, ymm2"),
        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),
        Q!("    vpmuldq         " "ymm9, ymm9, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm0"),
        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),
        Q!("    vpmuldq         " "ymm15, ymm15, ymm0"),
        Q!("    vpsubd          " "ymm6, ymm6, ymm12"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm14"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm15"),
        Q!("    vmovshdup       " "ymm6, ymm6"),
        Q!("    vmovshdup       " "ymm7, ymm7"),
        Q!("    vpblendd        " "ymm6, ymm6, ymm8, 0xAA"),
        Q!("    vpblendd        " "ymm7, ymm7, ymm9, 0xAA"),

        // Bounds: |ymm{i}| < MONTMUL_BOUND for i in 4...7

        //
        // In the following we show that |montmul(a, b)| < MONTMUL_BOUND := ceil(3q/4),
        // given that a fits inside int32_t (thus |a| <= R/2) and b is signed canonical
        // (in the range -(Q-1)/2...(Q-1)/2).
        //
        // In Section 2.2 of https://eprint.iacr.org/2023/1962, they showed that b being
        // signed canonical implies:
        //
        // |montmul(a, b)| <= (|a| (q/2) + (R/2) q) / R = (q/2) (1 + |a|/R).
        //
        // From this, simple computation gives |montmul(a, b)| <= 3q/4 < ceil(3q/4).
        //
        // See test/test_bounds.py for more empirical evidence (and some minor technical
        // details).
        //
        // TODO: Use proper citation. Currently, citations within asm can cause linter
        // to complain about unused citation, because comments are not preserved
        // after simpasm.
        //

        Q!("    vmovdqa         " "[rdi + 0 + 32 * 2], ymm4"),
        Q!("    vmovdqa         " "[rdi + 128 + 32 * 2], ymm5"),
        Q!("    vmovdqa         " "[rdi + 256 + 32 * 2], ymm6"),
        Q!("    vmovdqa         " "[rdi + 384 + 32 * 2], ymm7"),
        Q!("    vmovdqa         " "ymm4, [rdi + 0 + 32 * 3]"),
        Q!("    vmovdqa         " "ymm5, [rdi + 128 + 32 * 3]"),
        Q!("    vmovdqa         " "ymm6, [rdi + 256 + 32 * 3]"),
        Q!("    vmovdqa         " "ymm7, [rdi + 384 + 32 * 3]"),
        Q!("    vmovdqa         " "ymm8, [rdi + 512 + 32 * 3]"),
        Q!("    vmovdqa         " "ymm9, [rdi + 640 + 32 * 3]"),
        Q!("    vmovdqa         " "ymm10, [rdi + 768 + 32 * 3]"),
        Q!("    vmovdqa         " "ymm11, [rdi + 896 + 32 * 3]"),

        // level 6
        Q!("    vpbroadcastd    " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 3))]"),
        Q!("    vpbroadcastd    " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 3))]"),
        Q!("    vpsubd          " "ymm12, ymm6, ymm4"),
        Q!("    vpaddd          " "ymm4, ymm6, ymm4"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm6, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm6, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm6, ymm6, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm6, ymm6, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm6, ymm12, ymm6, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm7, ymm5"),
        Q!("    vpaddd          " "ymm5, ymm7, ymm5"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm7, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm7, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm7, ymm7, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm7, ymm12, ymm7, 0xAA"),

        Q!("    vpbroadcastd    " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 2))]"),
        Q!("    vpbroadcastd    " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 2))]"),
        Q!("    vpsubd          " "ymm12, ymm10, ymm8"),
        Q!("    vpaddd          " "ymm8, ymm10, ymm8"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm10, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm10, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm10, ymm10, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm10, ymm10, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm10, ymm12, ymm10, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm11, ymm9"),
        Q!("    vpaddd          " "ymm9, ymm11, ymm9"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm11, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm11, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm11, ymm12, ymm11, 0xAA"),

        // Bounds: |ymm{i}| < 128q

        // level 7
        Q!("    vpbroadcastd    " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS_QINV!() "+ 0))]"),
        Q!("    vpbroadcastd    " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_ZETAS!() "+ 0))]"),

        Q!("    vpsubd          " "ymm12, ymm8, ymm4"),
        Q!("    vpaddd          " "ymm4, ymm8, ymm4"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm8, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm8, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm8, ymm12, ymm8, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm9, ymm5"),
        Q!("    vpaddd          " "ymm5, ymm9, ymm5"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm9, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm9, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm9, ymm9, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm9, ymm12, ymm9, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm10, ymm6"),
        Q!("    vpaddd          " "ymm6, ymm10, ymm6"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm10, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm10, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm10, ymm10, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm10, ymm10, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm10, ymm12, ymm10, 0xAA"),
        Q!("    vpsubd          " "ymm12, ymm11, ymm7"),
        Q!("    vpaddd          " "ymm7, ymm11, ymm7"),

        Q!("    vpmuldq         " "ymm13, ymm12, ymm1"),
        Q!("    vmovshdup       " "ymm11, ymm12"),
        Q!("    vpmuldq         " "ymm14, ymm11, ymm1"),

        Q!("    vpmuldq         " "ymm12, ymm12, ymm2"),
        Q!("    vpmuldq         " "ymm11, ymm11, ymm2"),

        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),

        Q!("    vpsubd          " "ymm12, ymm12, ymm13"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm14"),

        Q!("    vmovshdup       " "ymm12, ymm12"),
        Q!("    vpblendd        " "ymm11, ymm12, ymm11, 0xAA"),

        //
        // Bounds: |ymm{i}| < 256q          for i in 4...7
        // < MONTMUL_BOUND for i in 8...11
        //

        Q!("    vmovdqa         " "[rdi + 512 + 32 * 3], ymm8"),
        Q!("    vmovdqa         " "[rdi + 640 + 32 * 3], ymm9"),
        Q!("    vmovdqa         " "[rdi + 768 + 32 * 3], ymm10"),
        Q!("    vmovdqa         " "[rdi + 896 + 32 * 3], ymm11"),

        //
        // In order to (a) remove the factor of 256 arising from the 256-point INTT
        // butterflies and (b) transform the output into Montgomery domain, we need to
        // multiply all coefficients by 2^32/256.
        //
        // For ymm{8,9,10,11}, the scaling has been merged into the last butterfly, so
        // only ymm{4,5,6,7} need to be scaled explicitly.
        //
        // The scaling is achieved by computing montmul(-, MLD_AVX2_DIV).
        //
        // Bounds: |ymm{i}| < 256q for i in 4...7
        //

        Q!("    vmovdqa         " "ymm1, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_8XDIV_QINV!() "))]"),
        Q!("    vmovdqa         " "ymm2, [rsi + (4 * (" MLD_AVX2_BACKEND_DATA_OFFSET_8XDIV!() "))]"),
        Q!("    vpmuldq         " "ymm12, ymm4, ymm1"),
        Q!("    vpmuldq         " "ymm13, ymm5, ymm1"),
        Q!("    vmovshdup       " "ymm8, ymm4"),
        Q!("    vmovshdup       " "ymm9, ymm5"),
        Q!("    vpmuldq         " "ymm14, ymm8, ymm1"),
        Q!("    vpmuldq         " "ymm15, ymm9, ymm1"),
        Q!("    vpmuldq         " "ymm4, ymm4, ymm2"),
        Q!("    vpmuldq         " "ymm5, ymm5, ymm2"),
        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),
        Q!("    vpmuldq         " "ymm9, ymm9, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm0"),
        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),
        Q!("    vpmuldq         " "ymm15, ymm15, ymm0"),
        Q!("    vpsubd          " "ymm4, ymm4, ymm12"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm14"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm15"),
        Q!("    vmovshdup       " "ymm4, ymm4"),
        Q!("    vmovshdup       " "ymm5, ymm5"),
        Q!("    vpblendd        " "ymm4, ymm4, ymm8, 0xAA"),
        Q!("    vpblendd        " "ymm5, ymm5, ymm9, 0xAA"),

        Q!("    vpmuldq         " "ymm12, ymm6, ymm1"),
        Q!("    vpmuldq         " "ymm13, ymm7, ymm1"),
        Q!("    vmovshdup       " "ymm8, ymm6"),
        Q!("    vmovshdup       " "ymm9, ymm7"),
        Q!("    vpmuldq         " "ymm14, ymm8, ymm1"),
        Q!("    vpmuldq         " "ymm15, ymm9, ymm1"),
        Q!("    vpmuldq         " "ymm6, ymm6, ymm2"),
        Q!("    vpmuldq         " "ymm7, ymm7, ymm2"),
        Q!("    vpmuldq         " "ymm8, ymm8, ymm2"),
        Q!("    vpmuldq         " "ymm9, ymm9, ymm2"),
        Q!("    vpmuldq         " "ymm12, ymm12, ymm0"),
        Q!("    vpmuldq         " "ymm13, ymm13, ymm0"),
        Q!("    vpmuldq         " "ymm14, ymm14, ymm0"),
        Q!("    vpmuldq         " "ymm15, ymm15, ymm0"),
        Q!("    vpsubd          " "ymm6, ymm6, ymm12"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm13"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm14"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm15"),
        Q!("    vmovshdup       " "ymm6, ymm6"),
        Q!("    vmovshdup       " "ymm7, ymm7"),
        Q!("    vpblendd        " "ymm6, ymm6, ymm8, 0xAA"),
        Q!("    vpblendd        " "ymm7, ymm7, ymm9, 0xAA"),

        // Bounds: |ymm{i}| < MONTMUL_BOUND for i in 4...7

        //
        // In the following we show that |montmul(a, b)| < MONTMUL_BOUND := ceil(3q/4),
        // given that a fits inside int32_t (thus |a| <= R/2) and b is signed canonical
        // (in the range -(Q-1)/2...(Q-1)/2).
        //
        // In Section 2.2 of https://eprint.iacr.org/2023/1962, they showed that b being
        // signed canonical implies:
        //
        // |montmul(a, b)| <= (|a| (q/2) + (R/2) q) / R = (q/2) (1 + |a|/R).
        //
        // From this, simple computation gives |montmul(a, b)| <= 3q/4 < ceil(3q/4).
        //
        // See test/test_bounds.py for more empirical evidence (and some minor technical
        // details).
        //
        // TODO: Use proper citation. Currently, citations within asm can cause linter
        // to complain about unused citation, because comments are not preserved
        // after simpasm.
        //

        Q!("    vmovdqa         " "[rdi + 0 + 32 * 3], ymm4"),
        Q!("    vmovdqa         " "[rdi + 128 + 32 * 3], ymm5"),
        Q!("    vmovdqa         " "[rdi + 256 + 32 * 3], ymm6"),
        Q!("    vmovdqa         " "[rdi + 384 + 32 * 3], ymm7"),

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
        mldsa_intt,
        &mut crate::low::abi::Aligned([0; 256]).0,
        &crate::low::abi::Aligned([0; 624]).0
    );
}
