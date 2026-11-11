// Copyright (c) The mldsa-native project authors
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT

//! ML-DSA's polynomial arithmetic in natural coefficient order, for armv7 and
//! x86_64 CPUs without AVX2: a Rust port of mldsa-native v2.0.0's portable C
//! (`poly.c`, `poly_kl.c`, `reduce.h`, and `rounding.h`), whose contracts
//! s2n-bignum's routines share. mldsa-native's CBMC proofs of its C do not
//! cover this port; rind's tests check it against s2n-bignum's AVX2 and Neon
//! routines.
//!
//! Coefficient arithmetic wraps: the bounds rule out overflow, and a debug
//! build's overflow check would branch on secret values.

use crate::low;

/// A polynomial's coefficients, aligned for the vector routines.
#[derive(Clone, Copy, Debug)]
#[repr(C, align(32))]
pub(crate) struct MldsaPoly(pub(crate) [i32; 256]);

impl MldsaPoly {
    pub(crate) const ZERO: Self = Self([0; 256]);
}

impl low::Zeroable for MldsaPoly {}

/// `polys` as the contiguous coefficient arrays s2n-bignum's routines read.
#[cfg(any(rind_backend = "x86_64", rind_backend = "aarch64"))]
pub(crate) fn rows<const L: usize>(polys: &[MldsaPoly]) -> &[[i32; 256]; L] {
    let polys: &[MldsaPoly; L] = polys.try_into().unwrap();
    // SAFETY: `MldsaPoly` is `repr(C)` over `[i32; 256]`, whose 1024 bytes
    // leave no padding at its 32-byte alignment, so `L` of them are laid
    // out as `[[i32; 256]; L]`.
    unsafe { &*(polys as *const [MldsaPoly; L]).cast::<[[i32; 256]; L]>() }
}

pub(crate) const Q: i32 = 8380417;
const GAMMA2_88: i32 = (Q - 1) / 88;
const GAMMA2_32: i32 = (Q - 1) / 32;

/// mldsa-native's `mld_zetas`: powers of 1753, bit-reversed, in Montgomery
/// form.
const ZETAS: [i32; 256] = [
    0, 25847, -2608894, -518909, 237124, -777960, -876248, 466468, 1826347, 2353451, -359251,
    -2091905, 3119733, -2884855, 3111497, 2680103, 2725464, 1024112, -1079900, 3585928, -549488,
    -1119584, 2619752, -2108549, -2118186, -3859737, -1399561, -3277672, 1757237, -19422, 4010497,
    280005, 2706023, 95776, 3077325, 3530437, -1661693, -3592148, -2537516, 3915439, -3861115,
    -3043716, 3574422, -2867647, 3539968, -300467, 2348700, -539299, -1699267, -1643818, 3505694,
    -3821735, 3507263, -2140649, -1600420, 3699596, 811944, 531354, 954230, 3881043, 3900724,
    -2556880, 2071892, -2797779, -3930395, -1528703, -3677745, -3041255, -1452451, 3475950,
    2176455, -1585221, -1257611, 1939314, -4083598, -1000202, -3190144, -3157330, -3632928, 126922,
    3412210, -983419, 2147896, 2715295, -2967645, -3693493, -411027, -2477047, -671102, -1228525,
    -22981, -1308169, -381987, 1349076, 1852771, -1430430, -3343383, 264944, 508951, 3097992,
    44288, -1100098, 904516, 3958618, -3724342, -8578, 1653064, -3249728, 2389356, -210977, 759969,
    -1316856, 189548, -3553272, 3159746, -1851402, -2409325, -177440, 1315589, 1341330, 1285669,
    -1584928, -812732, -1439742, -3019102, -3881060, -3628969, 3839961, 2091667, 3407706, 2316500,
    3817976, -3342478, 2244091, -2446433, -3562462, 266997, 2434439, -1235728, 3513181, -3520352,
    -3759364, -1197226, -3193378, 900702, 1859098, 909542, 819034, 495491, -1613174, -43260,
    -522500, -655327, -3122442, 2031748, 3207046, -3556995, -525098, -768622, -3595838, 342297,
    286988, -2437823, 4108315, 3437287, -3342277, 1735879, 203044, 2842341, 2691481, -2590150,
    1265009, 4055324, 1247620, 2486353, 1595974, -3767016, 1250494, 2635921, -3548272, -2994039,
    1869119, 1903435, -1050970, -1333058, 1237275, -3318210, -1430225, -451100, 1312455, 3306115,
    -1962642, -1279661, 1917081, -2546312, -1374803, 1500165, 777191, 2235880, 3406031, -542412,
    -2831860, -1671176, -1846953, -2584293, -3724270, 594136, -3776993, -2013608, 2432395, 2454455,
    -164721, 1957272, 3369112, 185531, -1207385, -3183426, 162844, 1616392, 3014001, 810149,
    1652634, -3694233, -1799107, -3038916, 3523897, 3866901, 269760, 2213111, -975884, 1717735,
    472078, -426683, 1723600, -1803090, 1910376, -1667432, -1104333, -260646, -3833893, -2939036,
    -2235985, -420899, -2286327, 183443, -976891, 1612842, -3545687, -554416, 3919660, -48306,
    -1362209, 3937738, 1400424, -846154, 1976782,
];

