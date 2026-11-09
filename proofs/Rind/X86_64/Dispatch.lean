import Rind.X86_64.Funs
open Aeneas Aeneas.Std Result

/-!
# The agreement and header-protection APIs' dispatch, modelled by hand

`PrivateKey` reaches each curve's `Agree` impl, and `HeaderProtectionKey` each
cipher's `Mask` impl, through function pointers, which Aeneas cannot
translate, so the translation starts below them and this file models the Rust
above them. `admin/prove` fails unless these quotes are still that Rust, so a
change to it is a change to this model:

```rust
pub struct Algorithm {
    id: AlgorithmId,
    // The only paths to the curve's code, so a binary links only the curves
    // whose algorithms it names.
    generate: fn() -> Result<Private, Error>,
    load: fn(Source<'_>) -> Result<Private, Error>,
    parse_public: fn(&[u8]) -> Result<PublicKey, Error>,
}

pub static X25519: Algorithm = Algorithm {
    id: AlgorithmId::X25519,
    generate: Keyed::<X25519Curve>::generate,
    load: Keyed::<X25519Curve>::load,
    parse_public: x25519_public_key,
};

impl PrivateKey {
    /// Generates a private key for `algorithm` from the system random source.
    pub fn generate(algorithm: &'static Algorithm) -> Result<Self, Error> {
        Ok(Self((algorithm.generate)()?))
    }

    /// Loads a private key for `algorithm` from its scalar: X25519's 32
    /// bytes, any value, or a NIST curve's big-endian scalar, exactly the
    /// curve's length and refused unless it is from 1 to n - 1.
    ///
    /// This suits a JWK's `d`; prefer [`Self::from_pkcs8`] for stored keys.
    pub fn from_scalar(algorithm: &'static Algorithm, scalar: &[u8]) -> Result<Self, Error> {
        Ok(Self((algorithm.load)(Source::Scalar(scalar))?))
    }

    /// Loads a PKCS#8 private key for `algorithm`.
    ///
    /// X25519 takes RFC 8410's, v1 or v2, refused if a v2 public key does
    /// not match; a NIST curve takes v1 `ECPrivateKey` on its curve, as
    /// [`EcdsaKeyPair::from_pkcs8`](crate::signature::EcdsaKeyPair::from_pkcs8)
    /// does.
    pub fn from_pkcs8(algorithm: &'static Algorithm, der: &[u8]) -> Result<Self, Error> {
        Ok(Self((algorithm.load)(Source::Pkcs8(der))?))
    }

    /// Loads a SEC1 (RFC 5915) `ECPrivateKey` on `algorithm`'s curve, as
    /// [`EcdsaKeyPair::from_sec1`](crate::signature::EcdsaKeyPair::from_sec1)
    /// does.
    ///
    /// X25519 has no SEC1 encoding, so it refuses every key.
    pub fn from_sec1(algorithm: &'static Algorithm, der: &[u8]) -> Result<Self, Error> {
        Ok(Self((algorithm.load)(Source::Sec1(der))?))
    }

    /// Returns the public key to send to the peer.
    pub fn public_key(&self) -> PublicKey {
        match &self.0 {
            Private::X25519(key) => key.public_key(),
            Private::P256(key) => key.public_key(),
            Private::P384(key) => key.public_key(),
            Private::P521(key) => key.public_key(),
        }
    }

    /// Agrees on a secret with the peer's encoded public key.
    ///
    /// The peer's key is parsed for this key's algorithm, and refused if it
    /// is malformed or off the curve, and so is X25519's all-zero output from
    /// a small-order point
    /// ([RFC7748 section 6.1](https://datatracker.ietf.org/doc/html/rfc7748#section-6.1)).
    /// A NIST curve's key is an uncompressed point, as TLS sends it;
    /// [`PublicKey::new`] decompresses a compressed one.
    pub fn agree(&self, peer: &[u8]) -> Result<SharedSecret, Error> {
        Ok(SharedSecret(match &self.0 {
            Private::X25519(key) => key.agree(peer),
            Private::P256(key) => key.agree(peer),
            Private::P384(key) => key.agree(peer),
            Private::P521(key) => key.agree(peer),
        }?))
    }

    /// Encodes the private key as PKCS#8: v1 for X25519, and for a NIST
    /// curve as [`EcdsaKeyPair::to_pkcs8`](crate::signature::EcdsaKeyPair::to_pkcs8)
    /// does, with its public key.
    pub fn to_pkcs8(&self) -> Pkcs8 {
        Pkcs8(Buffer::encode(|output| match &self.0 {
            Private::X25519(key) => key.to_pkcs8(output),
            Private::P256(key) => key.to_pkcs8(output),
            Private::P384(key) => key.to_pkcs8(output),
            Private::P521(key) => key.to_pkcs8(output),
        }))
    }

    /// Encodes the private key as the scalar [`Self::from_scalar`] loads.
    pub fn to_scalar(&self) -> Scalar {
        Scalar(Buffer::encode(|output| match &self.0 {
            Private::X25519(key) => key.to_scalar(output),
            Private::P256(key) => key.to_scalar(output),
            Private::P384(key) => key.to_scalar(output),
            Private::P521(key) => key.to_scalar(output),
        }))
    }
}

struct Keyed<K: Agree> {
    key: K::Key,
    ops: low::ZeroableRef<Ops<K::Key>>,
}

struct Ops<K> {
    public_key: fn(&K) -> PublicKey,
    agree: fn(&K, &[u8]) -> Result<Secret, Error>,
    to_pkcs8: Write<K>,
    to_scalar: Write<K>,
}

impl<K: Agree> Keyed<K> {
    fn generate() -> Result<Private, Error> {
        Ok(K::wrap(Self::new(K::random()?)))
    }

    fn load(source: Source<'_>) -> Result<Private, Error> {
        Ok(K::wrap(Self::new(K::load(source)?)))
    }

    fn new(key: K::Key) -> Self {
        Self {
            key,
            ops: low::ZeroableRef::new(
                const {
                    &Ops {
                        public_key: K::encode_public,
                        agree: K::agree,
                        to_pkcs8: K::encode_pkcs8,
                        to_scalar: K::encode_scalar,
                    }
                },
            ),
        }
    }

    fn public_key(&self) -> PublicKey {
        (self.ops.get().public_key)(&self.key)
    }

    fn agree(&self, peer: &[u8]) -> Result<Secret, Error> {
        (self.ops.get().agree)(&self.key, peer)
    }

    fn to_pkcs8<'a>(&self, output: &'a mut [u8]) -> Result<&'a [u8], Error> {
        (self.ops.get().to_pkcs8)(&self.key, output)
    }

    fn to_scalar<'a>(&self, output: &'a mut [u8]) -> Result<&'a [u8], Error> {
        (self.ops.get().to_scalar)(&self.key, output)
    }
}

pub(crate) struct ZeroableRef<T: 'static>(Option<&'static T>);

impl<T> ZeroableRef<T> {
    pub(crate) const fn new(value: &'static T) -> Self {
        Self(Some(value))
    }

    pub(crate) fn get(&self) -> &'static T {
        self.0.expect("wiped only on drop")
    }
}

```

