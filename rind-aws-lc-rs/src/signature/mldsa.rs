//! ML-DSA-44, ML-DSA-65, and ML-DSA-87, as aws-lc-rs names them.
//!
//! aws-lc-rs picks the parameter set at run time. rind's key pair takes it
//! as a type, so [`PqdsaKeyPair`] holds an enum of the three and dispatches
//! on the [`PqdsaSigningAlgorithm`] it was given.

use alloc::boxed::Box;
use alloc::sync::Arc;
use alloc::vec::Vec;
use core::fmt;

use rind::signature::sign::{MlDsa44, MlDsa65, MlDsa87, MlDsaKeyPair};

use crate::encoding::{AsDer, Pkcs8V1Der, PublicKeyX509Der};
use crate::error::{KeyRejected, Unspecified, unspecified};
use crate::pkcs8::Document;
use crate::signature;
use crate::wipe::Wiped;

/// Which ML-DSA parameter set a key uses. The names are aws-lc-rs's `Debug`
/// text.
#[allow(non_camel_case_types, clippy::upper_case_acronyms)]
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum AlgorithmId {
    ML_DSA_44,
    ML_DSA_65,
    ML_DSA_87,
}

impl AlgorithmId {
    const fn public_key_len(self) -> usize {
        match self {
            Self::ML_DSA_44 => 1312,
            Self::ML_DSA_65 => 1952,
            Self::ML_DSA_87 => 2592,
        }
    }

    const fn signature_len(self) -> usize {
        match self {
            Self::ML_DSA_44 => 2420,
            Self::ML_DSA_65 => 3309,
            Self::ML_DSA_87 => 4627,
        }
    }

    /// Every parameter set's seed is 32 bytes.
    const fn seed_len(self) -> usize {
        match self {
            Self::ML_DSA_44 | Self::ML_DSA_65 | Self::ML_DSA_87 => 32,
        }
    }

    /// FIPS 204's expanded private key.
    const fn raw_private_len(self) -> usize {
        match self {
            Self::ML_DSA_44 => 2560,
            Self::ML_DSA_65 => 4032,
            Self::ML_DSA_87 => 4896,
        }
    }

    fn verify(self) -> &'static rind::signature::VerificationAlgorithm {
        match self {
            Self::ML_DSA_44 => &rind::signature::verify::ML_DSA_44,
            Self::ML_DSA_65 => &rind::signature::verify::ML_DSA_65,
            Self::ML_DSA_87 => &rind::signature::verify::ML_DSA_87,
        }
    }

    /// The parameter set whose expanded private key is `len` bytes, as
    /// aws-lc-rs selects it before checking the caller's algorithm.
    fn from_raw_len(len: usize) -> Option<Self> {
        [Self::ML_DSA_44, Self::ML_DSA_65, Self::ML_DSA_87]
            .into_iter()
            .find(|id| id.raw_private_len() == len)
    }
}

/// An ML-DSA verification algorithm.
#[derive(Debug, Eq, PartialEq)]
pub struct PqdsaVerificationAlgorithm {
    id: &'static AlgorithmId,
}

impl PqdsaVerificationAlgorithm {
    fn id(&self) -> AlgorithmId {
        *self.id
    }
}

impl signature::private::Verify for PqdsaVerificationAlgorithm {
    fn parse(&self, public_key: &[u8]) -> Result<rind::signature::PublicKey, KeyRejected> {
        let algorithm = self.id().verify();
        // aws-lc-rs takes the raw public key or a `SubjectPublicKeyInfo`.
        // The raw key's length is the parameter set's, and an SPKI is longer.
        if public_key.len() == self.id().public_key_len() {
            rind::signature::PublicKey::new(algorithm, public_key)
        } else {
            rind::signature::PublicKey::from_spki(algorithm, public_key)
        }
        .map_err(KeyRejected::rind)
    }

    fn verify_parsed(
        &self,
        key: &rind::signature::PublicKey,
        msg: &[u8],
        signature: &[u8],
    ) -> Result<(), Unspecified> {
        key.verify(msg, signature).map_err(unspecified)
    }

