// Written for Graviola by Joe Birr-Pixton, 2025.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

use crate::Error;
use crate::error::KeyFormatError;
use crate::high::asn1::{self, Type, pkix};
use crate::high::pkcs8;
use crate::low::{self, Entry, ct};
use crate::mid::ed25519;
use crate::mid::rng::{RandomSource, SystemRandom};

/// An Ed25519 verification public key.
#[derive(Debug)]
pub(crate) struct Ed25519VerifyingKey(ed25519::VerifyingKey);

impl Ed25519VerifyingKey {
    /// Encode in `SubjectPublicKeyInfo` DER format.
    ///
    /// The encoding is written to the start of `output`, and the used slice is
    /// returned.  [`Error::WrongLength`] is returned if `output` is not sufficient
    /// to contain the full encoding.
    pub(crate) fn to_spki_der<'a>(&self, output: &'a mut [u8]) -> Result<&'a [u8], Error> {
        let pub_key_buffer = self.as_bytes();

        let spki = pkix::SubjectPublicKeyInfo {
            algorithm: pkix::AlgorithmIdentifier {
                algorithm: asn1::oid::id_ed25519.clone(),
                parameters: None,
            },
            subjectPublicKey: asn1::BitString::new(&pub_key_buffer[..]),
        };

        let len = spki
            .encode(&mut asn1::Encoder::new(output))
            .map_err(|_| Error::WrongLength)?;
        Ok(&output[..len])
    }

    /// Decode from the 32-byte Ed25519 public key encoding, refusing a point
    /// of small order.
    ///
    /// aws-lc-rs takes one, but with the identity as the key, `R = identity`
    /// and `S = 0` verify any message. No honest key has small order, so
    /// rind refuses them all, as libsodium does.
    pub(crate) fn from_bytes(bytes: &[u8]) -> Result<Self, Error> {
        let _entry = Entry::new_public();
        if has_small_order(bytes) {
            return Err(KeyFormatError::SmallOrder.into());
        }
        ed25519::VerifyingKey::from_bytes(bytes).map(Self)
    }

    /// Encode using compressed point encoding.
    pub(crate) fn as_bytes(&self) -> [u8; 32] {
        self.0.as_bytes()
    }

    /// Verify a `signature` against the given `message`.
    ///
    /// The signature must be precisely 64 bytes.
    ///
    /// Returns `Error::BadSignature` if the signature is invalid.
    pub(crate) fn verify(&self, signature: &[u8], message: &[u8]) -> Result<(), Error> {
        let _entry = Entry::new_public();

        self.0.verify(
            signature.try_into().map_err(|_| Error::BadSignature)?,
            message,
        )
    }
}

/// Whether `bytes` encodes a point of small order, canonically or not.
///
/// These are libsodium's `ge25519_has_small_order` encodings, compared, as
/// there, in constant time and without the sign bit of `x`: the eight points
/// of order dividing 8, then `y = p` and `y = p + 1`, the only `y` of a
/// small-order point whose non-canonical `y + p` fits in 255 bits.
fn has_small_order(bytes: &[u8]) -> bool {
    const SMALL_ORDER_Y: [[u8; 32]; 7] = [
        // `y = 0`, order 4.
        [0; 32],
        // `y = 1`, the identity.
        {
            let mut y = [0; 32];
            y[0] = 1;
            y
        },
        // Order 8.
        [
            0x26, 0xe8, 0x95, 0x8f, 0xc2, 0xb2, 0x27, 0xb0, 0x45, 0xc3, 0xf4, 0x89, 0xf2, 0xef,
            0x98, 0xf0, 0xd5, 0xdf, 0xac, 0x05, 0xd3, 0xc6, 0x33, 0x39, 0xb1, 0x38, 0x02, 0x88,
            0x6d, 0x53, 0xfc, 0x05,
        ],
        // Order 8.
        [
            0xc7, 0x17, 0x6a, 0x70, 0x3d, 0x4d, 0xd8, 0x4f, 0xba, 0x3c, 0x0b, 0x76, 0x0d, 0x10,
            0x67, 0x0f, 0x2a, 0x20, 0x53, 0xfa, 0x2c, 0x39, 0xcc, 0xc6, 0x4e, 0xc7, 0xfd, 0x77,
            0x92, 0xac, 0x03, 0x7a,
        ],
        // `y = p - 1`, order 2, then `y = p` and `y = p + 1`.
        near_p(0xec),
        near_p(0xed),
        near_p(0xee),
    ];

    /// `p = 2^255 - 19`, little-endian, with its lowest byte `low`.
    const fn near_p(low: u8) -> [u8; 32] {
        let mut y = [0xff; 32];
        y[0] = low;
        y[31] = 0x7f;
        y
    }

    let Ok(mut y) = <[u8; 32]>::try_from(bytes) else {
        return false;
    };
    y[31] &= 0x7f;
    SMALL_ORDER_Y
        .iter()
        .fold(false, |found, small| found | low::ct_equal(&y, small))
}

