// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! ML-KEM's ciphertext compression with mlkem-native's AVX2 routines, which
//! `admin/import-aws-lc` takes from aws-lc's copy. mlkem-native's HOL Light
//! proofs cover them, as it builds them.

/// `ByteEncode_10(Compress_10(a))`, for `a` in `[0, Q)`.
pub(crate) fn mlkem_compress_d10(r: &mut [u8; 320], a: &[i16; 256]) {
    assert!((a.as_ptr() as usize).is_multiple_of(32));
    // SAFETY: `r` and `a` are the sizes the routine writes and reads, `a` and
    // the table are 32-byte aligned for its aligned loads, and `super::mlkem`
    // calls this only with AVX2.
    unsafe {
        asm_call!(unsafe extern "sysv64" mlkem_poly_compress_d10_avx2_asm(r, a, &COMPRESS_D10_DATA))
    }
}

/// `ByteEncode_4(Compress_4(a))`, for `a` in `[0, Q)`.
pub(crate) fn mlkem_compress_d4(r: &mut [u8; 128], a: &[i16; 256]) {
    assert!((a.as_ptr() as usize).is_multiple_of(32));
    // SAFETY: as for `mlkem_compress_d10`.
    unsafe {
        asm_call!(unsafe extern "sysv64" mlkem_poly_compress_d4_avx2_asm(r, a, &COMPRESS_D4_DATA))
    }
}

#[repr(C, align(32))]
struct Table([u8; 32]);

/// mlkem-native's `mlk_compress_d10_data`: the byte shuffle that packs.
static COMPRESS_D10_DATA: Table = Table([
    0, 1, 2, 3, 4, 8, 9, 10, 11, 12, 255, 255, 255, 255, 255, 255, 9, 10, 11, 12, 255, 255, 255,
    255, 255, 255, 0, 1, 2, 3, 4, 8,
]);

/// mlkem-native's `mlk_compress_d4_data`: the dword permutation that packs.
static COMPRESS_D4_DATA: Table = Table([
    0, 0, 0, 0, 4, 0, 0, 0, 1, 0, 0, 0, 5, 0, 0, 0, 2, 0, 0, 0, 6, 0, 0, 0, 3, 0, 0, 0, 7, 0, 0, 0,
]);

// Both routines take the System V ABI on every OS, since their text is
// aws-lc's ELF and Mach-O flavors, which read their arguments from its
// registers.

#[unsafe(naked)]
unsafe extern "sysv64" fn mlkem_poly_compress_d10_avx2_asm(
    r: *mut [u8; 320],
    a: *const [i16; 256],
    data: *const Table,
) {
    #[cfg(not(target_vendor = "apple"))]
    core::arch::naked_asm!(
        include_str!("aws_lc/mlkem_poly_compress_d10_avx2_asm.linux.s"),
        options(att_syntax),
    );
    #[cfg(target_vendor = "apple")]
    core::arch::naked_asm!(
        include_str!("aws_lc/mlkem_poly_compress_d10_avx2_asm.apple.s"),
        options(att_syntax),
    );
}

#[unsafe(naked)]
unsafe extern "sysv64" fn mlkem_poly_compress_d4_avx2_asm(
    r: *mut [u8; 128],
    a: *const [i16; 256],
    data: *const Table,
) {
    #[cfg(not(target_vendor = "apple"))]
    core::arch::naked_asm!(
        include_str!("aws_lc/mlkem_poly_compress_d4_avx2_asm.linux.s"),
        options(att_syntax),
    );
    #[cfg(target_vendor = "apple")]
    core::arch::naked_asm!(
        include_str!("aws_lc/mlkem_poly_compress_d4_avx2_asm.apple.s"),
        options(att_syntax),
    );
}
