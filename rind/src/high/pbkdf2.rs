// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! PBKDF2 (Password-Based Key Derivation Function 2).
//!
//! PBKDF2 is standardized in [RFC 8018](https://datatracker.ietf.org/doc/html/rfc8018#section-5.2).

use core::fmt;
use core::num::NonZeroU32;

use super::digest::Digest;
use super::hash::{Hash, LegacySha1, Sha256, Sha384, Sha512};
use super::hmac;
use crate::Error;
use crate::low::pbkdf2_vg::Pbkdf2;
use crate::low::{Entry, Zeroable, ZeroableRef, ct, ct_equal, zeroise, zeroise_value};

/// A PBKDF2 algorithm, chosen by one of this module's constants.
pub struct Algorithm {
    hmac: &'static hmac::Algorithm,
    // pyca/verified-garbage's routine, where this CPU runs it and it
    // measured faster than rind's loop: see `low::pbkdf2_vg`.
    vg: fn() -> Option<&'static Pbkdf2>,
    // The hash HMAC shortens a key longer than its block with, for VG's
    // routine, which takes HMAC's key; and that block's length.
    hash: fn(&[u8]) -> Digest,
    block_len: usize,
}

impl fmt::Debug for Algorithm {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_tuple("Algorithm").field(self.hmac).finish()
    }
}

/// PBKDF2-HMAC-SHA1, for legacy formats only.
///
/// PBKDF2 does not rely on SHA-1's broken collision resistance, and formats
/// such as WPA2 and older PKCS#12 files still require it.
pub static PBKDF2_HMAC_SHA1: Algorithm = Algorithm {
    hmac: &hmac::HMAC_SHA1,
    vg: Pbkdf2::sha1,
    hash: LegacySha1::hash,
    block_len: 64,
};

/// PBKDF2-HMAC-SHA256.
pub static PBKDF2_HMAC_SHA256: Algorithm = Algorithm {
    hmac: &hmac::HMAC_SHA256,
    vg: Pbkdf2::sha256,
    hash: Sha256::hash,
    block_len: 64,
};

/// PBKDF2-HMAC-SHA384.
pub static PBKDF2_HMAC_SHA384: Algorithm = Algorithm {
    hmac: &hmac::HMAC_SHA384,
    vg: Pbkdf2::sha384,
    hash: Sha384::hash,
    block_len: 128,
};

/// PBKDF2-HMAC-SHA512.
pub static PBKDF2_HMAC_SHA512: Algorithm = Algorithm {
    hmac: &hmac::HMAC_SHA512,
    vg: Pbkdf2::sha512,
    hash: Sha512::hash,
    block_len: 128,
};

/// A secret, such as a password, keyed once for every salt it derives with; wiped on drop.
pub struct Secret(Keyed);

// All-zero is the `Rind` variant with an all-zero `hmac::Key`, which that
// type allows, as `Vg`'s fields do.
#[repr(u8)]
enum Keyed {
    Rind(Rind),
    Vg(Vg),
}

impl Zeroable for Secret {}

// Wipes the keys, the discriminant, and the space a smaller variant leaves
// unused.
impl Drop for Secret {
    fn drop(&mut self) {
        zeroise_value(self);
    }
}

impl fmt::Debug for Secret {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let algorithm = match &self.0 {
            Keyed::Rind(rind) => rind.0.id(),
            Keyed::Vg(vg) => vg.algorithm.get().hmac.id(),
        };
        f.debug_struct("Secret")
            .field("algorithm", &algorithm)
            .finish_non_exhaustive()
    }
}

impl Secret {
    /// Keys `algorithm` with `secret`, which may be any length.
    pub fn new(algorithm: &'static Algorithm, secret: &[u8]) -> Self {
        Self(match (algorithm.vg)() {
            Some(routine) => Keyed::Vg(Vg::new(algorithm, routine, secret)),
            None => Keyed::Rind(Rind(hmac::Key::new(algorithm.hmac, secret))),
        })
    }

