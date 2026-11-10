// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! Inputs for testing modular arithmetic: values built from the limbs a
//! dropped carry shows on, and aws-lc's modular vectors.
//!
//! A random word is all ones or zero, where a carry between limbs goes wrong,
//! only once in 2^64 tries, so the values here are built limb by limb from
//! those, as Go's `weirdLimbs` builds its field elements. A routine working
//! in limbs narrower than a word, as RSAZ's do, needs them in its own radix.

#[cfg(not(rind_backend = "portable"))]
use proptest::prelude::*;

use super::file_test;
use crate::low;

/// A `bits`-bit limb: random, or one of zero, one, all ones, the top bit
/// alone, or all but the top bit.
#[cfg(not(rind_backend = "portable"))]
pub(crate) fn limb(bits: u32) -> impl Strategy<Value = u64> {
    let ones = u64::MAX >> (64 - bits);
    let top = 1 << (bits - 1);
    prop_oneof![
        4 => 0..=ones,
        1 => Just(0),
        1 => Just(1),
        1 => Just(ones),
        1 => Just(top),
        1 => Just(top - 1),
    ]
}

/// `min` to `max` words of [`limb`]s.
#[cfg(any(rind_backend = "x86_64", rind_backend = "aarch64"))]
pub(crate) fn words(min: usize, max: usize) -> impl Strategy<Value = Vec<u64>> {
    prop::collection::vec(limb(64), min..=max)
}

/// `k` words of `bits`-bit [`limb`]s, the least significant first, cutting
/// the top one to fit.
#[cfg(not(rind_backend = "portable"))]
pub(crate) fn radix_words(bits: u32, k: usize) -> impl Strategy<Value = Vec<u64>> {
    let limbs = (64 * k).div_ceil(bits as usize);
    prop::collection::vec(limb(bits), limbs).prop_map(move |limbs| {
        let mut words = vec![0; k];
        for (i, limb) in limbs.iter().enumerate() {
            let at = i * bits as usize;
            words[at / 64] |= limb << (at % 64);
            if at % 64 + bits as usize > 64 && at / 64 + 1 < k {
                words[at / 64 + 1] |= limb >> (64 - at % 64);
            }
        }
        words
    })
}

/// An odd modulus of `k` words of `bits`-bit limbs, with a nonzero top
/// word, above one.
#[cfg(not(rind_backend = "portable"))]
pub(crate) fn modulus(bits: u32, k: usize) -> impl Strategy<Value = Vec<u64>> {
    radix_words(bits, k).prop_map(|mut m| {
        m[0] |= 1;
        let top = m.last_mut().unwrap();
        *top = (*top).max(1);
        if m == [1] {
            m[0] = u64::MAX;
        }
        m
    })
}

/// A value below `m`, as wide, of `bits`-bit limbs below its top nonzero
/// word: such a value, or `m - 1` less one, which takes the edge limbs to
/// `m`'s top.
#[cfg(not(rind_backend = "portable"))]
pub(crate) fn below(bits: u32, m: Vec<u64>) -> impl Strategy<Value = Vec<u64>> {
    (radix_words(bits, m.len()), any::<bool>()).prop_map(move |(mut x, from_top)| {
        let top = m.iter().rposition(|w| *w != 0).unwrap();
        x[top + 1..].fill(0);
        x[top] %= m[top];
        if from_top {
            // m - 1 - x, which is below m as x is.
            let mut borrow = 1;
            for (x, m) in x.iter_mut().zip(&m) {
                let (d, b1) = m.overflowing_sub(*x);
                let (d, b2) = d.overflowing_sub(borrow);
                (*x, borrow) = (d, u64::from(b1 | b2));
            }
        }
        x
    })
}

/// One of aws-lc's modular vectors with an odd modulus `m`, each operand
/// reduced below it and as wide as it.
pub(crate) struct ModVector {
    /// The vector's file and line.
    pub(crate) at: String,
    pub(crate) m: Vec<u64>,
    pub(crate) a: Vec<u64>,
    /// `B` for a product, and `A` again for a square.
    pub(crate) b: Vec<u64>,
    /// The exponent, in as few words as hold it.
    pub(crate) e: Vec<u64>,
    /// `a * b mod m`, or `a^e mod m`.
    pub(crate) want: Vec<u64>,
}

/// aws-lc's `ModMul` and `ModSquare` vectors with an odd modulus.
pub(crate) fn mod_mul_vectors() -> Vec<ModVector> {
    vectors("aws-lc/crypto/fipsmodule/bn/test/mod_mul_tests.txt")
}

