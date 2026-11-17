// Ported from the Argon2 reference implementation, Copyright 2015 Daniel
// Dinu, Dmitry Khovratovich, Jean-Philippe Aumasson, and Samuel Neves, under
// CC0-1.0.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! Argon2's compression function on AVX-512F.
//!
//! A port of the reference implementation's `fill_block` (`opt.c` and
//! `blamka-round-opt.h`), the same permutation `perf/argon2-sha3-umlal`'s
//! parent `d6114f56` runs. The quest's plan names libsodium's
//! `argon2-fill-block-avx512f.c` as the layout to measure against the AVX2
//! port; this is the reference's layout, kept so that measurement has a
//! kernel that already matches the portable permutation.
//!
//! Built for the tests, and for a release that passes `--cfg rind_argon2_avx512`.
//! Dispatch does not select it until that build, and only on a CPU with
//! AVX-512F. Keep it where it wins on Zen 4 or 5 and on Sapphire Rapids.
//! `admin/ctgrind` cannot decode AVX-512, so `ct_sde_argon2_avx512` is the
//! constant-time check, under `admin/ct-sde`.

use core::arch::x86_64::*;

use crate::low::generic::argon2::Argon2Block;

/// # Safety
/// The CPU must have AVX-512F. Each block is 1024 bytes.
#[target_feature(enable = "avx512f")]
pub(crate) unsafe fn compress(x: &Argon2Block, y: &Argon2Block, out: &mut Argon2Block, xor: bool) {
    // SAFETY: the caller proved AVX-512F, and these are the same blocks.
    unsafe { compress_avx512(out, x, y, xor) }
}

#[target_feature(enable = "avx512f")]
unsafe fn compress_avx512(
    next: &mut Argon2Block,
    prev: &Argon2Block,
    reference: &Argon2Block,
    with_xor: bool,
) {
    // SAFETY: `prev` is 1024 bytes, as `load` requires.
    let mut state = unsafe { load(prev) };
    let mut xy = [_mm512_setzero_si512(); 16];
    // SAFETY: each block is 1024 aligned bytes, sixteen 64-byte lanes.
    unsafe {
        for i in 0..16 {
            let r = _mm512_loadu_si512(reference.0.as_ptr().add(i * 8).cast());
            state[i] = _mm512_xor_si512(state[i], r);
            xy[i] = if with_xor {
                let n = _mm512_loadu_si512(next.0.as_ptr().add(i * 8).cast());
                _mm512_xor_si512(state[i], n)
            } else {
                state[i]
            };
        }
        for i in 0..2 {
            round1(&mut state, i);
        }
        for i in 0..2 {
            round2(&mut state, i);
        }
        for i in 0..16 {
            state[i] = _mm512_xor_si512(state[i], xy[i]);
            _mm512_storeu_si512(next.0.as_mut_ptr().add(i * 8).cast(), state[i]);
        }
    }
}

#[target_feature(enable = "avx512f")]
unsafe fn load(block: &Argon2Block) -> [__m512i; 16] {
    let mut state = [_mm512_setzero_si512(); 16];
    // SAFETY: `block` is 1024 bytes.
    unsafe {
        for (i, lane) in state.iter_mut().enumerate() {
            *lane = _mm512_loadu_si512(block.0.as_ptr().add(i * 8).cast());
        }
    }
    state
}

// `_MM_SHUFFLE` as the C headers spell it.
const fn shuffle(z: i32, y: i32, x: i32, w: i32) -> i32 {
    (z << 6) | (y << 4) | (x << 2) | w
}

#[target_feature(enable = "avx512f")]
fn muladd(x: __m512i, y: __m512i) -> __m512i {
    let z = _mm512_mul_epu32(x, y);
    _mm512_add_epi64(_mm512_add_epi64(x, y), _mm512_add_epi64(z, z))
}

#[target_feature(enable = "avx512f")]
fn ror32(x: __m512i) -> __m512i {
    _mm512_or_si512(_mm512_srli_epi64::<32>(x), _mm512_slli_epi64::<32>(x))
}

#[target_feature(enable = "avx512f")]
fn ror24(x: __m512i) -> __m512i {
    _mm512_or_si512(_mm512_srli_epi64::<24>(x), _mm512_slli_epi64::<40>(x))
}

#[target_feature(enable = "avx512f")]
fn ror16(x: __m512i) -> __m512i {
    _mm512_or_si512(_mm512_srli_epi64::<16>(x), _mm512_slli_epi64::<48>(x))
}

#[target_feature(enable = "avx512f")]
fn ror63(x: __m512i) -> __m512i {
    _mm512_or_si512(_mm512_srli_epi64::<63>(x), _mm512_slli_epi64::<1>(x))
}

