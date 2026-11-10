// Written for Graviola by Joe Birr-Pixton, 2024.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

use core::arch::x86_64::*;

/// Compresses `blocks`.
pub(in crate::low) fn sha256_compress_blocks_shaext(
    state: &mut [u32; 8],
    blocks: &[u8],
    _token: super::cpu::HaveSha256,
) {
    debug_assert!(blocks.len().is_multiple_of(64));
    // SAFETY: `_token` proves the caller checked the `sha`, `ssse3`, and
    // `sse4.1` features
    unsafe { sha256(state, blocks) }
}

/// The digest of `state` followed by `message`, padded and closed by
/// `length`.
///
/// The last block is padded in registers, and the digest is written from
/// them, so no load waits on a store that cannot forward.
pub(in crate::low) fn sha256_finish_shaext(
    state: &[u32; 8],
    message: &[u8],
    length: [u8; 8],
    _token: super::cpu::HaveSha256,
) -> [u8; 32] {
    // SAFETY: `_token` proves the caller checked the `sha`, `ssse3`, and
    // `sse4.1` features
    unsafe { sha256_finish(state, message, length) }
}

macro_rules! k {
    ($k:literal) => {
        // SAFETY: `$k` is a compile-time constant and results in a valid index
        // into the const table `K`.  `K` has proper alignment for this aligned
        // load.
        unsafe { _mm_load_si128(K.0.as_ptr().add($k * 4).cast()) }
    };
}

macro_rules! round {
    ($msg_cur:ident, $state0:ident, $state1:ident, $k:expr) => {
        let msg = _mm_add_epi32($msg_cur, $k);
        $state1 = _mm_sha256rnds2_epu32($state1, $state0, msg);
        let msg = _mm_shuffle_epi32(msg, 0b00_00_11_10);
        $state0 = _mm_sha256rnds2_epu32($state0, $state1, msg);
    };

    ($msg_cur:ident, $msg_prev:ident, $state0:ident, $state1:ident, $k:expr) => {
        round!($msg_cur, $state0, $state1, $k);
        let $msg_prev = _mm_sha256msg1_epu32($msg_prev, $msg_cur);
    };

    ($msg_cur:ident, $msg_prev:ident, $msg_next:ident, $state0:ident, $state1:ident, $k:expr) => {
        let msg = _mm_add_epi32($msg_cur, $k);
        $state1 = _mm_sha256rnds2_epu32($state1, $state0, msg);
        let tmp = _mm_alignr_epi8($msg_cur, $msg_prev, 4);
        let $msg_next = _mm_add_epi32($msg_next, tmp);
        let $msg_next = _mm_sha256msg2_epu32($msg_next, $msg_cur);
        let msg = _mm_shuffle_epi32(msg, 0b00_00_11_10);
        $state0 = _mm_sha256rnds2_epu32($state0, $state1, msg);
        let $msg_prev = _mm_sha256msg1_epu32($msg_prev, $msg_cur);
    };
}

/// Each big-endian word of a block, or of the digest, as a little-endian one.
#[target_feature(enable = "sha,sse4.1,ssse3")]
fn byte_swap() -> __m128i {
    _mm_set_epi64x(0x0c0d0e0f08090a0b, 0x0405060700010203)
}

#[target_feature(enable = "sha,sse4.1,ssse3")]
fn round_constants() -> [__m128i; 16] {
    [
        k!(0),
        k!(1),
        k!(2),
        k!(3),
        k!(4),
        k!(5),
        k!(6),
        k!(7),
        k!(8),
        k!(9),
        k!(10),
        k!(11),
        k!(12),
        k!(13),
        k!(14),
        k!(15),
    ]
}

/// `state` as the SHA extensions hold it: ABEF and CDGH.
#[target_feature(enable = "sha,sse4.1,ssse3")]
fn load_state(state: &[u32; 8]) -> (__m128i, __m128i) {
    // SAFETY: `state` is 8 32-bit words and readable
    let (state0, state1) = unsafe {
        (
            _mm_loadu_si128(state[0..4].as_ptr().cast()),
            _mm_loadu_si128(state[4..8].as_ptr().cast()),
        )
    };

    let tmp = _mm_shuffle_epi32(state0, 0b10_11_00_01);
    let state1 = _mm_shuffle_epi32(state1, 0b00_01_10_11);
    (
        _mm_alignr_epi8(tmp, state1, 8),
        _mm_blend_epi16(state1, tmp, 0xf0),
    )
}

/// ABEF and CDGH as ABCD and EFGH.
#[target_feature(enable = "sha,sse4.1,ssse3")]
fn unload_state(state0: __m128i, state1: __m128i) -> (__m128i, __m128i) {
    let tmp = _mm_shuffle_epi32(state0, 0b00_01_10_11);
    let state1 = _mm_shuffle_epi32(state1, 0b10_11_00_01);
    (
        _mm_blend_epi16(tmp, state1, 0xf0),
        _mm_alignr_epi8(state1, tmp, 8),
    )
}

