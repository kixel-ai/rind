// generated source. do not edit.
#![allow(non_upper_case_globals, unused_macros, unused_imports)]
use crate::low::macros::*;

// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT

// ----------------------------------------------------------------------------
// Uniform rejection sampling for ML-DSA
// Input buf[840] (uint8_t); output r[256] (int32_t); table[2048] (uint64_t)
// Returns: number of valid coefficients in r (at most 256)
//
// This function implements the rejection-sampling loop for ML-DSA, extracting
// 23-bit coefficients from packed 24-bit input bytes and keeping only those
// strictly less than q = 8380417. A main AVX2 loop processes 24 bytes (8
// coefficients) per iteration using VPERMQ+VPSHUFB extraction, VPAND masking,
// VPSUBD+VMOVMSKPS rejection, and VPERMD+table compaction. A scalar tail
// handles any remaining bytes after the main loop exits.
//
// This implementation is derived from the public domain AVX2 Dilithium
// implementation from CRYSTALS-Dilithium optimized AVX2 implementation by
// Bai, Ducas, Kiltz, Lepoint, Lyubashevsky, Schwabe, Seiler, Stehlé
// (https://github.com/pq-crystals/dilithium/tree/master/avx2)
//
// extern uint32_t mldsa_rej_uniform_VARIABLE_TIME_x86
//   (int32_t r[static 256],
//    const uint8_t buf[static 840],
//    const uint64_t table[static 256]);
//
// Standard x86-64 ABI: RDI = r, RSI = buf, RDX = table
// Microsoft x64 ABI:   RCX = r, RDX = buf, R8 = table
// ----------------------------------------------------------------------------

