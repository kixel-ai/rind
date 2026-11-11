// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! Keccak-f[1600] on OpenSSL's `keccak1600-armv4` routines: NEON where the CPU
//! has it, and integer code on bit-interleaved lanes otherwise.
//!
//! The assembly is OpenSSL's, imported by `admin/import-openssl`. It is not
//! formally verified: its correctness rests on its use and testing in
//! OpenSSL, and on rind's tests of SHA-3 and ML-KEM against their vectors and
//! aws-lc-rs.

use super::cpu::HaveNeon;

unsafe extern "C" {
    #[link_name = aws_lc_symbol!("KeccakF1600")]
    fn keccak_f1600_int(a: *mut [[u32; 2]; 25]);

    #[link_name = aws_lc_symbol!("KeccakF1600_neon")]
    fn keccak_f1600_neon_regs();

    #[link_name = aws_lc_symbol!("keccak_f1600_neon")]
    fn keccak_f1600_neon(a: *mut [u64; 25]);
}

// As in `sha_armv4`: ARM mode with NEON, then the target's `.fpu` again.
// OpenSSL's NEON permutation takes the state in d0-d24, so rind's entry loads
// and stores it as OpenSSL's `SHA3_absorb_neon` does around it, using the
// state as the permutation's scratch.
core::arch::global_asm!(
    ".text",
    ".fpu neon",
    ".code 32",
    ".globl {KeccakF1600}",
    ".globl {KeccakF1600_neon}",
    include_str!("openssl/keccak1600-armv4.s"),
    ".globl {keccak_f1600_neon}",
    ".type {keccak_f1600_neon}, %function",
    ".align 5",
    "{keccak_f1600_neon}:",
    "stmdb sp!, {{r4, lr}}",
    "vstmdb sp!, {{d8-d15}}",
    "mov r4, r0",
    "vld1.32 {{d0}}, [r0,:64]!",
    "vld1.32 {{d2}}, [r0,:64]!",
    "vld1.32 {{d4}}, [r0,:64]!",
    "vld1.32 {{d6}}, [r0,:64]!",
    "vld1.32 {{d8}}, [r0,:64]!",
    "vld1.32 {{d1}}, [r0,:64]!",
    "vld1.32 {{d3}}, [r0,:64]!",
    "vld1.32 {{d5}}, [r0,:64]!",
    "vld1.32 {{d7}}, [r0,:64]!",
    "vld1.32 {{d9}}, [r0,:64]!",
    "vld1.32 {{d10}}, [r0,:64]!",
    "vld1.32 {{d12}}, [r0,:64]!",
    "vld1.32 {{d14}}, [r0,:64]!",
    "vld1.32 {{d16}}, [r0,:64]!",
    "vld1.32 {{d18}}, [r0,:64]!",
    "vld1.32 {{d11}}, [r0,:64]!",
    "vld1.32 {{d13}}, [r0,:64]!",
    "vld1.32 {{d15}}, [r0,:64]!",
    "vld1.32 {{d17}}, [r0,:64]!",
    "vld1.32 {{d19}}, [r0,:64]!",
    "vld1.32 {{d20-d23}}, [r0,:64]!",
    "vld1.32 {{d24}}, [r0,:64]",
    "mov r0, r4",
    "bl {KeccakF1600_neon}",
    "mov r0, r4",
    "vst1.32 {{d0}}, [r0,:64]!",
    "vst1.32 {{d2}}, [r0,:64]!",
    "vst1.32 {{d4}}, [r0,:64]!",
    "vst1.32 {{d6}}, [r0,:64]!",
    "vst1.32 {{d8}}, [r0,:64]!",
    "vst1.32 {{d1}}, [r0,:64]!",
    "vst1.32 {{d3}}, [r0,:64]!",
    "vst1.32 {{d5}}, [r0,:64]!",
    "vst1.32 {{d7}}, [r0,:64]!",
    "vst1.32 {{d9}}, [r0,:64]!",
    "vst1.32 {{d10}}, [r0,:64]!",
    "vst1.32 {{d12}}, [r0,:64]!",
    "vst1.32 {{d14}}, [r0,:64]!",
    "vst1.32 {{d16}}, [r0,:64]!",
    "vst1.32 {{d18}}, [r0,:64]!",
    "vst1.32 {{d11}}, [r0,:64]!",
    "vst1.32 {{d13}}, [r0,:64]!",
    "vst1.32 {{d15}}, [r0,:64]!",
    "vst1.32 {{d17}}, [r0,:64]!",
    "vst1.32 {{d19}}, [r0,:64]!",
    "vst1.32 {{d20-d23}}, [r0,:64]!",
    "vst1.32 {{d24}}, [r0,:64]",
    "vldmia sp!, {{d8-d15}}",
    "ldmia sp!, {{r4, pc}}",
    ".size {keccak_f1600_neon}, .-{keccak_f1600_neon}",
    ".fpu vfpv3",
    KeccakF1600 = sym keccak_f1600_int,
    KeccakF1600_neon = sym keccak_f1600_neon_regs,
    keccak_f1600_neon = sym keccak_f1600_neon,
);