#[target_feature(enable = "sha,sse4.1,ssse3")]
fn load_block(block: &[u8; 64]) -> [__m128i; 4] {
    // SAFETY: `block` is 64 bytes and readable
    unsafe {
        [
            _mm_loadu_si128(block[0..].as_ptr().cast()),
            _mm_loadu_si128(block[16..].as_ptr().cast()),
            _mm_loadu_si128(block[32..].as_ptr().cast()),
            _mm_loadu_si128(block[48..].as_ptr().cast()),
        ]
    }
}

/// Compresses the block whose bytes `msg` holds into ABEF and CDGH.
#[target_feature(enable = "sha,sse4.1,ssse3")]
fn compress_block(state: &mut (__m128i, __m128i), msg: [__m128i; 4], k: &[__m128i; 16]) {
    let (mut state0, mut state1) = *state;
    let swap = byte_swap();
    let msg0 = _mm_shuffle_epi8(msg[0], swap);
    let msg1 = _mm_shuffle_epi8(msg[1], swap);
    let msg2 = _mm_shuffle_epi8(msg[2], swap);
    let msg3 = _mm_shuffle_epi8(msg[3], swap);

    round!(msg0, state0, state1, k[0]);
    round!(msg1, msg0, state0, state1, k[1]);
    round!(msg2, msg1, state0, state1, k[2]);
    round!(msg3, msg2, msg0, state0, state1, k[3]);
    round!(msg0, msg3, msg1, state0, state1, k[4]);
    round!(msg1, msg0, msg2, state0, state1, k[5]);
    round!(msg2, msg1, msg3, state0, state1, k[6]);
    round!(msg3, msg2, msg0, state0, state1, k[7]);
    round!(msg0, msg3, msg1, state0, state1, k[8]);
    round!(msg1, msg0, msg2, state0, state1, k[9]);
    round!(msg2, msg1, msg3, state0, state1, k[10]);
    round!(msg3, msg2, msg0, state0, state1, k[11]);
    round!(msg0, msg3, msg1, state0, state1, k[12]);
    round!(msg1, msg0, msg2, state0, state1, k[13]);
    round!(msg2, msg1, msg3, state0, state1, k[14]);
    round!(msg3, state0, state1, k[15]);
    let _ = msg1;
    let _ = msg0;

    *state = (
        _mm_add_epi32(state0, state.0),
        _mm_add_epi32(state1, state.1),
    );
}

#[target_feature(enable = "sha,sse4.1,ssse3")]
fn sha256(state: &mut [u32; 8], blocks: &[u8]) {
    let k = round_constants();
    let mut abef = load_state(state);
    let (blocks, _) = blocks.as_chunks::<64>();
    for block in blocks {
        compress_block(&mut abef, load_block(block), &k);
    }
    let (abcd, efgh) = unload_state(abef.0, abef.1);

    // SAFETY: `state` is 8 32-bit words and writable
    unsafe {
        _mm_storeu_si128(state[0..4].as_mut_ptr().cast(), abcd);
        _mm_storeu_si128(state[4..8].as_mut_ptr().cast(), efgh);
    }
}

#[target_feature(enable = "sha,sse4.1,ssse3")]
fn sha256_finish(state: &[u32; 8], message: &[u8], length: [u8; 8]) -> [u8; 32] {
    let k = round_constants();
    let mut abef = load_state(state);
    let (blocks, tail) = message.as_chunks::<64>();
    for block in blocks {
        compress_block(&mut abef, load_block(block), &k);
    }
    let (last, next) = super::sha_tail::padded_tail(tail, length);
    compress_block(&mut abef, last, &k);
    if let Some(next) = next {
        compress_block(&mut abef, next, &k);
    }

    let (abcd, efgh) = unload_state(abef.0, abef.1);
    let swap = byte_swap();
    let mut digest = [0u8; 32];
    // SAFETY: `digest` is 32 bytes and writable
    unsafe {
        _mm_storeu_si128(
            digest[0..].as_mut_ptr().cast(),
            _mm_shuffle_epi8(abcd, swap),
        );
        _mm_storeu_si128(
            digest[16..].as_mut_ptr().cast(),
            _mm_shuffle_epi8(efgh, swap),
        );
    }
    digest
}

#[repr(align(16))]
struct Aligned([u32; 64]);

static K: Aligned = Aligned([
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
]);