    /// Fills `out` with the key derived from `salt` over `iterations` rounds.
    ///
    /// Each hash length of `out` costs another `iterations` rounds, which
    /// slows the defender but not an attacker, who needs only the first, so
    /// expand one hash's length with HKDF for more. The cost is linear in
    /// `iterations`, so cap any taken from untrusted input, such as PBES2 or
    /// PKCS#12 parameters.
    ///
    /// Fails with [`Error::WrongLength`], leaving `out` unchanged, if `out`
    /// is empty or longer than PBKDF2 allows.
    pub fn derive(&self, iterations: NonZeroU32, salt: &[u8], out: &mut [u8]) -> Result<(), Error> {
        match &self.0 {
            Keyed::Rind(rind) => rind.derive(iterations, salt, out),
            Keyed::Vg(vg) => vg.derive(iterations, salt, out),
        }
    }

    /// Checks in constant time that `previously_derived` is what [`Secret::derive`] makes for `salt` and `iterations`.
    ///
    /// The key derived is as long as `previously_derived`. Fails with
    /// [`Error::WrongLength`] if that is shorter than the HMAC output or
    /// longer than PBKDF2 allows, and with [`Error::BadSignature`] if the keys
    /// differ. A truncated stored value is refused because it is easier to
    /// match.
    pub fn verify(
        &self,
        iterations: NonZeroU32,
        salt: &[u8],
        previously_derived: &[u8],
    ) -> Result<(), Error> {
        match &self.0 {
            Keyed::Rind(rind) => rind.verify(iterations, salt, previously_derived),
            Keyed::Vg(vg) => vg.verify(iterations, salt, previously_derived),
        }
    }
}

// rind's loop over its HMAC, keyed once.
struct Rind(hmac::Key);

impl Rind {
    // `Secret::derive`.
    fn derive(&self, iterations: NonZeroU32, salt: &[u8], out: &mut [u8]) -> Result<(), Error> {
        let _entry = Entry::new_secret();
        self.check_len(out.len())?;
        let salted = self.salted(salt);
        let hash_len = self.0.algorithm().tag_len();
        for (index, offset) in (1..=u32::MAX).zip((0..out.len()).step_by(hash_len)) {
            let block = self.block(&salted, iterations, index);
            let len = hash_len.min(out.len() - offset);
            out[offset..offset + len].copy_from_slice(&block.as_ref()[..len]);
        }
        Ok(())
    }

    // `Secret::verify`.
    fn verify(
        &self,
        iterations: NonZeroU32,
        salt: &[u8],
        previously_derived: &[u8],
    ) -> Result<(), Error> {
        let _entry = Entry::new_secret();
        if previously_derived.len() < self.0.algorithm().tag_len() {
            return Err(Error::WrongLength);
        }
        self.check_len(previously_derived.len())?;
        // Block by block, so verifying needs no buffer as long as the key.
        let salted = self.salted(salt);
        let hash_len = self.0.algorithm().tag_len();
        let mut equal = true;
        for (index, offset) in (1..=u32::MAX).zip((0..previously_derived.len()).step_by(hash_len)) {
            let block = self.block(&salted, iterations, index);
            let len = hash_len.min(previously_derived.len() - offset);
            equal &= ct_equal(
                &block.as_ref()[..len],
                &previously_derived[offset..offset + len],
            );
        }
        match ct::into_public(equal) {
            true => Ok(()),
            false => Err(Error::BadSignature),
        }
    }

    // RFC 8018 numbers blocks with a 32-bit counter starting at 1.
    fn check_len(&self, len: usize) -> Result<(), Error> {
        let blocks = len.div_ceil(self.0.algorithm().tag_len());
        if blocks == 0 || blocks > u32::MAX as usize {
            Err(Error::WrongLength)
        } else {
            Ok(())
        }
    }

    // The secret's HMAC with the salt absorbed, which begins every block's
    // first message.
    fn salted(&self, salt: &[u8]) -> hmac::Streaming {
        let mut salted = self.0.start();
        salted.update(salt);
        salted
    }

    // RFC 8018's block `index` of the key, `T_index`, from `salted`.
    //
    // A function each caller loops over, rather than one loop handing each
    // block to a closure, which Aeneas mistranslates when it captures `&mut`.
    #[allow(clippy::needless_range_loop)]
    fn block(&self, salted: &hmac::Streaming, iterations: NonZeroU32, index: u32) -> Digest {
        let mut ctx = salted.clone();
        ctx.update(&index.to_be_bytes());
        let mut u = ctx.finish();
        let mut t = u;
        for _ in 1..iterations.get() {
            u = self.0.tag(u.as_ref());
            // Indexes rather than zipping `iter_mut`, which Aeneas cannot
            // translate; slicing `u` to `t`'s length elides the bounds checks.
            let sum = t.as_mut();
            let next = &u.as_ref()[..sum.len()];
            for i in 0..sum.len() {
                sum[i] ^= next[i];
            }
        }
        t
    }
}