/// Keccak-f[1600] on one state.
///
/// `_rc` is Keccak-f's round constants, which the assembly carries itself.
pub(crate) fn sha3_keccak_f1600(a: &mut [u64; 25], _rc: &[u64; 24]) {
    match HaveNeon::check() {
        Some(neon) => permute_neon(neon, a),
        None => permute_int(a),
    }
}

/// Keccak-f[1600] on all four states in `a`, one at a time.
pub(crate) fn sha3_keccak4_f1600(a: &mut [[u64; 25]; 4], rc: &[u64; 24]) {
    sha3_keccak_nof4_f1600::<4>(a, rc)
}

/// Keccak-f[1600] on the first `N` states in `a`, one at a time.
pub(crate) fn sha3_keccak_nof4_f1600<const N: usize>(a: &mut [[u64; 25]; 4], _rc: &[u64; 24]) {
    match HaveNeon::check() {
        Some(neon) => a[..N].iter_mut().for_each(|a| permute_neon(neon, a)),
        None => a[..N].iter_mut().for_each(permute_int),
    }
}

fn permute_neon(_: HaveNeon, a: &mut [u64; 25]) {
    // SAFETY: `a` is 25 writable, 8-byte aligned lanes, and the token proves
    // the CPU has NEON.
    unsafe { asm_call!(unsafe extern "C" keccak_f1600_neon(a)) }
}

/// The integer routine keeps each lane as its even bits then its odd bits,
/// whose rotations are 32-bit ones.
fn permute_int(a: &mut [u64; 25]) {
    let mut s = a.map(interleave);
    // SAFETY: `s` is 25 writable interleaved lanes.
    unsafe { asm_call!(unsafe extern "C" keccak_f1600_int(&mut s)) };
    *a = s.map(deinterleave);
}

/// Gathers the even bits of `x` into its low half.
fn evens(x: u32) -> u32 {
    let mut x = x & 0x5555_5555;
    x = (x | (x >> 1)) & 0x3333_3333;
    x = (x | (x >> 2)) & 0x0f0f_0f0f;
    x = (x | (x >> 4)) & 0x00ff_00ff;
    (x | (x >> 8)) & 0x0000_ffff
}

/// Spreads the low half of `x` to its even bits.
fn spread(x: u32) -> u32 {
    let mut x = x & 0x0000_ffff;
    x = (x | (x << 8)) & 0x00ff_00ff;
    x = (x | (x << 4)) & 0x0f0f_0f0f;
    x = (x | (x << 2)) & 0x3333_3333;
    (x | (x << 1)) & 0x5555_5555
}

fn interleave(lane: u64) -> [u32; 2] {
    let (lo, hi) = (lane as u32, (lane >> 32) as u32);
    [
        evens(lo) | (evens(hi) << 16),
        evens(lo >> 1) | (evens(hi >> 1) << 16),
    ]
}

fn deinterleave([even, odd]: [u32; 2]) -> u64 {
    let lo = spread(even) | (spread(odd) << 1);
    let hi = spread(even >> 16) | (spread(odd >> 16) << 1);
    lo as u64 | ((hi as u64) << 32)
}

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
mod tests {
    use super::*;

    // Every other test sees only the path the CPU picks, so the two routines
    // are checked against each other here.
    #[test]
    fn neon_matches_int() {
        let Some(neon) = HaveNeon::check() else {
            return;
        };
        let mut want: [u64; 25] =
            core::array::from_fn(|i| (i as u64 + 1).wrapping_mul(0x9e37_79b9_7f4a_7c15));
        let mut got = want;
        for _ in 0..3 {
            permute_int(&mut want);
            permute_neon(neon, &mut got);
            assert_eq!(got, want);
        }
    }

    #[test]
    fn interleave_round_trips() {
        for lane in [0, u64::MAX, 1, 1 << 63, 0x0123_4567_89ab_cdef] {
            assert_eq!(deinterleave(interleave(lane)), lane);
        }
        assert_eq!(interleave(0b10), [0, 1]);
        assert_eq!(interleave(1 << 32), [1 << 16, 0]);
    }
}