/// An Ed25519 signing private key.
pub(crate) struct Ed25519SigningKey(ed25519::SigningKey);

impl Ed25519SigningKey {
    /// Generate a new signing key.
    pub(crate) fn generate() -> Result<Self, Error> {
        let _entry = Entry::new_secret();
        let mut seed = [0u8; 32];
        SystemRandom.fill(&mut seed)?;
        Ok(Self(ed25519::SigningKey::from_seed(&seed)))
    }

    /// Sign `message`.
    pub(crate) fn sign(&self, message: &[u8]) -> [u8; 64] {
        let _entry = Entry::new_secret();
        self.0.sign(message)
    }

    /// Return the corresponding public key.
    pub(crate) fn public_key(&self) -> Ed25519VerifyingKey {
        let _entry = Entry::new_public();
        Ed25519VerifyingKey(self.0.verifying_key().clone())
    }

    /// Load an Ed25519 private key in PKCS#8 format.
    ///
    /// This supports PKCS#8 v1 (RFC 5208) and v2 (RFC 5958, which may include the public key).
    /// If the encoding includes the alleged public key, this is checked against the actual one.
    pub(crate) fn from_pkcs8_der(bytes: &[u8]) -> Result<Self, Error> {
        let _entry = Entry::new_secret();

        let p8 = pkcs8::Key::decode(bytes, &asn1::oid::id_ed25519, None)?;

        let key = asn1::OctetString::from_bytes(p8.private_key())
            .map_err(|e| Error::from(KeyFormatError::Asn1(e)))
            .and_then(|pk| Self::from_bytes(pk.as_octets()))?;

        if let Some(alleged_pub_key) = p8.public_key() {
            let actual_pub_key = key.public_key().as_bytes();
            if alleged_pub_key != actual_pub_key {
                return Err(KeyFormatError::MismatchedPkcs8PublicKey.into());
            }
        }

        Ok(key)
    }

    /// Encode this private key in PKCS#8 DER format.
    ///
    /// This produces an RFC5958 PKCS#8 "v2" format.
    ///
    /// The encoding is written to the start of `output`, and the used slice is
    /// returned.  [`Error::WrongLength`] is returned if `output` is not sufficient
    /// to contain the full encoding.
    pub(crate) fn to_pkcs8_der<'a>(&self, output: &'a mut [u8]) -> Result<&'a [u8], Error> {
        let _entry = Entry::new_secret();

        let mut private_key_buf = [0u8; 34];
        let private_key_len = asn1::OctetString::new(self.0.as_seed_bytes())
            .encode(&mut asn1::Encoder::new(&mut private_key_buf))
            .map_err(|_| Error::WrongLength)?;
        assert_eq!(private_key_len, private_key_buf.len());

        let public_key = self.public_key().as_bytes();

        match pkcs8::Key::construct(
            &private_key_buf[..],
            Some(&public_key[..]),
            asn1::oid::id_ed25519.clone(),
            None,
        )
        .encode(output)
        {
            Ok(bytes) => {
                ct::public_slice(bytes);
                Ok(bytes)
            }
            Err(e) => Err(e),
        }
    }

    /// Load an Ed25519 private key from a 32-byte seed.
    pub(crate) fn from_bytes(seed: &[u8]) -> Result<Self, Error> {
        let _entry = Entry::new_secret();
        seed.try_into()
            .map(|seed| Self(ed25519::SigningKey::from_seed(&seed)))
            .map_err(|_| KeyFormatError::WrongLength.into())
    }

    /// Return the 32-byte seed, still secret, which [`Self::from_bytes`] loads.
    pub(crate) fn seed(&self) -> &[u8; 32] {
        self.0.as_seed_bytes()
    }
}

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
mod tests {
    use super::*;

    #[test]
    fn pairwise() {
        for _ in 0..100 {
            let k = Ed25519SigningKey::generate().unwrap();
            let pk = k.public_key();
            let mut msg = [0u8; 128];
            SystemRandom.fill(&mut msg).unwrap();
            let sig = k.sign(&msg);

            pk.verify(&sig, &msg).unwrap();
        }
    }

    #[test]
    fn decode_pkcs8_v1() {
        let bytes = include_bytes!("asn1/testdata/ed25519-p8v1.bin");
        let key = Ed25519SigningKey::from_pkcs8_der(bytes).unwrap();

        let mut buf = vec![0; 128];
        let buf = key.to_pkcs8_der(&mut buf).unwrap();
        assert_ne!(bytes, buf);
        assert!(bytes.len() < buf.len());
    }

