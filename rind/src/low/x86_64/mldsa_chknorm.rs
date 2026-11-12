// generated source. do not edit.
#![allow(non_upper_case_globals, unused_macros, unused_imports)]
use crate::low::macros::*;

// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT

// ----------------------------------------------------------------------------
// Infinity-norm bound check on polynomial coefficients for ML-DSA
// Input a[256] (signed 32-bit words), scalar bound
//
// Checks the infinity norm of the polynomial against the given bound.
// Returns 0 if every |coefficient| is strictly smaller than the bound;
// otherwise returns 1 (i.e. returns 1 if any |coefficient| >= bound).
// The bound is assumed to be non-negative.
//
// extern uint64_t mldsa_chknorm(const int32_t a[static 256], uint64_t bound);
//
// Standard x86-64 ABI: RDI = a, RSI = bound, returns RAX
// Microsoft x64 ABI:   RCX = a, RDX = bound, returns RAX
// ----------------------------------------------------------------------------

// This implementation is derived from the public domain AVX2 Dilithium
// implementation (pq-crystals/dilithium) via the mldsa-native project.

// For each 8-lane vector: OR into the accumulator ymm1 a mask that is
// all-ones in any lane where |coefficient| > (bound - 1), i.e. >= bound.

// Transliterated from s2n-bignum's x86/mldsa/mldsa_chknorm.S.
/// Infinity-norm bound check on polynomial coefficients for ML-DSA
///
/// Input a[256] (signed 32-bit words), scalar bound
///
/// Checks the infinity norm of the polynomial against the given bound.
/// Returns 0 if every |coefficient| is strictly smaller than the bound;
/// otherwise returns 1 (i.e. returns 1 if any |coefficient| >= bound).
/// The bound is assumed to be non-negative.
#[inline(never)]
pub(crate) fn mldsa_chknorm(a: &[i32; 256], bound: u64) -> u64 {
    let ret: u64;
    assert!((a.as_ptr() as usize).is_multiple_of(32));
    // SAFETY: inline assembly. see [crate::low::inline_assembly_safety] for safety info.
    unsafe {
        core::arch::asm!(

        Q!("    endbr64         " ),

        // Set up constants: ymm1 = zero accumulator, ymm2 = (bound - 1) broadcast
        Q!("    sub             " "esi, 1"),
        Q!("    vpxor           " "xmm1, xmm1, xmm1"),
        Q!("    vmovd           " "xmm2, esi"),
        Q!("    vpbroadcastd    " "ymm2, xmm2"),

        // Process all 256 coefficients (32 vectors of 8 int32 each)
        Q!("    vpabsd          " "ymm0, [rdi + 0]"),
        Q!("    vpcmpgtd        " "ymm0, ymm0, ymm2"),
        Q!("    vpor            " "ymm1, ymm1, ymm0"),
        Q!("    vpabsd          " "ymm3, [rdi + 32]"),
        Q!("    vpcmpgtd        " "ymm3, ymm3, ymm2"),
        Q!("    vpor            " "ymm1, ymm1, ymm3"),
        Q!("    vpabsd          " "ymm4, [rdi + 64]"),
        Q!("    vpcmpgtd        " "ymm4, ymm4, ymm2"),
        Q!("    vpor            " "ymm1, ymm1, ymm4"),
        Q!("    vpabsd          " "ymm5, [rdi + 96]"),
        Q!("    vpcmpgtd        " "ymm5, ymm5, ymm2"),
        Q!("    vpor            " "ymm1, ymm1, ymm5"),
        Q!("    vpabsd          " "ymm0, [rdi + 128]"),
        Q!("    vpcmpgtd        " "ymm0, ymm0, ymm2"),
        Q!("    vpor            " "ymm1, ymm1, ymm0"),
        Q!("    vpabsd          " "ymm3, [rdi + 160]"),
        Q!("    vpcmpgtd        " "ymm3, ymm3, ymm2"),
        Q!("    vpor            " "ymm1, ymm1, ymm3"),
        Q!("    vpabsd          " "ymm4, [rdi + 192]"),
        Q!("    vpcmpgtd        " "ymm4, ymm4, ymm2"),
        Q!("    vpor            " "ymm1, ymm1, ymm4"),
        Q!("    vpabsd          " "ymm5, [rdi + 224]"),
        Q!("    vpcmpgtd        " "ymm5, ymm5, ymm2"),
        Q!("    vpor            " "ymm1, ymm1, ymm5"),
        Q!("    vpabsd          " "ymm0, [rdi + 256]"),
        Q!("    vpcmpgtd        " "ymm0, ymm0, ymm2"),
        Q!("    vpor            " "ymm1, ymm1, ymm0"),
        Q!("    vpabsd          " "ymm3, [rdi + 288]"),
        Q!("    vpcmpgtd        " "ymm3, ymm3, ymm2"),
        Q!("    vpor            " "ymm1, ymm1, ymm3"),
        Q!("    vpabsd          " "ymm4, [rdi + 320]"),
        Q!("    vpcmpgtd        " "ymm4, ymm4, ymm2"),
        Q!("    vpor            " "ymm1, ymm1, ymm4"),
        Q!("    vpabsd          " "ymm5, [rdi + 352]"),
        Q!("    vpcmpgtd        " "ymm5, ymm5, ymm2"),
        Q!("    vpor            " "ymm1, ymm1, ymm5"),
        Q!("    vpabsd          " "ymm0, [rdi + 384]"),
        Q!("    vpcmpgtd        " "ymm0, ymm0, ymm2"),
        Q!("    vpor            " "ymm1, ymm1, ymm0"),
        Q!("    vpabsd          " "ymm3, [rdi + 416]"),
        Q!("    vpcmpgtd        " "ymm3, ymm3, ymm2"),
        Q!("    vpor            " "ymm1, ymm1, ymm3"),
        Q!("    vpabsd          " "ymm4, [rdi + 448]"),
        Q!("    vpcmpgtd        " "ymm4, ymm4, ymm2"),
        Q!("    vpor            " "ymm1, ymm1, ymm4"),
        Q!("    vpabsd          " "ymm5, [rdi + 480]"),
        Q!("    vpcmpgtd        " "ymm5, ymm5, ymm2"),
        Q!("    vpor            " "ymm1, ymm1, ymm5"),
        Q!("    vpabsd          " "ymm0, [rdi + 512]"),
        Q!("    vpcmpgtd        " "ymm0, ymm0, ymm2"),
        Q!("    vpor            " "ymm1, ymm1, ymm0"),
        Q!("    vpabsd          " "ymm3, [rdi + 544]"),
        Q!("    vpcmpgtd        " "ymm3, ymm3, ymm2"),
        Q!("    vpor            " "ymm1, ymm1, ymm3"),
        Q!("    vpabsd          " "ymm4, [rdi + 576]"),
        Q!("    vpcmpgtd        " "ymm4, ymm4, ymm2"),
        Q!("    vpor            " "ymm1, ymm1, ymm4"),
        Q!("    vpabsd          " "ymm5, [rdi + 608]"),
        Q!("    vpcmpgtd        " "ymm5, ymm5, ymm2"),
        Q!("    vpor            " "ymm1, ymm1, ymm5"),
        Q!("    vpabsd          " "ymm0, [rdi + 640]"),
        Q!("    vpcmpgtd        " "ymm0, ymm0, ymm2"),
        Q!("    vpor            " "ymm1, ymm1, ymm0"),
        Q!("    vpabsd          " "ymm3, [rdi + 672]"),
        Q!("    vpcmpgtd        " "ymm3, ymm3, ymm2"),
        Q!("    vpor            " "ymm1, ymm1, ymm3"),
        Q!("    vpabsd          " "ymm4, [rdi + 704]"),
        Q!("    vpcmpgtd        " "ymm4, ymm4, ymm2"),
        Q!("    vpor            " "ymm1, ymm1, ymm4"),
        Q!("    vpabsd          " "ymm5, [rdi + 736]"),
        Q!("    vpcmpgtd        " "ymm5, ymm5, ymm2"),
        Q!("    vpor            " "ymm1, ymm1, ymm5"),
        Q!("    vpabsd          " "ymm0, [rdi + 768]"),
        Q!("    vpcmpgtd        " "ymm0, ymm0, ymm2"),
        Q!("    vpor            " "ymm1, ymm1, ymm0"),
        Q!("    vpabsd          " "ymm3, [rdi + 800]"),
        Q!("    vpcmpgtd        " "ymm3, ymm3, ymm2"),
        Q!("    vpor            " "ymm1, ymm1, ymm3"),
        Q!("    vpabsd          " "ymm4, [rdi + 832]"),
        Q!("    vpcmpgtd        " "ymm4, ymm4, ymm2"),
        Q!("    vpor            " "ymm1, ymm1, ymm4"),
        Q!("    vpabsd          " "ymm5, [rdi + 864]"),
        Q!("    vpcmpgtd        " "ymm5, ymm5, ymm2"),
        Q!("    vpor            " "ymm1, ymm1, ymm5"),
        Q!("    vpabsd          " "ymm0, [rdi + 896]"),
        Q!("    vpcmpgtd        " "ymm0, ymm0, ymm2"),
        Q!("    vpor            " "ymm1, ymm1, ymm0"),
        Q!("    vpabsd          " "ymm3, [rdi + 928]"),
        Q!("    vpcmpgtd        " "ymm3, ymm3, ymm2"),
        Q!("    vpor            " "ymm1, ymm1, ymm3"),
        Q!("    vpabsd          " "ymm4, [rdi + 960]"),
        Q!("    vpcmpgtd        " "ymm4, ymm4, ymm2"),
        Q!("    vpor            " "ymm1, ymm1, ymm4"),
        Q!("    vpabsd          " "ymm5, [rdi + 992]"),
        Q!("    vpcmpgtd        " "ymm5, ymm5, ymm2"),
        Q!("    vpor            " "ymm1, ymm1, ymm5"),

        // Return 1 iff the accumulator has any nonzero lane, else 0
        Q!("    xor             " "eax, eax"),
        Q!("    vptest          " "ymm1, ymm1"),
        Q!("    setne           " "al"),

        Q!("    vzeroupper      " ),
        inout("rdi") a.as_ptr() => _,
        inout("rsi") bound => _,
        out("rax") ret,
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
    ret
}

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
#[test]
fn abi() {
    if !std::arch::is_x86_feature_detected!("avx2") {
        return;
    }
    crate::low::abi::call!(mldsa_chknorm, &crate::low::abi::Aligned([0; 256]).0, 0);
}