    fn verify_parsed_digest(
        &self,
        _: &rind::signature::PublicKey,
        _: &crate::digest::Digest,
        _: &[u8],
    ) -> Result<(), Unspecified> {
        // Pure ML-DSA signs the message. A digest is not FIPS 204's `mu`.
        Err(Unspecified)
    }
}

signature::verification_algorithm!(PqdsaVerificationAlgorithm);

/// An ML-DSA signing algorithm.
#[derive(Debug, Eq, PartialEq)]
pub struct PqdsaSigningAlgorithm(pub(crate) &'static PqdsaVerificationAlgorithm);

impl PqdsaSigningAlgorithm {
    /// The signature's length, in bytes.
    #[must_use]
    pub fn signature_len(&self) -> usize {
        self.0.id().signature_len()
    }

    /// The raw public key's length, in bytes.
    #[must_use]
    pub fn public_key_len(&self) -> usize {
        self.0.id().public_key_len()
    }

    /// The seed's length, in bytes. Every ML-DSA parameter set uses 32.
    #[must_use]
    pub fn seed_len(&self) -> usize {
        self.0.id().seed_len()
    }

    fn id(&self) -> AlgorithmId {
        self.0.id()
    }
}

/// Verification of ML-DSA-44 signatures.
pub const ML_DSA_44: PqdsaVerificationAlgorithm = PqdsaVerificationAlgorithm {
    id: &AlgorithmId::ML_DSA_44,
};

/// Verification of ML-DSA-65 signatures.
pub const ML_DSA_65: PqdsaVerificationAlgorithm = PqdsaVerificationAlgorithm {
    id: &AlgorithmId::ML_DSA_65,
};

/// Verification of ML-DSA-87 signatures.
pub const ML_DSA_87: PqdsaVerificationAlgorithm = PqdsaVerificationAlgorithm {
    id: &AlgorithmId::ML_DSA_87,
};

/// Signing with ML-DSA-44.
pub const ML_DSA_44_SIGNING: PqdsaSigningAlgorithm = PqdsaSigningAlgorithm(&ML_DSA_44);

/// Signing with ML-DSA-65.
pub const ML_DSA_65_SIGNING: PqdsaSigningAlgorithm = PqdsaSigningAlgorithm(&ML_DSA_65);

/// Signing with ML-DSA-87.
pub const ML_DSA_87_SIGNING: PqdsaSigningAlgorithm = PqdsaSigningAlgorithm(&ML_DSA_87);

const SIGNING: [&PqdsaSigningAlgorithm; 3] =
    [&ML_DSA_44_SIGNING, &ML_DSA_65_SIGNING, &ML_DSA_87_SIGNING];

/// An ML-DSA public key's raw bytes.
#[derive(Clone)]
pub struct PqdsaPublicKey {
    algorithm: &'static PqdsaVerificationAlgorithm,
    octets: Box<[u8]>,
}

impl AsRef<[u8]> for PqdsaPublicKey {
    fn as_ref(&self) -> &[u8] {
        &self.octets
    }
}

impl AsDer<PublicKeyX509Der<'static>> for PqdsaPublicKey {
    fn as_der(&self) -> Result<PublicKeyX509Der<'static>, Unspecified> {
        let key = rind::signature::PublicKey::new(self.algorithm.id().verify(), &self.octets)
            .map_err(unspecified)?;
        Ok(PublicKeyX509Der::new(key.to_spki().as_ref().to_vec()))
    }
}

impl fmt::Debug for PqdsaPublicKey {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("PqdsaPublicKey(\"")?;
        crate::write_hex(f, &self.octets)?;
        f.write_str("\")")
    }
}

/// One parameter set's key pair. Boxed so the enum stays small.
enum Key {
    MlDsa44(Box<MlDsaKeyPair<MlDsa44>>),
    MlDsa65(Box<MlDsaKeyPair<MlDsa65>>),
    MlDsa87(Box<MlDsaKeyPair<MlDsa87>>),
}

