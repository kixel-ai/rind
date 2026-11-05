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

/// The digest of `state` followed by `blocks`, then the first `used` bytes
/// of `last`, padded and closed by `length`.
///
/// `last` is padded in registers, and the digest is written from them, so
/// neither takes a trip through memory that a load could wait on.
pub(in crate::low) fn sha256_finish_shaext(
    state: &[u32; 8],
    blocks: &[u8],
    last: &[u8; 64],
    used: usize,
    length: [u8; 8],
    _token: super::cpu::HaveSha256,
) -> [u8; 32] {
    debug_assert!(blocks.len().is_multiple_of(64));
    debug_assert!(used <= 64);
    // SAFETY: `_token` proves the caller checked the `sha`, `ssse3`, and
    // `sse4.1` features
    unsafe { sha256_finish(state, blocks, last, used, length) }
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
fn sha256_finish(
    state: &[u32; 8],
    blocks: &[u8],
    last: &[u8; 64],
    used: usize,
    length: [u8; 8],
) -> [u8; 32] {
    let k = round_constants();
    let mut abef = load_state(state);
    let (blocks, _) = blocks.as_chunks::<64>();
    for block in blocks {
        compress_block(&mut abef, load_block(block), &k);
    }

    // Keeps the bytes before `used`, and puts the 0x80 that ends the message
    // at `used`. `used` is the message's length, so it may be branched on.
    let used_at = _mm_set1_epi8(used as i8);
    let end = _mm_set1_epi8(0x80u8 as i8);
    let first = _mm_setr_epi8(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
    let mut msg = load_block(last);
    for (i, lane) in msg.iter_mut().enumerate() {
        let index = _mm_add_epi8(first, _mm_set1_epi8((16 * i) as i8));
        let kept = _mm_and_si128(*lane, _mm_cmpgt_epi8(used_at, index));
        *lane = _mm_or_si128(kept, _mm_and_si128(_mm_cmpeq_epi8(used_at, index), end));
    }
    // The length's bytes, as the block's last eight.
    let length = _mm_set_epi64x(i64::from_le_bytes(length), 0);
    if used + 1 + 8 <= 64 {
        msg[3] = _mm_or_si128(msg[3], length);
        compress_block(&mut abef, msg, &k);
    } else {
        compress_block(&mut abef, msg, &k);
        let zero = _mm_setzero_si128();
        // A full `last` leaves the 0x80 to the block after it.
        let end = _mm_cvtsi32_si128(if used == 64 { 0x80 } else { 0 });
        compress_block(&mut abef, [end, zero, zero, length], &k);
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

/// SHA-256 without the SHA extensions on Intel, with aws-lc's
/// `sha256_block_data_order_avx`, imported by `admin/import-aws-lc`. It
/// rotates with `shrd`, which is fast on Intel's cores and slow on pre-Zen
/// AMD's, so aws-lc runs it on Intel only, and so does rind.
pub(in crate::low) fn sha256_compress_blocks_avx(
    state: &mut [u32; 8],
    blocks: &[u8],
    _token: super::cpu::HaveAvx,
) {
    debug_assert!(blocks.len().is_multiple_of(64));
    // The routine runs its loop at least once, so zero blocks would read past
    // `blocks`.
    if blocks.is_empty() {
        return;
    }
    // SAFETY: `blocks` is `blocks.len() / 64` readable blocks, and `_token`
    // proves AVX.
    unsafe { sha256_block_data_order_avx(state, blocks.as_ptr(), blocks.len() / 64) }
}

/// SHA-256 without the SHA extensions or AVX2 on other vendors' CPUs, with
/// aws-lc's `sha256_block_data_order_ssse3`, as aws-lc runs there.
pub(in crate::low) fn sha256_compress_blocks_ssse3(
    state: &mut [u32; 8],
    blocks: &[u8],
    _token: super::cpu::HaveSsse3,
) {
    debug_assert!(blocks.len().is_multiple_of(64));
    // As for the AVX routine.
    if blocks.is_empty() {
        return;
    }
    // SAFETY: `blocks` is `blocks.len() / 64` readable blocks, and `_token`
    // proves SSSE3.
    unsafe { sha256_block_data_order_ssse3(state, blocks.as_ptr(), blocks.len() / 64) }
}

/// SHA-256 on CPUs without SSSE3, with aws-lc's integer
/// `sha256_block_data_order_nohw`, as aws-lc runs there.
pub(in crate::low) fn sha256_compress_blocks_nohw(state: &mut [u32; 8], blocks: &[u8]) {
    debug_assert!(blocks.len().is_multiple_of(64));
    // As for the AVX routine.
    if blocks.is_empty() {
        return;
    }
    // SAFETY: `blocks` is `blocks.len() / 64` readable blocks.
    unsafe { sha256_block_data_order_nohw(state, blocks.as_ptr(), blocks.len() / 64) }
}

/// The round constants, each group of four twice for the vector additions,
/// then the byte-swap and shuffle masks, as the routine loads them.
#[repr(C, align(64))]
struct Table([u32; 152]);

static K256: Table = Table(include!("aws_lc/sha256-x86_64.K256.rs"));

// The routines take the System V ABI on every OS, since their text is
// aws-lc's ELF and Mach-O flavors, which read their arguments from its
// registers.

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

/// SHA-256 without the SHA extensions on other vendors' CPUs with AVX2,
/// structured as aws-lc's `sha256_block_data_order_avx2`: AVX2 computes the
/// message schedule of two blocks at once, one per 128-bit lane, interleaved
/// with the scalar rounds of the first block; the second block's rounds then
/// read their half.
pub(in crate::low) fn sha256_compress_blocks_avx2(
    state: &mut [u32; 8],
    blocks: &[u8],
    _token: super::cpu::HaveAvx2,
) {
    debug_assert!(blocks.len().is_multiple_of(64));
    // SAFETY: `_token` proves the `avx2` and `bmi2` cpu features
    unsafe { sha256_avx2(state, blocks) }
}

#[target_feature(enable = "avx,avx2,bmi2")]
fn sha256_avx2(state: &mut [u32; 8], blocks: &[u8]) {
    let (blocks, _) = blocks.as_chunks::<64>();
    let (pairs, last) = blocks.as_chunks::<2>();
    let mut wk = [[[0; 4]; 2]; 16];
    for [first, second] in pairs {
        schedule_and_rounds(state, &mut wk, first, second);
        second_rounds(state, &wk);
    }
    // An odd last block fills both lanes, and only its first runs.
    if let [last] = last {
        schedule_and_rounds(state, &mut wk, last, last);
    }
}

/// W[t] + K[t] for rounds `4g..4g + 4` of two blocks: `[g][0]` for the first
/// block, `[g][1]` for the second.
type Schedule = [[[u32; 4]; 2]; 16];

/// One round of FIPS 180-4, 6.2.2, given W[t] + K[t]. Rather than moving
/// every variable, each round names them one place further along.
///
/// MAJ(a, b, c) = b ^ ((a ^ b) & (b ^ c)), and this round's a ^ b is the
/// next round's b ^ c, so `$bc` carries it.
macro_rules! round {
    ($a:ident $b:ident $c:ident $d:ident $e:ident $f:ident $g:ident $h:ident, $bc:ident, $wk:expr) => {
        $h = $h
            .wrapping_add($wk)
            .wrapping_add($e.rotate_right(6) ^ $e.rotate_right(11) ^ $e.rotate_right(25))
            .wrapping_add($g ^ ($e & ($f ^ $g)));
        $d = $d.wrapping_add($h);
        let ab = $a ^ $b;
        $h = $h
            .wrapping_add($a.rotate_right(2) ^ $a.rotate_right(13) ^ $a.rotate_right(22))
            .wrapping_add($b ^ (ab & $bc));
        $bc = ab;
    };
}

/// Four rounds, given their W + K. After them, `e f g h a b c d` name what
/// `a b c d e f g h` did.
macro_rules! rounds4 {
    ($a:ident $b:ident $c:ident $d:ident $e:ident $f:ident $g:ident $h:ident, $bc:ident, $wk:expr) => {
        let wk: [u32; 4] = $wk;
        round!($a $b $c $d $e $f $g $h, $bc, wk[0]);
        round!($h $a $b $c $d $e $f $g, $bc, wk[1]);
        round!($g $h $a $b $c $d $e $f, $bc, wk[2]);
        round!($f $g $h $a $b $c $d $e, $bc, wk[3]);
    };
}

/// Fills `wk` from `first` and `second`, running the first block's rounds as
/// each group of four is ready, so the vector work overlaps the serial
/// scalar rounds.
#[inline]
#[target_feature(enable = "avx,avx2,bmi2")]
fn schedule_and_rounds(
    state: &mut [u32; 8],
    wk: &mut Schedule,
    first: &[u8; 64],
    second: &[u8; 64],
) {
    let mut w0 = load(first, second, 0);
    let mut w1 = load(first, second, 1);
    let mut w2 = load(first, second, 2);
    let mut w3 = load(first, second, 3);
    store(wk, 0, w0);
    store(wk, 1, w1);
    store(wk, 2, w2);
    store(wk, 3, w3);

    let [mut a, mut b, mut c, mut d, mut e, mut f, mut g, mut h] = *state;
    let mut bc = b ^ c;
    for i in (0..12).step_by(4) {
        rounds4!(a b c d e f g h, bc, wk[i][0]);
        w0 = schedule(w0, w1, w2, w3);
        store(wk, i + 4, w0);
        rounds4!(e f g h a b c d, bc, wk[i + 1][0]);
        w1 = schedule(w1, w2, w3, w0);
        store(wk, i + 5, w1);
        rounds4!(a b c d e f g h, bc, wk[i + 2][0]);
        w2 = schedule(w2, w3, w0, w1);
        store(wk, i + 6, w2);
        rounds4!(e f g h a b c d, bc, wk[i + 3][0]);
        w3 = schedule(w3, w0, w1, w2);
        store(wk, i + 7, w3);
    }
    rounds4!(a b c d e f g h, bc, wk[12][0]);
    rounds4!(e f g h a b c d, bc, wk[13][0]);
    rounds4!(a b c d e f g h, bc, wk[14][0]);
    rounds4!(e f g h a b c d, bc, wk[15][0]);
    // The last round's a ^ b is unused.
    let _ = bc;

    for (s, v) in state.iter_mut().zip([a, b, c, d, e, f, g, h]) {
        *s = s.wrapping_add(v);
    }
}

/// Runs the second block's rounds from a filled `wk`.
#[inline]
#[target_feature(enable = "bmi2")]
fn second_rounds(state: &mut [u32; 8], wk: &Schedule) {
    let [mut a, mut b, mut c, mut d, mut e, mut f, mut g, mut h] = *state;
    let mut bc = b ^ c;
    for i in (0..16).step_by(2) {
        rounds4!(a b c d e f g h, bc, wk[i][1]);
        rounds4!(e f g h a b c d, bc, wk[i + 1][1]);
    }

    for (s, v) in state.iter_mut().zip([a, b, c, d, e, f, g, h]) {
        *s = s.wrapping_add(v);
    }
}

/// W[4i..4i + 4] of both blocks: the message's big-endian words.
#[inline]
#[target_feature(enable = "avx,avx2")]
fn load(first: &[u8; 64], second: &[u8; 64], i: usize) -> __m256i {
    let byte_reverse = _mm256_set_epi64x(
        0x0c0d0e0f_08090a0b,
        0x04050607_00010203,
        0x0c0d0e0f_08090a0b,
        0x04050607_00010203,
    );
    let (first, second) = (
        &first.as_chunks::<16>().0[i],
        &second.as_chunks::<16>().0[i],
    );
    // SAFETY: `first` and `second` are 16 bytes and readable
    let (lo, hi) = unsafe {
        (
            _mm_loadu_si128(first.as_ptr().cast()),
            _mm_loadu_si128(second.as_ptr().cast()),
        )
    };
    let words = _mm256_inserti128_si256::<1>(_mm256_castsi128_si256(lo), hi);
    _mm256_shuffle_epi8(words, byte_reverse)
}

/// Stores W[4g..4g + 4] + K[4g..4g + 4] of both blocks as group `g` of `wk`.
#[inline]
#[target_feature(enable = "avx,avx2")]
fn store(wk: &mut Schedule, g: usize, w: __m256i) {
    let k = &K.0.as_chunks::<4>().0[g];
    // SAFETY: `k` is 4 32-bit words, so 16 bytes are readable
    let k = _mm256_broadcastsi128_si256(unsafe { _mm_loadu_si128(k.as_ptr().cast()) });
    // SAFETY: `wk[g]` is 8 32-bit words, so 32 bytes are writable
    unsafe { _mm256_storeu_si256(wk[g].as_mut_ptr().cast(), _mm256_add_epi32(w, k)) };
}

/// The next four words of each block's schedule, from the sixteen before:
/// W[t] = SSIG1(W[t-2]) + W[t-7] + SSIG0(W[t-15]) + W[t-16] (FIPS 180-4,
/// 6.2.2). Every AVX2 op used here works within its 128-bit lane, so the two
/// blocks never mix.
#[inline]
#[target_feature(enable = "avx,avx2")]
fn schedule(w16: __m256i, w12: __m256i, w8: __m256i, w4: __m256i) -> __m256i {
    let x = _mm256_add_epi32(
        _mm256_add_epi32(w16, _mm256_alignr_epi8::<4>(w4, w8)),
        ssig0(_mm256_alignr_epi8::<4>(w12, w16)),
    );
    // W[t+2] and W[t+3] need W[t] and W[t+1] from this same group, so the
    // SSIG1 term is added a pair at a time: words 0 and 1 first, from the
    // last two words of `w4`, then words 2 and 3 from those.
    let place_low = _mm256_set_epi64x(-1, 0x0b0a0908_03020100, -1, 0x0b0a0908_03020100);
    let place_high = _mm256_set_epi64x(0x0b0a0908_03020100, -1, 0x0b0a0908_03020100, -1);
    let x = _mm256_add_epi32(
        x,
        ssig1_pair(_mm256_shuffle_epi32::<0b11_11_10_10>(w4), place_low),
    );
    _mm256_add_epi32(
        x,
        ssig1_pair(_mm256_shuffle_epi32::<0b01_01_00_00>(x), place_high),
    )
}

/// SSIG0 of each 32-bit word: ROTR7 ^ ROTR18 ^ SHR3.
#[inline]
#[target_feature(enable = "avx,avx2")]
fn ssig0(x: __m256i) -> __m256i {
    _mm256_xor_si256(
        _mm256_xor_si256(
            _mm256_xor_si256(_mm256_srli_epi32::<7>(x), _mm256_slli_epi32::<25>(x)),
            _mm256_xor_si256(_mm256_srli_epi32::<18>(x), _mm256_slli_epi32::<14>(x)),
        ),
        _mm256_srli_epi32::<3>(x),
    )
}

/// SSIG1 (ROTR17 ^ ROTR19 ^ SHR10) of two words per lane, each given twice
/// as a 64-bit half of `pairs`, so a 64-bit shift rotates it. The `place`
/// shuffle moves the two results into position and zeroes the other words.
#[inline]
#[target_feature(enable = "avx,avx2")]
fn ssig1_pair(pairs: __m256i, place: __m256i) -> __m256i {
    let x = _mm256_xor_si256(
        _mm256_xor_si256(
            _mm256_srli_epi64::<17>(pairs),
            _mm256_srli_epi64::<19>(pairs),
        ),
        _mm256_srli_epi32::<10>(pairs),
    );
    _mm256_shuffle_epi8(x, place)
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::low::generic;
    use crate::low::x86_64::cpu::{HaveAvx, HaveAvx2, HaveSha256, HaveSsse3};

    const START: [u32; 8] = [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab,
        0x5be0cd19,
    ];

    // The SHA extensions, AVX2, SSSE3, and the vendor hide all but one path from
    // every other test, so each the CPU can run is checked against the
    // portable code directly: odd and even block counts, with distinct bytes
    // in every block.
    #[test]
    fn paths_match_generic() {
        let (ssse3, avx, avx2) = (HaveSsse3::check(), HaveAvx::check(), HaveAvx2::check());
        let sha = HaveSha256::check();
        let blocks: Vec<u8> = (0..5 * 64u32)
            .map(|i| (i.wrapping_mul(0x9e3779b9) >> 24) as u8)
            .collect();
        for n in 0..=5 {
            let mut wanted = START;
            let blocks = &blocks[..n * 64];
            generic::sha256::sha256_compress_blocks(&mut wanted, blocks);

            let mut got = START;
            sha256_compress_blocks_nohw(&mut got, blocks);
            assert_eq!(got, wanted, "nohw, {n} blocks");
            if let Some(token) = ssse3 {
                let mut got = START;
                sha256_compress_blocks_ssse3(&mut got, blocks, token);
                assert_eq!(got, wanted, "ssse3, {n} blocks");
            }
            if let Some(token) = avx {
                let mut got = START;
                sha256_compress_blocks_avx(&mut got, blocks, token);
                assert_eq!(got, wanted, "avx, {n} blocks");
            }
            if let Some(token) = avx2 {
                let mut got = START;
                sha256_compress_blocks_avx2(&mut got, blocks, token);
                assert_eq!(got, wanted, "avx2, {n} blocks");
            }
            if let Some(token) = sha {
                let mut got = START;
                sha256_compress_blocks_shaext(&mut got, blocks, token);
                assert_eq!(got, wanted, "shaext, {n} blocks");
            }
        }
    }

    // Every length of the last block's message, around each place the
    // padding can fall, after zero to two whole blocks, with bytes past the
    // message that must not count.
    #[test]
    fn finish_matches_generic() {
        let Some(token) = HaveSha256::check() else {
            return;
        };
        let bytes: Vec<u8> = (0..3 * 64u32)
            .map(|i| (i.wrapping_mul(0x9e3779b9) >> 24) as u8)
            .collect();
        let (blocks, last) = bytes.split_at(2 * 64);
        let last: &[u8; 64] = last.try_into().unwrap();
        let length = 0x0102030405060708u64.to_be_bytes();
        for n in 0..=2 {
            let blocks = &blocks[..n * 64];
            for used in 0..=64 {
                let mut wanted = START;
                generic::sha256::sha256_compress_blocks(&mut wanted, blocks);
                let mut padded = [[0u8; 64]; 2];
                let padded = crate::low::pad(&last[..used], length, &mut padded);
                generic::sha256::sha256_compress_blocks(&mut wanted, padded);
                let got = sha256_finish_shaext(&START, blocks, last, used, length, token);
                assert_eq!(
                    got,
                    crate::low::sha256_digest(&wanted),
                    "{n} blocks, {used} bytes"
                );
            }
        }
    }
}