```rust
pub struct Algorithm {
    id: AlgorithmId,
    // The only path to the cipher's code, so a binary links only the ciphers
    // whose algorithms it names.
    new: fn(&[u8]) -> Result<Key, Error>,
}

pub static CHACHA20: Algorithm = Algorithm {
    id: AlgorithmId::ChaCha20,
    new: |key| {
        let key = key.try_into().map_err(|_| Error::WrongLength)?;
        Ok(Key::ChaCha20(Masker::new(ChaCha20::new(key))))
    },
};

impl HeaderProtectionKey {
    /// Expands `key` for `algorithm`, failing with [`Error::WrongLength`] if
    /// it is not [`Algorithm::key_len`] bytes.
    pub fn new(algorithm: &'static Algorithm, key: &[u8]) -> Result<Self, Error> {
        Ok(Self((algorithm.new)(key)?))
    }

    /// Computes the mask for `sample`: its first byte masks the packet's first
    /// byte, and the rest mask the packet number.
    pub fn mask(&self, sample: &[u8; SAMPLE_LEN]) -> [u8; 5] {
        match &self.0 {
            Key::Aes(key) => key.mask(sample),
            Key::ChaCha20(key) => key.mask(sample),
        }
    }
}

struct Masker<C: Mask> {
    key: C,
    mask: ZeroableRef<MaskFn<C>>,
}

type MaskFn<C> = fn(&C, &[u8; SAMPLE_LEN]) -> [u8; 5];

impl<C: Mask> Masker<C> {
    fn new(key: C) -> Self {
        Self {
            key,
            mask: ZeroableRef::new(const { &(C::mask as MaskFn<C>) }),
        }
    }

    fn mask(&self, sample: &[u8; SAMPLE_LEN]) -> [u8; 5] {
        (self.mask.get())(&self.key, sample)
    }
}

```

The model departs from the Rust in six ways, and adds no axiom:

- `Ops<K::Key>` holds nothing, and `Keyed`'s methods call `K`'s `encode_public` and
  `agree` directly: `Ops` is private to `high::agreement`, whose only value of
  one is `Keyed::new`'s, of `K`'s own functions. `admin/prove` checks that the
  quote holds every mention of `Ops` there.
- `PrivateKey::to_pkcs8` and `to_scalar`, and `Keyed`'s, are left out: no
  theorem states what they return.
