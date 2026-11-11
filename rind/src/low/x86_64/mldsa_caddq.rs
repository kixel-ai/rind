// generated source. do not edit.
#![allow(non_upper_case_globals, unused_macros, unused_imports)]
use crate::low::macros::*;

// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT

// ----------------------------------------------------------------------------
// Conditional addition of Q to polynomial coefficients for ML-DSA
// Input/output a[256] (signed 32-bit words)
//
// For each coefficient x in (-Q, Q), computes x rem Q in [0, Q).
// If x < 0, adds Q = 8380417; otherwise leaves x unchanged.
//
// extern void mldsa_caddq(int32_t a[static 256]);
//
// Standard x86-64 ABI: RDI = a
// Microsoft x64 ABI:   RCX = a
// ----------------------------------------------------------------------------

// This implementation is derived from the public domain AVX2 Dilithium
// implementation (pq-crystals/dilithium) via the mldsa-native project.

// Transliterated from s2n-bignum's x86/mldsa/mldsa_caddq.S.
/// Conditional addition of Q to polynomial coefficients for ML-DSA
///
/// Input/output a[256] (signed 32-bit words)
///
/// For each coefficient x in (-Q, Q), computes x rem Q in [0, Q).
/// If x < 0, adds Q = 8380417; otherwise leaves x unchanged.
#[inline(never)]
pub(crate) fn mldsa_caddq(a: &mut [i32; 256]) {
    assert!((a.as_mut_ptr() as usize).is_multiple_of(32));
    // SAFETY: inline assembly. see [crate::low::inline_assembly_safety] for safety info.
    unsafe {
        core::arch::asm!(

        Q!("    endbr64         " ),

        // Set up constants: ymm2 = zero, ymm1 = Q broadcast
        Q!("    vpxor           " "xmm2, xmm2, xmm2"),
        Q!("    mov             " "eax, 8380417"),
        Q!("    vmovd           " "xmm1, eax"),
        Q!("    vpbroadcastd    " "ymm1, xmm1"),

        // Process all 256 coefficients (32 vectors of 8 int32 each)
        Q!("    vpcmpgtd        " "ymm0, ymm2, [rdi + 0]"),
        Q!("    vpand           " "ymm0, ymm0, ymm1"),
        Q!("    vpaddd          " "ymm0, ymm0, [rdi + 0]"),
        Q!("    vmovdqa         " "[rdi + 0], ymm0"),
        Q!("    vpcmpgtd        " "ymm3, ymm2, [rdi + 32]"),
        Q!("    vpand           " "ymm3, ymm3, ymm1"),
        Q!("    vpaddd          " "ymm3, ymm3, [rdi + 32]"),
        Q!("    vmovdqa         " "[rdi + 32], ymm3"),
        Q!("    vpcmpgtd        " "ymm4, ymm2, [rdi + 64]"),
        Q!("    vpand           " "ymm4, ymm4, ymm1"),
        Q!("    vpaddd          " "ymm4, ymm4, [rdi + 64]"),
        Q!("    vmovdqa         " "[rdi + 64], ymm4"),
        Q!("    vpcmpgtd        " "ymm5, ymm2, [rdi + 96]"),
        Q!("    vpand           " "ymm5, ymm5, ymm1"),
        Q!("    vpaddd          " "ymm5, ymm5, [rdi + 96]"),
        Q!("    vmovdqa         " "[rdi + 96], ymm5"),
        Q!("    vpcmpgtd        " "ymm0, ymm2, [rdi + 128]"),
        Q!("    vpand           " "ymm0, ymm0, ymm1"),
        Q!("    vpaddd          " "ymm0, ymm0, [rdi + 128]"),
        Q!("    vmovdqa         " "[rdi + 128], ymm0"),
        Q!("    vpcmpgtd        " "ymm3, ymm2, [rdi + 160]"),
        Q!("    vpand           " "ymm3, ymm3, ymm1"),
        Q!("    vpaddd          " "ymm3, ymm3, [rdi + 160]"),
        Q!("    vmovdqa         " "[rdi + 160], ymm3"),
        Q!("    vpcmpgtd        " "ymm4, ymm2, [rdi + 192]"),
        Q!("    vpand           " "ymm4, ymm4, ymm1"),
        Q!("    vpaddd          " "ymm4, ymm4, [rdi + 192]"),
        Q!("    vmovdqa         " "[rdi + 192], ymm4"),
        Q!("    vpcmpgtd        " "ymm5, ymm2, [rdi + 224]"),
        Q!("    vpand           " "ymm5, ymm5, ymm1"),
        Q!("    vpaddd          " "ymm5, ymm5, [rdi + 224]"),
        Q!("    vmovdqa         " "[rdi + 224], ymm5"),
        Q!("    vpcmpgtd        " "ymm0, ymm2, [rdi + 256]"),
        Q!("    vpand           " "ymm0, ymm0, ymm1"),
        Q!("    vpaddd          " "ymm0, ymm0, [rdi + 256]"),
        Q!("    vmovdqa         " "[rdi + 256], ymm0"),
        Q!("    vpcmpgtd        " "ymm3, ymm2, [rdi + 288]"),
        Q!("    vpand           " "ymm3, ymm3, ymm1"),
        Q!("    vpaddd          " "ymm3, ymm3, [rdi + 288]"),
        Q!("    vmovdqa         " "[rdi + 288], ymm3"),
        Q!("    vpcmpgtd        " "ymm4, ymm2, [rdi + 320]"),
        Q!("    vpand           " "ymm4, ymm4, ymm1"),
        Q!("    vpaddd          " "ymm4, ymm4, [rdi + 320]"),
        Q!("    vmovdqa         " "[rdi + 320], ymm4"),
        Q!("    vpcmpgtd        " "ymm5, ymm2, [rdi + 352]"),
        Q!("    vpand           " "ymm5, ymm5, ymm1"),
        Q!("    vpaddd          " "ymm5, ymm5, [rdi + 352]"),
        Q!("    vmovdqa         " "[rdi + 352], ymm5"),
        Q!("    vpcmpgtd        " "ymm0, ymm2, [rdi + 384]"),
        Q!("    vpand           " "ymm0, ymm0, ymm1"),
        Q!("    vpaddd          " "ymm0, ymm0, [rdi + 384]"),
        Q!("    vmovdqa         " "[rdi + 384], ymm0"),
        Q!("    vpcmpgtd        " "ymm3, ymm2, [rdi + 416]"),
        Q!("    vpand           " "ymm3, ymm3, ymm1"),
        Q!("    vpaddd          " "ymm3, ymm3, [rdi + 416]"),
        Q!("    vmovdqa         " "[rdi + 416], ymm3"),
        Q!("    vpcmpgtd        " "ymm4, ymm2, [rdi + 448]"),
        Q!("    vpand           " "ymm4, ymm4, ymm1"),
        Q!("    vpaddd          " "ymm4, ymm4, [rdi + 448]"),
        Q!("    vmovdqa         " "[rdi + 448], ymm4"),
        Q!("    vpcmpgtd        " "ymm5, ymm2, [rdi + 480]"),
        Q!("    vpand           " "ymm5, ymm5, ymm1"),
        Q!("    vpaddd          " "ymm5, ymm5, [rdi + 480]"),
        Q!("    vmovdqa         " "[rdi + 480], ymm5"),
        Q!("    vpcmpgtd        " "ymm0, ymm2, [rdi + 512]"),
        Q!("    vpand           " "ymm0, ymm0, ymm1"),
        Q!("    vpaddd          " "ymm0, ymm0, [rdi + 512]"),
        Q!("    vmovdqa         " "[rdi + 512], ymm0"),
        Q!("    vpcmpgtd        " "ymm3, ymm2, [rdi + 544]"),
        Q!("    vpand           " "ymm3, ymm3, ymm1"),
        Q!("    vpaddd          " "ymm3, ymm3, [rdi + 544]"),
        Q!("    vmovdqa         " "[rdi + 544], ymm3"),
        Q!("    vpcmpgtd        " "ymm4, ymm2, [rdi + 576]"),
        Q!("    vpand           " "ymm4, ymm4, ymm1"),
        Q!("    vpaddd          " "ymm4, ymm4, [rdi + 576]"),
        Q!("    vmovdqa         " "[rdi + 576], ymm4"),
        Q!("    vpcmpgtd        " "ymm5, ymm2, [rdi + 608]"),
        Q!("    vpand           " "ymm5, ymm5, ymm1"),
        Q!("    vpaddd          " "ymm5, ymm5, [rdi + 608]"),
        Q!("    vmovdqa         " "[rdi + 608], ymm5"),
        Q!("    vpcmpgtd        " "ymm0, ymm2, [rdi + 640]"),
        Q!("    vpand           " "ymm0, ymm0, ymm1"),
        Q!("    vpaddd          " "ymm0, ymm0, [rdi + 640]"),
        Q!("    vmovdqa         " "[rdi + 640], ymm0"),
        Q!("    vpcmpgtd        " "ymm3, ymm2, [rdi + 672]"),
        Q!("    vpand           " "ymm3, ymm3, ymm1"),
        Q!("    vpaddd          " "ymm3, ymm3, [rdi + 672]"),
        Q!("    vmovdqa         " "[rdi + 672], ymm3"),
        Q!("    vpcmpgtd        " "ymm4, ymm2, [rdi + 704]"),
        Q!("    vpand           " "ymm4, ymm4, ymm1"),
        Q!("    vpaddd          " "ymm4, ymm4, [rdi + 704]"),
        Q!("    vmovdqa         " "[rdi + 704], ymm4"),
        Q!("    vpcmpgtd        " "ymm5, ymm2, [rdi + 736]"),
        Q!("    vpand           " "ymm5, ymm5, ymm1"),
        Q!("    vpaddd          " "ymm5, ymm5, [rdi + 736]"),
        Q!("    vmovdqa         " "[rdi + 736], ymm5"),
        Q!("    vpcmpgtd        " "ymm0, ymm2, [rdi + 768]"),
        Q!("    vpand           " "ymm0, ymm0, ymm1"),
        Q!("    vpaddd          " "ymm0, ymm0, [rdi + 768]"),
        Q!("    vmovdqa         " "[rdi + 768], ymm0"),
        Q!("    vpcmpgtd        " "ymm3, ymm2, [rdi + 800]"),
        Q!("    vpand           " "ymm3, ymm3, ymm1"),
        Q!("    vpaddd          " "ymm3, ymm3, [rdi + 800]"),
        Q!("    vmovdqa         " "[rdi + 800], ymm3"),
        Q!("    vpcmpgtd        " "ymm4, ymm2, [rdi + 832]"),
        Q!("    vpand           " "ymm4, ymm4, ymm1"),
        Q!("    vpaddd          " "ymm4, ymm4, [rdi + 832]"),
        Q!("    vmovdqa         " "[rdi + 832], ymm4"),
        Q!("    vpcmpgtd        " "ymm5, ymm2, [rdi + 864]"),
        Q!("    vpand           " "ymm5, ymm5, ymm1"),
        Q!("    vpaddd          " "ymm5, ymm5, [rdi + 864]"),
        Q!("    vmovdqa         " "[rdi + 864], ymm5"),
        Q!("    vpcmpgtd        " "ymm0, ymm2, [rdi + 896]"),
        Q!("    vpand           " "ymm0, ymm0, ymm1"),
        Q!("    vpaddd          " "ymm0, ymm0, [rdi + 896]"),
        Q!("    vmovdqa         " "[rdi + 896], ymm0"),
        Q!("    vpcmpgtd        " "ymm3, ymm2, [rdi + 928]"),
        Q!("    vpand           " "ymm3, ymm3, ymm1"),
        Q!("    vpaddd          " "ymm3, ymm3, [rdi + 928]"),
        Q!("    vmovdqa         " "[rdi + 928], ymm3"),
        Q!("    vpcmpgtd        " "ymm4, ymm2, [rdi + 960]"),
        Q!("    vpand           " "ymm4, ymm4, ymm1"),
        Q!("    vpaddd          " "ymm4, ymm4, [rdi + 960]"),
        Q!("    vmovdqa         " "[rdi + 960], ymm4"),
        Q!("    vpcmpgtd        " "ymm5, ymm2, [rdi + 992]"),
        Q!("    vpand           " "ymm5, ymm5, ymm1"),
        Q!("    vpaddd          " "ymm5, ymm5, [rdi + 992]"),
        Q!("    vmovdqa         " "[rdi + 992], ymm5"),

        Q!("    vzeroupper      " ),
        inout("rdi") a.as_mut_ptr() => _,
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
    crate::low::abi::call!(mldsa_caddq, &mut crate::low::abi::Aligned([0; 256]).0);
}
