// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! X-Wing, the hybrid of X25519 and ML-KEM-768 that
//! draft-connolly-cfrg-xwing-kem defines, and that HPKE registers as KEM
//! `0x647A`, composed from rind's own ML-KEM-768, X25519, SHAKE256, and
//! SHA3-256.
//!
//! See <https://datatracker.ietf.org/doc/draft-connolly-cfrg-xwing-kem/>.
//! It adds no arithmetic of its own, so it holds no secret-dependent branch or
//! index: what it does with secrets is the hashing, the copies, and the calls
//! below.

use core::fmt;

use crate::error::{Error, KeyFormatError};
use crate::low;
use crate::mid::mlkem::{self, Message, MlKem768};
use crate::mid::rng::{RandomSource, SystemRandom};
use crate::mid::sha3::{Sha3_256Context, Shake256Sponge};
use crate::mid::x25519;

/// X-Wing: X25519 and ML-KEM-768, as draft-connolly-cfrg-xwing-kem defines
/// it.
#[derive(Debug)]
pub enum XWing {}

/// The private key: the 32-byte seed the rest expands from.
pub(crate) const SEED_LEN: usize = 32;
/// An encapsulation key: ML-KEM-768's, then X25519's.
pub(crate) const ENCAP_KEY_LEN: usize = MLKEM_KEY_LEN + X25519_LEN;
/// A ciphertext: ML-KEM-768's, then X25519's.
pub(crate) const CIPHERTEXT_LEN: usize = MLKEM_CIPHERTEXT_LEN + X25519_LEN;
/// The randomness an encapsulation draws: ML-KEM-768's message, then
/// X25519's ephemeral key.
const ESEED_LEN: usize = 64;

const MLKEM_KEY_LEN: usize = 1184;
const MLKEM_CIPHERTEXT_LEN: usize = 1088;
const X25519_LEN: usize = 32;

/// The combiner's last input, `XWingLabel`: the ASCII art `\./` over `/^\`.
const LABEL: [u8; 6] = [0x5c, 0x2e, 0x2f, 0x2f, 0x5e, 0x5c];

/// An X-Wing decapsulation key as the draft's `expandDecapsulationKey`
/// leaves it: the seed it expands from, and the expanded keys, which
/// decapsulation then does not derive again.
#[doc(hidden)]
pub struct DecapKey {
    seed: [u8; SEED_LEN],
    /// `sk_X`.
    x: x25519::PrivateKey,
    /// `pk_X`, which the combiner hashes in.
    pk_x: [u8; X25519_LEN],
    /// `sk_M`, with its encapsulation key `pk_M`.
    mlkem: mlkem::DecapKey<MlKem768>,
}

impl DecapKey {
    /// Generate a key from the system random source: the draft's
    /// `GenerateKeyPair`.
    ///
    /// This fails only if random material generation fails.
    pub(crate) fn generate() -> Result<Self, Error> {
        let _entry = low::Entry::new_secret();
        let mut seed = [0u8; SEED_LEN];
        SystemRandom.fill(&mut seed)?;
        Ok(Self::from_seed(&seed))
    }

    /// Expand `seed`, which is the private key: the draft's
    /// `expandDecapsulationKey`.
    pub(crate) fn from_seed(seed: &[u8; SEED_LEN]) -> Self {
        let _entry = low::Entry::new_secret();
        low::ct::secret_slice(seed);

        // expanded = SHAKE256(sk, 96 * 8)
        let mut expanded = [0u8; 96];
        let mut shake = Shake256Sponge::new();
        shake.absorb(seed);
        shake.finish().squeeze(&mut expanded);

        // (pk_M, sk_M) = ML-KEM-768.KeyGen_internal(expanded[0:32], expanded[32:64])
        let mut mlkem_seed = [0u8; 64];
        mlkem_seed.copy_from_slice(&expanded[..64]);
        let mlkem = mlkem::DecapKey::keygen_internal(&mlkem_seed);

        // sk_X = expanded[64:96]; pk_X = X25519(sk_X, X25519_BASE)
        let mut x_seed = [0u8; X25519_LEN];
        x_seed.copy_from_slice(&expanded[64..]);
        let x = x25519::PrivateKey::from_array(&x_seed);
        let pk_x = x.public_key().as_bytes();

        Self {
            seed: *seed,
            x,
            pk_x,
            mlkem,
        }
    }