- `Algorithm`'s `parse_public`, which only `PublicKey::new` and `from_spki`
  read, is left out, so no static here sets it: no theorem is about loading a
  peer's key, and `agree` takes the peer's bytes.
- `Masker<C>` is its key, and `Masker::mask` calls `C`'s `mask` directly:
  `Masker`'s fields are private to `aead::quic`, where only `Masker::new`
  builds one, with `C::mask`. `admin/prove` checks that the quote holds every
  `Masker` literal and `impl` there, and every write to a `mask` field.
- `ZeroableRef<T>` is its `T`: only the drop that wipes it leaves it `None`.
- `?` is a `match`, since each error it passes on is already an `Error`, and
  `map_err(|_| Error::WrongLength)?` a `match` returning that error.

Drops are not modelled, as everywhere in the translation. Of the algorithm
statics, only `X25519` and `CHACHA20` are here; `Rind.Aarch64.P256Dispatch`
models `ECDH_P256` on aarch64.

As in the translation, `Keyed` and `Agree` take the curve marker `K` and its
associated key type as separate type parameters.
-/

namespace rind.x86_64

/-- `Algorithm`. -/
structure high.agreement.Algorithm where
  id : high.agreement.AlgorithmId
  generate : Result (core.result.Result high.agreement.Private error.Error)
  load : high.agreement.Source → Result (core.result.Result high.agreement.Private error.Error)

/-- `Keyed::<K>::new`, whose `ops` holds `K`'s own functions. -/
def high.agreement.Keyed.new {K Key : Type} (key : Key) : Result (high.agreement.Keyed K Key) :=
  ok { key, ops := () }

/-- `Keyed::<K>::generate`. -/
def high.agreement.Keyed.generate {K Key : Type} (AgreeInst : high.agreement.Agree K Key) :
    Result (core.result.Result high.agreement.Private error.Error) := do
  let r ← AgreeInst.random
  match r with
  | .Ok key =>
    let k ← high.agreement.Keyed.new key
    let p ← AgreeInst.wrap k
    ok (.Ok p)
  | .Err e => ok (.Err e)

/-- `Keyed::<K>::load`. -/
def high.agreement.Keyed.load {K Key : Type} (AgreeInst : high.agreement.Agree K Key)
    (source : high.agreement.Source) :
    Result (core.result.Result high.agreement.Private error.Error) := do
  let r ← AgreeInst.load source
  match r with
  | .Ok key =>
    let k ← high.agreement.Keyed.new key
    let p ← AgreeInst.wrap k
    ok (.Ok p)
  | .Err e => ok (.Err e)

/-- `Keyed::<K>::public_key`, whose `ops.public_key` is `K::encode_public`. -/
def high.agreement.Keyed.public_key {K Key : Type} (AgreeInst : high.agreement.Agree K Key)
    (self : high.agreement.Keyed K Key) : Result high.agreement.PublicKey :=
  AgreeInst.encode_public self.key

/-- `Keyed::<K>::agree`, whose `ops.agree` is `K::agree`. -/
def high.agreement.Keyed.agree {K Key : Type} (AgreeInst : high.agreement.Agree K Key)
    (self : high.agreement.Keyed K Key) (peer : Slice Std.U8) :
    Result (core.result.Result high.agreement.Secret error.Error) :=
  AgreeInst.agree self.key peer

/-- The `X25519` static. -/
def high.agreement.X25519 : high.agreement.Algorithm where
  id := .X25519
  generate := high.agreement.Keyed.generate high.agreement.X25519Curve.Insts.RindHighAgreementAgreePrivateKey
  load := high.agreement.Keyed.load high.agreement.X25519Curve.Insts.RindHighAgreementAgreePrivateKey

/-- `PrivateKey::generate`. -/
def high.agreement.PrivateKey.generate (algorithm : high.agreement.Algorithm) :
    Result (core.result.Result high.agreement.PrivateKey error.Error) := do
  let r ← algorithm.generate
  match r with
  | .Ok key => ok (.Ok key)
  | .Err e => ok (.Err e)

/-- `PrivateKey::from_scalar`, `from_pkcs8`, and `from_sec1`, each
`algorithm.load` of its own `Source`. -/
def high.agreement.PrivateKey.load (algorithm : high.agreement.Algorithm)
    (source : high.agreement.Source) :
    Result (core.result.Result high.agreement.PrivateKey error.Error) := do
  let r ← algorithm.load source
  match r with
  | .Ok key => ok (.Ok key)
  | .Err e => ok (.Err e)

/-- `PrivateKey::from_scalar`. -/
def high.agreement.PrivateKey.from_scalar (algorithm : high.agreement.Algorithm)
    (scalar : Slice Std.U8) :
    Result (core.result.Result high.agreement.PrivateKey error.Error) :=
  high.agreement.PrivateKey.load algorithm (.Scalar scalar)