/// SHA-256 without the SHA extensions on CPUs with AVX2, with OpenSSL's
/// `sha256_block_data_order_avx2`, imported by `admin/import-openssl`, which
/// computes the message schedule of two blocks at once.
pub(in crate::low) fn sha256_compress_blocks_avx2(
    state: &mut [u32; 8],
    blocks: &[u8],
    _token: super::cpu::HaveAvx2,
) {
    debug_assert!(blocks.len().is_multiple_of(64));
    // The routine runs its loop at least once, so zero blocks would read past
    // `blocks`.
    if blocks.is_empty() {
        return;
    }
    // SAFETY: `blocks` is `blocks.len() / 64` readable blocks, and `_token`
    // proves AVX2, BMI1, and BMI2.
    unsafe {
        asm_call!(unsafe extern "sysv64" sha256_block_data_order_avx2(state, blocks.as_ptr(), blocks.len() / 64))
    }
}

/// SHA-256 without the SHA extensions or AVX2 on Intel, with aws-lc's
/// `sha256_block_data_order_avx`, imported by `admin/import-aws-lc`. It
/// rotates with `shrd`, which is fast on Intel's cores and slow on pre-Zen
/// AMD's, so aws-lc runs it on Intel only, and so does rind.
pub(in crate::low) fn sha256_compress_blocks_avx(
    state: &mut [u32; 8],
    blocks: &[u8],
    _token: super::cpu::HaveAvx,
) {
    debug_assert!(blocks.len().is_multiple_of(64));
    // As for the AVX2 routine.
    if blocks.is_empty() {
        return;
    }
    // SAFETY: `blocks` is `blocks.len() / 64` readable blocks, and `_token`
    // proves AVX.
    unsafe {
        asm_call!(unsafe extern "sysv64" sha256_block_data_order_avx(state, blocks.as_ptr(), blocks.len() / 64))
    }
}

/// SHA-256 without the SHA extensions or AVX2 on other vendors' CPUs, with
/// aws-lc's `sha256_block_data_order_ssse3`, as aws-lc runs there.
pub(in crate::low) fn sha256_compress_blocks_ssse3(
    state: &mut [u32; 8],
    blocks: &[u8],
    _token: super::cpu::HaveSsse3,
) {
    debug_assert!(blocks.len().is_multiple_of(64));
    // As for the AVX2 routine.
    if blocks.is_empty() {
        return;
    }
    // SAFETY: `blocks` is `blocks.len() / 64` readable blocks, and `_token`
    // proves SSSE3.
    unsafe {
        asm_call!(unsafe extern "sysv64" sha256_block_data_order_ssse3(state, blocks.as_ptr(), blocks.len() / 64))
    }
}

/// SHA-256 on CPUs without SSSE3, with aws-lc's integer
/// `sha256_block_data_order_nohw`, as aws-lc runs there.
pub(in crate::low) fn sha256_compress_blocks_nohw(state: &mut [u32; 8], blocks: &[u8]) {
    debug_assert!(blocks.len().is_multiple_of(64));
    // As for the AVX2 routine.
    if blocks.is_empty() {
        return;
    }
    // SAFETY: `blocks` is `blocks.len() / 64` readable blocks.
    unsafe {
        asm_call!(unsafe extern "sysv64" sha256_block_data_order_nohw(state, blocks.as_ptr(), blocks.len() / 64))
    }
}

/// The round constants, each group of four twice for the vector additions,
/// then the byte-swap and shuffle masks, as the routines load them.
#[repr(C, align(64))]
struct Table([u32; 152]);

static K256: Table = Table(include!("aws_lc/sha256-x86_64.K256.rs"));

// The routines take the System V ABI on every OS, since their text is
// OpenSSL's and aws-lc's ELF and Mach-O flavors, which read their arguments
// from its registers.

#[unsafe(naked)]
unsafe extern "sysv64" fn sha256_block_data_order_avx2(
    state: *mut [u32; 8],
    data: *const u8,
    blocks: usize,
) {
    #[cfg(not(target_vendor = "apple"))]
    core::arch::naked_asm!(
        include_str!("openssl/sha256_block_data_order_avx2.linux.s"),
        K256 = sym K256,
        options(att_syntax),
    );
    #[cfg(target_vendor = "apple")]
    core::arch::naked_asm!(
        include_str!("openssl/sha256_block_data_order_avx2.apple.s"),
        K256 = sym K256,
        options(att_syntax),
    );
}

#[unsafe(naked)]
unsafe extern "sysv64" fn sha256_block_data_order_avx(
    state: *mut [u32; 8],
    data: *const u8,
    blocks: usize,
) {
    #[cfg(not(target_vendor = "apple"))]
    core::arch::naked_asm!(
        include_str!("aws_lc/sha256_block_data_order_avx.linux.s"),
        K256 = sym K256,
        options(att_syntax),
    );
    #[cfg(target_vendor = "apple")]
    core::arch::naked_asm!(
        include_str!("aws_lc/sha256_block_data_order_avx.apple.s"),
        K256 = sym K256,
        options(att_syntax),
    );
}