// VG's routine, which keys HMAC itself on every call, with HMAC's key: the
// secret, or its hash where it is longer than a block.
struct Vg {
    algorithm: ZeroableRef<Algorithm>,
    routine: ZeroableRef<Pbkdf2>,
    key: [u8; 128],
    len: usize,
}

impl Vg {
    fn new(algorithm: &'static Algorithm, routine: &'static Pbkdf2, secret: &[u8]) -> Self {
        let _entry = Entry::new_secret();
        let mut key = [0u8; 128];
        let len = if secret.len() > algorithm.block_len {
            let hash = (algorithm.hash)(secret);
            key[..hash.as_ref().len()].copy_from_slice(hash.as_ref());
            hash.as_ref().len()
        } else {
            key[..secret.len()].copy_from_slice(secret);
            secret.len()
        };
        Self {
            algorithm: ZeroableRef::new(algorithm),
            routine: ZeroableRef::new(routine),
            key,
            len,
        }
    }

    // As `Rind::derive`.
    fn derive(&self, iterations: NonZeroU32, salt: &[u8], out: &mut [u8]) -> Result<(), Error> {
        let _entry = Entry::new_secret();
        self.check_len(out.len())?;
        self.routine
            .get()
            .derive(&self.key[..self.len], salt, iterations, out);
        Ok(())
    }

    // As `Rind::verify`, but over the whole derived key, since VG's routine
    // derives no block alone; that key is wiped, as derived from the secret.
    fn verify(
        &self,
        iterations: NonZeroU32,
        salt: &[u8],
        previously_derived: &[u8],
    ) -> Result<(), Error> {
        let _entry = Entry::new_secret();
        if previously_derived.len() < self.algorithm.get().hmac.tag_len() {
            return Err(Error::WrongLength);
        }
        self.check_len(previously_derived.len())?;
        let mut derived = vec![0u8; previously_derived.len()];
        self.routine
            .get()
            .derive(&self.key[..self.len], salt, iterations, &mut derived);
        let equal = ct_equal(&derived, previously_derived);
        zeroise(&mut derived);
        match ct::into_public(equal) {
            true => Ok(()),
            false => Err(Error::BadSignature),
        }
    }

    // As `Rind::check_len`.
    fn check_len(&self, len: usize) -> Result<(), Error> {
        let blocks = len.div_ceil(self.algorithm.get().hmac.tag_len());
        if blocks == 0 || blocks > u32::MAX as usize {
            Err(Error::WrongLength)
        } else {
            Ok(())
        }
    }
}

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
mod tests {
    use super::*;

    const ONE: NonZeroU32 = NonZeroU32::MIN;

    static ALGORITHMS: [&Algorithm; 4] = [
        &PBKDF2_HMAC_SHA1,
        &PBKDF2_HMAC_SHA256,
        &PBKDF2_HMAC_SHA384,
        &PBKDF2_HMAC_SHA512,
    ];

    // `secret` keyed on rind's loop, and on VG's routine where it runs.
    fn secrets(algorithm: &'static Algorithm, secret: &[u8]) -> Vec<Secret> {
        let rind = Secret(Keyed::Rind(Rind(hmac::Key::new(algorithm.hmac, secret))));
        let vg =
            (algorithm.vg)().map(|routine| Secret(Keyed::Vg(Vg::new(algorithm, routine, secret))));
        [Some(rind), vg].into_iter().flatten().collect()
    }

    fn check_len(secret: &Secret, len: usize) -> Result<(), Error> {
        match &secret.0 {
            Keyed::Rind(rind) => rind.check_len(len),
            Keyed::Vg(vg) => vg.check_len(len),
        }
    }