/// `a * 2^-32 mod q`, with `|result| < q` for `|a| < 2^31 * q`.
#[inline(always)]
fn montgomery_reduce(a: i64) -> i32 {
    const QINV: u32 = 58728449; // q^-1 mod 2^32
    let t = (a as u32).wrapping_mul(QINV) as i32;
    (a.wrapping_sub((t as i64).wrapping_mul(Q as i64)) >> 32) as i32
}

/// `a * b * 2^-32 mod q`.
#[inline(always)]
fn fqmul(a: i32, b: i32) -> i32 {
    montgomery_reduce((a as i64).wrapping_mul(b as i64))
}

/// All ones when `a` is negative, else zero.
#[inline(always)]
fn negative_mask(a: i32) -> i32 {
    a >> 31
}

/// Forward NTT: coefficients bounded by `q` map to ones bounded by `9q`, in
/// bit-reversed order.
pub(crate) fn mldsa_ntt(a: &mut [i32; 256]) {
    for layer in 1..9 {
        let len = 256 >> layer;
        let first = 1 << (layer - 1);
        for (k, start) in (first..).zip((0..256).step_by(2 * len)) {
            let zeta = ZETAS[k];
            for j in start..start + len {
                let t = fqmul(a[j + len], zeta);
                a[j + len] = a[j].wrapping_sub(t);
                a[j] = a[j].wrapping_add(t);
            }
        }
    }
}

/// Inverse NTT, multiplying by the Montgomery factor `2^32`: coefficients
/// bounded by `q` map to ones bounded by `q`.
pub(crate) fn mldsa_intt(a: &mut [i32; 256]) {
    // mont^2 / 256
    const F: i32 = 41978;
    for layer in (1..9).rev() {
        let len = 256 >> layer;
        let mut k = (1 << layer) - 1;
        for start in (0..256).step_by(2 * len) {
            let zeta = ZETAS[k].wrapping_neg();
            k -= 1;
            for j in start..start + len {
                let t = a[j];
                a[j] = t.wrapping_add(a[j + len]);
                a[j + len] = fqmul(t.wrapping_sub(a[j + len]), zeta);
            }
        }
    }
    for c in a.iter_mut() {
        *c = fqmul(*c, F);
    }
}

/// Permutes NTT-domain coefficients into the order the forward transform
/// produces. Natural order needs nothing.
pub(crate) fn mldsa_nttunpack(_a: &mut [i32; 256]) {}

/// `c = a * b * 2^-32` coefficient-wise, for `|a|, |b| < 9q`, giving `|c| < q`.
pub(crate) fn mldsa_pointwise(c: &mut [i32; 256], a: &[i32; 256], b: &[i32; 256]) {
    for ((c, a), b) in c.iter_mut().zip(a.iter()).zip(b.iter()) {
        *c = fqmul(*a, *b);
    }
}

/// `c = sum(a[i] * b[i]) * 2^-32` coefficient-wise, for `|a| < q` and
/// `|b| < 9q`, giving `|c| < q`.
pub(crate) fn mldsa_pointwise_acc(c: &mut [i32; 256], a: &[MldsaPoly], b: &[MldsaPoly]) {
    assert_eq!(a.len(), b.len());
    for (j, c) in c.iter_mut().enumerate() {
        let mut t = 0i64;
        for (a, b) in a.iter().zip(b.iter()) {
            t = t.wrapping_add((a.0[j] as i64).wrapping_mul(b.0[j] as i64));
        }
        *c = montgomery_reduce(t);
    }
}

