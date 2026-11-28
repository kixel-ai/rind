// Written for Graviola by Joe Birr-Pixton, 2026.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! ML-KEM's matrix sampling, eight polynomials at a time, over the eight-way
//! Keccak-f.
//
// The loops count indices, and only `load`, `store`, and `store_low` touch a
// pointer, since `proofs/` proves Aeneas's translation, which takes no
// iterator adapter, closure, or raw pointer.
#![allow(
    clippy::needless_range_loop,
    clippy::manual_map,
    reason = "Aeneas translates no iterator adapter or closure"
)]

use core::arch::x86_64::*;

use super::cpu::HaveAvx512ForMlKem;
use super::sha3_keccak8_f1600::{RC, keccak8_f1600};

/// What the eight-way sampler leaves its caller: how many coefficients of
/// each polynomial it wrote, and for each with fewer than 256, the SHAKE128
/// state after the three blocks it read, to squeeze the rest from.
pub(crate) struct Tails {
    pub(crate) used: [usize; 8],
    pub(crate) states: [[u64; 25]; 8],
}

/// Writes to each of `outputs` the candidates below Q of the first three
/// blocks of SHAKE128 on the first 34 bytes of its input, up to 256, or does
/// nothing and returns `None` where the CPU lacks AVX-512. Each input's byte
/// 34 is SHAKE128's padding byte and the rest zero.
pub(crate) fn mlkem_sample_poly_ntt_8x(
    inputs: &[[u8; 40]; 8],
    outputs: &mut [[i16; 256]; 8],
) -> Option<Tails> {
    match HaveAvx512ForMlKem::check() {
        // SAFETY: `HaveAvx512ForMlKem` checks for the target features.
        Some(proof) => Some(unsafe { sample_poly_ntt_8x_avx512(inputs, outputs, proof) }),
        None => None,
    }
}

#[target_feature(enable = "avx512f,avx512bw,avx512vbmi,avx512vbmi2,popcnt")]
fn sample_poly_ntt_8x_avx512(
    inputs: &[[u8; 40]; 8],
    outputs: &mut [[i16; 256]; 8],
    _proof: HaveAvx512ForMlKem,
) -> Tails {
    // Each input is one block of SHAKE128 once padded: its five words, then
    // the padding's last bit, the top of the rate's last word.
    let mut states = [_mm512_setzero_si512(); 25];
    for lane in 0..5 {
        states[lane] = _mm512_setr_epi64(
            word(&inputs[0], lane),
            word(&inputs[1], lane),
            word(&inputs[2], lane),
            word(&inputs[3], lane),
            word(&inputs[4], lane),
            word(&inputs[5], lane),
            word(&inputs[6], lane),
            word(&inputs[7], lane),
        );
    }
    states[RATE_WORDS - 1] = _mm512_set1_epi64(i64::MIN);

    // Like the generic version, we generate three squeezes of data to
    // sample coefficients from.  This gives up to 336 candidates for 256 output
    // coefficients.
    let mut used = [0; 8];
    keccak8_f1600(&mut states, &RC);
    squeeze_rate_and_reject(&states, outputs, &mut used);
    keccak8_f1600(&mut states, &RC);
    squeeze_rate_and_reject(&states, outputs, &mut used);
    keccak8_f1600(&mut states, &RC);
    squeeze_rate_and_reject(&states, outputs, &mut used);

    let mut tails = Tails {
        used,
        states: [[0; 25]; 8],
    };
    for i in 0..8 {
        if used[i] < 256 {
            tails.states[i] = extract_state(&states, i);
        }
    }
    tails
}

/// Word `lane` of `input`, little-endian.
fn word(input: &[u8; 40], lane: usize) -> i64 {
    u64::from_le_bytes(input[lane * 8..lane * 8 + 8].try_into().unwrap()) as i64
}

/// Extract a single keccak state from the 8-way `states`, where `index` is in `0..8`.
///
/// `states[lane]` holds `lane` for all eight states, so the result collects the
/// `index`th 64-bit word of each lane.
#[target_feature(enable = "avx512f")]
fn extract_state(states: &[__m512i; 25], index: usize) -> [u64; 25] {
    let mut r = [0u64; 25];
    for lane in 0..25 {
        r[lane] = store(states[lane])[index];
    }
    r
}

