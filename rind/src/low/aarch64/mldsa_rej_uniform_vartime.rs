// generated source. do not edit.
#![allow(non_upper_case_globals, unused_macros, unused_imports)]
use crate::low::macros::*;

// Copyright (c) The mldsa-native project authors
// Copyright (c) The mlkem-native project authors
// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT

// ----------------------------------------------------------------------------
// Uniform rejection sampling for ML-DSA
// Inputs *buf (unsigned bytes), buflen, table (unsigned bytes); output r[256] (signed 32-bit words), return
//
// extern uint64_t mldsa_rej_uniform_VARIABLE_TIME
//                     (int32_t r[S2N_BIGNUM_STATIC 256],
//                      const uint8_t *buf,uint64_t buflen,
//                      const uint8_t *table);
//
// Interprets the input buffer as packed 24-bit numbers with a length of
// buflen bytes, assumed to be a multiple of 24. Masks each to 23 bits and
// fills the output array with those numbers that are < q = 8380417, in the
// order of appearance, returning the total number of entries written, with a
// maximum of 256. The table argument is a specific precomputed table of
// constants that is defined alongside the proof (see also our test code).
//
// Like its ML-KEM counterpart, this is *not* a constant-time function. The
// time taken depends not only on the buffer size "buflen", but also how many
// elements of the buffer are needed to provide the 256 entries for the output.
//
// Standard ARM ABI: X0 = r, X1 = buf, X2 = buflen, X3 = table
// ----------------------------------------------------------------------------

