// generated source. do not edit.
#![allow(non_upper_case_globals, unused_macros, unused_imports)]
use crate::low::macros::*;

// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT

// ----------------------------------------------------------------------------
// Canonical reduction of polynomial coefficients for ML-DSA
// Input a[256] (signed 32-bit words); output a[256] (signed 32-bit words)
//
// This reduces each element of the 256-element array of 32-bit signed
// integers modulo 8380417 with the result being centered around zero,
// specifically -6283009 <= r <= 6283008, in-place.
//
// Each input coefficient must satisfy a <= 0x7fbfffff (2143289343); this
// rules out the top 0x400000 positive values, for which the internal
// "+ 4194304" rounding step would overflow a signed 32-bit word and give
// an incorrect (non-congruent) result. Every input in the standard ML-DSA
// coefficient range comfortably satisfies this.
//
// extern void mldsa_reduce(int32_t a[static 256]);
//
// Standard x86-64 ABI: RDI = a
// Microsoft x64 ABI:   RCX = a
// ----------------------------------------------------------------------------

macro_rules! a {
    () => {
        "rdi"
    };
}

// Transliterated from s2n-bignum's x86/mldsa/mldsa_reduce.S.
/// Canonical reduction of polynomial coefficients for ML-DSA
///
/// Input a[256] (signed 32-bit words); output a[256] (signed 32-bit words)
///
/// This reduces each element of the 256-element array of 32-bit signed
/// integers modulo 8380417 with the result being centered around zero,
/// specifically -6283009 <= r <= 6283008, in-place.
///
/// Each input coefficient must satisfy a <= 0x7fbfffff (2143289343); this
/// rules out the top 0x400000 positive values, for which the internal
/// "+ 4194304" rounding step would overflow a signed 32-bit word and give
/// an incorrect (non-congruent) result. Every input in the standard ML-DSA
/// coefficient range comfortably satisfies this.
#[inline(never)]
pub(crate) fn mldsa_reduce(a: &mut [i32; 256]) {
    assert!((a.as_mut_ptr() as usize).is_multiple_of(32));
    // SAFETY: inline assembly. see [crate::low::inline_assembly_safety] for safety info.
    unsafe {
        core::arch::asm!(

        Q!("    endbr64         " ),

        // Load constants - poly_reduce only takes one parameter (the polynomial)
        Q!("    mov             " "eax, 8380417"),
        Q!("    movd            " "xmm0, eax"),
        Q!("    vpbroadcastd    " "ymm0, xmm0"),

        // Load offset constant inline to avoid PIE issues
        Q!("    mov             " "eax, 4194304"),
        Q!("    movd            " "xmm1, eax"),
        Q!("    vpbroadcastd    " "ymm1, xmm1"),

        // Process all 32 vectors (256 coefficients) using NTT-style block processing
        // First batch: vectors 0-7
        Q!("    vmovdqa         " "ymm4, [rdi + 0]"),
        Q!("    vmovdqa         " "ymm5, [rdi + 32]"),
        Q!("    vmovdqa         " "ymm6, [rdi + 64]"),
        Q!("    vmovdqa         " "ymm7, [rdi + 96]"),
        Q!("    vmovdqa         " "ymm8, [rdi + 128]"),
        Q!("    vmovdqa         " "ymm9, [rdi + 160]"),
        Q!("    vmovdqa         " "ymm10, [rdi + 192]"),
        Q!("    vmovdqa         " "ymm11, [rdi + 224]"),

        // Process all 8 vectors in parallel - first half of pipeline
        Q!("    vpaddd          " "ymm12, ymm4, ymm1"),
        Q!("    vpaddd          " "ymm13, ymm5, ymm1"),
        Q!("    vpaddd          " "ymm14, ymm6, ymm1"),
        Q!("    vpaddd          " "ymm15, ymm7, ymm1"),
        Q!("    vpsrad          " "ymm12, ymm12, 23"),
        Q!("    vpsrad          " "ymm13, ymm13, 23"),
        Q!("    vpsrad          " "ymm14, ymm14, 23"),
        Q!("    vpsrad          " "ymm15, ymm15, 23"),
        Q!("    vpmulld         " "ymm12, ymm12, ymm0"),
        Q!("    vpmulld         " "ymm13, ymm13, ymm0"),
        Q!("    vpmulld         " "ymm14, ymm14, ymm0"),
        Q!("    vpmulld         " "ymm15, ymm15, ymm0"),
        Q!("    vpsubd          " "ymm4, ymm4, ymm12"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm13"),
        Q!("    vpsubd          " "ymm6, ymm6, ymm14"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm15"),

        // Process second half of vectors
        Q!("    vpaddd          " "ymm12, ymm8, ymm1"),
        Q!("    vpaddd          " "ymm13, ymm9, ymm1"),
        Q!("    vpaddd          " "ymm14, ymm10, ymm1"),
        Q!("    vpaddd          " "ymm15, ymm11, ymm1"),
        Q!("    vpsrad          " "ymm12, ymm12, 23"),
        Q!("    vpsrad          " "ymm13, ymm13, 23"),
        Q!("    vpsrad          " "ymm14, ymm14, 23"),
        Q!("    vpsrad          " "ymm15, ymm15, 23"),
        Q!("    vpmulld         " "ymm12, ymm12, ymm0"),
        Q!("    vpmulld         " "ymm13, ymm13, ymm0"),
        Q!("    vpmulld         " "ymm14, ymm14, ymm0"),
        Q!("    vpmulld         " "ymm15, ymm15, ymm0"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm12"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm13"),
        Q!("    vpsubd          " "ymm10, ymm10, ymm14"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm15"),

        // Store first batch results
        Q!("    vmovdqa         " "[rdi + 0], ymm4"),
        Q!("    vmovdqa         " "[rdi + 32], ymm5"),
        Q!("    vmovdqa         " "[rdi + 64], ymm6"),
        Q!("    vmovdqa         " "[rdi + 96], ymm7"),
        Q!("    vmovdqa         " "[rdi + 128], ymm8"),
        Q!("    vmovdqa         " "[rdi + 160], ymm9"),
        Q!("    vmovdqa         " "[rdi + 192], ymm10"),
        Q!("    vmovdqa         " "[rdi + 224], ymm11"),

        // Second batch: vectors 8-15
        Q!("    vmovdqa         " "ymm4, [rdi + 256]"),
        Q!("    vmovdqa         " "ymm5, [rdi + 288]"),
        Q!("    vmovdqa         " "ymm6, [rdi + 320]"),
        Q!("    vmovdqa         " "ymm7, [rdi + 352]"),
        Q!("    vmovdqa         " "ymm8, [rdi + 384]"),
        Q!("    vmovdqa         " "ymm9, [rdi + 416]"),
        Q!("    vmovdqa         " "ymm10, [rdi + 448]"),
        Q!("    vmovdqa         " "ymm11, [rdi + 480]"),

        // Process second batch in parallel
        Q!("    vpaddd          " "ymm12, ymm4, ymm1"),
        Q!("    vpaddd          " "ymm13, ymm5, ymm1"),
        Q!("    vpaddd          " "ymm14, ymm6, ymm1"),
        Q!("    vpaddd          " "ymm15, ymm7, ymm1"),
        Q!("    vpsrad          " "ymm12, ymm12, 23"),
        Q!("    vpsrad          " "ymm13, ymm13, 23"),
        Q!("    vpsrad          " "ymm14, ymm14, 23"),
        Q!("    vpsrad          " "ymm15, ymm15, 23"),
        Q!("    vpmulld         " "ymm12, ymm12, ymm0"),
        Q!("    vpmulld         " "ymm13, ymm13, ymm0"),
        Q!("    vpmulld         " "ymm14, ymm14, ymm0"),
        Q!("    vpmulld         " "ymm15, ymm15, ymm0"),
        Q!("    vpsubd          " "ymm4, ymm4, ymm12"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm13"),
        Q!("    vpsubd          " "ymm6, ymm6, ymm14"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm15"),

        Q!("    vpaddd          " "ymm12, ymm8, ymm1"),
        Q!("    vpaddd          " "ymm13, ymm9, ymm1"),
        Q!("    vpaddd          " "ymm14, ymm10, ymm1"),
        Q!("    vpaddd          " "ymm15, ymm11, ymm1"),
        Q!("    vpsrad          " "ymm12, ymm12, 23"),
        Q!("    vpsrad          " "ymm13, ymm13, 23"),
        Q!("    vpsrad          " "ymm14, ymm14, 23"),
        Q!("    vpsrad          " "ymm15, ymm15, 23"),
        Q!("    vpmulld         " "ymm12, ymm12, ymm0"),
        Q!("    vpmulld         " "ymm13, ymm13, ymm0"),
        Q!("    vpmulld         " "ymm14, ymm14, ymm0"),
        Q!("    vpmulld         " "ymm15, ymm15, ymm0"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm12"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm13"),
        Q!("    vpsubd          " "ymm10, ymm10, ymm14"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm15"),

        // Store second batch
        Q!("    vmovdqa         " "[rdi + 256], ymm4"),
        Q!("    vmovdqa         " "[rdi + 288], ymm5"),
        Q!("    vmovdqa         " "[rdi + 320], ymm6"),
        Q!("    vmovdqa         " "[rdi + 352], ymm7"),
        Q!("    vmovdqa         " "[rdi + 384], ymm8"),
        Q!("    vmovdqa         " "[rdi + 416], ymm9"),
        Q!("    vmovdqa         " "[rdi + 448], ymm10"),
        Q!("    vmovdqa         " "[rdi + 480], ymm11"),

        // Third batch: vectors 16-23
        Q!("    vmovdqa         " "ymm4, [rdi + 512]"),
        Q!("    vmovdqa         " "ymm5, [rdi + 544]"),
        Q!("    vmovdqa         " "ymm6, [rdi + 576]"),
        Q!("    vmovdqa         " "ymm7, [rdi + 608]"),
        Q!("    vmovdqa         " "ymm8, [rdi + 640]"),
        Q!("    vmovdqa         " "ymm9, [rdi + 672]"),
        Q!("    vmovdqa         " "ymm10, [rdi + 704]"),
        Q!("    vmovdqa         " "ymm11, [rdi + 736]"),

        // Process third batch
        Q!("    vpaddd          " "ymm12, ymm4, ymm1"),
        Q!("    vpaddd          " "ymm13, ymm5, ymm1"),
        Q!("    vpaddd          " "ymm14, ymm6, ymm1"),
        Q!("    vpaddd          " "ymm15, ymm7, ymm1"),
        Q!("    vpsrad          " "ymm12, ymm12, 23"),
        Q!("    vpsrad          " "ymm13, ymm13, 23"),
        Q!("    vpsrad          " "ymm14, ymm14, 23"),
        Q!("    vpsrad          " "ymm15, ymm15, 23"),
        Q!("    vpmulld         " "ymm12, ymm12, ymm0"),
        Q!("    vpmulld         " "ymm13, ymm13, ymm0"),
        Q!("    vpmulld         " "ymm14, ymm14, ymm0"),
        Q!("    vpmulld         " "ymm15, ymm15, ymm0"),
        Q!("    vpsubd          " "ymm4, ymm4, ymm12"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm13"),
        Q!("    vpsubd          " "ymm6, ymm6, ymm14"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm15"),

        Q!("    vpaddd          " "ymm12, ymm8, ymm1"),
        Q!("    vpaddd          " "ymm13, ymm9, ymm1"),
        Q!("    vpaddd          " "ymm14, ymm10, ymm1"),
        Q!("    vpaddd          " "ymm15, ymm11, ymm1"),
        Q!("    vpsrad          " "ymm12, ymm12, 23"),
        Q!("    vpsrad          " "ymm13, ymm13, 23"),
        Q!("    vpsrad          " "ymm14, ymm14, 23"),
        Q!("    vpsrad          " "ymm15, ymm15, 23"),
        Q!("    vpmulld         " "ymm12, ymm12, ymm0"),
        Q!("    vpmulld         " "ymm13, ymm13, ymm0"),
        Q!("    vpmulld         " "ymm14, ymm14, ymm0"),
        Q!("    vpmulld         " "ymm15, ymm15, ymm0"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm12"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm13"),
        Q!("    vpsubd          " "ymm10, ymm10, ymm14"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm15"),

        // Store third batch
        Q!("    vmovdqa         " "[rdi + 512], ymm4"),
        Q!("    vmovdqa         " "[rdi + 544], ymm5"),
        Q!("    vmovdqa         " "[rdi + 576], ymm6"),
        Q!("    vmovdqa         " "[rdi + 608], ymm7"),
        Q!("    vmovdqa         " "[rdi + 640], ymm8"),
        Q!("    vmovdqa         " "[rdi + 672], ymm9"),
        Q!("    vmovdqa         " "[rdi + 704], ymm10"),
        Q!("    vmovdqa         " "[rdi + 736], ymm11"),

        // Fourth batch: vectors 24-31
        Q!("    vmovdqa         " "ymm4, [rdi + 768]"),
        Q!("    vmovdqa         " "ymm5, [rdi + 800]"),
        Q!("    vmovdqa         " "ymm6, [rdi + 832]"),
        Q!("    vmovdqa         " "ymm7, [rdi + 864]"),
        Q!("    vmovdqa         " "ymm8, [rdi + 896]"),
        Q!("    vmovdqa         " "ymm9, [rdi + 928]"),
        Q!("    vmovdqa         " "ymm10, [rdi + 960]"),
        Q!("    vmovdqa         " "ymm11, [rdi + 992]"),

        // Process final batch
        Q!("    vpaddd          " "ymm12, ymm4, ymm1"),
        Q!("    vpaddd          " "ymm13, ymm5, ymm1"),
        Q!("    vpaddd          " "ymm14, ymm6, ymm1"),
        Q!("    vpaddd          " "ymm15, ymm7, ymm1"),
        Q!("    vpsrad          " "ymm12, ymm12, 23"),
        Q!("    vpsrad          " "ymm13, ymm13, 23"),
        Q!("    vpsrad          " "ymm14, ymm14, 23"),
        Q!("    vpsrad          " "ymm15, ymm15, 23"),
        Q!("    vpmulld         " "ymm12, ymm12, ymm0"),
        Q!("    vpmulld         " "ymm13, ymm13, ymm0"),
        Q!("    vpmulld         " "ymm14, ymm14, ymm0"),
        Q!("    vpmulld         " "ymm15, ymm15, ymm0"),
        Q!("    vpsubd          " "ymm4, ymm4, ymm12"),
        Q!("    vpsubd          " "ymm5, ymm5, ymm13"),
        Q!("    vpsubd          " "ymm6, ymm6, ymm14"),
        Q!("    vpsubd          " "ymm7, ymm7, ymm15"),

        Q!("    vpaddd          " "ymm12, ymm8, ymm1"),
        Q!("    vpaddd          " "ymm13, ymm9, ymm1"),
        Q!("    vpaddd          " "ymm14, ymm10, ymm1"),
        Q!("    vpaddd          " "ymm15, ymm11, ymm1"),
        Q!("    vpsrad          " "ymm12, ymm12, 23"),
        Q!("    vpsrad          " "ymm13, ymm13, 23"),
        Q!("    vpsrad          " "ymm14, ymm14, 23"),
        Q!("    vpsrad          " "ymm15, ymm15, 23"),
        Q!("    vpmulld         " "ymm12, ymm12, ymm0"),
        Q!("    vpmulld         " "ymm13, ymm13, ymm0"),
        Q!("    vpmulld         " "ymm14, ymm14, ymm0"),
        Q!("    vpmulld         " "ymm15, ymm15, ymm0"),
        Q!("    vpsubd          " "ymm8, ymm8, ymm12"),
        Q!("    vpsubd          " "ymm9, ymm9, ymm13"),
        Q!("    vpsubd          " "ymm10, ymm10, ymm14"),
        Q!("    vpsubd          " "ymm11, ymm11, ymm15"),

        // Store final batch
        Q!("    vmovdqa         " "[rdi + 768], ymm4"),
        Q!("    vmovdqa         " "[rdi + 800], ymm5"),
        Q!("    vmovdqa         " "[rdi + 832], ymm6"),
        Q!("    vmovdqa         " "[rdi + 864], ymm7"),
        Q!("    vmovdqa         " "[rdi + 896], ymm8"),
        Q!("    vmovdqa         " "[rdi + 928], ymm9"),
        Q!("    vmovdqa         " "[rdi + 960], ymm10"),
        Q!("    vmovdqa         " "[rdi + 992], ymm11"),

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
    crate::low::abi::call!(mldsa_reduce, &mut crate::low::abi::Aligned([0; 256]).0);
}