impl Key {
    fn generate(id: AlgorithmId) -> Result<Self, rind::Error> {
        match id {
            AlgorithmId::ML_DSA_44 => Ok(Self::MlDsa44(Box::new(MlDsaKeyPair::generate()?))),
            AlgorithmId::ML_DSA_65 => Ok(Self::MlDsa65(Box::new(MlDsaKeyPair::generate()?))),
            AlgorithmId::ML_DSA_87 => Ok(Self::MlDsa87(Box::new(MlDsaKeyPair::generate()?))),
        }
    }

    fn from_seed(id: AlgorithmId, seed: &[u8]) -> Result<Self, rind::Error> {
        match id {
            AlgorithmId::ML_DSA_44 => Ok(Self::MlDsa44(Box::new(MlDsaKeyPair::from_seed(seed)?))),
            AlgorithmId::ML_DSA_65 => Ok(Self::MlDsa65(Box::new(MlDsaKeyPair::from_seed(seed)?))),
            AlgorithmId::ML_DSA_87 => Ok(Self::MlDsa87(Box::new(MlDsaKeyPair::from_seed(seed)?))),
        }
    }

    fn from_pkcs8(id: AlgorithmId, pkcs8: &[u8]) -> Result<Self, rind::Error> {
        match id {
            AlgorithmId::ML_DSA_44 => Ok(Self::MlDsa44(Box::new(MlDsaKeyPair::from_pkcs8(pkcs8)?))),
            AlgorithmId::ML_DSA_65 => Ok(Self::MlDsa65(Box::new(MlDsaKeyPair::from_pkcs8(pkcs8)?))),
            AlgorithmId::ML_DSA_87 => Ok(Self::MlDsa87(Box::new(MlDsaKeyPair::from_pkcs8(pkcs8)?))),
        }
    }

    fn public_bytes(&self) -> Box<[u8]> {
        match self {
            Self::MlDsa44(key) => key.public_key().as_ref().into(),
            Self::MlDsa65(key) => key.public_key().as_ref().into(),
            Self::MlDsa87(key) => key.public_key().as_ref().into(),
        }
    }

    fn has_seed(&self) -> bool {
        match self {
            Self::MlDsa44(key) => key.to_seed().is_some(),
            Self::MlDsa65(key) => key.to_seed().is_some(),
            Self::MlDsa87(key) => key.to_seed().is_some(),
        }
    }

    fn pkcs8(&self) -> Wiped<Vec<u8>> {
        let bytes = match self {
            Self::MlDsa44(key) => key.to_pkcs8().as_ref().to_vec(),
            Self::MlDsa65(key) => key.to_pkcs8().as_ref().to_vec(),
            Self::MlDsa87(key) => key.to_pkcs8().as_ref().to_vec(),
        };
        Wiped::new(bytes)
    }

    fn sign_into(&self, message: &[u8], out: &mut [u8]) -> Result<(), rind::Error> {
        match self {
            Self::MlDsa44(key) => out.copy_from_slice(key.sign(message)?.as_ref()),
            Self::MlDsa65(key) => out.copy_from_slice(key.sign(message)?.as_ref()),
            Self::MlDsa87(key) => out.copy_from_slice(key.sign(message)?.as_ref()),
        }
        Ok(())
    }
}

/// An ML-DSA private key and its public key.
///
/// Signing is hedged: each signature draws fresh randomness, as aws-lc-rs's
/// does, and verification accepts either side's signature.
#[derive(Clone)]
pub struct PqdsaKeyPair {
    algorithm: &'static PqdsaSigningAlgorithm,
    key: Arc<Key>,
    pubkey: PqdsaPublicKey,
}

impl PqdsaKeyPair {
    fn new(algorithm: &'static PqdsaSigningAlgorithm, key: Key) -> Self {
        let pubkey = PqdsaPublicKey {
            algorithm: algorithm.0,
            octets: key.public_bytes(),
        };
        Self {
            algorithm,
            key: Arc::new(key),
            pubkey,
        }
    }

    /// Generates a key pair for `algorithm`.
    pub fn generate(algorithm: &'static PqdsaSigningAlgorithm) -> Result<Self, Unspecified> {
        let key = Key::generate(algorithm.id()).map_err(unspecified)?;
        Ok(Self::new(algorithm, key))
    }

