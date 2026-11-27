//! `kem` 0.3's traits on rind: ML-KEM-512, ML-KEM-768 and ML-KEM-1024 as
//! [`kem::Kem`], with `Encapsulate`, `Decapsulate`, `Generate` and
//! `KeyInit` from a 64-byte seed, mirroring RustCrypto's `ml-kem` crate.
//!
//! Every type is a thin wrapper that calls rind; nothing here is a
//! primitive. The README lists what rind cannot back.
#![no_std]

use core::fmt;
use core::marker::PhantomData;

use hybrid_array::sizes::{U32, U64, U768, U800, U1088, U1184, U1568};
use kem::common::array::{Array, ArraySize};
use kem::common::rand_core::{CryptoRng, TryCryptoRng};
use kem::{
    Ciphertext, Decapsulate, Decapsulator, Encapsulate, Generate, InvalidKey, Key, KeyExport,
    KeyInit, KeySizeUser, SharedKey, TryKeyInit,
};
use zeroize::Zeroize;

/// The 64-byte seed `d || z` a decapsulation key is made from.
pub type Seed = Array<u8, U64>;

/// A parameter set: its rind algorithm and its encodings' sizes.
pub trait ParameterSet:
    kem::Kem<DecapsulationKey = DecapsulationKey<Self>, EncapsulationKey = EncapsulationKey<Self>>
{
    /// rind's algorithm for this set.
    type Rind: rind::kem::Algorithm;
    /// The encapsulation key's length.
    type EncapsulationKeySize: ArraySize;
}

macro_rules! sets {
    ($($(#[$meta:meta])* $name:ident, $module:ident, $ek:ty, $ct:ty;)*) => {$(
        $(#[$meta])*
        #[derive(Clone, Copy, Debug, Default, PartialEq, Eq, PartialOrd, Ord)]
        pub struct $name;

        impl ParameterSet for $name {
            type Rind = rind::kem::$name;
            type EncapsulationKeySize = $ek;
        }

        impl kem::Kem for $name {
            type DecapsulationKey = DecapsulationKey<$name>;
            type EncapsulationKey = EncapsulationKey<$name>;
            type SharedKeySize = U32;
            type CiphertextSize = $ct;
        }

        #[doc = concat!("Type aliases for ", stringify!($name), ", as `ml-kem`'s `", stringify!($module), "` module names them.")]
        pub mod $module {
            /// The decapsulation key.
            pub type DecapsulationKey = crate::DecapsulationKey<super::$name>;
            /// The encapsulation key.
            pub type EncapsulationKey = crate::EncapsulationKey<super::$name>;
            /// The ciphertext.
            pub type Ciphertext = kem::Ciphertext<super::$name>;
        }
    )*};
}

sets! {
    /// ML-KEM-512, FIPS 203's parameter set for security category 1.
    MlKem512, ml_kem_512, U800, U768;
    /// ML-KEM-768, FIPS 203's parameter set for security category 3.
    MlKem768, ml_kem_768, U1184, U1088;
    /// ML-KEM-1024, FIPS 203's parameter set for security category 5.
    MlKem1024, ml_kem_1024, U1568, U1568;
}

/// An encapsulation key: rind's, which checks FIPS 203's modulus as it
/// loads and wipes itself on drop.
pub struct EncapsulationKey<P: ParameterSet> {
    key: rind::kem::EncapsulationKey<P::Rind>,
    set: PhantomData<P>,
}

impl<P: ParameterSet> Clone for EncapsulationKey<P> {
    fn clone(&self) -> Self {
        Self {
            key: self.key.clone(),
            set: PhantomData,
        }
    }
}

impl<P: ParameterSet> fmt::Debug for EncapsulationKey<P> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        fmt::Debug::fmt(&self.key, f)
    }
}

// Public bytes, so a plain comparison.
impl<P: ParameterSet> PartialEq for EncapsulationKey<P> {
    fn eq(&self, other: &Self) -> bool {
        self.key.as_ref() == other.key.as_ref()
    }
}

impl<P: ParameterSet> Eq for EncapsulationKey<P> {}

impl<P: ParameterSet> KeySizeUser for EncapsulationKey<P> {
    type KeySize = P::EncapsulationKeySize;
}