/// Reduces each coefficient to `[-6283009, 6283008]`, for coefficients at most
/// `2^31 - 2^22 - 1`.
pub(crate) fn mldsa_reduce(a: &mut [i32; 256]) {
    for c in a.iter_mut() {
        let t = c.wrapping_add(1 << 22) >> 23;
        *c = c.wrapping_sub(t.wrapping_mul(Q));
    }
}

/// Adds `q` to each negative coefficient, mapping `(-q, q)` to `[0, q)`.
pub(crate) fn mldsa_caddq(a: &mut [i32; 256]) {
    for c in a.iter_mut() {
        *c = c.wrapping_add(negative_mask(*c) & Q);
    }
}

/// 1 if any coefficient's magnitude is at least `bound`, else 0. Its time
/// does not depend on the coefficients.
pub(crate) fn mldsa_chknorm(a: &[i32; 256], bound: u64) -> u64 {
    let bound = bound as i32;
    let mut t = 0;
    for c in a.iter() {
        let m = negative_mask(*c);
        let abs = (*c ^ m).wrapping_sub(m);
        t |= negative_mask(bound.wrapping_sub(1).wrapping_sub(abs));
    }
    (t & 1) as u64
}

/// Splits each coefficient `a` of `a0`, in `[0, q)`, into `a1 * 2 * gamma2 + a0`
/// with `-gamma2 < a0 <= gamma2`, except that `a1 = (q - 1) / (2 * gamma2)`
/// becomes `a1 = 0` with `a0` lowered by `q`.
#[inline(always)]
fn decompose<const GAMMA2: i32>(a1: &mut [i32; 256], a0: &mut [i32; 256]) {
    for (a1, a0) in a1.iter_mut().zip(a0.iter_mut()) {
        let a = *a0;
        let mut r1 = a.wrapping_add(127) >> 7;
        if GAMMA2 == GAMMA2_32 {
            r1 = r1.wrapping_mul(1025).wrapping_add(1 << 21) >> 22;
            r1 &= 15;
        } else {
            r1 = r1.wrapping_mul(11275).wrapping_add(1 << 23) >> 24;
            r1 &= !negative_mask(43i32.wrapping_sub(r1));
        }
        let mut r0 = a.wrapping_sub(r1.wrapping_mul(2 * GAMMA2));
        r0 = r0.wrapping_sub(negative_mask(((Q - 1) / 2).wrapping_sub(r0)) & Q);
        *a1 = r1;
        *a0 = r0;
    }
}

/// [`decompose`] for `gamma2 = (q - 1) / 32`.
pub(crate) fn mldsa_decompose_32(a1: &mut [i32; 256], a0: &mut [i32; 256]) {
    decompose::<GAMMA2_32>(a1, a0);
}

/// [`decompose`] for `gamma2 = (q - 1) / 88`.
pub(crate) fn mldsa_decompose_88(a1: &mut [i32; 256], a0: &mut [i32; 256]) {
    decompose::<GAMMA2_88>(a1, a0);
}

/// Replaces each coefficient of `a`, in `[0, q)`, with its high part
/// corrected by the hint bit in `h`. Verification calls this on public
/// values alone.
#[inline(always)]
fn use_hint<const GAMMA2: i32>(a: &mut [i32; 256], h: &[i32; 256]) {
    let mut a1 = [0; 256];
    decompose::<GAMMA2>(&mut a1, a);
    for ((a, a1), h) in a.iter_mut().zip(a1.iter()).zip(h.iter()) {
        let a0 = *a;
        *a = match (*h != 0, a0 > 0) {
            (false, _) => *a1,
            (true, up) if GAMMA2 == GAMMA2_32 => (a1 + if up { 1 } else { -1 }) & 15,
            (true, true) => {
                if *a1 == 43 {
                    0
                } else {
                    a1 + 1
                }
            }
            (true, false) => {
                if *a1 == 0 {
                    43
                } else {
                    a1 - 1
                }
            }
        };
    }
}

/// [`use_hint`] for `gamma2 = (q - 1) / 32`.
pub(crate) fn mldsa_poly_use_hint_32(a: &mut [i32; 256], h: &[i32; 256]) {
    use_hint::<GAMMA2_32>(a, h);
}

