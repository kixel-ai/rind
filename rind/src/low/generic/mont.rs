// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! The s2n-bignum routines `low::PosInt` uses that multiply, with their
//! contracts, in portable Rust over limbs of the width the parent module
//! picks, and the portable backend's Montgomery multiplication, which armv7
//! runs aws-lc's assembly for.
//!
//! A limb is half a register's width (`Wide`), so its products are one
//! multiply instruction, or two for a 64-bit limb's low and high halves:
//! 32-bit limbs where a 64 by 64-bit product's high half would be a library
//! call, and 64-bit ones where the CPU has that instruction, for a quarter
//! of the products.
//!
//! Each runs in time that depends only on its lengths, and its modulus's
//! width in `bignum_montifier`, never on its values: loops run a count fixed
//! by those, and selects are masks. Arithmetic on values wraps, though the
//! bounds rule out overflow, since a debug build's overflow check would
//! branch on them.
//!
//! The algorithms are the textbook ones, each stated with its bound where
//! it is defined: Montgomery multiplication and reduction (HAC 14.32 and
//! 14.36), by Koç, Acar, and Kaliski's CIOS method.

use super::super::bignum::{MAX_WORDS, nonzero, select, word};
use super::{Limb, Wide};
use crate::low::ct;

/// Limbs in a 64-bit word.
const PER_WORD: usize = (u64::BITS / Limb::BITS) as usize;

/// `MAX_WORDS` in limbs.
const MAX_LIMBS: usize = MAX_WORDS * PER_WORD;

/// Compute "montification" constant z := 2^{128k} mod m
///
/// Input m[k]; output z[k]; temporary buffer t[>=k]
///
/// For an odd m above one, as Montgomery multiplication needs. `_t` is
/// s2n-bignum's scratch space, which this does not need. Its time also
/// depends on, and so reveals, m's width in limbs, as aws-lc's reveals its
/// width in bits: an RSA key's encoding gives its primes' widths.
pub(crate) fn bignum_montifier(z: &mut [u64], m: &[u64], _t: &mut [u64]) {
    let n = m.len() * PER_WORD;
    let m = limbs(m);
    let m = &m[..n];
    let n0 = neg_inverse(m[0]);

    // 2^(bt) for m's top nonzero limb t, with b bits a limb, is below m, as
    // m is odd and above one. Doubling it (b(n - t) + 1) times gives
    // 2^(bn + 1) mod m, which is 2 in Montgomery form. Squaring 2^e there
    // gives 2^2e, and doubling 2^(e + 1), so squaring and doubling by the
    // bits of bn below its top one raise it to 2^bn, whose Montgomery form
    // 2^2bn is the montifier.
    let mut top = 0;
    for (i, limb) in m.iter().enumerate() {
        top = select(nonzero(u64::from(*limb)), i as u64, top);
    }
    let top = ct::into_public(top) as usize;
    let mut r = [0; MAX_LIMBS];
    let r = &mut r[..n];
    r[top] = 1;
    for _ in 0..=Limb::BITS as usize * (n - top) {
        mod_double(r, m);
    }
    let e = Limb::BITS as usize * n;
    let mut square = [0; MAX_LIMBS];
    let square = &mut square[..n];
    for bit in (0..e.ilog2()).rev() {
        mont_mul_limbs(square, r, r, m, n0);
        r.copy_from_slice(square);
        if e >> bit & 1 == 1 {
            mod_double(r, m);
        }
    }
    join(r, z);
}