impl<P: ParameterSet> TryKeyInit for EncapsulationKey<P> {
    /// Fails if rind refuses the key: FIPS 203's modulus check.
    fn new(key: &Key<Self>) -> Result<Self, InvalidKey> {
        let key = rind::kem::EncapsulationKey::new(key.as_slice()).map_err(|_| InvalidKey)?;
        Ok(Self {
            key,
            set: PhantomData,
        })
    }
}

impl<P: ParameterSet> KeyExport for EncapsulationKey<P> {
    fn to_bytes(&self) -> Key<Self> {
        Array::try_from(self.key.as_ref()).expect("the set's encapsulation key length")
    }
}

impl<P: ParameterSet> Encapsulate for EncapsulationKey<P> {
    type Kem = P;

    /// Encapsulates a secret from 32 bytes of `rng`, through rind's
    /// `kem::Message`, which zeroes the bytes it takes.
    fn encapsulate_with_rng<R>(&self, rng: &mut R) -> (Ciphertext<P>, SharedKey<P>)
    where
        R: CryptoRng + ?Sized,
    {
        let mut m = [0u8; 32];
        rng.fill_bytes(&mut m);
        let (ciphertext, secret) = rind::kem::Message::new(&mut m).encapsulate(&self.key);
        (
            Array::try_from(ciphertext.as_ref()).expect("the set's ciphertext length"),
            Array::try_from(secret.as_ref()).expect("a 32-byte shared secret"),
        )
    }
}

/// A decapsulation key, made from its 64-byte seed as `ml-kem`'s is: rind's,
/// which wipes itself on drop, beside its encapsulation key.
pub struct DecapsulationKey<P: ParameterSet> {
    key: rind::kem::DecapsulationKey<P::Rind>,
    public: EncapsulationKey<P>,
}

impl<P: ParameterSet> DecapsulationKey<P> {
    fn from_seed(seed: &[u8]) -> Self {
        let key = rind::kem::DecapsulationKey::<P::Rind>::from_seed(seed)
            .expect("a 64-byte seed is a key");
        let public = EncapsulationKey {
            key: key.public_key().clone(),
            set: PhantomData,
        };
        Self { key, public }
    }
}

impl<P: ParameterSet> fmt::Debug for DecapsulationKey<P> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("DecapsulationKey").finish_non_exhaustive()
    }
}

impl<P: ParameterSet> KeySizeUser for DecapsulationKey<P> {
    type KeySize = U64;
}

impl<P: ParameterSet> KeyInit for DecapsulationKey<P> {
    /// The key `seed` makes, FIPS 203's `ML-KEM.KeyGen_internal(d, z)`.
    fn new(seed: &Seed) -> Self {
        Self::from_seed(seed.as_slice())
    }
}

impl<P: ParameterSet> KeyExport for DecapsulationKey<P> {
    /// The key's seed, which rind holds for every key made here.
    fn to_bytes(&self) -> Seed {
        let seed = self.key.to_seed().expect("made from a seed");
        Array::try_from(seed.as_ref()).expect("a 64-byte seed")
    }
}

impl<P: ParameterSet> Generate for DecapsulationKey<P> {
    /// A key from a seed of 64 bytes of `rng`, wiped once rind has it.
    fn try_generate_from_rng<R>(rng: &mut R) -> Result<Self, R::Error>
    where
        R: TryCryptoRng + ?Sized,
    {
        let mut seed = [0u8; 64];
        let filled = rng.try_fill_bytes(&mut seed);
        let key = filled.map(|()| Self::from_seed(&seed));
        seed.zeroize();
        key
    }
}

impl<P: ParameterSet> Decapsulator for DecapsulationKey<P> {
    type Kem = P;

    fn encapsulation_key(&self) -> &EncapsulationKey<P> {
        &self.public
    }
}

impl<P: ParameterSet> Decapsulate for DecapsulationKey<P> {
    /// FIPS 203's `ML-KEM.Decaps`: an altered ciphertext gives the implicit
    /// rejection secret, never an error.
    fn decapsulate(&self, ct: &Ciphertext<P>) -> SharedKey<P> {
        let ct = rind::kem::Ciphertext::<P::Rind>::new(ct.as_slice())
            .expect("the set's ciphertext length");
        let secret = self.key.decapsulate(&ct);
        Array::try_from(secret.as_ref()).expect("a 32-byte shared secret")
    }
}
