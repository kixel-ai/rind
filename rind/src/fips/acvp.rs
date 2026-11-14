// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! The deterministic forms of the module's randomized services, which ACVP
//! drives with randomness of its own: the DRBG from given entropy, ML-KEM
//! from given seeds and messages, and ML-DSA from given seeds and `rnd`.
//!
//! FIPS 203 and 204 allow these only for testing, so only the module's ACVP
//! build exports them, to `rind-acvp`; each is the code the module's own
//! services run, with the randomness passed in.

use crate::Error;
use crate::error::KeyFormatError;
use crate::high::hash::Sha512;
use crate::high::hmac_drbg::HmacDrbg;
use crate::high::signature::MlDsaParameterSet;
use crate::low::Entry;
use crate::mid::mldsa::{self, KeyPair};
use crate::mid::mlkem768::{Ciphertext, DecapKey, EncapKey, Message};

/// One prediction-resistant generate's inputs: the entropy it reseeds with,
/// and the additional input it reseeds with.
pub struct Generate<'a> {
    /// The reseed's entropy input.
    pub entropy: &'a [u8],
    /// The reseed's additional input; the generate itself takes none.
    pub additional_input: &'a [u8],
}

/// ACVP's prediction-resistance test of HMAC_DRBG over SHA-512, the module's
/// DRBG: an instantiation, then two generates.
pub struct Drbg<'a> {
    /// The instantiation's entropy input.
    pub entropy: &'a [u8],
    /// The instantiation's nonce.
    pub nonce: &'a [u8],
    /// The instantiation's personalization string.
    pub personalization: &'a [u8],
    /// The two generates.
    pub generates: [Generate<'a>; 2],
}

impl Drbg<'_> {
    /// Runs the test, writing the second generate's output to `out`.
    ///
    /// A request with prediction resistance reseeds with its additional
    /// input, then generates with none (SP 800-90A section 9.3.1, step 7),
    /// as the module's every draw does.
    pub fn run(&self, out: &mut [u8]) {
        let mut drbg = HmacDrbg::<Sha512>::new(self.entropy, self.nonce, self.personalization);
        for generate in &self.generates {
            drbg.reseed(generate.entropy, generate.additional_input);
            drbg.generate(out, b"");
        }
    }
}

/// An ML-KEM-768 encapsulation key's length.
pub const ML_KEM_768_ENCAPSULATION_KEY_LEN: usize = 1184;

/// An ML-KEM-768 expanded decapsulation key's length.
pub const ML_KEM_768_DECAPSULATION_KEY_LEN: usize = 2400;

/// An ML-KEM-768 ciphertext's length.
pub const ML_KEM_768_CIPHERTEXT_LEN: usize = 1088;

/// FIPS 203's `ML-KEM.KeyGen_internal` for ML-KEM-768 from seeds `d` and
/// `z`: the encapsulation key and the expanded decapsulation key.
pub fn ml_kem_768_key_gen(d: &[u8; 32], z: &[u8; 32]) -> ([u8; 1184], [u8; 2400]) {
    let _entry = Entry::new_secret();
    let mut seed = [0u8; 64];
    seed[..32].copy_from_slice(d);
    seed[32..].copy_from_slice(z);
    let key = DecapKey::keygen_internal(&seed);
    crate::low::zeroise(&mut seed);
    (key.encapsulation_key().as_bytes(), key.as_bytes())
}

/// FIPS 203's `ML-KEM.Encaps_internal` of message `m` to ML-KEM-768
/// encapsulation key `ek`, after its input checks: the ciphertext and the
/// shared secret.
pub fn ml_kem_768_encap(ek: &[u8], m: &[u8; 32]) -> Result<([u8; 1088], [u8; 32]), Error> {
    let ek = encapsulation_key(ek)?;
    let _entry = Entry::new_secret();
    let (secret, ciphertext) = ek.encaps_internal(Message(*m));
    Ok((*ciphertext.as_ref(), *secret.as_ref()))
}

