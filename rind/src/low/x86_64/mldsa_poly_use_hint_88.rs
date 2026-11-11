// generated source. do not edit.
#![allow(non_upper_case_globals, unused_macros, unused_imports)]
use crate::low::macros::*;

// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT

// ----------------------------------------------------------------------------
// Use the hint to correct the high bits of a polynomial for ML-DSA
// (GAMMA2 = (Q-1)/88, ML-DSA-44). Operates in place on a[256].
//
// For each coefficient a of the input polynomial (a standard canonical
// representative, 0 <= a < Q) and hint bit h in {0,1}, compute UseHint(h, a):
// the high part of the decomposition of a, adjusted up or down by one modulo
// 44 when h = 1. The corrected high part (in [0,44)) is written back in place.
//
// extern void mldsa_poly_use_hint_88(int32_t a[static 256],
//                                    const int32_t h[static 256]);
//
// Standard x86-64 ABI: RDI = a, RSI = h
// Microsoft x64 ABI:   RCX = a, RDX = h
// ----------------------------------------------------------------------------

// This implementation is derived from the public domain AVX2 Dilithium
// implementation (pq-crystals/dilithium) via the mldsa-native project.

// Transliterated from s2n-bignum's x86/mldsa/mldsa_poly_use_hint_88.S.
/// Use the hint to correct the high bits of a polynomial for ML-DSA
///
/// (GAMMA2 = (Q-1)/88, ML-DSA-44). Operates in place on a[256].
///
/// For each coefficient a of the input polynomial (a standard canonical
/// representative, 0 <= a < Q) and hint bit h in {0,1}, compute UseHint(h, a):
/// the high part of the decomposition of a, adjusted up or down by one modulo
/// 44 when h = 1. The corrected high part (in [0,44)) is written back in place.
#[inline(never)]
pub(crate) fn mldsa_poly_use_hint_88(a: &mut [i32; 256], h: &[i32; 256]) {
    assert!((a.as_mut_ptr() as usize).is_multiple_of(32));
    assert!((h.as_ptr() as usize).is_multiple_of(32));
    // SAFETY: inline assembly. see [crate::low::inline_assembly_safety] for safety info.
    unsafe {
        core::arch::asm!(

        Q!("    endbr64         " ),

        // Set up broadcast constants used by the Barrett high-bits sequence.
        Q!("    mov             " "ecx, 0x7f"),
        Q!("    xor             " "eax, eax"),
        Q!("    vpxor           " "xmm5, xmm5, xmm5"),
        Q!("    mov             " "r8d, 0x2c0b"),
        Q!("    vmovd           " "xmm8, r8d"),
        Q!("    vpbroadcastd    " "ymm8, xmm8"),
        Q!("    vmovd           " "xmm4, ecx"),
        Q!("    mov             " "ecx, 0x7e6c00"),
        Q!("    mov             " "r9d, 0x80"),
        Q!("    vmovd           " "xmm7, r9d"),
        Q!("    vpbroadcastd    " "ymm7, xmm7"),
        Q!("    mov             " "r10d, 0x2b"),
        Q!("    vmovd           " "xmm6, r10d"),
        Q!("    vpbroadcastd    " "ymm6, xmm6"),
        Q!("    vmovd           " "xmm3, ecx"),
        Q!("    vpbroadcastd    " "ymm4, xmm4"),
        Q!("    vpbroadcastd    " "ymm3, xmm3"),

        Q!(Label!("Lmldsa_poly_use_hint_88_loop", 2) ":"),
        Q!("    vmovdqa         " "ymm0, [rdi]"),
        Q!("    vmovdqa         " "ymm1, [rsi]"),
        Q!("    vpaddd          " "ymm10, ymm4, ymm0"),
        Q!("    vpsrld          " "ymm10, ymm10, 0x7"),
        Q!("    vpmulhuw        " "ymm10, ymm10, ymm8"),
        Q!("    vpmulhrsw       " "ymm10, ymm10, ymm7"),
        Q!("    vpcmpgtd        " "ymm11, ymm0, ymm3"),
        Q!("    vpandn          " "ymm9, ymm11, ymm10"),
        Q!("    vpslld          " "ymm12, ymm10, 0x1"),
        Q!("    vpaddd          " "ymm12, ymm12, ymm10"),
        Q!("    vpslld          " "ymm10, ymm12, 0x5"),
        Q!("    vpsubd          " "ymm10, ymm10, ymm12"),
        Q!("    vpslld          " "ymm10, ymm10, 0xb"),
        Q!("    vpsubd          " "ymm0, ymm0, ymm10"),
        Q!("    vpaddd          " "ymm0, ymm0, ymm11"),
        Q!("    vpcmpgtd        " "ymm0, ymm0, ymm5"),
        Q!("    vpandn          " "ymm0, ymm0, ymm1"),
        Q!("    vpslld          " "ymm0, ymm0, 0x1"),
        Q!("    vpsubd          " "ymm0, ymm1, ymm0"),
        Q!("    vpaddd          " "ymm0, ymm0, ymm9"),
        Q!("    vpblendvb       " "ymm0, ymm0, ymm6, ymm0"),
        Q!("    vpcmpgtd        " "ymm1, ymm0, ymm6"),
        Q!("    vpandn          " "ymm0, ymm1, ymm0"),
        Q!("    vmovdqa         " "[rdi], ymm0"),
        Q!("    add             " "rdi, 0x20"),
        Q!("    add             " "rsi, 0x20"),
        Q!("    add             " "rax, 0x20"),
        Q!("    cmp             " "rax, 0x400"),
        Q!("    jne             " Label!("Lmldsa_poly_use_hint_88_loop", 2, Before)),

        Q!("    vzeroupper      " ),
        inout("rdi") a.as_mut_ptr() => _,
        inout("rsi") h.as_ptr() => _,
        // clobbers
        out("r10") _,
        out("r8") _,
        out("r9") _,
        out("rax") _,
        out("rcx") _,
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
        mldsa_poly_use_hint_88,
        &mut crate::low::abi::Aligned([0; 256]).0,
        &crate::low::abi::Aligned([0; 256]).0
    );
}