/// [`use_hint`] for `gamma2 = (q - 1) / 88`.
pub(crate) fn mldsa_poly_use_hint_88(a: &mut [i32; 256], h: &[i32; 256]) {
    use_hint::<GAMMA2_88>(a, h);
}

/// Unpacks 18-bit fields `t` into `2^17 - t`.
pub(crate) fn mldsa_polyz_unpack_17(r: &mut [i32; 256], b: &[u8; 576]) {
    const GAMMA1: i32 = 1 << 17;
    for (r, b) in r
        .as_chunks_mut::<4>()
        .0
        .iter_mut()
        .zip(b.as_chunks::<9>().0)
    {
        let b = b.map(|b| b as i32);
        r[0] = (b[0] | (b[1] << 8) | (b[2] << 16)) & 0x3ffff;
        r[1] = ((b[2] >> 2) | (b[3] << 6) | (b[4] << 14)) & 0x3ffff;
        r[2] = ((b[4] >> 4) | (b[5] << 4) | (b[6] << 12)) & 0x3ffff;
        r[3] = ((b[6] >> 6) | (b[7] << 2) | (b[8] << 10)) & 0x3ffff;
        for r in r.iter_mut() {
            *r = GAMMA1.wrapping_sub(*r);
        }
    }
}

/// Unpacks 20-bit fields `t` into `2^19 - t`.
pub(crate) fn mldsa_polyz_unpack_19(r: &mut [i32; 256], b: &[u8; 640]) {
    const GAMMA1: i32 = 1 << 19;
    for (r, b) in r
        .as_chunks_mut::<2>()
        .0
        .iter_mut()
        .zip(b.as_chunks::<5>().0)
    {
        let b = b.map(|b| b as i32);
        r[0] = (b[0] | (b[1] << 8) | (b[2] << 16)) & 0xfffff;
        r[1] = (b[2] >> 4) | (b[3] << 4) | (b[4] << 12);
        for r in r.iter_mut() {
            *r = GAMMA1.wrapping_sub(*r);
        }
    }
}

/// Fills `r[offset..]` with the 23-bit candidates in `buf` that are below
/// `q`, returning how many of `r` are now written. Its time depends on which
/// candidates are rejected, which is public: the bytes expand the public
/// seed `rho`.
pub(crate) fn mldsa_rej_uniform_vartime(r: &mut [i32; 256], offset: usize, buf: &[u8]) -> usize {
    let mut ctr = offset;
    for b in buf.as_chunks::<3>().0 {
        if ctr == r.len() {
            break;
        }
        let t = (b[0] as i32 | ((b[1] as i32) << 8) | ((b[2] as i32) << 16)) & 0x7fffff;
        if t < Q {
            r[ctr] = t;
            ctr += 1;
        }
    }
    ctr
}

/// Fills `r[offset..]` from the nibbles of `buf`, accepting those below
/// `bound` and mapping them by `map`, returning how many of `r` are now
/// written.
///
/// Which nibbles are rejected is public, as FIPS 204 allows: the accepted
/// values are independent of it.
#[inline(always)]
fn rej_eta(
    r: &mut [i32; 256],
    offset: usize,
    buf: &[u8],
    bound: u32,
    map: impl Fn(u32) -> i32,
) -> usize {
    let mut ctr = offset;
    for b in buf {
        for t in [(*b & 0x0f) as u32, (*b >> 4) as u32] {
            if ctr < r.len() && low::ct::into_public(t < bound) {
                r[ctr] = map(t);
                ctr += 1;
            }
        }
        if ctr == r.len() {
            break;
        }
    }
    ctr
}

/// [`rej_eta`] for `eta = 2`.
pub(crate) fn mldsa_rej_uniform_eta2_vartime(
    r: &mut [i32; 256],
    offset: usize,
    buf: &[u8],
) -> usize {
    rej_eta(r, offset, buf, 15, |t| {
        // t mod 5, for t < 15
        let t = t.wrapping_sub((205u32.wrapping_mul(t) >> 10).wrapping_mul(5));
        2i32.wrapping_sub(t as i32)
    })
}

/// [`rej_eta`] for `eta = 4`.
pub(crate) fn mldsa_rej_uniform_eta4_vartime(
    r: &mut [i32; 256],
    offset: usize,
    buf: &[u8],
) -> usize {
    rej_eta(r, offset, buf, 9, |t| 4i32.wrapping_sub(t as i32))
}