    /// Loads a PKCS#8 key for `algorithm`: the seed, the expanded private
    /// key, or both when they agree. A v2 public key that does not match is
    /// refused.
    pub fn from_pkcs8(
        algorithm: &'static PqdsaSigningAlgorithm,
        pkcs8: &[u8],
    ) -> Result<Self, KeyRejected> {
        match Key::from_pkcs8(algorithm.id(), pkcs8) {
            Ok(key) => Ok(Self::new(algorithm, key)),
            Err(err) => Err(pkcs8_rejected(algorithm, pkcs8, err)),
        }
    }

    /// Loads an expanded private key, FIPS 204's encoding.
    ///
    /// The bytes are wrapped in the PKCS#8 form rind loads. A seed-sized
    /// input is refused: this is the expanded key, not [`Self::from_seed`].
    pub fn from_raw_private_key(
        algorithm: &'static PqdsaSigningAlgorithm,
        raw_private_key: &[u8],
    ) -> Result<Self, KeyRejected> {
        // aws-lc-rs picks the parameter set from the length, then refuses
        // the key when that set is not `algorithm`.
        let Some(id) = AlgorithmId::from_raw_len(raw_private_key.len()) else {
            return Err(KeyRejected::invalid_encoding());
        };
        let der = Wiped::new(expanded_pkcs8(id, raw_private_key));
        let key = match Key::from_pkcs8(id, &der) {
            Ok(key) => key,
            Err(_) => return Err(KeyRejected::invalid_encoding()),
        };
        if id != algorithm.id() {
            return Err(KeyRejected::unspecified());
        }
        Ok(Self::new(algorithm, key))
    }

    /// Expands a 32-byte seed into its key pair.
    pub fn from_seed(
        algorithm: &'static PqdsaSigningAlgorithm,
        seed: &[u8],
    ) -> Result<Self, KeyRejected> {
        match seed.len().cmp(&algorithm.seed_len()) {
            core::cmp::Ordering::Less => return Err(KeyRejected::too_small()),
            core::cmp::Ordering::Greater => return Err(KeyRejected::too_large()),
            core::cmp::Ordering::Equal => {}
        }
        let key = Key::from_seed(algorithm.id(), seed).map_err(KeyRejected::rind)?;
        Ok(Self::new(algorithm, key))
    }

    /// Encodes the private key as PKCS#8 v1 in seed form.
    ///
    /// A key loaded from its expanded form has no seed, and this fails, as
    /// aws-lc-rs's does. rind would write the expanded form; that encoding
    /// is not returned here.
    pub fn to_pkcs8v1(&self) -> Result<Document, Unspecified> {
        self.pkcs8_seed()
    }

    /// Deprecated alias for [`Self::to_pkcs8v1`].
    ///
    /// # Errors
    ///
    /// Returns `Unspecified` when the key has no seed.
    #[cfg(feature = "unstable")]
    #[deprecated(since = "1.18.0", note = "use `PqdsaKeyPair::to_pkcs8v1`")]
    pub fn to_pkcs8(&self) -> Result<Document, Unspecified> {
        self.to_pkcs8v1()
    }

    /// Signs `msg`, writing the signature into `signature`, which must be at
    /// least [`PqdsaSigningAlgorithm::signature_len`] bytes. Returns the
    /// number of bytes written.
    pub fn sign(&self, msg: &[u8], signature: &mut [u8]) -> Result<usize, Unspecified> {
        let len = self.algorithm.signature_len();
        if signature.len() < len {
            return Err(Unspecified);
        }
        self.key
            .sign_into(msg, &mut signature[..len])
            .map_err(unspecified)?;
        Ok(len)
    }

    /// The signing algorithm.
    #[must_use]
    pub fn algorithm(&self) -> &'static PqdsaSigningAlgorithm {
        self.algorithm
    }

    /// The private key.
    #[must_use]
    pub fn private_key(&self) -> PqdsaPrivateKey<'_> {
        PqdsaPrivateKey(self)
    }

    fn pkcs8_seed(&self) -> Result<Document, Unspecified> {
        if !self.key.has_seed() {
            return Err(Unspecified);
        }
        let der = self.key.pkcs8();
        Ok(Document::new(&der))
    }
}