    #[test]
    fn lengths() {
        for algorithm in ALGORITHMS {
            for secret in secrets(algorithm, b"password") {
                assert_eq!(
                    secret.derive(ONE, b"salt", &mut []),
                    Err(Error::WrongLength)
                );

                // Derive takes any non-empty length, but verify refuses a
                // stored key shorter than the HMAC output, even a true prefix.
                let hash_len = algorithm.hmac.tag_len();
                let mut key = vec![0u8; hash_len + 1];
                secret.derive(ONE, b"salt", &mut key).unwrap();
                assert_eq!(secret.verify(ONE, b"salt", &[]), Err(Error::WrongLength));
                assert_eq!(
                    secret.verify(ONE, b"salt", &key[..hash_len - 1]),
                    Err(Error::WrongLength)
                );
                assert_eq!(secret.verify(ONE, b"salt", &key[..hash_len]), Ok(()));
                assert_eq!(secret.verify(ONE, b"salt", &key), Ok(()));

                // RFC 8018's 32-bit block counter bounds the length, which
                // only the check can reach without allocating it. On a 32-bit
                // target no length reaches it.
                match (u32::MAX as usize).checked_mul(hash_len) {
                    Some(most) => {
                        assert_eq!(check_len(&secret, most), Ok(()));
                        assert_eq!(check_len(&secret, most + 1), Err(Error::WrongLength));
                    }
                    None => assert_eq!(check_len(&secret, usize::MAX), Ok(())),
                }
            }
        }
    }

    #[test]
    fn verify_checks_every_byte() {
        // Two whole SHA-256 blocks and a partial third, so a flip in any
        // block, including the partial one, must be caught.
        let iterations = NonZeroU32::new(3).unwrap();
        for secret in secrets(&PBKDF2_HMAC_SHA256, b"password") {
            let mut key = [0u8; 70];
            secret.derive(iterations, b"salt", &mut key).unwrap();
            assert_eq!(secret.verify(iterations, b"salt", &key), Ok(()));

            for i in 0..key.len() {
                let mut wrong = key;
                wrong[i] ^= 1;
                assert_eq!(
                    secret.verify(iterations, b"salt", &wrong),
                    Err(Error::BadSignature)
                );
            }
            let other = NonZeroU32::new(4).unwrap();
            assert_eq!(
                secret.verify(other, b"salt", &key),
                Err(Error::BadSignature)
            );
            assert_eq!(
                secret.verify(iterations, b"pepper", &key),
                Err(Error::BadSignature)
            );
        }
    }

    #[test]
    fn vg_matches_rind() {
        // VG's routine keys HMAC itself, so this crosses every length of
        // secret around HMAC's block, where rind passes it whole or hashed,
        // with salts and outputs around a block and a hash length.
        for algorithm in ALGORITHMS {
            let block = algorithm.block_len;
            let hash_len = algorithm.hmac.tag_len();
            for secret_len in [0, 1, block - 1, block, block + 1, 3 * block] {
                let secret: Vec<u8> = (0..secret_len).map(|i| i as u8).collect();
                let [rind, rest @ ..] = &secrets(algorithm, &secret)[..] else {
                    unreachable!()
                };
                for salt_len in [0, 1, block - 5, block, 2 * block + 3] {
                    let salt = vec![0xa5; salt_len];
                    for out_len in [1, hash_len - 1, hash_len, hash_len + 1, 3 * hash_len + 5] {
                        for iterations in [1, 2, 7] {
                            let iterations = NonZeroU32::new(iterations).unwrap();
                            let mut wanted = vec![0u8; out_len];
                            rind.derive(iterations, &salt, &mut wanted).unwrap();
                            for vg in rest {
                                let mut got = vec![0u8; out_len];
                                vg.derive(iterations, &salt, &mut got).unwrap();
                                assert_eq!(got, wanted);
                                if out_len >= hash_len {
                                    assert_eq!(vg.verify(iterations, &salt, &wanted), Ok(()));
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    #[test]
    fn secret_password() {
        // Under `admin/ctgrind`, nothing may branch on or index by the
        // password or anything derived from it, until the derived key or
        // verify's answer is declassified. Passwords longer than a block are
        // hashed first.
        let iterations = NonZeroU32::new(3).unwrap();
        for algorithm in ALGORITHMS {
            for password_len in [16, 200] {
                let password = vec![0x5a; password_len];
                let mut wanted = [0u8; 100];
                Secret::new(algorithm, &password)
                    .derive(iterations, b"salt", &mut wanted)
                    .unwrap();

                ct::secret_slice(&password);
                for secret in secrets(algorithm, &password) {
                    let mut got = [0u8; 100];
                    secret.derive(iterations, b"salt", &mut got).unwrap();
                    ct::public_slice(&got);
                    assert_eq!(got, wanted);
                    assert_eq!(secret.verify(iterations, b"salt", &wanted), Ok(()));
                }
            }
        }
    }
}