#[cfg(test)]
mod tests {
    //! Checks the backend's routines, which are s2n-bignum's where it has
    //! them, against this port.

    use super::*;

    use MldsaPoly as Poly;

    struct Rng(u64);

    impl Rng {
        fn next(&mut self) -> u64 {
            // xorshift64*
            self.0 ^= self.0 >> 12;
            self.0 ^= self.0 << 25;
            self.0 ^= self.0 >> 27;
            self.0.wrapping_mul(0x2545f4914f6cdd1d)
        }

        /// Uniform in `(-bound, bound)`.
        fn signed(&mut self, bound: i32) -> i32 {
            (self.next() % (2 * bound as u64 - 1)) as i32 - (bound - 1)
        }

        fn poly(&mut self, bound: i32) -> Poly {
            Poly(core::array::from_fn(|_| self.signed(bound)))
        }

        fn bytes<const N: usize>(&mut self) -> [u8; N] {
            core::array::from_fn(|_| self.next() as u8)
        }
    }

    fn canonical(a: &[i32; 256]) -> [i32; 256] {
        a.map(|c| c.rem_euclid(Q))
    }

    /// The backend's order for natural-order NTT-domain `a`.
    fn unpacked(a: &Poly) -> Poly {
        let mut a = *a;
        low::mldsa_nttunpack(&mut a.0);
        a
    }

    fn bounded(a: &[i32; 256], bound: i32) -> bool {
        a.iter().all(|c| c.abs() < bound)
    }

