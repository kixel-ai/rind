// generated source. do not edit.
#![allow(non_upper_case_globals, unused_macros, unused_imports)]
use crate::low::macros::*;

// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT

// ----------------------------------------------------------------------------
// NTT unpack for ML-DSA
// Input a[256] (signed 32-bit words); output a[256] (signed 32-bit words)
//
// This function performs the unpacking transformation on NTT-domain polynomial
// coefficients, converting from a packed representation to a standard layout.
// The operation is performed in-place on a 256-element array of signed 32-bit
// integers. This is a supporting operation for ML-DSA signature operations.
//
// This implementation is derived from the public domain AVX2 Dilithium
// implementation from CRYSTALS-Dilithium optimized AVX2 implementation by
// Bai, Ducas, Kiltz, Lepoint, Lyubashevsky, Schwabe, Seiler, Stehlé
// (https://github.com/pq-crystals/dilithium/tree/master/avx2)
//
// extern void mldsa_nttunpack(int32_t a[static 256]);
//
// Standard x86-64 ABI: RDI = a
// Microsoft x64 ABI:   RCX = a
// ----------------------------------------------------------------------------

macro_rules! a {
    () => {
        "rdi"
    };
}

// Transliterated from s2n-bignum's x86/mldsa/mldsa_nttunpack.S.
/// NTT unpack for ML-DSA
///
/// Input a[256] (signed 32-bit words); output a[256] (signed 32-bit words)
///
/// This function performs the unpacking transformation on NTT-domain polynomial
/// coefficients, converting from a packed representation to a standard layout.
/// The operation is performed in-place on a 256-element array of signed 32-bit
/// integers. This is a supporting operation for ML-DSA signature operations.
///
/// This implementation is derived from the public domain AVX2 Dilithium
/// implementation from CRYSTALS-Dilithium optimized AVX2 implementation by
/// Bai, Ducas, Kiltz, Lepoint, Lyubashevsky, Schwabe, Seiler, Stehlé
/// (https://github.com/pq-crystals/dilithium/tree/master/avx2)
#[inline(never)]
pub(crate) fn mldsa_nttunpack(a: &mut [i32; 256]) {
    assert!((a.as_mut_ptr() as usize).is_multiple_of(32));
    // SAFETY: inline assembly. see [crate::low::inline_assembly_safety] for safety info.
    unsafe {
        core::arch::asm!(

        Q!("    endbr64         " ),

        // load
        Q!("    vmovdqa         " "ymm4, [rdi + (0 + 0)]"),
        Q!("    vmovdqa         " "ymm5, [rdi + (0 + 32)]"),
        Q!("    vmovdqa         " "ymm6, [rdi + (0 + 64)]"),
        Q!("    vmovdqa         " "ymm7, [rdi + (0 + 96)]"),
        Q!("    vmovdqa         " "ymm8, [rdi + (0 + 128)]"),
        Q!("    vmovdqa         " "ymm9, [rdi + (0 + 160)]"),
        Q!("    vmovdqa         " "ymm10, [rdi + (0 + 192)]"),
        Q!("    vmovdqa         " "ymm11, [rdi + (0 + 224)]"),

        Q!("    vperm2i128      " "ymm3, ymm4, ymm8, 0x20"),
        Q!("    vperm2i128      " "ymm8, ymm4, ymm8, 0x31"),
        Q!("    vperm2i128      " "ymm4, ymm5, ymm9, 0x20"),
        Q!("    vperm2i128      " "ymm9, ymm5, ymm9, 0x31"),
        Q!("    vperm2i128      " "ymm5, ymm6, ymm10, 0x20"),
        Q!("    vperm2i128      " "ymm10, ymm6, ymm10, 0x31"),
        Q!("    vperm2i128      " "ymm6, ymm7, ymm11, 0x20"),
        Q!("    vperm2i128      " "ymm11, ymm7, ymm11, 0x31"),

        Q!("    vpunpcklqdq     " "ymm7, ymm3, ymm5"),
        Q!("    vpunpckhqdq     " "ymm5, ymm3, ymm5"),
        Q!("    vpunpcklqdq     " "ymm3, ymm8, ymm10"),
        Q!("    vpunpckhqdq     " "ymm10, ymm8, ymm10"),
        Q!("    vpunpcklqdq     " "ymm8, ymm4, ymm6"),
        Q!("    vpunpckhqdq     " "ymm6, ymm4, ymm6"),
        Q!("    vpunpcklqdq     " "ymm4, ymm9, ymm11"),
        Q!("    vpunpckhqdq     " "ymm11, ymm9, ymm11"),

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

        // store
        Q!("    vmovdqa         " "[rdi + (0 + 0)], ymm9"),
        Q!("    vmovdqa         " "[rdi + (0 + 32)], ymm8"),
        Q!("    vmovdqa         " "[rdi + (0 + 64)], ymm7"),
        Q!("    vmovdqa         " "[rdi + (0 + 96)], ymm6"),
        Q!("    vmovdqa         " "[rdi + (0 + 128)], ymm5"),
        Q!("    vmovdqa         " "[rdi + (0 + 160)], ymm4"),
        Q!("    vmovdqa         " "[rdi + (0 + 192)], ymm3"),
        Q!("    vmovdqa         " "[rdi + (0 + 224)], ymm11"),
        // load
        Q!("    vmovdqa         " "ymm4, [rdi + (256 + 0)]"),
        Q!("    vmovdqa         " "ymm5, [rdi + (256 + 32)]"),
        Q!("    vmovdqa         " "ymm6, [rdi + (256 + 64)]"),
        Q!("    vmovdqa         " "ymm7, [rdi + (256 + 96)]"),
        Q!("    vmovdqa         " "ymm8, [rdi + (256 + 128)]"),
        Q!("    vmovdqa         " "ymm9, [rdi + (256 + 160)]"),
        Q!("    vmovdqa         " "ymm10, [rdi + (256 + 192)]"),
        Q!("    vmovdqa         " "ymm11, [rdi + (256 + 224)]"),

        Q!("    vperm2i128      " "ymm3, ymm4, ymm8, 0x20"),
        Q!("    vperm2i128      " "ymm8, ymm4, ymm8, 0x31"),
        Q!("    vperm2i128      " "ymm4, ymm5, ymm9, 0x20"),
        Q!("    vperm2i128      " "ymm9, ymm5, ymm9, 0x31"),
        Q!("    vperm2i128      " "ymm5, ymm6, ymm10, 0x20"),
        Q!("    vperm2i128      " "ymm10, ymm6, ymm10, 0x31"),
        Q!("    vperm2i128      " "ymm6, ymm7, ymm11, 0x20"),
        Q!("    vperm2i128      " "ymm11, ymm7, ymm11, 0x31"),

        Q!("    vpunpcklqdq     " "ymm7, ymm3, ymm5"),
        Q!("    vpunpckhqdq     " "ymm5, ymm3, ymm5"),
        Q!("    vpunpcklqdq     " "ymm3, ymm8, ymm10"),
        Q!("    vpunpckhqdq     " "ymm10, ymm8, ymm10"),
        Q!("    vpunpcklqdq     " "ymm8, ymm4, ymm6"),
        Q!("    vpunpckhqdq     " "ymm6, ymm4, ymm6"),
        Q!("    vpunpcklqdq     " "ymm4, ymm9, ymm11"),
        Q!("    vpunpckhqdq     " "ymm11, ymm9, ymm11"),

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

        // store
        Q!("    vmovdqa         " "[rdi + (256 + 0)], ymm9"),
        Q!("    vmovdqa         " "[rdi + (256 + 32)], ymm8"),
        Q!("    vmovdqa         " "[rdi + (256 + 64)], ymm7"),
        Q!("    vmovdqa         " "[rdi + (256 + 96)], ymm6"),
        Q!("    vmovdqa         " "[rdi + (256 + 128)], ymm5"),
        Q!("    vmovdqa         " "[rdi + (256 + 160)], ymm4"),
        Q!("    vmovdqa         " "[rdi + (256 + 192)], ymm3"),
        Q!("    vmovdqa         " "[rdi + (256 + 224)], ymm11"),
        // load
        Q!("    vmovdqa         " "ymm4, [rdi + (512 + 0)]"),
        Q!("    vmovdqa         " "ymm5, [rdi + (512 + 32)]"),
        Q!("    vmovdqa         " "ymm6, [rdi + (512 + 64)]"),
        Q!("    vmovdqa         " "ymm7, [rdi + (512 + 96)]"),
        Q!("    vmovdqa         " "ymm8, [rdi + (512 + 128)]"),
        Q!("    vmovdqa         " "ymm9, [rdi + (512 + 160)]"),
        Q!("    vmovdqa         " "ymm10, [rdi + (512 + 192)]"),
        Q!("    vmovdqa         " "ymm11, [rdi + (512 + 224)]"),

        Q!("    vperm2i128      " "ymm3, ymm4, ymm8, 0x20"),
        Q!("    vperm2i128      " "ymm8, ymm4, ymm8, 0x31"),
        Q!("    vperm2i128      " "ymm4, ymm5, ymm9, 0x20"),
        Q!("    vperm2i128      " "ymm9, ymm5, ymm9, 0x31"),
        Q!("    vperm2i128      " "ymm5, ymm6, ymm10, 0x20"),
        Q!("    vperm2i128      " "ymm10, ymm6, ymm10, 0x31"),
        Q!("    vperm2i128      " "ymm6, ymm7, ymm11, 0x20"),
        Q!("    vperm2i128      " "ymm11, ymm7, ymm11, 0x31"),

        Q!("    vpunpcklqdq     " "ymm7, ymm3, ymm5"),
        Q!("    vpunpckhqdq     " "ymm5, ymm3, ymm5"),
        Q!("    vpunpcklqdq     " "ymm3, ymm8, ymm10"),
        Q!("    vpunpckhqdq     " "ymm10, ymm8, ymm10"),
        Q!("    vpunpcklqdq     " "ymm8, ymm4, ymm6"),
        Q!("    vpunpckhqdq     " "ymm6, ymm4, ymm6"),
        Q!("    vpunpcklqdq     " "ymm4, ymm9, ymm11"),
        Q!("    vpunpckhqdq     " "ymm11, ymm9, ymm11"),

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

        // store
        Q!("    vmovdqa         " "[rdi + (512 + 0)], ymm9"),
        Q!("    vmovdqa         " "[rdi + (512 + 32)], ymm8"),
        Q!("    vmovdqa         " "[rdi + (512 + 64)], ymm7"),
        Q!("    vmovdqa         " "[rdi + (512 + 96)], ymm6"),
        Q!("    vmovdqa         " "[rdi + (512 + 128)], ymm5"),
        Q!("    vmovdqa         " "[rdi + (512 + 160)], ymm4"),
        Q!("    vmovdqa         " "[rdi + (512 + 192)], ymm3"),
        Q!("    vmovdqa         " "[rdi + (512 + 224)], ymm11"),
        // load
        Q!("    vmovdqa         " "ymm4, [rdi + (768 + 0)]"),
        Q!("    vmovdqa         " "ymm5, [rdi + (768 + 32)]"),
        Q!("    vmovdqa         " "ymm6, [rdi + (768 + 64)]"),
        Q!("    vmovdqa         " "ymm7, [rdi + (768 + 96)]"),
        Q!("    vmovdqa         " "ymm8, [rdi + (768 + 128)]"),
        Q!("    vmovdqa         " "ymm9, [rdi + (768 + 160)]"),
        Q!("    vmovdqa         " "ymm10, [rdi + (768 + 192)]"),
        Q!("    vmovdqa         " "ymm11, [rdi + (768 + 224)]"),

        Q!("    vperm2i128      " "ymm3, ymm4, ymm8, 0x20"),
        Q!("    vperm2i128      " "ymm8, ymm4, ymm8, 0x31"),
        Q!("    vperm2i128      " "ymm4, ymm5, ymm9, 0x20"),
        Q!("    vperm2i128      " "ymm9, ymm5, ymm9, 0x31"),
        Q!("    vperm2i128      " "ymm5, ymm6, ymm10, 0x20"),
        Q!("    vperm2i128      " "ymm10, ymm6, ymm10, 0x31"),
        Q!("    vperm2i128      " "ymm6, ymm7, ymm11, 0x20"),
        Q!("    vperm2i128      " "ymm11, ymm7, ymm11, 0x31"),

        Q!("    vpunpcklqdq     " "ymm7, ymm3, ymm5"),
        Q!("    vpunpckhqdq     " "ymm5, ymm3, ymm5"),
        Q!("    vpunpcklqdq     " "ymm3, ymm8, ymm10"),
        Q!("    vpunpckhqdq     " "ymm10, ymm8, ymm10"),
        Q!("    vpunpcklqdq     " "ymm8, ymm4, ymm6"),
        Q!("    vpunpckhqdq     " "ymm6, ymm4, ymm6"),
        Q!("    vpunpcklqdq     " "ymm4, ymm9, ymm11"),
        Q!("    vpunpckhqdq     " "ymm11, ymm9, ymm11"),

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

        // store
        Q!("    vmovdqa         " "[rdi + (768 + 0)], ymm9"),
        Q!("    vmovdqa         " "[rdi + (768 + 32)], ymm8"),
        Q!("    vmovdqa         " "[rdi + (768 + 64)], ymm7"),
        Q!("    vmovdqa         " "[rdi + (768 + 96)], ymm6"),
        Q!("    vmovdqa         " "[rdi + (768 + 128)], ymm5"),
        Q!("    vmovdqa         " "[rdi + (768 + 160)], ymm4"),
        Q!("    vmovdqa         " "[rdi + (768 + 192)], ymm3"),
        Q!("    vmovdqa         " "[rdi + (768 + 224)], ymm11"),

        Q!("    vzeroupper      " ),
        inout("rdi") a.as_mut_ptr() => _,
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
    crate::low::abi::call!(mldsa_nttunpack, &mut crate::low::abi::Aligned([0; 256]).0);
}