/// Squeeze rate bytes from `state`, rejection sampling into `output`.
///
/// `used` counts the coefficients each polynomial in `output` has, and is
/// updated with those this writes.
#[target_feature(enable = "avx512f,avx512bw,avx512vbmi,avx512vbmi2,popcnt")]
fn squeeze_rate_and_reject(
    state: &[__m512i; 25],
    output: &mut [[i16; 256]; 8],
    used: &mut [usize; 8],
) {
    let mut rate = [[0u64; 8]; RATE_WORDS];
    for lane in 0..RATE_WORDS {
        rate[lane] = store(state[lane]);
    }

    let spread = load(&SPREAD);

    let q = _mm512_set1_epi16(Q as i16);
    let twelve_bits = _mm512_set1_epi16(0x0fff);

    // Within each pair of 16-bit lanes, the first candidate needs no shift and the
    // second needs to lose the four bits it shares with the first.
    let shifts = _mm512_set1_epi32(0x0004_0000);

    let mut bytes = [0u8; RATE_BYTES + 64];

    for i in 0..8 {
        // Collect this state's rate bytes.  Candidates straddle the 64-bit lanes,
        // so it is simplest to linearise them first.  The trailing padding means a
        // 64-byte load from anywhere within the rate stays in bounds.
        for lane in 0..RATE_WORDS {
            bytes[lane * 8..lane * 8 + 8].copy_from_slice(&rate[lane][i].to_le_bytes());
        }

        for group in 0..GROUPS {
            if used[i] < 256 {
                // Rejection sample, per FIPS-203 `SampleNTT()`: each three bytes give two
                // 12-bit candidates.  `SPREAD` gathers each three-byte group into a pair
                // of 16-bit lanes, which are then reduced to the candidates themselves.
                let offset = group * GROUP_BYTES;
                let raw = load(bytes[offset..offset + 64].try_into().unwrap());
                let candidates = _mm512_and_si512(
                    _mm512_srlv_epi16(_mm512_permutexvar_epi8(spread, raw), shifts),
                    twelve_bits,
                );

                // Accept candidates less than Q.  Lanes past the end of the rate read as
                // zero, which would otherwise be accepted, so discard them.
                let mut accept = _mm512_cmplt_epu16_mask(candidates, q);
                if group == GROUPS - 1 {
                    accept &= LAST_GROUP;
                }

                // Compact the accepted candidates to the bottom of a register, then store
                // only as many as fit.
                let room = 256 - used[i];
                let accepted = accept.count_ones() as usize;
                let take = if accepted < room { accepted } else { room };
                let compacted = _mm512_maskz_compress_epi16(accept, candidates);
                store_low(&mut output[i][used[i]..used[i] + take], compacted);
                used[i] += take;
            }
        }
    }
}

/// The 64 bytes at `bytes`, byte 0 lowest.
//
// A load through a pointer, which `proofs/` models by hand, as it does
// `store` and `store_low`.
#[inline]
#[target_feature(enable = "avx512f")]
fn load(bytes: &[u8; 64]) -> __m512i {
    // SAFETY: `bytes` is 64 bytes, exactly the width of one `__m512i`.
    unsafe { _mm512_loadu_si512(bytes.as_ptr().cast()) }
}

/// `v`'s eight 64-bit elements, element 0 first.
#[inline]
#[target_feature(enable = "avx512f")]
fn store(v: __m512i) -> [u64; 8] {
    let mut r = [0u64; 8];
    // SAFETY: `r` is 8 * 8 = 64 bytes, exactly the width of one `__m512i`.
    unsafe { _mm512_storeu_si512(r.as_mut_ptr().cast(), v) };
    r
}

/// Sets `out` to `v`'s first 16-bit elements, as many as `out` holds, up to 32.
#[inline]
#[target_feature(enable = "avx512f,avx512bw")]
fn store_low(out: &mut [i16], v: __m512i) {
    let mask = if out.len() < 32 {
        (1u32 << out.len()) - 1
    } else {
        u32::MAX
    };
    // SAFETY: the mask writes only the first `out.len()` elements, up to 32.
    unsafe { _mm512_mask_storeu_epi16(out.as_mut_ptr(), mask, v) }
}

/// SHAKE128's rate, in 64-bit words: 168 bytes.
const RATE_WORDS: usize = (1600 - 256) / 64;

/// SHAKE128's rate, in bytes.
const RATE_BYTES: usize = RATE_WORDS * 8;

/// Candidates produced by one vector pass.
const GROUP_CANDIDATES: usize = 32;

/// Bytes consumed by one vector pass; three bytes give two candidates.
const GROUP_BYTES: usize = GROUP_CANDIDATES / 2 * 3;

/// Vector passes over the rate, the last short.
const GROUPS: usize = RATE_BYTES.div_ceil(GROUP_BYTES);

/// The candidates of the last pass that lie within the rate.
const LAST_GROUP: u32 = (1 << ((RATE_BYTES - (GROUPS - 1) * GROUP_BYTES) / 3 * 2)) - 1;

/// Byte permutation spreading `GROUP_BYTES` packed bytes into 32 16-bit lanes.
///
/// Lane `k` (where `j = k / 2`) takes bytes `3j` and `3j + 1` when `k` is even,
/// or `3j + 1` and `3j + 2` when it is odd.
//
// Spelled out, so that `proofs/` reads its bytes rather than the loop that
// would build them.
static SPREAD: [u8; 64] = [
    0, 1, 1, 2, 3, 4, 4, 5, 6, 7, 7, 8, 9, 10, 10, 11, 12, 13, 13, 14, 15, 16, 16, 17, 18, 19, 19,
    20, 21, 22, 22, 23, 24, 25, 25, 26, 27, 28, 28, 29, 30, 31, 31, 32, 33, 34, 34, 35, 36, 37, 37,
    38, 39, 40, 40, 41, 42, 43, 43, 44, 45, 46, 46, 47,
];

/// The ML-KEM prime.
const Q: u16 = 3329;