/// aws-lc's `ModExp` vectors with an odd modulus, the dual exponentiation's
/// pair among them.
pub(crate) fn mod_exp_vectors() -> Vec<ModVector> {
    let mut vectors = vectors("aws-lc/crypto/fipsmodule/bn/test/mod_exp_tests.txt");
    vectors.extend(self::vectors(
        "aws-lc/crypto/fipsmodule/bn/test/mod_exp_x2_tests.txt",
    ));
    vectors
}

fn vectors(path: &str) -> Vec<ModVector> {
    let mut out = Vec::new();
    for test in file_test::tests(path) {
        // The dual exponentiation's file holds both of its pair in one test.
        let halves: &[&str] = match test.get("ModExp1") {
            Some(_) => &["1", "2"],
            None => &[""],
        };
        for n in halves {
            let value = |name: &str| int(test.get(&format!("{name}{n}")));
            let (m, _) = value("M").unwrap();
            if m[0] & 1 == 0 {
                continue;
            }
            let reduced = |name: &str| value(name).map(|(x, negative)| reduce(&x, negative, &m));
            let (want, a, b, e) = match ["ModMul", "ModSquare", "ModExp"]
                .into_iter()
                .find(|kind| test.get(&format!("{kind}{n}")).is_some())
            {
                Some("ModMul") => (value("ModMul"), reduced("A"), reduced("B"), None),
                Some("ModSquare") => {
                    let a = reduced("A");
                    (value("ModSquare"), a.clone(), a, None)
                }
                _ => (value("ModExp"), reduced("A"), None, value("E")),
            };
            let (mut want, _) = want.unwrap();
            want.resize(m.len(), 0);
            let mut e = e.map_or(vec![], |(e, _)| e);
            while e.last() == Some(&0) {
                e.pop();
            }
            out.push(ModVector {
                at: test.to_string(),
                a: a.unwrap(),
                b: b.unwrap_or_default(),
                e,
                want,
                m,
            });
        }
    }
    assert!(!out.is_empty(), "{path} has no odd moduli");
    out
}

/// A hex value as words and whether it is negative, trimming the modulus's
/// leading zero words so its width is its value's.
fn int(hex: Option<&str>) -> Option<(Vec<u64>, bool)> {
    let hex = hex?;
    let (negative, hex) = match hex.strip_prefix('-') {
        Some(hex) => (true, hex),
        None => (false, hex),
    };
    let mut words: Vec<u64> = hex
        .as_bytes()
        .rchunks(16)
        .map(|chunk| u64::from_str_radix(core::str::from_utf8(chunk).unwrap(), 16).unwrap())
        .collect();
    while words.len() > 1 && words.last() == Some(&0) {
        words.pop();
    }
    Some((words, negative))
}

/// `x mod m`, or `-x mod m`, as wide as `m`.
fn reduce(x: &[u64], negative: bool, m: &[u64]) -> Vec<u64> {
    // x / R^j, for R = 2^(64k), times R j times, where x fits in j * k words.
    let k = m.len();
    let j = x.len().div_ceil(k);
    let mut wide = x.to_vec();
    wide.resize(j * k, 0);
    let mut y = vec![0; k];
    low::bignum_montredc(&mut y, &wide, m, (j * k) as u64);
    for _ in 0..j {
        y = mul_r(&y, m);
    }
    if negative {
        let mut neg = vec![0; k];
        low::bignum_modsub(&mut neg, &vec![0; k], &y, m);
        y = neg;
    }
    y
}

/// `x * 2^(64k) mod m`, for `x` below `m` and `k` words each.
pub(crate) fn mul_r(x: &[u64], m: &[u64]) -> Vec<u64> {
    let k = m.len();
    let mut rr = vec![0; k];
    low::bignum_montifier(&mut rr, m, &mut vec![0; k]);
    let mut product = vec![0; 2 * k];
    low::bignum_mul(&mut product, x, &rr);
    let mut z = vec![0; k];
    low::bignum_montredc(&mut z, &product, m, k as u64);
    z
}

/// `x / 2^(64k) mod m`, for `x` below `m` and `k` words each.
pub(crate) fn div_r(x: &[u64], m: &[u64]) -> Vec<u64> {
    let mut z = vec![0; m.len()];
    low::bignum_montredc(&mut z, x, m, m.len() as u64);
    z
}