impl signature::KeyPair for PqdsaKeyPair {
    type PublicKey = PqdsaPublicKey;

    fn public_key(&self) -> &PqdsaPublicKey {
        &self.pubkey
    }
}

impl fmt::Debug for PqdsaKeyPair {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("PqdsaKeyPair")
            .field("algorithm", &self.algorithm)
            .finish()
    }
}

/// An ML-DSA private key, borrowed from its [`PqdsaKeyPair`].
pub struct PqdsaPrivateKey<'a>(pub(crate) &'a PqdsaKeyPair);

impl AsDer<Pkcs8V1Der<'static>> for PqdsaPrivateKey<'_> {
    fn as_der(&self) -> Result<Pkcs8V1Der<'static>, Unspecified> {
        let doc = self.0.pkcs8_seed()?;
        Ok(Pkcs8V1Der::new(doc.as_ref().to_vec()))
    }
}

impl fmt::Debug for PqdsaPrivateKey<'_> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "PqdsaPrivateKey({:?})", self.0.algorithm.0.id())
    }
}

/// A PKCS#8 load failed. A key of another ML-DSA parameter set is
/// `Unspecified`, matching aws-lc-rs's size check after a successful parse.
/// Any other algorithm that still parsed as PKCS#8 is `WrongAlgorithm`.
/// Anything that did not parse stays rind's refusal, whose `description_`
/// is `InvalidEncoding`.
fn pkcs8_rejected(
    algorithm: &'static PqdsaSigningAlgorithm,
    pkcs8: &[u8],
    err: rind::Error,
) -> KeyRejected {
    for other in SIGNING {
        if other.id() == algorithm.id() {
            continue;
        }
        if Key::from_pkcs8(other.id(), pkcs8).is_ok() {
            return KeyRejected::unspecified();
        }
    }
    let message = err.to_string();
    if message.contains("mismatched PKCS#8 algorithm") {
        KeyRejected::wrong_algorithm()
    } else {
        KeyRejected::rind(err)
    }
}

/// RFC 5958 v1 around RFC 9881's expanded private key: an `OCTET STRING`
/// holding the raw key, itself inside PKCS#8's `privateKey` `OCTET STRING`.
fn expanded_pkcs8(id: AlgorithmId, raw: &[u8]) -> Vec<u8> {
    let mut choice = Wiped::new(Vec::new());
    push_tlv(&mut choice, 0x04, raw);
    let mut private_key = Wiped::new(Vec::new());
    push_tlv(&mut private_key, 0x04, &choice);
    let mut body = Wiped::new(Vec::new());
    body.extend_from_slice(&[0x02, 0x01, 0x00]);
    body.extend_from_slice(algorithm_identifier(id));
    body.extend_from_slice(&private_key);
    let mut der = Vec::new();
    push_tlv(&mut der, 0x30, &body);
    der
}

/// `AlgorithmIdentifier` for the parameter set, with no parameters.
fn algorithm_identifier(id: AlgorithmId) -> &'static [u8] {
    match id {
        // id-ml-dsa-44, 2.16.840.1.101.3.4.3.17
        AlgorithmId::ML_DSA_44 => &[
            0x30, 0x0b, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x03, 0x11,
        ],
        // id-ml-dsa-65, 2.16.840.1.101.3.4.3.18
        AlgorithmId::ML_DSA_65 => &[
            0x30, 0x0b, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x03, 0x12,
        ],
        // id-ml-dsa-87, 2.16.840.1.101.3.4.3.19
        AlgorithmId::ML_DSA_87 => &[
            0x30, 0x0b, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x03, 0x13,
        ],
    }
}

/// Appends a DER element. `body.len()` is a public size.
fn push_tlv(out: &mut Vec<u8>, tag: u8, body: &[u8]) {
    out.push(tag);
    let len = body.len();
    if len < 0x80 {
        out.push(len as u8);
    } else if len <= 0xff {
        out.extend([0x81, len as u8]);
    } else {
        let len = u16::try_from(len).expect("an ML-DSA key fits in two DER length bytes");
        out.extend([0x82, (len >> 8) as u8, len as u8]);
    }
    out.extend_from_slice(body);
}