/// Montgomery reduce, z := (x' / 2^{64p}) MOD m
///
/// Inputs x[n], m[k], p; output z[k]
///
/// Does a := (x' / 2^{64p}) mod m where x' = x if n <= p + k and in general
/// is the lowest (p+k) digits of x, assuming x' <= 2^{64p} * m. That is,
/// p-fold Montgomery reduction w.r.t. a k-digit modulus m giving a k-digit
/// answer.
pub(crate) fn bignum_montredc(z: &mut [u64], x: &[u64], m: &[u64], p: u64) {
    let (k, p) = (m.len() * PER_WORD, p as usize * PER_WORD);
    let m = limbs(m);
    let m = &m[..k];
    let n0 = neg_inverse(m[0]);
    let mut t = [0; MAX_LIMBS * 2];
    let t = &mut t[..p + k];
    for (i, t) in t.iter_mut().enumerate() {
        *t = limb(x, i);
    }

    // Each step clears the lowest limb by adding a multiple of m. The carry
    // out of the top of a step's sum waits in `top` for the next, as it lands
    // where the next step's sum ends.
    let mut top = 0;
    for i in 0..p {
        let u = t[i].wrapping_mul(n0);
        let carry = mul_add(&mut t[i..i + k], m, u);
        let sum = Wide::from(t[i + k]).wrapping_add(carry).wrapping_add(top);
        t[i + k] = sum as Limb;
        top = sum >> Limb::BITS;
    }

    // Below 2m, as x' <= 2^64p * m and the multiples are below 2^64p * m.
    let r = &mut t[p..];
    let below = cmp_lt_limbs(r, m);
    sub_limbs_masked(r, m, Limb::wrapping_sub(0, top as Limb | (below ^ 1)));
    join(r, z);
}

/// Multiply z := x * y
///
/// Inputs x[m], y[n]; output z[k]
///
/// Truncates the result in general unless k >= m + n
pub(crate) fn bignum_mul(z: &mut [u64], x: &[u64], y: &[u64]) {
    let (m, n) = (x.len() * PER_WORD, y.len() * PER_WORD);
    let (x, y) = (limbs(x), limbs(y));
    let mut product = [0; MAX_LIMBS * 2];
    for (i, x) in x[..m].iter().enumerate() {
        product[i + n] = mul_add(&mut product[i..i + n], &y[..n], *x) as Limb;
    }
    z.fill(0);
    join(&product, z);
}

/// `z = x * y / 2^(64k) mod m`, for `x` and `y` below the odd `m`, where `k`
/// is the length of each and `n0` is `-m^-1 mod 2^64`.
///
/// HACL*'s verified `Hacl_Bignum` has this, but its Rust allocates scratch
/// for each call and frees it unwiped, though RSA's private operations put
/// their secrets there.
#[cfg(any(
    rind_backend = "portable",
    all(test, any(rind_backend = "x86_64", rind_backend = "aarch64"))
))]
pub(crate) fn mont_mul(z: &mut [u64], x: &[u64], y: &[u64], m: &[u64], n0: u64) {
    let k = m.len();
    assert!(k >= 1 && z.len() == k && x.len() == k && y.len() == k);
    let n = k * PER_WORD;
    let (x, y, m) = (limbs(x), limbs(y), limbs(m));
    let mut r = [0; MAX_LIMBS];
    // The low limb of `-m^-1 mod 2^64` is `-m^-1` mod a limb.
    mont_mul_limbs(&mut r[..n], &x[..n], &y[..n], &m[..n], n0 as Limb);
    join(&r[..n], z);
}

/// `z = x^2 / 2^(64k) mod m`, as [`mont_mul`] takes them.
#[cfg(rind_backend = "portable")]
pub(crate) fn mont_sqr(z: &mut [u64], x: &[u64], m: &[u64], n0: u64) {
    mont_mul(z, x, x, m, n0);
}