#[unsafe(naked)]
unsafe extern "sysv64" fn sha256_block_data_order_ssse3(
    state: *mut [u32; 8],
    data: *const u8,
    blocks: usize,
) {
    #[cfg(not(target_vendor = "apple"))]
    core::arch::naked_asm!(
        include_str!("aws_lc/sha256_block_data_order_ssse3.linux.s"),
        K256 = sym K256,
        options(att_syntax),
    );
    #[cfg(target_vendor = "apple")]
    core::arch::naked_asm!(
        include_str!("aws_lc/sha256_block_data_order_ssse3.apple.s"),
        K256 = sym K256,
        options(att_syntax),
    );
}

#[unsafe(naked)]
unsafe extern "sysv64" fn sha256_block_data_order_nohw(
    state: *mut [u32; 8],
    data: *const u8,
    blocks: usize,
) {
    #[cfg(not(target_vendor = "apple"))]
    core::arch::naked_asm!(
        include_str!("aws_lc/sha256_block_data_order_nohw.linux.s"),
        K256 = sym K256,
        options(att_syntax),
    );
    #[cfg(target_vendor = "apple")]
    core::arch::naked_asm!(
        include_str!("aws_lc/sha256_block_data_order_nohw.apple.s"),
        K256 = sym K256,
        options(att_syntax),
    );
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::low::x86_64::cpu::{HaveAvx, HaveAvx2, HaveSha256, HaveSsse3};
    use crate::low::{ct, generic};

    const START: [u32; 8] = [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab,
        0x5be0cd19,
    ];

    // The SHA extensions, AVX2, SSSE3, and the vendor hide all but one path from
    // every other test, so each the CPU can run is checked against the
    // portable code directly, on blocks `admin/ctgrind` keeps secret: odd and
    // even block counts, with distinct bytes in every block. That checks
    // Intel's AVX code, which only Intel CPUs without AVX2 pick, on any CPU.
    #[test]
    fn paths_match_generic() {
        let (ssse3, avx, avx2) = (HaveSsse3::check(), HaveAvx::check(), HaveAvx2::check());
        let sha = HaveSha256::check();
        let blocks: Vec<u8> = (0..5 * 64u32)
            .map(|i| (i.wrapping_mul(0x9e3779b9) >> 24) as u8)
            .collect();
        ct::secret_slice(&blocks);
        for n in 0..=5 {
            let mut wanted = START;
            let blocks = &blocks[..n * 64];
            generic::sha256::sha256_compress_blocks(&mut wanted, blocks);
            let wanted = ct::into_public(wanted);

            let mut got = START;
            sha256_compress_blocks_nohw(&mut got, blocks);
            assert_eq!(ct::into_public(got), wanted, "nohw, {n} blocks");
            if let Some(token) = ssse3 {
                let mut got = START;
                sha256_compress_blocks_ssse3(&mut got, blocks, token);
                assert_eq!(ct::into_public(got), wanted, "ssse3, {n} blocks");
            }
            if let Some(token) = avx {
                let mut got = START;
                sha256_compress_blocks_avx(&mut got, blocks, token);
                assert_eq!(ct::into_public(got), wanted, "avx, {n} blocks");
            }
            if let Some(token) = avx2 {
                let mut got = START;
                sha256_compress_blocks_avx2(&mut got, blocks, token);
                assert_eq!(ct::into_public(got), wanted, "avx2, {n} blocks");
            }
            if let Some(token) = sha {
                let mut got = START;
                sha256_compress_blocks_shaext(&mut got, blocks, token);
                assert_eq!(ct::into_public(got), wanted, "shaext, {n} blocks");
            }
        }
    }

    // Every length up to three blocks, so every place the padding can fall
    // after zero to two whole blocks, with bytes past the message that must
    // not count.
    #[test]
    fn finish_matches_generic() {
        let Some(token) = HaveSha256::check() else {
            return;
        };
        let bytes: Vec<u8> = (0..4 * 64u32)
            .map(|i| (i.wrapping_mul(0x9e3779b9) >> 24) as u8)
            .collect();
        let length = 0x0102030405060708u64.to_be_bytes();
        for len in 0..=3 * 64 {
            let message = &bytes[..len];
            let (blocks, rest) = crate::low::split_tail::<64, 8>(message);
            let mut wanted = START;
            generic::sha256::sha256_compress_blocks(&mut wanted, blocks);
            let mut padded = [[0u8; 64]; 2];
            let padded = crate::low::pad(rest, length, &mut padded);
            generic::sha256::sha256_compress_blocks(&mut wanted, padded);
            let got = sha256_finish_shaext(&START, message, length, token);
            assert_eq!(got, crate::low::sha256_digest(&wanted), "{len} bytes");
        }
    }
}