/-- `PrivateKey::from_pkcs8`. -/
def high.agreement.PrivateKey.from_pkcs8 (algorithm : high.agreement.Algorithm)
    (der : Slice Std.U8) :
    Result (core.result.Result high.agreement.PrivateKey error.Error) :=
  high.agreement.PrivateKey.load algorithm (.Pkcs8 der)

/-- `PrivateKey::from_sec1`. -/
def high.agreement.PrivateKey.from_sec1 (algorithm : high.agreement.Algorithm)
    (der : Slice Std.U8) :
    Result (core.result.Result high.agreement.PrivateKey error.Error) :=
  high.agreement.PrivateKey.load algorithm (.Sec1 der)

/-- `PrivateKey::public_key`. -/
def high.agreement.PrivateKey.public_key (self : high.agreement.PrivateKey) :
    Result high.agreement.PublicKey :=
  match self with
  | .X25519 key =>
    high.agreement.Keyed.public_key high.agreement.X25519Curve.Insts.RindHighAgreementAgreePrivateKey key
  | .P256 key => high.agreement.Keyed.public_key high.curve.P256.Insts.RindHighAgreementAgreePrivateKey key
  | .P384 key => high.agreement.Keyed.public_key high.curve.P384.Insts.RindHighAgreementAgreePrivateKey key
  | .P521 key => high.agreement.Keyed.public_key high.curve.P521.Insts.RindHighAgreementAgreePrivateKey key

/-- `PrivateKey::agree`. -/
def high.agreement.PrivateKey.agree (self : high.agreement.PrivateKey) (peer : Slice Std.U8) :
    Result (core.result.Result high.agreement.SharedSecret error.Error) := do
  let r ← match self with
    | .X25519 key =>
      high.agreement.Keyed.agree high.agreement.X25519Curve.Insts.RindHighAgreementAgreePrivateKey key peer
    | .P256 key => high.agreement.Keyed.agree high.curve.P256.Insts.RindHighAgreementAgreePrivateKey key peer
    | .P384 key => high.agreement.Keyed.agree high.curve.P384.Insts.RindHighAgreementAgreePrivateKey key peer
    | .P521 key => high.agreement.Keyed.agree high.curve.P521.Insts.RindHighAgreementAgreePrivateKey key peer
  match r with
  | .Ok secret => ok (.Ok secret)
  | .Err e => ok (.Err e)

/-- `quic::Algorithm`. -/
structure aead.quic.Algorithm where
  id : aead.quic.AlgorithmId
  new : Slice Std.U8 → Result (core.result.Result aead.quic.Key error.Error)

/-- `Masker::<C>::new`, whose `mask` is `C::mask`. -/
def aead.quic.Masker.new {C : Type} (key : C) : Result (aead.quic.Masker C) :=
  ok key

/-- `Masker::<C>::mask`, whose `mask` is `C::mask`. -/
def aead.quic.Masker.mask {C : Type} (MaskInst : aead.quic.Mask C) (self : aead.quic.Masker C)
    (sample : Array Std.U8 16#usize) : Result (Array Std.U8 5#usize) :=
  MaskInst.mask self sample

/-- The `CHACHA20` static. -/
def aead.quic.CHACHA20 : aead.quic.Algorithm where
  id := .ChaCha20
  new key := do
    let r ← core.array.TryFromArrayCopySlice.try_from 32#usize core.marker.CopyU8 key
    match r with
    | .Ok key =>
      let c ← mid.chacha20.ChaCha20.new key
      let m ← aead.quic.Masker.new c
      ok (.Ok (.ChaCha20 m))
    | .Err _ => ok (.Err .WrongLength)

/-- `HeaderProtectionKey::new`. -/
def aead.quic.HeaderProtectionKey.new (algorithm : aead.quic.Algorithm) (key : Slice Std.U8) :
    Result (core.result.Result aead.quic.HeaderProtectionKey error.Error) := do
  let r ← algorithm.new key
  match r with
  | .Ok k => ok (.Ok k)
  | .Err e => ok (.Err e)

/-- `HeaderProtectionKey::mask`. -/
def aead.quic.HeaderProtectionKey.mask (self : aead.quic.HeaderProtectionKey)
    (sample : Array Std.U8 16#usize) : Result (Array Std.U8 5#usize) :=
  match self with
  | .Aes key => aead.quic.Masker.mask mid.aes.Aes.Insts.RindAeadQuicMask key sample
  | .ChaCha20 key => aead.quic.Masker.mask mid.chacha20.ChaCha20.Insts.RindAeadQuicMask key sample

end rind.x86_64