/// `z := x * y / 2^bn mod m`, for `x` and `y` below the odd `m`, each `n`
/// limbs of `b` bits, where `n0` is `-m^-1 mod 2^b`.
///
/// Koç, Acar, and Kaliski's CIOS method: each step adds `x[i] * y`, then
/// clears the lowest limb by adding a multiple of `m` and shifts down a
/// limb, keeping the running sum below 2m.
fn mont_mul_limbs(z: &mut [Limb], x: &[Limb], y: &[Limb], m: &[Limb], n0: Limb) {
    let n = m.len();
    let mut t = [0; MAX_LIMBS + 2];
    let t = &mut t[..n + 2];
    for x in x {
        let sum = Wide::from(t[n]).wrapping_add(mul_add(&mut t[..n], y, *x));
        t[n] = sum as Limb;
        t[n + 1] = (sum >> Limb::BITS) as Limb;

        let u = t[0].wrapping_mul(n0);
        let sum = Wide::from(t[n]).wrapping_add(mul_add(&mut t[..n], m, u));
        t[n] = sum as Limb;
        t[n + 1] = t[n + 1].wrapping_add((sum >> Limb::BITS) as Limb);
        t.copy_within(1.., 0);
        t[n + 1] = 0;
    }
    let below = cmp_lt_limbs(&t[..n], m);
    let keep = Limb::wrapping_sub(0, t[n] | (below ^ 1));
    sub_limbs_masked(&mut t[..n], m, keep);
    z.copy_from_slice(&t[..n]);
}

/// `x += y * u`, returning the carry out of the top limb.
fn mul_add(x: &mut [Limb], y: &[Limb], u: Limb) -> Wide {
    let mut carry = 0;
    for (x, y) in x.iter_mut().zip(y) {
        // At most (2^b - 1)^2 + 2 (2^b - 1) = 2^2b - 1.
        let t = Wide::from(u)
            .wrapping_mul(Wide::from(*y))
            .wrapping_add(Wide::from(*x))
            .wrapping_add(carry);
        *x = t as Limb;
        carry = t >> Limb::BITS;
    }
    carry
}

/// `r := 2r mod m`, for `r` below `m`.
fn mod_double(r: &mut [Limb], m: &[Limb]) {
    let mut out = 0;
    for r in r.iter_mut() {
        let next = *r >> (Limb::BITS - 1);
        *r = *r << 1 | out;
        out = next;
    }
    let below = cmp_lt_limbs(r, m);
    sub_limbs_masked(r, m, Limb::wrapping_sub(0, out | (below ^ 1)));
}

/// `-m^-1` mod a limb, for an odd `m`.
fn neg_inverse(m: Limb) -> Limb {
    // Correct to 5 bits, then Newton's iteration doubles that each time.
    let mut inv = m.wrapping_mul(3) ^ 2;
    for _ in 0..Limb::BITS.ilog2() - 2 {
        inv = inv.wrapping_mul(Limb::wrapping_sub(2, m.wrapping_mul(inv)));
    }
    inv.wrapping_neg()
}

/// `bignum_cmp_lt` for limbs of one length.
fn cmp_lt_limbs(x: &[Limb], y: &[Limb]) -> Limb {
    let mut borrow = 0;
    for (x, y) in x.iter().zip(y) {
        let (diff, b1) = x.overflowing_sub(*y);
        let (_, b2) = diff.overflowing_sub(borrow);
        borrow = Limb::from(b1 | b2);
    }
    borrow
}

/// `x := x - y` where `keep` is all ones.
fn sub_limbs_masked(x: &mut [Limb], y: &[Limb], keep: Limb) {
    let mut borrow = 0;
    for (x, y) in x.iter_mut().zip(y) {
        let (diff, b1) = x.overflowing_sub(y & keep);
        let (diff, b2) = diff.overflowing_sub(borrow);
        *x = diff;
        borrow = Limb::from(b1 | b2);
    }
}

/// Limb `i` of `x`, low first, or zero beyond its length.
fn limb(x: &[u64], i: usize) -> Limb {
    (word(x, i / PER_WORD) >> (Limb::BITS as usize * (i % PER_WORD))) as Limb
}

/// `x`'s limbs, low first.
fn limbs(x: &[u64]) -> [Limb; MAX_LIMBS] {
    let mut out = [0; MAX_LIMBS];
    for (i, out) in out[..x.len() * PER_WORD].iter_mut().enumerate() {
        *out = limb(x, i);
    }
    out
}

/// Joins `x`'s limbs into the words of `z`.
fn join(x: &[Limb], z: &mut [u64]) {
    for (z, limbs) in z.iter_mut().zip(x.as_chunks::<PER_WORD>().0) {
        *z = 0;
        for (i, limb) in limbs.iter().enumerate() {
            *z |= u64::from(*limb) << (Limb::BITS as usize * i);
        }
    }
}