#[target_feature(enable = "avx512f")]
fn g1(
    a0: &mut __m512i,
    b0: &mut __m512i,
    c0: &mut __m512i,
    d0: &mut __m512i,
    a1: &mut __m512i,
    b1: &mut __m512i,
    c1: &mut __m512i,
    d1: &mut __m512i,
) {
    *a0 = muladd(*a0, *b0);
    *a1 = muladd(*a1, *b1);
    *d0 = ror32(_mm512_xor_si512(*d0, *a0));
    *d1 = ror32(_mm512_xor_si512(*d1, *a1));
    *c0 = muladd(*c0, *d0);
    *c1 = muladd(*c1, *d1);
    *b0 = ror24(_mm512_xor_si512(*b0, *c0));
    *b1 = ror24(_mm512_xor_si512(*b1, *c1));
}

#[target_feature(enable = "avx512f")]
fn g2(
    a0: &mut __m512i,
    b0: &mut __m512i,
    c0: &mut __m512i,
    d0: &mut __m512i,
    a1: &mut __m512i,
    b1: &mut __m512i,
    c1: &mut __m512i,
    d1: &mut __m512i,
) {
    *a0 = muladd(*a0, *b0);
    *a1 = muladd(*a1, *b1);
    *d0 = ror16(_mm512_xor_si512(*d0, *a0));
    *d1 = ror16(_mm512_xor_si512(*d1, *a1));
    *c0 = muladd(*c0, *d0);
    *c1 = muladd(*c1, *d1);
    *b0 = ror63(_mm512_xor_si512(*b0, *c0));
    *b1 = ror63(_mm512_xor_si512(*b1, *c1));
}

#[target_feature(enable = "avx512f")]
unsafe fn diagonalize(
    b0: &mut __m512i,
    c0: &mut __m512i,
    d0: &mut __m512i,
    b1: &mut __m512i,
    c1: &mut __m512i,
    d1: &mut __m512i,
) {
    *b0 = _mm512_permutex_epi64::<{ shuffle(0, 3, 2, 1) }>(*b0);
    *b1 = _mm512_permutex_epi64::<{ shuffle(0, 3, 2, 1) }>(*b1);
    *c0 = _mm512_permutex_epi64::<{ shuffle(1, 0, 3, 2) }>(*c0);
    *c1 = _mm512_permutex_epi64::<{ shuffle(1, 0, 3, 2) }>(*c1);
    *d0 = _mm512_permutex_epi64::<{ shuffle(2, 1, 0, 3) }>(*d0);
    *d1 = _mm512_permutex_epi64::<{ shuffle(2, 1, 0, 3) }>(*d1);
}

#[target_feature(enable = "avx512f")]
unsafe fn undiagonalize(
    b0: &mut __m512i,
    c0: &mut __m512i,
    d0: &mut __m512i,
    b1: &mut __m512i,
    c1: &mut __m512i,
    d1: &mut __m512i,
) {
    *b0 = _mm512_permutex_epi64::<{ shuffle(2, 1, 0, 3) }>(*b0);
    *b1 = _mm512_permutex_epi64::<{ shuffle(2, 1, 0, 3) }>(*b1);
    *c0 = _mm512_permutex_epi64::<{ shuffle(1, 0, 3, 2) }>(*c0);
    *c1 = _mm512_permutex_epi64::<{ shuffle(1, 0, 3, 2) }>(*c1);
    *d0 = _mm512_permutex_epi64::<{ shuffle(0, 3, 2, 1) }>(*d0);
    *d1 = _mm512_permutex_epi64::<{ shuffle(0, 3, 2, 1) }>(*d1);
}

#[target_feature(enable = "avx512f")]
unsafe fn blake2_round(
    a0: &mut __m512i,
    b0: &mut __m512i,
    c0: &mut __m512i,
    d0: &mut __m512i,
    a1: &mut __m512i,
    b1: &mut __m512i,
    c1: &mut __m512i,
    d1: &mut __m512i,
) {
    // SAFETY: each helper requires only AVX-512F.
    unsafe {
        g1(a0, b0, c0, d0, a1, b1, c1, d1);
        g2(a0, b0, c0, d0, a1, b1, c1, d1);
        diagonalize(b0, c0, d0, b1, c1, d1);
        g1(a0, b0, c0, d0, a1, b1, c1, d1);
        g2(a0, b0, c0, d0, a1, b1, c1, d1);
        undiagonalize(b0, c0, d0, b1, c1, d1);
    }
}

#[target_feature(enable = "avx512f")]
unsafe fn swap_halves(a: &mut __m512i, b: &mut __m512i) {
    let t0 = _mm512_shuffle_i64x2::<{ shuffle(1, 0, 1, 0) }>(*a, *b);
    let t1 = _mm512_shuffle_i64x2::<{ shuffle(3, 2, 3, 2) }>(*a, *b);
    *a = t0;
    *b = t1;
}

#[target_feature(enable = "avx512f")]
unsafe fn swap_quarters(a: &mut __m512i, b: &mut __m512i) {
    // SAFETY: AVX-512F, from the caller's feature gate.
    unsafe {
        swap_halves(a, b);
        let idx = _mm512_setr_epi64(0, 1, 4, 5, 2, 3, 6, 7);
        *a = _mm512_permutexvar_epi64(idx, *a);
        *b = _mm512_permutexvar_epi64(idx, *b);
    }
}