    /// The seed this key expands from, still secret.
    pub(crate) fn seed(&self) -> [u8; SEED_LEN] {
        self.seed
    }

    /// Return the corresponding [`EncapKey`].
    pub(crate) fn encapsulation_key(&self) -> EncapKey {
        let _entry = low::Entry::new_public();
        let mlkem = self.mlkem.encapsulation_key();
        let mut bytes = [0u8; ENCAP_KEY_LEN];
        bytes[..MLKEM_KEY_LEN].copy_from_slice(&mlkem.as_bytes()[..]);
        bytes[MLKEM_KEY_LEN..].copy_from_slice(&self.pk_x);
        EncapKey {
            bytes,
            pk_x: self.pk_x,
            mlkem,
        }
    }

    /// The draft's `Decapsulate`, from the expanded key.
    ///
    /// A tampered ML-KEM ciphertext yields ML-KEM's implicit-rejection
    /// secret, so this cannot fail, and the X25519 share takes whatever
    /// value it has, a small-order one included, as the draft computes it.
    pub(crate) fn decaps(&self, c: &Ciphertext) -> SharedSecret {
        let _entry = low::Entry::new_secret();
        let mut ct_x = [0u8; X25519_LEN];
        ct_x.copy_from_slice(&c.bytes[MLKEM_CIPHERTEXT_LEN..]);

        // ss_M = ML-KEM-768.Decapsulate(ct_M, sk_M)
        let ss_m = self.mlkem.decaps(&c.mlkem());
        // ss_X = X25519(sk_X, ct_X)
        let ss_x = self
            .x
            .diffie_hellman_unchecked(&x25519::PublicKey::from_array(&ct_x));
        combiner(ss_m.as_ref(), &ss_x.0, &ct_x, &self.pk_x)
    }
}

// Wiped whole, so no byte of the key survives, padding included. The boxed
// decoded form goes first, since the whole-value wipe nulls its pointer.
impl Drop for DecapKey {
    fn drop(&mut self) {
        self.mlkem.free_decoded();
        low::zeroise_value(self);
    }
}

// Words and bytes, and ML-KEM's key, which is wiped the same way.
impl low::Zeroable for DecapKey {}

/// An X-Wing encapsulation key.
#[doc(hidden)]
pub struct EncapKey {
    /// The key as the draft encodes it, `pk_M || pk_X`.
    bytes: [u8; ENCAP_KEY_LEN],
    /// `pk_X`, as `bytes` ends.
    pk_x: [u8; X25519_LEN],
    /// `pk_M`, checked, and decoded where rind's encryption runs.
    mlkem: mlkem::EncapKey<MlKem768>,
}

impl EncapKey {
    /// Wipes and frees the decoded form of ML-KEM's key, so that a key
    /// pair's drop can wipe the rest of the key's value.
    pub(crate) fn free_decoded(&mut self) {
        self.mlkem.free_decoded();
    }

    /// Parse an encapsulation key, the draft's `pk`.
    ///
    /// Fails if it is not [`ENCAP_KEY_LEN`] bytes, or if ML-KEM's half fails
    /// FIPS-203's modulus check, which the draft requires of encapsulation.
    /// X25519's half is any 32 bytes.
    pub(crate) fn from_bytes(input: &[u8]) -> Result<Self, Error> {
        let _entry = low::Entry::new_public();
        let bytes: [u8; ENCAP_KEY_LEN] =
            input.try_into().map_err(|_| KeyFormatError::WrongLength)?;

        let mut pk_m = [0u8; MLKEM_KEY_LEN];
        pk_m.copy_from_slice(&bytes[..MLKEM_KEY_LEN]);
        let mlkem = mlkem::EncapKey::from_bytes(&pk_m)?;
        let mut pk_x = [0u8; X25519_LEN];
        pk_x.copy_from_slice(&bytes[MLKEM_KEY_LEN..]);

        Ok(Self { bytes, pk_x, mlkem })
    }

    /// The key as the draft encodes it.
    pub(crate) fn as_bytes(&self) -> &[u8; ENCAP_KEY_LEN] {
        &self.bytes
    }