/// Checks each routine against s2n-bignum's, word for word.
///
/// The values are marked secret, so under `admin/ctgrind` these also check
/// each routine is constant time in them.
#[cfg(all(test, any(rind_backend = "x86_64", rind_backend = "aarch64")))]
#[cfg_attr(coverage_nightly, coverage(off))]
mod tests {
    use proptest::prelude::*;

    use super::super::super::bignum::tests::{modulus, public, secret};
    use super::*;
    use crate::low;
    use crate::low::ct::into_secret;
    use crate::test::bignum::words;

    proptest! {
        #[test]
        fn product(x in words(0, 8), y in words(0, 8), extra in 0..3usize) {
            // rind's s2n-bignum wrappers refuse to truncate a product.
            let wide = x.len() + y.len() + extra;
            let (mut ours, mut theirs) = (vec![1; wide], vec![0; wide]);
            bignum_mul(&mut ours, &secret(&x), &secret(&y));
            low::bignum_mul(&mut theirs, &x, &y);
            prop_assert_eq!(public(&ours), theirs);
        }

        #[test]
        fn modular((m, x, y) in modulus(), extra in words(0, 4)) {
            let k = m.len();
            let (sm, sx, sy) = (secret(&m), secret(&x), secret(&y));
            let (mut ours, mut theirs) = (vec![0; k], vec![0; k]);

            bignum_montifier(&mut ours, &sm, &mut []);
            low::bignum_montifier(&mut theirs, &m, &mut vec![0; k]);
            prop_assert_eq!(public(&ours), theirs.clone());

            // x * y + extra * 2^64k * m stays within 2^64(k + p) * m for p
            // above the extra words.
            let p = k + extra.len();
            let mut wide = vec![0; 2 * k + extra.len() + 1];
            low::bignum_mul(&mut wide, &x, &y);
            let mut em = vec![0; k + extra.len()];
            low::bignum_mul(&mut em, &extra, &m);
            let mut sum = vec![0; wide.len()];
            low::bignum_add(&mut sum, &wide, &[vec![0; k], em].concat());
            bignum_montredc(&mut ours, &secret(&sum), &sm, p as u64);
            low::bignum_montredc(&mut theirs, &sum, &m, p as u64);
            prop_assert_eq!(public(&ours), theirs.clone());

            let mut n0 = [0];
            low::bignum_negmodinv(&mut n0, &m[..1]);
            mont_mul(&mut ours, &sx, &sy, &sm, into_secret(n0[0]));
            low::mont_mul(&mut theirs, &x, &y, &m, n0[0]);
            prop_assert_eq!(public(&ours), theirs);
        }
    }

    /// The widest values, which the fixed buffers must hold.
    #[test]
    fn widest() {
        let m = [u64::MAX; MAX_WORDS];
        let x = [u64::MAX - 1; MAX_WORDS];
        let (mut product, mut theirs) = ([0; MAX_WORDS * 2], [0; MAX_WORDS * 2]);
        bignum_mul(&mut product, &x, &x);
        low::bignum_mul(&mut theirs, &x, &x);
        assert_eq!(product, theirs);

        let (mut ours, mut theirs) = ([0; MAX_WORDS], [0; MAX_WORDS]);
        bignum_montredc(&mut ours, &product, &m, MAX_WORDS as u64);
        low::bignum_montredc(&mut theirs, &product, &m, MAX_WORDS as u64);
        assert_eq!(ours, theirs);
        bignum_montifier(&mut ours, &m, &mut []);
        low::bignum_montifier(&mut theirs, &m, &mut [0; MAX_WORDS]);
        assert_eq!(ours, theirs);
        // -m^-1 is one for an m of all ones.
        mont_mul(&mut ours, &x, &x, &m, 1);
        low::mont_mul(&mut theirs, &x, &x, &m, 1);
        assert_eq!(ours, theirs);
    }
}