    #[test]
    fn backend_matches_port() {
        let mut rng = Rng(0x0123_4567_89ab_cdef);
        for round in 0..64 {
            let x = rng.poly(Q);

            let mut want = x;
            mldsa_ntt(&mut want.0);
            let mut got = x;
            low::mldsa_ntt(&mut got.0);
            assert_eq!(
                canonical(&got.0),
                canonical(&unpacked(&want).0),
                "ntt, round {round}"
            );
            assert!(bounded(&got.0, 9 * Q), "ntt bound, round {round}");

            let mut want = x;
            mldsa_intt(&mut want.0);
            let mut got = unpacked(&x);
            low::mldsa_intt(&mut got.0);
            assert_eq!(canonical(&got.0), canonical(&want.0), "intt, round {round}");
            assert!(bounded(&got.0, Q), "intt bound, round {round}");

            let a = rng.poly(9 * Q);
            let b = rng.poly(9 * Q);
            let mut want = Poly([0; 256]);
            mldsa_pointwise(&mut want.0, &a.0, &b.0);
            let mut got = Poly([0; 256]);
            low::mldsa_pointwise(&mut got.0, &a.0, &b.0);
            assert_eq!(
                canonical(&got.0),
                canonical(&want.0),
                "pointwise, round {round}"
            );
            assert!(bounded(&got.0, Q), "pointwise bound, round {round}");

            fn acc<const L: usize>(rng: &mut Rng, round: usize) {
                let a: [Poly; L] = core::array::from_fn(|_| rng.poly(Q));
                let b: [Poly; L] = core::array::from_fn(|_| rng.poly(9 * Q));
                let mut want = Poly([0; 256]);
                mldsa_pointwise_acc(&mut want.0, &a, &b);
                let mut got = Poly([0; 256]);
                low::mldsa_pointwise_acc(&mut got.0, &a, &b);
                assert_eq!(
                    canonical(&got.0),
                    canonical(&want.0),
                    "acc l{L}, round {round}"
                );
                assert!(bounded(&got.0, Q), "acc l{L} bound, round {round}");
            }
            acc::<4>(&mut rng, round);
            acc::<5>(&mut rng, round);
            acc::<7>(&mut rng, round);

            // Inputs within reduce's bound, and caddq's.
            let r = Poly(core::array::from_fn(|_| (rng.next() as i32) >> 1));
            let mut want = r;
            mldsa_reduce(&mut want.0);
            let mut got = r;
            low::mldsa_reduce(&mut got.0);
            assert_eq!(got.0, want.0, "reduce, round {round}");

            let mut want = x;
            mldsa_caddq(&mut want.0);
            let mut got = x;
            low::mldsa_caddq(&mut got.0);
            assert_eq!(got.0, want.0, "caddq, round {round}");

            let small = rng.poly(1 << 20);
            for bound in [1, 2, 1 << 17, (1 << 19) - 1, 1 << 20, (Q - 1) / 2] {
                assert_eq!(
                    low::mldsa_chknorm(&small.0, bound as u64),
                    mldsa_chknorm(&small.0, bound as u64),
                    "chknorm {bound}, round {round}"
                );
            }

            let canon = Poly(canonical(&x.0));
            let hints = Poly(core::array::from_fn(|_| (rng.next() & 1) as i32));
            type Decompose = fn(&mut [i32; 256], &mut [i32; 256]);
            type UseHint = fn(&mut [i32; 256], &[i32; 256]);
            let ops: [(&str, Decompose, Decompose, UseHint, UseHint); 2] = [
                (
                    "32",
                    low::mldsa_decompose_32,
                    mldsa_decompose_32,
                    low::mldsa_poly_use_hint_32,
                    mldsa_poly_use_hint_32,
                ),
                (
                    "88",
                    low::mldsa_decompose_88,
                    mldsa_decompose_88,
                    low::mldsa_poly_use_hint_88,
                    mldsa_poly_use_hint_88,
                ),
            ];
            for (name, decompose, decompose_port, use_hint, use_hint_port) in ops {
                let (mut want1, mut want0) = (Poly([0; 256]), canon);
                decompose_port(&mut want1.0, &mut want0.0);
                let (mut got1, mut got0) = (Poly([0; 256]), canon);
                decompose(&mut got1.0, &mut got0.0);
                assert_eq!(
                    (got1.0, got0.0),
                    (want1.0, want0.0),
                    "decompose {name}, round {round}"
                );

                let mut want = canon;
                use_hint_port(&mut want.0, &hints.0);
                let mut got = canon;
                use_hint(&mut got.0, &hints.0);
                assert_eq!(got.0, want.0, "use_hint {name}, round {round}");
            }

            let b = rng.bytes::<576>();
            let (mut want, mut got) = (Poly([0; 256]), Poly([0; 256]));
            mldsa_polyz_unpack_17(&mut want.0, &b);
            low::mldsa_polyz_unpack_17(&mut got.0, &b);
            assert_eq!(got.0, want.0, "polyz_unpack_17, round {round}");

            let b = rng.bytes::<640>();
            let (mut want, mut got) = (Poly([0; 256]), Poly([0; 256]));
            mldsa_polyz_unpack_19(&mut want.0, &b);
            low::mldsa_polyz_unpack_19(&mut got.0, &b);
            assert_eq!(got.0, want.0, "polyz_unpack_19, round {round}");

            type Sample = fn(&mut [i32; 256], usize, &[u8]) -> usize;
            let ops: [(&str, Sample, Sample, usize); 4] = [
                (
                    "uniform",
                    low::mldsa_rej_uniform_vartime,
                    mldsa_rej_uniform_vartime,
                    840,
                ),
                (
                    "uniform block",
                    low::mldsa_rej_uniform_vartime,
                    mldsa_rej_uniform_vartime,
                    168,
                ),
                (
                    "eta2",
                    low::mldsa_rej_uniform_eta2_vartime,
                    mldsa_rej_uniform_eta2_vartime,
                    136,
                ),
                (
                    "eta4",
                    low::mldsa_rej_uniform_eta4_vartime,
                    mldsa_rej_uniform_eta4_vartime,
                    272,
                ),
            ];
            let buf = rng.bytes::<840>();
            for (name, sample, sample_port, len) in ops {
                let (mut want, mut got) = (Poly([0; 256]), Poly([0; 256]));
                let n_want = sample_port(&mut want.0, 0, &buf[..len]);
                let n_got = sample(&mut got.0, 0, &buf[..len]);
                // The eta samplers return secret coefficients.
                low::ct::public_slice(&got.0);
                assert_eq!(
                    (n_got, &got.0[..n_got]),
                    (n_want, &want.0[..n_want]),
                    "rej {name}, round {round}"
                );

                // Continuing from an offset, as when the first squeeze falls
                // short.
                let n_want = sample_port(&mut want.0, n_want, &buf[..len]);
                let n_got = sample(&mut got.0, n_got, &buf[..len]);
                low::ct::public_slice(&got.0);
                assert_eq!(
                    (n_got, got.0),
                    (n_want, want.0),
                    "rej {name} continued, round {round}"
                );
            }
        }
    }
}