    /// The draft's `Encapsulate`: encapsulate a fresh random secret,
    /// returning the shared secret and the ciphertext.
    pub(crate) fn encaps(&self) -> Result<(SharedSecret, Ciphertext), Error> {
        let _entry = low::Entry::new_secret();
        let mut eseed = [0u8; ESEED_LEN];
        SystemRandom.fill(&mut eseed)?;
        Ok(self.encaps_internal(&eseed))
    }

    /// The draft's `EncapsulateDerand`, with its 64-byte `eseed`: ML-KEM's
    /// message, then X25519's ephemeral key.
    pub(crate) fn encaps_internal(&self, eseed: &[u8; ESEED_LEN]) -> (SharedSecret, Ciphertext) {
        low::ct::secret_slice(eseed);
        let mut m = [0u8; 32];
        m.copy_from_slice(&eseed[..32]);
        let mut ek_x = [0u8; X25519_LEN];
        ek_x.copy_from_slice(&eseed[32..]);

        // ct_X = X25519(ek_X, X25519_BASE)
        let ek_x = x25519::PrivateKey::from_array(&ek_x);
        let ct_x = ek_x.public_key().as_bytes();
        // ss_X = X25519(ek_X, pk_X)
        let ss_x = ek_x.diffie_hellman_unchecked(&x25519::PublicKey::from_array(&self.pk_x));
        // (ss_M, ct_M) = ML-KEM-768.Encaps_internal(pk_M, eseed[0:32])
        let (ss_m, ct_m) = self.mlkem.encaps_internal(Message(m));

        let mut ciphertext = Ciphertext {
            bytes: [0; CIPHERTEXT_LEN],
        };
        ciphertext.bytes[..MLKEM_CIPHERTEXT_LEN].copy_from_slice(ct_m.as_ref());
        ciphertext.bytes[MLKEM_CIPHERTEXT_LEN..].copy_from_slice(&ct_x);
        (
            combiner(ss_m.as_ref(), &ss_x.0, &ct_x, &self.pk_x),
            ciphertext,
        )
    }
}

impl Clone for EncapKey {
    fn clone(&self) -> Self {
        Self {
            bytes: self.bytes,
            pk_x: self.pk_x,
            mlkem: self.mlkem.clone(),
        }
    }
}

/// The draft's `Combiner`: SHA3-256 of `ss_M || ss_X || ct_X || pk_X ||
/// XWingLabel`, which fits one block of the sponge.
fn combiner(ss_m: &[u8; 32], ss_x: &[u8; 32], ct_x: &[u8; 32], pk_x: &[u8; 32]) -> SharedSecret {
    let mut h = Sha3_256Context::new();
    h.update(ss_m);
    h.update(ss_x);
    h.update(ct_x);
    h.update(pk_x);
    h.update(&LABEL);
    SharedSecret(h.finish())
}

/// An X-Wing ciphertext, the draft's `ct`: ML-KEM-768's, then X25519's.
#[doc(hidden)]
#[derive(Clone)]
pub struct Ciphertext {
    bytes: [u8; CIPHERTEXT_LEN],
}

impl Ciphertext {
    /// The ciphertext `bytes`, if they are [`CIPHERTEXT_LEN`] long.
    pub(crate) fn from_slice(bytes: &[u8]) -> Option<Self> {
        bytes.try_into().ok().map(|bytes| Self { bytes })
    }

    /// ML-KEM-768's ciphertext, `ct_M`.
    fn mlkem(&self) -> mlkem::Ciphertext<MlKem768> {
        mlkem::Ciphertext::from_slice(&self.bytes[..MLKEM_CIPHERTEXT_LEN])
            .expect("a ciphertext's first 1088 bytes are ML-KEM-768's")
    }
}

impl fmt::Debug for Ciphertext {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_tuple("Ciphertext").field(&self.bytes).finish()
    }
}

impl AsRef<[u8]> for Ciphertext {
    fn as_ref(&self) -> &[u8] {
        &self.bytes
    }
}

/// An X-Wing shared secret, wiped on drop.
#[doc(hidden)]
pub struct SharedSecret([u8; 32]);

impl AsRef<[u8; 32]> for SharedSecret {
    fn as_ref(&self) -> &[u8; 32] {
        &self.0
    }
}

impl fmt::Debug for SharedSecret {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_tuple("SharedSecret").finish_non_exhaustive()
    }
}

impl Drop for SharedSecret {
    fn drop(&mut self) {
        low::zeroise(&mut self.0);
    }
}