#[target_feature(enable = "avx512f")]
unsafe fn unswap_quarters(a: &mut __m512i, b: &mut __m512i) {
    // SAFETY: AVX-512F, from the caller's feature gate.
    unsafe {
        let idx = _mm512_setr_epi64(0, 1, 4, 5, 2, 3, 6, 7);
        *a = _mm512_permutexvar_epi64(idx, *a);
        *b = _mm512_permutexvar_epi64(idx, *b);
        swap_halves(a, b);
    }
}

/// Column round. The reference's macro binds its arguments `(A0, C0, B0, D0, A1, C1, B1, D1)`.
#[target_feature(enable = "avx512f")]
unsafe fn round1(state: &mut [__m512i; 16], i: usize) {
    let b = 8 * i;
    let (mut a0, mut c0, mut b0, mut d0, mut a1, mut c1, mut b1, mut d1) = (
        state[b],
        state[b + 1],
        state[b + 2],
        state[b + 3],
        state[b + 4],
        state[b + 5],
        state[b + 6],
        state[b + 7],
    );
    // SAFETY: AVX-512F, from the caller's feature gate.
    unsafe {
        swap_halves(&mut a0, &mut b0);
        swap_halves(&mut c0, &mut d0);
        swap_halves(&mut a1, &mut b1);
        swap_halves(&mut c1, &mut d1);
        blake2_round(
            &mut a0, &mut b0, &mut c0, &mut d0, &mut a1, &mut b1, &mut c1, &mut d1,
        );
        swap_halves(&mut a0, &mut b0);
        swap_halves(&mut c0, &mut d0);
        swap_halves(&mut a1, &mut b1);
        swap_halves(&mut c1, &mut d1);
    }
    state[b] = a0;
    state[b + 1] = c0;
    state[b + 2] = b0;
    state[b + 3] = d0;
    state[b + 4] = a1;
    state[b + 5] = c1;
    state[b + 6] = b1;
    state[b + 7] = d1;
}

/// Row round. Arguments are `(A0, A1, B0, B1, C0, C1, D0, D1)`.
#[target_feature(enable = "avx512f")]
unsafe fn round2(state: &mut [__m512i; 16], i: usize) {
    let (mut a0, mut a1, mut b0, mut b1, mut c0, mut c1, mut d0, mut d1) = (
        state[i],
        state[2 + i],
        state[4 + i],
        state[6 + i],
        state[8 + i],
        state[10 + i],
        state[12 + i],
        state[14 + i],
    );
    // SAFETY: AVX-512F, from the caller's feature gate.
    unsafe {
        swap_quarters(&mut a0, &mut a1);
        swap_quarters(&mut b0, &mut b1);
        swap_quarters(&mut c0, &mut c1);
        swap_quarters(&mut d0, &mut d1);
        blake2_round(
            &mut a0, &mut b0, &mut c0, &mut d0, &mut a1, &mut b1, &mut c1, &mut d1,
        );
        unswap_quarters(&mut a0, &mut a1);
        unswap_quarters(&mut b0, &mut b1);
        unswap_quarters(&mut c0, &mut c1);
        unswap_quarters(&mut d0, &mut d1);
    }
    state[i] = a0;
    state[2 + i] = a1;
    state[4 + i] = b0;
    state[6 + i] = b1;
    state[8 + i] = c0;
    state[10 + i] = c1;
    state[12 + i] = d0;
    state[14 + i] = d1;
}

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
mod tests {
    use super::*;
    use crate::low::generic::argon2::assert_matches_portable;
    use crate::low::x86_64::cpu::HaveAvx512ForArgon2;

    #[test]
    fn matches_portable() {
        if HaveAvx512ForArgon2::check().is_none() {
            return;
        }
        assert_matches_portable(|x, y, out, xor| {
            // SAFETY: AVX-512F checked above, and the blocks are 1024 bytes.
            unsafe { compress(x, y, out, xor) }
        });
    }

    // Valgrind decodes no AVX-512, so `admin/ct-sde` traces the permutation
    // here. The loads and stores cover the whole block, whichever words it holds.
    #[test]
    #[ignore = "admin/ct-sde runs it under Intel SDE"]
    fn ct_sde_argon2_avx512() {
        use crate::low::x86_64::ct_sde;

        assert!(HaveAvx512ForArgon2::check().is_some(), "AVX-512F");
        let seed = ct_sde::seed();
        let mut x = Argon2Block::ZERO;
        let mut y = Argon2Block::ZERO;
        let mut old = Argon2Block::ZERO;
        for i in 0..128 {
            x.0[i] = (i as u64).wrapping_mul(seed);
            y.0[i] = (i as u64).wrapping_mul(seed ^ 0x1234_5678_9ABC_DEF0) ^ 0x00FF;
            old.0[i] = 0xFFFF_0000_FFFF_0000 ^ seed.wrapping_add(i as u64);
        }
        let word = ct_sde::traced(|| {
            let mut out = old;
            // SAFETY: the assertion is proof of AVX-512F, and the blocks are
            // 1024 bytes.
            unsafe { compress(&x, &y, &mut out, true) };
            out.0[0]
        });
        core::hint::black_box(word);
    }
}