/// FIPS 203's `ML-KEM.Decaps_internal` of `ciphertext` with ML-KEM-768
/// expanded decapsulation key `dk`, after their input checks: the shared
/// secret, or the implicit rejection's.
pub fn ml_kem_768_decap(dk: &[u8], ciphertext: &[u8]) -> Result<[u8; 32], Error> {
    let key = decapsulation_key(dk)?;
    let ciphertext: [u8; ML_KEM_768_CIPHERTEXT_LEN] =
        ciphertext.try_into().map_err(|_| Error::WrongLength)?;
    Ok(*key.decaps(&Ciphertext::from(ciphertext)).as_ref())
}

/// FIPS 203's encapsulation input check of an ML-KEM-768 encapsulation key:
/// its length and its modulus check.
pub fn ml_kem_768_check_encapsulation_key(ek: &[u8]) -> Result<(), Error> {
    encapsulation_key(ek).map(drop)
}

/// FIPS 203's decapsulation input check of an ML-KEM-768 expanded
/// decapsulation key: its length and its hash check.
pub fn ml_kem_768_check_decapsulation_key(dk: &[u8]) -> Result<(), Error> {
    decapsulation_key(dk).map(drop)
}

fn encapsulation_key(ek: &[u8]) -> Result<EncapKey, Error> {
    let ek = ek
        .try_into()
        .map_err(|_| Error::from(KeyFormatError::WrongLength))?;
    EncapKey::from_bytes(ek)
}

fn decapsulation_key(dk: &[u8]) -> Result<DecapKey, Error> {
    let dk = dk
        .try_into()
        .map_err(|_| Error::from(KeyFormatError::WrongLength))?;
    DecapKey::from_bytes(dk).ok_or_else(|| KeyFormatError::MismatchedPublicKey.into())
}

/// What an ML-DSA signature is over, by the interface ACVP tests.
#[derive(Clone, Copy)]
pub enum MlDsaMessage<'a> {
    /// FIPS 204's external interface, pure ML-DSA: a message under a
    /// context of at most 255 bytes, as the module's services sign with an
    /// empty one.
    External {
        /// The context string.
        context: &'a [u8],
        /// The message.
        message: &'a [u8],
    },
    /// The internal interface's `M'`, taken as is.
    Internal(&'a [u8]),
    /// The message representative `mu`, computed elsewhere.
    Mu(&'a [u8]),
}

impl MlDsaMessage<'_> {
    /// `mu` for a public key whose hash is `tr`.
    fn mu(self, tr: &[u8; mldsa::TR_LEN]) -> Result<[u8; mldsa::MU_LEN], Error> {
        match self {
            Self::External { context, message } => mldsa::mu(tr, context, message),
            Self::Internal(message) => Ok(mldsa::mu_internal(tr, message)),
            Self::Mu(mu) => mu.try_into().map_err(|_| Error::WrongLength),
        }
    }
}

/// FIPS 204's `ML-DSA.KeyGen_internal` from `seed`: the public key and the
/// expanded private key.
pub fn ml_dsa_key_gen<P: MlDsaParameterSet>(seed: &[u8; 32]) -> (P::PublicKey, P::SecretKey) {
    let key = KeyPair::<P>::from_seed(seed);
    let secret_key = crate::low::ct::into_public(key.secret_key().clone());
    (key.public_key().clone(), secret_key)
}

/// FIPS 204's `ML-DSA.Sign_internal` with expanded private key `sk` over
/// `message`, with randomness `rnd`, all zeros for the deterministic variant.
pub fn ml_dsa_sign<P: MlDsaParameterSet>(
    sk: &[u8],
    message: MlDsaMessage<'_>,
    rnd: &[u8; 32],
) -> Result<P::Signature, Error> {
    let key = KeyPair::<P>::from_secret_key(sk)?;
    let mu = message.mu(key.tr())?;
    key.sign_internal(&mu, rnd)
}

/// FIPS 204's `ML-DSA.Verify_internal` of `signature` over `message` under
/// public key `pk`.
pub fn ml_dsa_verify<P: MlDsaParameterSet>(
    pk: &[u8],
    message: MlDsaMessage<'_>,
    signature: &[u8],
) -> Result<(), Error> {
    if pk.len() != mldsa::public_key_len::<P>() {
        return Err(Error::BadSignature);
    }
    let mu = message
        .mu(&mldsa::tr(pk))
        .map_err(|_| Error::BadSignature)?;
    mldsa::verify_internal::<P>(pk, &mu, signature)
}