// Transliterated from s2n-bignum's x86/mldsa/mldsa_rej_uniform_VARIABLE_TIME.S.
/// Uniform rejection sampling for ML-DSA
///
/// Input buf[840] (uint8_t); output r[256] (int32_t); table[2048] (uint64_t)
/// Returns: number of valid coefficients in r (at most 256)
///
/// This function implements the rejection-sampling loop for ML-DSA, extracting
/// 23-bit coefficients from packed 24-bit input bytes and keeping only those
/// strictly less than q = 8380417. A main AVX2 loop processes 24 bytes (8
/// coefficients) per iteration using VPERMQ+VPSHUFB extraction, VPAND masking,
/// VPSUBD+VMOVMSKPS rejection, and VPERMD+table compaction. A scalar tail
/// handles any remaining bytes after the main loop exits.
///
/// This implementation is derived from the public domain AVX2 Dilithium
/// implementation from CRYSTALS-Dilithium optimized AVX2 implementation by
/// Bai, Ducas, Kiltz, Lepoint, Lyubashevsky, Schwabe, Seiler, Stehlé
/// (https://github.com/pq-crystals/dilithium/tree/master/avx2)
#[inline(never)]
pub(crate) fn mldsa_rej_uniform_vartime(
    r: &mut [i32; 256],
    buf: &[u8; 840],
    table: &[u8; 2048],
) -> u64 {
    let ret: u64;
    assert!((r.as_mut_ptr() as usize).is_multiple_of(32));
    // SAFETY: inline assembly. see [crate::low::inline_assembly_safety] for safety info.
    unsafe {
        core::arch::asm!(

        Q!("    endbr64         " ),

        // Shuffle mask: expand 24 bytes (8 x 3-byte coefficients) into
        // 8 x 4-byte lanes (with a zero high byte in each).
        Q!("    mov             " "r10, 0xff050403ff020100"),
        Q!("    vmovq           " "xmm0, r10"),
        Q!("    mov             " "r10, 0xff0b0a09ff080706"),
        Q!("    vpinsrq         " "xmm0, xmm0, r10, 0x1"),
        Q!("    mov             " "r10, 0xff090807ff060504"),
        Q!("    vmovq           " "xmm3, r10"),
        Q!("    mov             " "r10, 0xff0f0e0dff0c0b0a"),
        Q!("    vpinsrq         " "xmm3, xmm3, r10, 0x1"),
        Q!("    vinserti128     " "ymm0, ymm0, xmm3, 0x1"),

        // Mask 0x7fffff in all 8 lanes (keep low 23 bits)
        Q!("    mov             " "r8d, 0x7fffff"),
        Q!("    vmovd           " "xmm1, r8d"),
        Q!("    vpbroadcastd    " "ymm1, xmm1"),

        // Threshold q = 0x7fe001 in all 8 lanes
        Q!("    mov             " "r8d, 0x7fe001"),
        Q!("    vmovd           " "xmm2, r8d"),
        Q!("    vpbroadcastd    " "ymm2, xmm2"),

        // rax = accepted count, rcx = byte offset into buf
        Q!("    xor             " "eax, eax"),
        Q!("    xor             " "ecx, ecx"),

        Q!(Label!("Lmldsa_rej_uniform_VARIABLE_TIME_x86_loop", 2) ":"),
        // Exit to scalar tail if we have 248 or more accepted (next 8 might
        // overflow) or if byte offset is past 808 (would read past buf+840-24).
        Q!("    cmp             " "eax, 0xf8"),
        Q!("    ja              " Label!("Lmldsa_rej_uniform_VARIABLE_TIME_x86_scalar", 3, After)),
        Q!("    cmp             " "ecx, 0x328"),
        Q!("    ja              " Label!("Lmldsa_rej_uniform_VARIABLE_TIME_x86_scalar", 3, After)),

        Q!("    vmovdqu         " "ymm3, YMMWORD PTR [rsi + rcx]"),
        Q!("    add             " "ecx, 0x18"),
        Q!("    vpermq          " "ymm3, ymm3, 0x94"),
        Q!("    vpshufb         " "ymm3, ymm3, ymm0"),
        Q!("    vpand           " "ymm3, ymm3, ymm1"),
        Q!("    vpsubd          " "ymm4, ymm3, ymm2"),
        Q!("    vmovmskps       " "r8d, ymm4"),
        Q!("    popcnt          " "r9d, r8d"),
        Q!("    vmovq           " "xmm4, QWORD PTR [rdx + 8 * r8]"),
        Q!("    vpmovzxbd       " "ymm4, xmm4"),
        Q!("    vpermd          " "ymm3, ymm4, ymm3"),
        Q!("    vmovdqu         " "YMMWORD PTR [rdi + 4 * rax], ymm3"),
        Q!("    add             " "eax, r9d"),
        Q!("    jmp             " Label!("Lmldsa_rej_uniform_VARIABLE_TIME_x86_loop", 2, Before)),

        Q!(Label!("Lmldsa_rej_uniform_VARIABLE_TIME_x86_scalar", 3) ":"),
        Q!("    cmp             " "eax, 0x100"),
        Q!("    jae             " Label!("Lmldsa_rej_uniform_VARIABLE_TIME_x86_done", 4, After)),
        Q!("    cmp             " "ecx, 0x345"),
        Q!("    ja              " Label!("Lmldsa_rej_uniform_VARIABLE_TIME_x86_done", 4, After)),
        Q!("    movzx           " "r8d, WORD PTR [rsi + rcx]"),
        Q!("    movzx           " "r9d, BYTE PTR [rsi + rcx + 2]"),
        Q!("    shl             " "r9d, 0x10"),
        Q!("    or              " "r8d, r9d"),
        Q!("    and             " "r8d, 0x7fffff"),
        Q!("    add             " "ecx, 0x3"),
        Q!("    cmp             " "r8d, 0x7fe001"),
        Q!("    jae             " Label!("Lmldsa_rej_uniform_VARIABLE_TIME_x86_scalar", 3, Before)),
        Q!("    mov             " "DWORD PTR [rdi + 4 * rax], r8d"),
        Q!("    add             " "eax, 0x1"),
        Q!("    jmp             " Label!("Lmldsa_rej_uniform_VARIABLE_TIME_x86_scalar", 3, Before)),

        Q!(Label!("Lmldsa_rej_uniform_VARIABLE_TIME_x86_done", 4) ":"),
        Q!("    vzeroupper      " ),
        inout("rdi") r.as_mut_ptr() => _,
        inout("rsi") buf.as_ptr() => _,
        inout("rdx") table.as_ptr() => _,
        out("rax") ret,
        // clobbers
        out("r10") _,
        out("r8") _,
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
    ret
}

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
#[test]
fn abi() {
    if !(std::arch::is_x86_feature_detected!("avx2")
        && std::arch::is_x86_feature_detected!("popcnt"))
    {
        return;
    }
    crate::low::abi::call!(
        mldsa_rej_uniform_vartime,
        &mut crate::low::abi::Aligned([0; 256]).0,
        &[0x55; 840],
        &super::mldsa::MLDSA_REJ_UNIFORM_TABLE
    );
}