    #[test]
    fn round_trip_pkcs8_v2() {
        let bytes = include_bytes!("asn1/testdata/ed25519-p8v2.bin");
        let key = Ed25519SigningKey::from_pkcs8_der(bytes).unwrap();

        let mut buf = vec![0; bytes.len()];
        assert_eq!(
            key.to_pkcs8_der(&mut buf[..bytes.len() - 1]),
            Err(Error::WrongLength)
        );
        let buf = key.to_pkcs8_der(&mut buf).unwrap();
        assert_eq!(bytes, buf);
    }

    #[test]
    fn spki_encode_length() {
        let pk = Ed25519SigningKey::generate().unwrap().public_key();
        assert_eq!(
            pk.to_spki_der(&mut [0u8; 32]).unwrap_err(),
            Error::WrongLength
        );
    }

    #[test]
    fn pkcs8_public_key_wrong() {
        let mut bytes = include_bytes!("asn1/testdata/ed25519-p8v2.bin").to_vec();
        bytes[52] ^= 0x01;
        assert_eq!(
            Ed25519SigningKey::from_pkcs8_der(&bytes).err(),
            Some(KeyFormatError::MismatchedPkcs8PublicKey.into())
        );
    }

    #[test]
    fn verifying_key_from_bytes() {
        const GOOD: &[u8] = &[
            0x53, 0x0e, 0x81, 0x33, 0x75, 0x16, 0x14, 0xbe, 0x84, 0x26, 0x71, 0x59, 0x50, 0xc2,
            0x49, 0x71, 0x67, 0x0c, 0xb5, 0xd9, 0x89, 0x14, 0xc0, 0xf0, 0xbd, 0xb4, 0xd9, 0x49,
            0x05, 0xee, 0x0d, 0x9e,
        ];
        assert!(Ed25519VerifyingKey::from_bytes(GOOD).is_ok());
        assert_eq!(
            Ed25519VerifyingKey::from_bytes(&[0xff; 32]).err(),
            Some(KeyFormatError::NotOnCurve.into())
        );

        // Each point has one encoding, `y` below `p`. A sign on `x = 0` (where
        // `y = ±1`) and `y = p` or `p + 1` encode points of small order, which
        // `small_order` covers.
        let mut y_three = [0; 32];
        y_three[0] = 3;
        let mut y_p_plus_three = [0xff; 32];
        y_p_plus_three[0] = 0xf0;
        y_p_plus_three[31] = 0x7f;
        let mut y_two = [0; 32];
        y_two[0] = 2;
        for (y, ok) in [
            (y_three, true),
            (y_p_plus_three, false),
            // No `x` has `y = 2`.
            (y_two, false),
        ] {
            let result = Ed25519VerifyingKey::from_bytes(&y);
            assert_eq!(
                result.err(),
                (!ok).then_some(KeyFormatError::NotOnCurve.into()),
                "{y:x?}"
            );
        }

        assert_eq!(
            Ed25519VerifyingKey::from_bytes(&[0; 31]).err(),
            Some(KeyFormatError::WrongLength.into())
        );
        assert_eq!(
            Ed25519VerifyingKey::from_bytes(&[0; 33]).err(),
            Some(KeyFormatError::WrongLength.into())
        );
    }

    #[test]
    fn small_order() {
        // libsodium's list: each `y` of a small-order point that fits in 255
        // bits, with either sign, eight of them the canonical encodings of
        // the points of order dividing 8.
        let mut points = 0;
        for y in [
            "0000000000000000000000000000000000000000000000000000000000000000",
            "0100000000000000000000000000000000000000000000000000000000000000",
            "26e8958fc2b227b045c3f489f2ef98f0d5dfac05d3c63339b13802886d53fc05",
            "c7176a703d4dd84fba3c0b760d10670f2a2053fa2c39ccc64ec7fd7792ac037a",
            "ecffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f",
            "edffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f",
            "eeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f",
        ] {
            for sign in [0, 0x80] {
                let mut bytes: [u8; 32] = hex::decode(y).unwrap().try_into().unwrap();
                bytes[31] |= sign;
                points += usize::from(ed25519::VerifyingKey::from_bytes(&bytes).is_ok());
                assert_eq!(
                    Ed25519VerifyingKey::from_bytes(&bytes).err(),
                    Some(KeyFormatError::SmallOrder.into()),
                    "{bytes:x?}"
                );
            }
        }
        assert_eq!(points, 8);
    }
}