// Transliterated from s2n-bignum's arm/mldsa/mldsa_rej_uniform_VARIABLE_TIME.S.
/// Uniform rejection sampling for ML-DSA
///
/// Inputs *buf (unsigned bytes), buflen, table (unsigned bytes); output r[256] (signed 32-bit words), return
///
/// Interprets the input buffer as packed 24-bit numbers with a length of
/// buflen bytes, assumed to be a multiple of 24. Masks each to 23 bits and
/// fills the output array with those numbers that are < q = 8380417, in the
/// order of appearance, returning the total number of entries written, with a
/// maximum of 256. The table argument is a specific precomputed table of
/// constants that is defined alongside the proof (see also our test code).
///
/// Like its ML-KEM counterpart, this is *not* a constant-time function. The
/// time taken depends not only on the buffer size "buflen", but also how many
/// elements of the buffer are needed to provide the 256 entries for the output.
#[inline(never)]
pub(crate) fn mldsa_rej_uniform_vartime(r: &mut [i32; 256], buf: &[u8], table: &[u8; 256]) -> u64 {
    let ret: u64;
    assert!(buf.len().is_multiple_of(24));
    // SAFETY: inline assembly. see [crate::low::inline_assembly_safety] for safety info.
    unsafe {
        core::arch::asm!(

        Q!("    sub             " "sp, sp, # (0x440 + 0)"),
        Q!("    mov             " "x7, #0x1"),
        Q!("    movk            " "x7, #0x2, lsl #32"),
        Q!("    mov             " "v31.d[0], x7"),
        Q!("    mov             " "x7, #0x4"),
        Q!("    movk            " "x7, #0x8, lsl #32"),
        Q!("    mov             " "v31.d[1], x7"),
        Q!("    mov             " "w7, #0xe001"),
        Q!("    movk            " "w7, #0x7f, lsl #16"),
        Q!("    dup             " "v30.4s, w7"),
        Q!("    mov             " "x8, sp"),
        Q!("    mov             " "x7, x8"),
        Q!("    mov             " "x11, #0x0"),
        Q!("    eor             " "v16.16b, v16.16b, v16.16b"),

        Q!(Label!("Lrej_uniform_initial_zero", 2) ":"),
        Q!("    str             " "q16, [x7], #0x40"),
        Q!("    stur            " "q16, [x7, #-0x30]"),
        Q!("    stur            " "q16, [x7, #-0x20]"),
        Q!("    stur            " "q16, [x7, #-0x10]"),
        Q!("    add             " "x11, x11, #0x10"),
        Q!("    cmp             " "x11, #0x100"),
        Q!("    b.lt            " Label!("Lrej_uniform_initial_zero", 2, Before)),
        Q!("    mov             " "x7, x8"),
        Q!("    mov             " "x9, #0x0"),
        Q!("    mov             " "x4, #0x100"),
        Q!("    cmp             " "x2, #0x30"),
        Q!("    b.lo            " Label!("Lrej_uniform_loop48_end", 3, After)),

        Q!(Label!("Lrej_uniform_loop48", 4) ":"),
        Q!("    cmp             " "x9, x4"),
        Q!("    b.hs            " Label!("Lrej_uniform_memory_copy", 5, After)),
        Q!("    sub             " "x2, x2, #0x30"),
        Q!("    ld3             " "{{ v0.16b, v1.16b, v2.16b }}, [x1], #48"),
        Q!("    movi            " "v4.16b, #0x80"),
        Q!("    bic             " "v2.16b, v2.16b, v4.16b"),
        Q!("    zip1            " "v4.16b, v0.16b, v1.16b"),
        Q!("    zip2            " "v5.16b, v0.16b, v1.16b"),
        Q!("    ushll           " "v6.8h, v2.8b, #0x0"),
        Q!("    ushll2          " "v7.8h, v2.16b, #0x0"),
        Q!("    zip1            " "v16.8h, v4.8h, v6.8h"),
        Q!("    zip2            " "v17.8h, v4.8h, v6.8h"),
        Q!("    zip1            " "v18.8h, v5.8h, v7.8h"),
        Q!("    zip2            " "v19.8h, v5.8h, v7.8h"),
        Q!("    cmhi            " "v4.4s, v30.4s, v16.4s"),
        Q!("    cmhi            " "v5.4s, v30.4s, v17.4s"),
        Q!("    cmhi            " "v6.4s, v30.4s, v18.4s"),
        Q!("    cmhi            " "v7.4s, v30.4s, v19.4s"),
        Q!("    and             " "v4.16b, v4.16b, v31.16b"),
        Q!("    and             " "v5.16b, v5.16b, v31.16b"),
        Q!("    and             " "v6.16b, v6.16b, v31.16b"),
        Q!("    and             " "v7.16b, v7.16b, v31.16b"),
        Q!("    uaddlv          " "d20, v4.4s"),
        Q!("    uaddlv          " "d21, v5.4s"),
        Q!("    uaddlv          " "d22, v6.4s"),
        Q!("    uaddlv          " "d23, v7.4s"),
        Q!("    fmov            " "x12, d20"),
        Q!("    fmov            " "x13, d21"),
        Q!("    fmov            " "x14, d22"),
        Q!("    fmov            " "x15, d23"),
        Q!("    ldr             " "q24, [x3, x12, lsl #4]"),
        Q!("    ldr             " "q25, [x3, x13, lsl #4]"),
        Q!("    ldr             " "q26, [x3, x14, lsl #4]"),
        Q!("    ldr             " "q27, [x3, x15, lsl #4]"),
        Q!("    cnt             " "v4.16b, v4.16b"),
        Q!("    cnt             " "v5.16b, v5.16b"),
        Q!("    cnt             " "v6.16b, v6.16b"),
        Q!("    cnt             " "v7.16b, v7.16b"),
        Q!("    uaddlv          " "d20, v4.4s"),
        Q!("    uaddlv          " "d21, v5.4s"),
        Q!("    uaddlv          " "d22, v6.4s"),
        Q!("    uaddlv          " "d23, v7.4s"),
        Q!("    fmov            " "x12, d20"),
        Q!("    fmov            " "x13, d21"),
        Q!("    fmov            " "x14, d22"),
        Q!("    fmov            " "x15, d23"),
        Q!("    tbl             " "v16.16b, {{ v16.16b }}, v24.16b"),
        Q!("    tbl             " "v17.16b, {{ v17.16b }}, v25.16b"),
        Q!("    tbl             " "v18.16b, {{ v18.16b }}, v26.16b"),
        Q!("    tbl             " "v19.16b, {{ v19.16b }}, v27.16b"),
        Q!("    st1             " "{{ v16.4s }}, [x7]"),
        Q!("    add             " "x7, x7, x12, lsl #2"),
        Q!("    st1             " "{{ v17.4s }}, [x7]"),
        Q!("    add             " "x7, x7, x13, lsl #2"),
        Q!("    st1             " "{{ v18.4s }}, [x7]"),
        Q!("    add             " "x7, x7, x14, lsl #2"),
        Q!("    st1             " "{{ v19.4s }}, [x7]"),
        Q!("    add             " "x7, x7, x15, lsl #2"),
        Q!("    add             " "x12, x12, x13"),
        Q!("    add             " "x14, x14, x15"),
        Q!("    add             " "x9, x9, x12"),
        Q!("    add             " "x9, x9, x14"),
        Q!("    cmp             " "x2, #0x30"),
        Q!("    b.hs            " Label!("Lrej_uniform_loop48", 4, Before)),

        Q!(Label!("Lrej_uniform_loop48_end", 3) ":"),
        Q!("    cmp             " "x9, x4"),
        Q!("    b.hs            " Label!("Lrej_uniform_memory_copy", 5, After)),
        Q!("    cmp             " "x2, #0x18"),
        Q!("    b.lo            " Label!("Lrej_uniform_memory_copy", 5, After)),
        Q!("    sub             " "x2, x2, #0x18"),
        Q!("    ld3             " "{{ v0.8b, v1.8b, v2.8b }}, [x1], #24"),
        Q!("    movi            " "v4.16b, #0x80"),
        Q!("    bic             " "v2.16b, v2.16b, v4.16b"),
        Q!("    zip1            " "v4.16b, v0.16b, v1.16b"),
        Q!("    ushll           " "v6.8h, v2.8b, #0x0"),
        Q!("    zip1            " "v16.8h, v4.8h, v6.8h"),
        Q!("    zip2            " "v17.8h, v4.8h, v6.8h"),
        Q!("    cmhi            " "v4.4s, v30.4s, v16.4s"),
        Q!("    cmhi            " "v5.4s, v30.4s, v17.4s"),
        Q!("    and             " "v4.16b, v4.16b, v31.16b"),
        Q!("    and             " "v5.16b, v5.16b, v31.16b"),
        Q!("    uaddlv          " "d20, v4.4s"),
        Q!("    uaddlv          " "d21, v5.4s"),
        Q!("    fmov            " "x12, d20"),
        Q!("    fmov            " "x13, d21"),
        Q!("    ldr             " "q24, [x3, x12, lsl #4]"),
        Q!("    ldr             " "q25, [x3, x13, lsl #4]"),
        Q!("    cnt             " "v4.16b, v4.16b"),
        Q!("    cnt             " "v5.16b, v5.16b"),
        Q!("    uaddlv          " "d20, v4.4s"),
        Q!("    uaddlv          " "d21, v5.4s"),
        Q!("    fmov            " "x12, d20"),
        Q!("    fmov            " "x13, d21"),
        Q!("    tbl             " "v16.16b, {{ v16.16b }}, v24.16b"),
        Q!("    tbl             " "v17.16b, {{ v17.16b }}, v25.16b"),
        Q!("    str             " "q16, [x7]"),
        Q!("    add             " "x7, x7, x12, lsl #2"),
        Q!("    str             " "q17, [x7]"),
        Q!("    add             " "x7, x7, x13, lsl #2"),
        Q!("    add             " "x9, x9, x12"),
        Q!("    add             " "x9, x9, x13"),

        Q!(Label!("Lrej_uniform_memory_copy", 5) ":"),
        Q!("    cmp             " "x9, x4"),
        Q!("    csel            " "x9, x9, x4, lo"),
        Q!("    mov             " "x11, #0x0"),
        Q!("    mov             " "x7, x8"),

        Q!(Label!("Lrej_uniform_final_copy", 6) ":"),
        Q!("    ldr             " "q16, [x7], #0x40"),
        Q!("    ldur            " "q17, [x7, #-0x30]"),
        Q!("    ldur            " "q18, [x7, #-0x20]"),
        Q!("    ldur            " "q19, [x7, #-0x10]"),
        Q!("    str             " "q16, [x0], #0x40"),
        Q!("    stur            " "q17, [x0, #-0x30]"),
        Q!("    stur            " "q18, [x0, #-0x20]"),
        Q!("    stur            " "q19, [x0, #-0x10]"),
        Q!("    add             " "x11, x11, #0x10"),
        Q!("    cmp             " "x11, #0x100"),
        Q!("    b.lt            " Label!("Lrej_uniform_final_copy", 6, Before)),
        Q!("    mov             " "x0, x9"),
        Q!("    b               " Label!("Lrej_uniform_return", 7, After)),

        Q!(Label!("Lrej_uniform_return", 7) ":"),
        Q!("    add             " "sp, sp, # (0x440 + 0)"),
        inout("x0") r.as_mut_ptr() => ret,
        inout("x1") buf.as_ptr() => _,
        inout("x2") buf.len() => _,
        inout("x3") table.as_ptr() => _,
        // clobbers
        out("v0") _,
        out("v1") _,
        out("v16") _,
        out("v17") _,
        out("v18") _,
        out("v19") _,
        out("v2") _,
        out("v20") _,
        out("v21") _,
        out("v22") _,
        out("v23") _,
        out("v24") _,
        out("v25") _,
        out("v26") _,
        out("v27") _,
        out("v30") _,
        out("v31") _,
        out("v4") _,
        out("v5") _,
        out("v6") _,
        out("v7") _,
        out("x11") _,
        out("x12") _,
        out("x13") _,
        out("x14") _,
        out("x15") _,
        out("x4") _,
        out("x7") _,
        out("x8") _,
        out("x9") _,
            )
    };
    ret
}

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
#[test]
fn abi() {
    crate::low::abi::call!(
        mldsa_rej_uniform_vartime,
        &mut crate::low::abi::Aligned([0; 256]).0,
        &[0x55; 840],
        &super::mldsa::MLDSA_REJ_UNIFORM_TABLE
    );
}
