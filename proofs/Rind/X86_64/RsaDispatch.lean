import Rind.X86_64.SignatureBuffer
import Rind.X86_64.RsaKey
-- BEGIN x86_64
import Rind.X86_64.RsaSign
-- END x86_64
open Aeneas Aeneas.Std Result rind.spec rind.spec.rsa

/-!
# The signature API's RSA public keys, modelled by hand

`rsa::PublicKey::verify` reaches each algorithm's verification through the
function pointer its `VerificationAlgorithm` holds, and every loader builds
the key's encoding with `Buffer::write`, both of which Aeneas cannot
translate, so the translation stops below them and this file models the Rust
above them for RSASSA-PKCS1-v1_5 and RSASSA-PSS with SHA-256,
`verify::PKCS1_SHA256` and `verify::PSS_SHA256`. `admin/prove` fails unless
this quote, and `SignatureBuffer`'s of `Buffer`, are still that Rust, so a
change to it is a change to this model:

```rust
enum HashId {
    Sha256,
    Sha384,
    Sha512,
}

impl HashId {
    /// The hash's output length, in bytes.
    const fn len(self) -> usize {
        match self {
            Self::Sha256 => 32,
            Self::Sha384 => 48,
            Self::Sha512 => 64,
        }
    }
}

const MAX_PUBLIC_MODULUS_BITS: usize = 8192;

pub(crate) const MAX_PUBLIC_MODULUS_BYTES: usize = MAX_PUBLIC_MODULUS_BITS / 8;

pub(crate) const MAX_PUBLIC_KEY_LEN: usize = rsa_pub::MAX_PUBLIC_MODULUS_BYTES + 64;

enum RsaPadding {
    /// RSASSA-PKCS1-v1_5.
    Pkcs1,
    /// RSASSA-PSS, with MGF1 on the same hash and a salt of this length.
    Pss(PssSalt),
}

struct RsaScheme {
    padding: RsaPadding,
    hash: HashId,
}

type RsaSign =
    for<'a> fn(&rsa::SigningKey, PssSalt, &'a mut [u8], &[u8]) -> Result<&'a [u8], Error>;

type RsaVerify = fn(&rsa::VerifyingKey, Option<PssSalt>, &[u8], &[u8]) -> Result<(), Error>;

impl RsaScheme {
    const fn pss(hash: HashId, salt: PssSalt) -> Self {
        Self {
            padding: RsaPadding::Pss(salt),
            hash,
        }
    }

    /// The PSS salt length, which PKCS#1 v1.5 ignores.
    const fn salt(self) -> PssSalt {
        match self.padding {
            RsaPadding::Pkcs1 => PssSalt::Hash,
            RsaPadding::Pss(salt) => salt,
        }
    }

    const fn signer(self) -> RsaSign {
        match (self.padding, self.hash) {
            (RsaPadding::Pkcs1, HashId::Sha256) => |key, _, out, m| key.sign_pkcs1_sha256(out, m),
            (RsaPadding::Pkcs1, HashId::Sha384) => |key, _, out, m| key.sign_pkcs1_sha384(out, m),
            (RsaPadding::Pkcs1, HashId::Sha512) => |key, _, out, m| key.sign_pkcs1_sha512(out, m),
            (RsaPadding::Pss(_), HashId::Sha256) => rsa::SigningKey::sign_pss_sha256,
            (RsaPadding::Pss(_), HashId::Sha384) => rsa::SigningKey::sign_pss_sha384,
            (RsaPadding::Pss(_), HashId::Sha512) => rsa::SigningKey::sign_pss_sha512,
        }
    }

    const fn verifier(self) -> RsaVerify {
        match (self.padding, self.hash) {
            (RsaPadding::Pkcs1, HashId::Sha256) => |key, _, s, m| key.verify_pkcs1_sha256(s, m),
            (RsaPadding::Pkcs1, HashId::Sha384) => |key, _, s, m| key.verify_pkcs1_sha384(s, m),
            (RsaPadding::Pkcs1, HashId::Sha512) => |key, _, s, m| key.verify_pkcs1_sha512(s, m),
            (RsaPadding::Pss(_), HashId::Sha256) => rsa::VerifyingKey::verify_pss_sha256,
            (RsaPadding::Pss(_), HashId::Sha384) => rsa::VerifyingKey::verify_pss_sha384,
            (RsaPadding::Pss(_), HashId::Sha512) => rsa::VerifyingKey::verify_pss_sha512,
        }
    }

    /// The smallest modulus whose PSS encoding fits the salt, if over
    /// `min_bits`: RFC 8017 section 9.1.1 needs `ceil((bits - 1) / 8)`
    /// bytes for the hash, the salt, and two more.
    const fn min_bits(self, min_bits: usize) -> usize {
        let salt = match self.padding {
            RsaPadding::Pkcs1 => return min_bits,
            RsaPadding::Pss(PssSalt::Hash) => self.hash.len(),
            RsaPadding::Pss(PssSalt::Max) => 0,
            RsaPadding::Pss(PssSalt::Len(len)) => len as usize,
        };
        let fits = 8 * (self.hash.len() + salt + 1) + 2;
        if fits > min_bits { fits } else { min_bits }
    }
}

enum RsaVerification {
    Scheme(RsaScheme),
    Pkcs1Sha1,
    PssAnySalt(HashId),
}

impl RsaVerification {
    const fn verifier(self) -> RsaVerify {
        match self {
            Self::Scheme(scheme) => scheme.verifier(),
            Self::Pkcs1Sha1 => |key, _, s, m| key.verify_pkcs1_sha1(s, m),
            Self::PssAnySalt(hash) => RsaScheme::pss(hash, PssSalt::Hash).verifier(),
        }
    }

    /// The PSS salt length to verify, `None` for any.
    fn salt(self) -> Option<PssSalt> {
        match self {
            Self::Scheme(scheme) => Some(scheme.salt()),
            Self::Pkcs1Sha1 | Self::PssAnySalt(_) => None,
        }
    }
}

pub struct VerificationAlgorithm {
    verification: RsaVerification,
    min_bits: usize,
    // The only path to the scheme's code, as ECDSA's algorithms hold theirs.
    verify: RsaVerify,
}

const fn verification(scheme: RsaScheme, min_bits: usize) -> VerificationAlgorithm {
    algorithm(RsaVerification::Scheme(scheme), scheme.min_bits(min_bits))
}

const fn algorithm(verification: RsaVerification, min_bits: usize) -> VerificationAlgorithm {
    VerificationAlgorithm {
        verification,
        min_bits,
        verify: verification.verifier(),
    }
}

pub struct SigningAlgorithm {
    scheme: RsaScheme,
    // The only path to the scheme's code, as `VerificationAlgorithm`'s.
    sign: RsaSign,
}

const fn signing(scheme: RsaScheme) -> SigningAlgorithm {
    SigningAlgorithm {
        scheme,
        sign: scheme.signer(),
    }
}

const PKCS1_SHA256_SCHEME: RsaScheme = RsaScheme {
    padding: RsaPadding::Pkcs1,
    hash: HashId::Sha256,
};

const PSS_SHA256_SCHEME: RsaScheme = RsaScheme::pss(HashId::Sha256, PssSalt::Hash);

pub(crate) const MIN_BITS: usize = 2048;

pub struct KeyPairComponents<B> {
    /// The modulus and public exponent, without leading zero bytes.
    pub public_key: PublicKeyComponents<B>,
    /// The private exponent.
    pub d: B,
    /// The first prime factor of the modulus.
    pub p: B,
    /// The second prime factor of the modulus.
    pub q: B,
    /// `d` mod `p - 1`.
    pub dp: B,
    /// `d` mod `q - 1`.
    pub dq: B,
    /// The inverse of `q` mod `p`.
    pub qi: B,
}

pub struct PublicKey {
    key: rsa::VerifyingKey,
    encoding: RsaPublicKeyDer,
}

struct RsaPublicKeyDer(Buffer<{ rsa::MAX_PUBLIC_KEY_LEN }>, [u64; 0]);

impl PublicKey {
    /// Parses a PKCS#1 `RSAPublicKey`, refusing a malformed key before any
    /// signature arrives.
    pub fn new(der: &[u8]) -> Result<Self, Error> {
        Self::from_key(rsa::VerifyingKey::from_pkcs1_der(der)?)
    }

    /// Parses a public key from its `SubjectPublicKeyInfo` DER, naming
    /// `rsaEncryption`, `id-RSAES-OAEP`, or `id-ea-rsa` with `NULL`
    /// parameters or none.
    pub fn from_spki(der: &[u8]) -> Result<Self, Error> {
        Self::from_key(rsa::VerifyingKey::from_spki_der(der)?)
    }

    /// Loads a public key from its big-endian modulus and exponent, as a
    /// JWK carries them.
    pub fn from_components(
        components: &PublicKeyComponents<impl AsRef<[u8]>>,
    ) -> Result<Self, Error> {
        let key = rsa::VerifyingKey::from_components(components.n.as_ref(), components.e.as_ref())?;
        Self::from_key(key)
    }

    fn from_key(key: rsa::VerifyingKey) -> Result<Self, Error> {
        Ok(Self {
            encoding: RsaPublicKeyDer(Buffer::write(|output| key.to_pkcs1_der(output))?, []),
            key,
        })
    }

    /// Encodes the public key as a `SubjectPublicKeyInfo` naming
    /// `rsaEncryption`.
    pub fn to_spki(&self) -> Spki {
        Spki(Buffer::encode(|output| self.key.to_spki_der(output)))
    }

    /// The modulus's length in bytes, which is also its signatures' length,
    /// so a caller can refuse a small key before it verifies anything.
    pub fn modulus_len(&self) -> usize {
        self.key.modulus_len_bits().div_ceil(8)
    }

    /// The modulus's length in bits, for a caller that enforces its own floor,
    /// such as one mirroring a library that refuses a key under 2048 bits.
    pub fn modulus_bits(&self) -> usize {
        self.key.modulus_len_bits()
    }

    /// Verifies `signature` over `message` with `algorithm`, refusing a
    /// malformed signature, and refusing the key if its modulus is below
    /// the algorithm's floor.
    pub fn verify(
        &self,
        algorithm: &VerificationAlgorithm,
        message: &[u8],
        signature: &[u8],
    ) -> Result<(), Error> {
        if self.key.modulus_len_bits() < algorithm.min_bits {
            return Err(KeyFormatError::RsaModulus.into());
        }
        (algorithm.verify)(&self.key, algorithm.verification.salt(), signature, message)
    }
}

pub struct Signature(Buffer<MAX_PUBLIC_MODULUS_BYTES>);

impl AsRef<[u8]> for Signature {
    fn as_ref(&self) -> &[u8] {
        self.0.as_ref()
    }
}

pub struct KeyPair {
    key: rsa::SigningKey,
    public: PublicKey,
}

impl KeyPair {
    /// Generates a key pair of `size` from the system random source.
    ///
    /// This is slow: about 30 milliseconds for 2048 bits, and 15 seconds or
    /// more for 8192 bits, with no upper bound. Its timing reveals only which
    /// candidate primes it discards.
    pub fn generate(size: RsaKeySize) -> Result<Self, Error> {
        Self::new(rsa::SigningKey::generate(size)?)
    }

    /// Loads a PKCS#8 v1 RSA private key, named `rsaEncryption`,
    /// `id-RSAES-OAEP`, or `id-ea-rsa`.
    pub fn from_pkcs8(der: &[u8]) -> Result<Self, Error> {
        Self::new(rsa::SigningKey::from_pkcs8_der(der)?)
    }

    /// Loads a PKCS#1 `RSAPrivateKey`.
    pub fn from_pkcs1(der: &[u8]) -> Result<Self, Error> {
        Self::new(rsa::SigningKey::from_pkcs1_der(der)?)
    }

    /// Loads a private key from its big-endian integers, as a JWK carries
    /// them, refusing one whose integers disagree.
    pub fn from_components(
        components: &KeyPairComponents<impl AsRef<[u8]>>,
    ) -> Result<Self, Error> {
        Self::new(rsa::SigningKey::from_components(&rsa::Components {
            n: components.public_key.n.as_ref(),
            e: components.public_key.e.as_ref(),
            d: components.d.as_ref(),
            p: components.p.as_ref(),
            q: components.q.as_ref(),
            dp: components.dp.as_ref(),
            dq: components.dq.as_ref(),
            qi: components.qi.as_ref(),
        })?)
    }

    fn new(key: rsa::SigningKey) -> Result<Self, Error> {
        let public = PublicKey::from_key(key.public_key())?;
        Ok(Self { key, public })
    }

    /// Returns the public key, which verifies what this key pair signs.
    pub fn public_key(&self) -> &PublicKey {
        &self.public
    }

    /// The bit lengths of the primes `p` and `q`, for a loader that sizes
    /// keys by them, as ring does.
    ///
    /// Loading a key already reveals them, as aws-lc treats them as public,
    /// and the encoding's framing shows their byte lengths.
    pub fn prime_bits(&self) -> [usize; 2] {
        self.key.prime_bits()
    }

    /// Signs `message` with `algorithm`, as long as the modulus.
    ///
    /// A PSS salt too long for the modulus is refused as the key's size.
    pub fn sign(&self, algorithm: &SigningAlgorithm, message: &[u8]) -> Result<Signature, Error> {
        Buffer::write(|output| {
            let output = output
                .get_mut(..self.key.modulus_len_bytes())
                .ok_or(Error::WrongLength)?;
            (algorithm.sign)(&self.key, algorithm.scheme.salt(), output, message)
        })
        .map(Signature)
    }

    /// Encodes the private key as PKCS#8.
    pub fn to_pkcs8(&self) -> Pkcs8 {
        Pkcs8(Buffer::encode(|output| self.key.to_pkcs8_der(output)))
    }
}

    pub static PKCS1_SHA256: SigningAlgorithm = signing(PKCS1_SHA256_SCHEME);

    pub static PSS_SHA256: SigningAlgorithm = signing(PSS_SHA256_SCHEME);

    pub static PKCS1_SHA256: VerificationAlgorithm = verification(PKCS1_SHA256_SCHEME, MIN_BITS);

    pub static PSS_SHA256: VerificationAlgorithm = verification(PSS_SHA256_SCHEME, MIN_BITS);

```

The model departs from the Rust in these ways, and adds no axiom:

- A `VerificationAlgorithm` is its `min_bits` and its `verify` with its
  `verification.salt()` passed, as `(key, signature, message)`:
  `algorithm` pairs the `verification` with that `verification`'s own
  `verifier()`, as the quote's only `VerificationAlgorithm` literal shows;
  `admin/prove` checks it is the only one.
- `verify::PKCS1_SHA256` is `verification(PKCS1_SHA256_SCHEME, 2048)`:
  `min_bits` 2048, as PKCS#1 v1.5 keeps the floor, `verify`
  `|key, _, s, m| key.verify_pkcs1_sha256(s, m)`, and salt
  `Some(PssSalt::Hash)`, which it ignores. `verify::PSS_SHA256` is
  `verification(PSS_SHA256_SCHEME, 2048)`: `min_bits` 2048, above PSS's
  8 · (32 + 32 + 1) + 2 = 522, `verify` `VerifyingKey::verify_pss_sha256`,
  and salt `Some(PssSalt::Hash)`.
- A `PublicKey`'s `encoding` is its `RsaPublicKeyDer`'s `Buffer`, as the
  empty array beside it holds nothing, of `MAX_PUBLIC_KEY_LEN`,
  8192 / 8 + 64 = 1088 bytes.
- `PublicKey::from_components` takes the components' `n` and `e` as
  slices, what their `as_ref` returns.
- `Buffer::write` is `SignatureBuffer`'s. The encoding it writes,
  `to_pkcs1_der`, is DER, which the ✓ leaves out, and opaque, as are
  `pkcs1_components` and `spki_components`, which `from_pkcs1_der` and
  `from_spki_der` read their components with.
- `?` is a `match`, since each error it passes on is already an `Error`.
- `to_spki`, `modulus_len`, `modulus_bits`, and `PublicKey`'s `AsRef`, which no theorem here
  is about, are not modelled.

Drops are not modelled, as everywhere in the translation.
-/

namespace rind.x86_64

/-- `VerificationAlgorithm`: the smallest modulus it accepts, and its
`verify` with its `verification.salt()` passed, as `(key, signature,
message)`. -/
structure high.signature.rsa.VerificationAlgorithm where
  min_bits : Std.Usize
  verify : high.rsa.VerifyingKey → Slice Std.U8 → Slice Std.U8 →
    Result (core.result.Result Unit error.Error)

/-- `PublicKey`, whose `encoding` is its `RsaPublicKeyDer`'s `Buffer`. -/
structure high.signature.rsa.PublicKey where
  key : high.rsa.VerifyingKey
  encoding : high.signature.Buffer 1088#usize

/-- `PublicKey::from_key`. -/
def high.signature.rsa.PublicKey.from_key (key : high.rsa.VerifyingKey) :
    Result (core.result.Result high.signature.rsa.PublicKey error.Error) := do
  let b ← high.signature.Buffer.write 1088#usize (high.rsa.VerifyingKey.to_pkcs1_der key)
  match b with
  | .Ok encoding => ok (.Ok { key, encoding })
  | .Err e => ok (.Err e)

/-- `PublicKey::new`. -/
def high.signature.rsa.PublicKey.new (der : Slice Std.U8) :
    Result (core.result.Result high.signature.rsa.PublicKey error.Error) := do
  let r ← high.rsa.VerifyingKey.from_pkcs1_der der
  match r with
  | .Ok key => high.signature.rsa.PublicKey.from_key key
  | .Err e => ok (.Err e)

/-- `PublicKey::from_spki`. -/
def high.signature.rsa.PublicKey.from_spki (der : Slice Std.U8) :
    Result (core.result.Result high.signature.rsa.PublicKey error.Error) := do
  let r ← high.rsa.VerifyingKey.from_spki_der der
  match r with
  | .Ok key => high.signature.rsa.PublicKey.from_key key
  | .Err e => ok (.Err e)

/-- `PublicKey::from_components`, with the components' `n` and `e`. -/
def high.signature.rsa.PublicKey.from_components (n e : Slice Std.U8) :
    Result (core.result.Result high.signature.rsa.PublicKey error.Error) := do
  let r ← high.rsa.VerifyingKey.from_components n e
  match r with
  | .Ok key => high.signature.rsa.PublicKey.from_key key
  | .Err e => ok (.Err e)

/-- `PublicKey::verify`. -/
def high.signature.rsa.PublicKey.verify (self : high.signature.rsa.PublicKey)
    (algorithm : high.signature.rsa.VerificationAlgorithm) (message signature : Slice Std.U8) :
    Result (core.result.Result Unit error.Error) := do
  let bits ← high.rsa.VerifyingKey.modulus_len_bits self.key
  if bits < algorithm.min_bits then
    let e ← core.convert.IntoFrom.into error.Error.Insts.CoreConvertFromKeyFormatError
      error.KeyFormatError.RsaModulus
    ok (.Err e)
  else algorithm.verify self.key signature message

/-- The `verify::PKCS1_SHA256` static, `verification(PKCS1_SHA256_SCHEME, MIN_BITS)`. -/
def high.signature.rsa.verify.PKCS1_SHA256 : high.signature.rsa.VerificationAlgorithm where
  min_bits := 2048#usize
  verify key signature message := high.rsa.VerifyingKey.verify_pkcs1_sha256 key signature message

/-- The `verify::PSS_SHA256` static, `verification(PSS_SHA256_SCHEME, MIN_BITS)`. -/
def high.signature.rsa.verify.PSS_SHA256 : high.signature.rsa.VerificationAlgorithm where
  min_bits := 2048#usize
  verify key signature message :=
    high.rsa.VerifyingKey.verify_pss_sha256 key (some .Hash) signature message

/-- A computation that meets a post returns a value meeting it. -/
theorem spec_eq_ok {α : Type} {m : Result α} {P : α → Prop} (h : WP.spec m P) : ∃ x, m = ok x ∧ P x := by
  cases m with
  | ret x => exact ⟨x, rfl, (WP.spec_ok x).mp h⟩
  | vis e k => exact absurd h (by simp [WP.spec_vis])
  | div => exact absurd h (by simp [WP.spec_div])

/-- A bind that returns ran its first step to a value. -/
theorem bind_eq_ok {α β : Type} {m : Result α} {k : α → Result β} {y : β} (h : Std.bind m k = ok y) :
    ∃ x, m = ok x ∧ k x = ok y := by
  cases m with
  | ret x => exact ⟨x, rfl, by simpa using h⟩
  | vis e k' =>
    have : WP.spec (Std.bind (vis e k') k) (fun _ => True) := by rw [h]; simp [WP.spec_ok]
    rw [bind_vis, WP.spec_vis] at this; exact this.elim
  | div =>
    have : WP.spec (Std.bind div k) (fun _ => True) := by rw [h]; simp [WP.spec_ok]
    rw [bind_div, WP.spec_div] at this; exact this.elim

/-- A public key `PublicKey::from_key` returns holds the key it was given,
which for a loaded `(N, E)` key has a modulus of 1017 to 8192 bits. -/
theorem from_key_ok {key : high.rsa.VerifyingKey} {N E : Nat} (hk : KeyLoaded key N E)
    {pk : high.signature.rsa.PublicKey}
    (hpk : high.signature.rsa.PublicKey.from_key key = ok (.Ok pk)) :
    KeyLoaded pk.key N E ∧ 1017 ≤ N.size ∧ N.size ≤ 8192 := by
  unfold high.signature.rsa.PublicKey.from_key at hpk
  obtain ⟨b, -, hb⟩ := bind_eq_ok hpk
  split at hb
  · simp only [ok.injEq, core.result.Result.Ok.injEq] at hb
    subst hb
    have hmin := hk.1.2.2.2.2.2.2.2.1
    have hmax := hk.1.2.2.2.2.2.2.2.2.1
    rw [hk.2.1] at hmin hmax
    exact ⟨hk, hmin, hmax⟩
  · simp at hb

/-- `PublicKey::new`: a key it returns is an `(N, E)` key of 1017 to 8192
bits, which `der` encodes as PKCS#1 DER the ✓ leaves out. -/
theorem rsa_signature_new_spec (h : Runs) (hheld : low.entry.Entry.assert_held = ok ()) (der : Slice U8)
    (pk : high.signature.rsa.PublicKey) (hpk : high.signature.rsa.PublicKey.new der = ok (.Ok pk)) :
    ∃ N E, KeyLoaded pk.key N E ∧ 1017 ≤ N.size ∧ N.size ≤ 8192 := by
  unfold high.signature.rsa.PublicKey.new high.rsa.VerifyingKey.from_pkcs1_der at hpk
  obtain ⟨r, hr, hk⟩ := bind_eq_ok hpk
  obtain ⟨_, -, hr⟩ := bind_eq_ok hr
  obtain ⟨x, -, hr⟩ := bind_eq_ok hr
  rcases x with ⟨n, e⟩ | err
  · simp only [core.result.Result.Insts.CoreOpsTry.branch, bind_ok] at hr
    change high.rsa.VerifyingKey.from_unsigned n e = ok r at hr
    have hs := from_unsigned_spec h hheld n e
    rw [hr, WP.spec_ok] at hs
    cases r with
    | Ok key => exact ⟨_, _, from_key_ok hs hk⟩
    | Err _ => simp at hk
  · simp only [core.result.Result.Insts.CoreOpsTry.branch, bind_ok,
      core.result.Result.Insts.CoreOpsTry_traitFromResidualResult.from_residual] at hr
    simp only [bind_tc_ok, ok.injEq] at hr
    subst hr
    simp at hk

/-- `PublicKey::from_spki`: a key it returns is an `(N, E)` key of 1017 to
8192 bits, which `der` encodes as `SubjectPublicKeyInfo` DER the ✓ leaves
out. -/
theorem rsa_signature_from_spki_spec (h : Runs) (hheld : low.entry.Entry.assert_held = ok ()) (der : Slice U8)
    (pk : high.signature.rsa.PublicKey) (hpk : high.signature.rsa.PublicKey.from_spki der = ok (.Ok pk)) :
    ∃ N E, KeyLoaded pk.key N E ∧ 1017 ≤ N.size ∧ N.size ≤ 8192 := by
  unfold high.signature.rsa.PublicKey.from_spki high.rsa.VerifyingKey.from_spki_der at hpk
  obtain ⟨r, hr, hk⟩ := bind_eq_ok hpk
  obtain ⟨_, -, hr⟩ := bind_eq_ok hr
  obtain ⟨x, -, hr⟩ := bind_eq_ok hr
  rcases x with ⟨n, e⟩ | err
  · change high.rsa.VerifyingKey.from_unsigned n e = ok r at hr
    have hs := from_unsigned_spec h hheld n e
    rw [hr, WP.spec_ok] at hs
    cases r with
    | Ok key => exact ⟨_, _, from_key_ok hs hk⟩
    | Err _ => simp at hk
  · simp only [ok.injEq] at hr
    subst hr
    simp at hk

/-- `PublicKey::from_components(&PublicKeyComponents { n, e })`: a key it
returns has the modulus and exponent `n` and `e` encode, of 1017 to 8192
bits. -/
theorem rsa_signature_from_components_spec (h : Runs) (hheld : low.entry.Entry.assert_held = ok ())
    (n e : Slice U8) (pk : high.signature.rsa.PublicKey)
    (hpk : high.signature.rsa.PublicKey.from_components n e = ok (.Ok pk)) :
    KeyLoaded pk.key (beNat n.val) (beNat e.val) ∧ 1017 ≤ (beNat n.val).size ∧ (beNat n.val).size ≤ 8192 := by
  unfold high.signature.rsa.PublicKey.from_components at hpk
  obtain ⟨r, hr, hk⟩ := bind_eq_ok hpk
  have hs := from_components_spec h hheld n e
  rw [hr, WP.spec_ok] at hs
  cases r with
  | Ok key => exact from_key_ok hs hk
  | Err _ => simp at hk

/-- `PublicKey::verify` with a loaded `(N, E)` key refuses it if its modulus
is under the algorithm's floor, and otherwise runs the algorithm's
`verify`. -/
theorem public_key_verify_spec (pk : high.signature.rsa.PublicKey)
    (algorithm : high.signature.rsa.VerificationAlgorithm) (N E : Nat) (hk : KeyLoaded pk.key N E)
    (message signature : Slice U8) {P : core.result.Result Unit error.Error → Prop}
    (hv : algorithm.min_bits.val ≤ N.size → algorithm.verify pk.key signature message ⦃ P ⦄) :
    high.signature.rsa.PublicKey.verify pk algorithm message signature ⦃ r =>
      if N.size < algorithm.min_bits.val then r = .Err (.KeyRejected .RsaModulus) else P r ⦄ := by
  obtain ⟨hinv, hN, -, -⟩ := hk
  unfold high.signature.rsa.PublicKey.verify high.rsa.VerifyingKey.modulus_len_bits
    mid.rsa_pub.RsaPublicKey.modulus_len_bits
  step with len_bits_spec pk.key.n hinv.2.1 as ⟨bits, hbits⟩
  rw [hN] at hbits
  split
  · rename_i hlt
    have hlt' : N.size < algorithm.min_bits.val := by rw [← hbits]; exact hlt
    simp [error.Error.Insts.CoreConvertFromKeyFormatError.from, hlt']
  · rename_i hge
    have hge' : ¬ N.size < algorithm.min_bits.val := by rw [← hbits]; exact hge
    apply WP.spec_mono (hv (by omega))
    intro r hr
    simpa [hge'] using hr

/-- `PublicKey::verify(&verify::PKCS1_SHA256, ..)` with a loaded `(N, E)`
key: refused if the modulus is under 2048 bits, and otherwise
RSASSA-PKCS1-V1_5-VERIFY with SHA-256, over Montgomery products at its
width, on any CPU whose check for AVX-512 IFMA returns. -/
theorem rsa_pkcs1_sha256_verify_spec (h : Runs) (hb : Sha256Blocks) (pk : high.signature.rsa.PublicKey)
    (N E : Nat) (hk : KeyLoaded pk.key N E) (hP : MontProducts ((N.size + 63) / 64)) (hifma : IfmaCheckReturns)
    (message signature : Slice U8) (hm : message.length ≤ maxInput) :
    high.signature.rsa.PublicKey.verify pk high.signature.rsa.verify.PKCS1_SHA256 message signature ⦃ r =>
      if N.size < 2048 then r = .Err (.KeyRejected .RsaModulus)
      else (r = .Ok () ↔ rsassaPkcs1v15Verify N E sha256.hash digestInfoSha256 (bv message.val)
        (bv signature.val)) ⦄ := by
  refine public_key_verify_spec pk _ N E hk message signature fun _ => ?_
  obtain ⟨hinv, hN, hE, hused⟩ := hk
  dsimp only [high.signature.rsa.verify.PKCS1_SHA256]
  rw [← hN, ← hE]
  exact verify_pkcs1_sha256_spec h hb pk.key hinv (by rw [hused, ← hN]; exact hN ▸ hP) hifma signature message hm

/-- `PublicKey::verify(&verify::PSS_SHA256, ..)` with a loaded `(N, E)` key:
refused if the modulus is under 2048 bits, and otherwise RSASSA-PSS-VERIFY
with SHA-256, MGF1 with SHA-256, and a 32-byte salt, over Montgomery
products at its width, on any CPU whose check for AVX-512 IFMA returns. -/
theorem rsa_pss_sha256_verify_spec (h : Runs) (hb : Sha256Blocks) (pk : high.signature.rsa.PublicKey)
    (N E : Nat) (hk : KeyLoaded pk.key N E) (hP : MontProducts ((N.size + 63) / 64)) (hifma : IfmaCheckReturns)
    (message signature : Slice U8) (hm : message.length ≤ maxInput) :
    high.signature.rsa.PublicKey.verify pk high.signature.rsa.verify.PSS_SHA256 message signature ⦃ r =>
      if N.size < 2048 then r = .Err (.KeyRejected .RsaModulus)
      else (r = .Ok () ↔ RsassaPss N E sha256.hash 32 (bv message.val) (bv signature.val) (some 32)) ⦄ := by
  refine public_key_verify_spec pk _ N E hk message signature fun _ => ?_
  obtain ⟨hinv, hN, hE, hused⟩ := hk
  dsimp only [high.signature.rsa.verify.PSS_SHA256]
  rw [← hN, ← hE]
  have := verify_pss_sha256_spec h hb pk.key hinv (by rw [hused, ← hN]; exact hN ▸ hP) hifma (some .Hash)
    signature message hm
  simpa [pssSaltLen] using this

-- BEGIN x86_64
/-- A 2048-bit modulus fills 32 words, whose Montgomery products rind runs
on s2n-bignum's proven routines on a CPU with BMI2 and ADX. -/
theorem rsa2048_mont_products (o : Option low.x86_64.cpu.HaveBmi2Adx)
    (hcheck : low.x86_64.cpu.HaveBmi2Adx.check = ok o) (hsome : o.isSome) (N : Nat) (hN : N.size = 2048) :
    MontProducts ((N.size + 63) / 64) := by
  rw [hN]
  exact karatsuba_products o hcheck hsome (Or.inr rfl)
-- END x86_64

-- BEGIN x86_64
/-! ## Key pairs, on x86_64 -/

/-- `SigningAlgorithm`: its `sign` with its `scheme.salt()` passed, as `(key,
output, message)`. -/
structure high.signature.rsa.SigningAlgorithm where
  sign : high.rsa.SigningKey → Slice Std.U8 → Slice Std.U8 →
    Result (core.result.Result (Slice Std.U8) error.Error × Slice Std.U8)

/-- `KeyPair`. -/
structure high.signature.rsa.KeyPair where
  key : high.rsa.SigningKey
  «public» : high.signature.rsa.PublicKey

/-- `KeyPair::new`. -/
def high.signature.rsa.KeyPair.new (key : high.rsa.SigningKey) :
    Result (core.result.Result high.signature.rsa.KeyPair error.Error) := do
  let vk ← high.rsa.SigningKey.public_key key
  let r ← high.signature.rsa.PublicKey.from_key vk
  match r with
  | .Ok «public» => ok (.Ok { key, «public» })
  | .Err e => ok (.Err e)

/-- `KeyPair::from_pkcs8`. -/
def high.signature.rsa.KeyPair.from_pkcs8 (der : Slice Std.U8) :
    Result (core.result.Result high.signature.rsa.KeyPair error.Error) := do
  let r ← high.rsa.SigningKey.from_pkcs8_der der
  match r with
  | .Ok key => high.signature.rsa.KeyPair.new key
  | .Err e => ok (.Err e)

/-- `KeyPair::from_pkcs1`. -/
def high.signature.rsa.KeyPair.from_pkcs1 (der : Slice Std.U8) :
    Result (core.result.Result high.signature.rsa.KeyPair error.Error) := do
  let r ← high.rsa.SigningKey.from_pkcs1_der der
  match r with
  | .Ok key => high.signature.rsa.KeyPair.new key
  | .Err e => ok (.Err e)

/-- `KeyPair::from_components`, with the components' integers. -/
def high.signature.rsa.KeyPair.from_components (n e d p q dp dq qi : Slice Std.U8) :
    Result (core.result.Result high.signature.rsa.KeyPair error.Error) := do
  let r ← high.rsa.SigningKey.from_components { n, e, d, p, q, dp, dq, qi }
  match r with
  | .Ok key => high.signature.rsa.KeyPair.new key
  | .Err e => ok (.Err e)

/-- `KeyPair::sign`. -/
def high.signature.rsa.KeyPair.sign (self : high.signature.rsa.KeyPair)
    (algorithm : high.signature.rsa.SigningAlgorithm) (message : Slice Std.U8) :
    Result (core.result.Result high.signature.rsa.Signature error.Error) :=
  high.signature.Buffer.write 1024#usize fun output => do
    let k ← high.rsa.SigningKey.modulus_len_bytes self.key
    let o ← core.slice.Slice.get_mut (core.slice.index.SliceIndexRangeToUsizeSlice Std.U8) output { «end» := k }
    match o.1 with
    | none => ok (.Err .WrongLength, o.2 none)
    | some out =>
      let r ← algorithm.sign self.key out message
      ok (r.1, o.2 (some r.2))

/-- The `sign::PKCS1_SHA256` static, `signing(PKCS1_SHA256_SCHEME)`. -/
def high.signature.rsa.sign.PKCS1_SHA256 : high.signature.rsa.SigningAlgorithm where
  sign key out m := high.rsa.SigningKey.sign_pkcs1_sha256 key out m

/-- The `sign::PSS_SHA256` static, `signing(PSS_SHA256_SCHEME)`. -/
def high.signature.rsa.sign.PSS_SHA256 : high.signature.rsa.SigningAlgorithm where
  sign key out m := high.rsa.SigningKey.sign_pss_sha256 key .Hash out m

/-- `KeyPair::sign` runs the algorithm's `sign` on the first `k` bytes of its
buffer, `k` the modulus's length, and returns what that wrote. -/
theorem key_pair_sign_of (h : Runs) (kp : high.signature.rsa.KeyPair) (hinv : PubKeyInv kp.key.public)
    (algorithm : high.signature.rsa.SigningAlgorithm) (message : Slice U8)
    (P : core.result.Result (Slice U8) error.Error → Prop)
    (hs : ∀ out : Slice U8, out.length = octetLen (keyN kp.key) →
      algorithm.sign kp.key out message ⦃ r sig' =>
        P r ∧ ∀ s, r = .Ok s → sig'.length = out.length ∧ sig'.val.take s.length = s.val ⦄) :
    high.signature.rsa.KeyPair.sign kp algorithm message ⦃ r =>
      (∀ sig, r = .Ok sig → ∃ s, P (.Ok s) ∧
        high.signature.rsa.Signature.Insts.CoreConvertAsRefSliceU8.as_ref sig ⦃ b => b.val = s.val ⦄) ∧
      ∀ e, r = .Err e → P (.Err e) ⦄ := by
  unfold high.signature.rsa.KeyPair.sign high.signature.Buffer.write high.signature.Buffer.new
  simp only [lift, bind_ok, Array.to_slice_mut]
  step with signing_modulus_len_bytes_spec h kp.key hinv as ⟨k, hk⟩
  obtain ⟨-, -, -, -, -, -, -, -, hs2, -⟩ := hinv
  have hk1024 : k.val ≤ 1024 := by rw [hk, octetLen]; unfold keyN; omega
  have hzl : (Array.repeat 1024#usize 0#u8).to_slice.length = 1024 := by
    simp only [Slice.length, Array.val_to_slice]; exact (Array.repeat 1024#usize 0#u8).property
  have hle : k ≤ (Array.repeat 1024#usize 0#u8).to_slice.length := by rw [hzl]; exact hk1024
  simp only [core.slice.Slice.get_mut, core.slice.index.SliceIndexRangeToUsizeSlice.get_mut, hle,
    ↓reduceIte, bind_ok]
  set Z := (Array.repeat 1024#usize 0#u8).to_slice with hZ
  have hZL : Z.val.length = 1024 := hzl
  simp only [Std.bind_assoc]
  have hXl : (List.slice 0 k.val Z.val).length = k.val := by
    rw [List.slice_zero_j, List.length_take]; omega
  apply WP.spec_bind (hs (Slice.from (List.slice 0 k.val Z.val) (by scalar_tac)) (by
    simp only [Slice.length, Slice.from_val]; rw [hXl, hk]))
  rintro ⟨r, sig'⟩ ⟨hP, hok⟩
  rcases r with sv | e
  · obtain ⟨hl, ht⟩ := hok sv rfl
    have hl' : sig'.val.length = k.val := by
      have : sig'.length = _ := hl; show sig'.length = k.val; rw [this]
      simp only [Slice.length, Slice.from_val]; exact hXl
    simp only [bind_ok, WP.spec_ok]
    refine ⟨fun sig hsig => ⟨sv, hP, ?_⟩, fun e h => nomatch h⟩
    cases hsig
    unfold high.signature.rsa.Signature.Insts.CoreConvertAsRefSliceU8.as_ref
    have hsvl : sv.val.length ≤ k.val := by
      have := congrArg List.length ht; rw [List.length_take] at this; omega
    apply WP.spec_mono (buffer_as_ref_spec _ (by show sv.length ≤ 1024; have : sv.length = sv.val.length := rfl; omega))
    intro b hb
    rw [hb]
    have hd : sig'.length = k.val := hl'
    simp only [hd, ↓reduceDIte]
    rw [Array.from_slice_val _ _ (by simp only [Slice.from_val]; rw [setSlice!_length', hZL]; rfl),
      Slice.from_val]
    have h1 := take_setSlice! Z.val sig'.val 0 (by omega)
    simp only [Nat.zero_add, List.take_zero, List.nil_append] at h1
    have : sv.len.val = sv.val.length := rfl
    rw [this, ← Nat.min_eq_left hsvl, ← hl', ← List.take_take, h1]
    exact ht
  · simp only [bind_ok, WP.spec_ok]
    refine ⟨fun sig h => (nomatch h), fun e' h => ?_⟩
    cases h
    exact hP

/-- A key pair holding the two-prime RSA private key `(n, e, d, p, q, dP, dQ,
qInv)`, which meets RFC 8017's relations but for the primes' primality, with
the values `RsaPrivateKey::new` computes from it, working at the wider
prime's width, and its own public key. -/
def KeyPairOf (kp : high.signature.rsa.KeyPair) (N E D P Q DP DQ QINV : Nat) : Prop :=
  PrivKeyInv kp.key ∧ kp.public.key = kp.key.public ∧ KeyLoaded kp.public.key N E ∧
    wordsNat (lowWords kp.key.d kp.key.d.used) = D ∧
    wordsNat (lowWords kp.key.p kp.key.p.used) = P ∧
    wordsNat (lowWords kp.key.q kp.key.p.used) = Q ∧
    wordsNat (lowWords kp.key.dp kp.key.dp.used) = DP ∧
    wordsNat (lowWords kp.key.dq kp.key.dq.used) = DQ ∧
    wordsNat (lowWords kp.key.iqmp kp.key.p.used) = QINV ∧
    kp.key.p.used.val = keyWords P Q ∧
    CrtRelations N P Q D DP DQ QINV E

/-- A key pair `KeyPair::new` makes of a key loaded from components holds
that key and its public key. -/
theorem key_pair_new_ok (h : Runs) {c : high.rsa.Components} {key : high.rsa.SigningKey} (hk : KeyFrom c key)
    {kp : high.signature.rsa.KeyPair} (hkp : high.signature.rsa.KeyPair.new key = ok (.Ok kp)) :
    KeyPairOf kp (beNat c.n.val) (beNat c.e.val) (beNat c.d.val) (beNat c.p.val) (beNat c.q.val)
      (beNat c.dp.val) (beNat c.dq.val) (beNat c.qi.val) := by
  obtain ⟨hinv, hn, he, hd, hp, hq, hdp, hdq, hqi, hpw, hcrt⟩ := hk
  unfold high.signature.rsa.KeyPair.new at hkp
  obtain ⟨vk, hvk, hkp⟩ := bind_eq_ok hkp
  have hs := signing_public_key_spec h key
  rw [hvk, WP.spec_ok] at hs
  subst hs
  obtain ⟨r, hr, hkp⟩ := bind_eq_ok hkp
  rcases r with pk | e
  · simp only [ok.injEq, core.result.Result.Ok.injEq] at hkp
    subst hkp
    have hkl := keyLoaded_of_inv key.public hinv.1
    obtain ⟨hl, -⟩ := from_key_ok hkl hr
    have hpk : pk.key = key.public := by
      unfold high.signature.rsa.PublicKey.from_key at hr
      obtain ⟨b, -, hb⟩ := bind_eq_ok hr
      split at hb
      · simp only [ok.injEq, core.result.Result.Ok.injEq] at hb; rw [← hb]
      · simp at hb
    refine ⟨hinv, hpk, ?_, hd, hp, hq, hdp, hdq, hqi, hpw, hcrt⟩
    rw [← he, ← hn]
    exact hl
  · simp at hkp

/-- `KeyPair::from_components(&KeyPairComponents { .. })`: a key pair it
returns holds the two-prime RSA private key its big-endian integers are,
which meet RFC 8017's relations but for the primes' primality, given
Montgomery products at the wider prime's width. -/
theorem rsa_key_pair_from_components_spec (h : Runs) (hheld : low.entry.Entry.assert_held = ok ())
    (hifma : IfmaCheckReturns) (hfp16 : ∀ t, ∃ b, low.x86_64.cpu.HaveAvx512ForRsa.fp16 t = ok b)
    (n e d p q dp dq qi : Slice U8) (hP : MontProducts (keyWords (beNat p.val) (beNat q.val)))
    (kp : high.signature.rsa.KeyPair)
    (hkp : high.signature.rsa.KeyPair.from_components n e d p q dp dq qi = ok (.Ok kp)) :
    KeyPairOf kp (beNat n.val) (beNat e.val) (beNat d.val) (beNat p.val) (beNat q.val) (beNat dp.val)
      (beNat dq.val) (beNat qi.val) := by
  unfold high.signature.rsa.KeyPair.from_components at hkp
  obtain ⟨r, hr, hkp⟩ := bind_eq_ok hkp
  have hs := signing_from_components_spec h hheld hifma hfp16 { n, e, d, p, q, dp, dq, qi } hP
  rw [hr, WP.spec_ok] at hs
  rcases r with key | err
  · exact key_pair_new_ok h (hs key rfl) hkp
  · simp at hkp

/-- A key `SigningKey::from_pkcs1_der` returns is one `from_unsigned` loaded
from some components. -/
theorem signing_from_pkcs1_ok {der : Slice U8} {key : high.rsa.SigningKey}
    (hk : high.rsa.SigningKey.from_pkcs1_der der = ok (.Ok key)) :
    ∃ c, high.rsa.SigningKey.from_unsigned c = ok (.Ok key) := by
  unfold high.rsa.SigningKey.from_pkcs1_der at hk
  obtain ⟨_, -, hk⟩ := bind_eq_ok hk
  obtain ⟨r, -, hk⟩ := bind_eq_ok hk
  obtain ⟨cf, hcf, hk⟩ := bind_eq_ok hk
  rcases r with c | err
  · simp only [core.result.Result.Insts.CoreOpsTry.branch, ok.injEq] at hcf
    subst hcf
    exact ⟨c, hk⟩
  · simp only [core.result.Result.Insts.CoreOpsTry.branch, ok.injEq] at hcf
    subst hcf
    simp [core.result.Result.Insts.CoreOpsTry_traitFromResidualResult.from_residual,
      core.convert.FromSame.from] at hk

/-- A key pair whose key `from_unsigned` loaded from `c` holds it, given
Montgomery products at the wider prime's width. -/
theorem key_pair_of_unsigned (h : Runs) (hheld : low.entry.Entry.assert_held = ok ())
    (hifma : IfmaCheckReturns) (hfp16 : ∀ t, ∃ b, low.x86_64.cpu.HaveAvx512ForRsa.fp16 t = ok b)
    {c : high.rsa.Components} {key : high.rsa.SigningKey} (hk : high.rsa.SigningKey.from_unsigned c = ok (.Ok key))
    (hP : MontProducts (keyWords (beNat c.p.val) (beNat c.q.val)))
    {kp : high.signature.rsa.KeyPair} (hkp : high.signature.rsa.KeyPair.new key = ok (.Ok kp)) :
    KeyPairOf kp (beNat c.n.val) (beNat c.e.val) (beNat c.d.val) (beNat c.p.val) (beNat c.q.val)
      (beNat c.dp.val) (beNat c.dq.val) (beNat c.qi.val) := by
  have hs := from_unsigned_priv_spec h hheld hifma hfp16 c hP
  rw [hk, WP.spec_ok] at hs
  exact key_pair_new_ok h (hs key rfl) hkp

/-- `KeyPair::from_pkcs1`: a key pair it returns holds the two-prime RSA
private key of the integers its PKCS#1 DER, which the ✓ leaves out, encodes,
which meet RFC 8017's relations but for the primes' primality, given
Montgomery products at the wider prime's width. -/
theorem rsa_key_pair_from_pkcs1_spec (h : Runs) (hheld : low.entry.Entry.assert_held = ok ())
    (hifma : IfmaCheckReturns) (hfp16 : ∀ t, ∃ b, low.x86_64.cpu.HaveAvx512ForRsa.fp16 t = ok b)
    (der : Slice U8) (kp : high.signature.rsa.KeyPair)
    (hkp : high.signature.rsa.KeyPair.from_pkcs1 der = ok (.Ok kp)) :
    ∃ c : high.rsa.Components, MontProducts (keyWords (beNat c.p.val) (beNat c.q.val)) →
      KeyPairOf kp (beNat c.n.val) (beNat c.e.val) (beNat c.d.val) (beNat c.p.val) (beNat c.q.val)
        (beNat c.dp.val) (beNat c.dq.val) (beNat c.qi.val) := by
  unfold high.signature.rsa.KeyPair.from_pkcs1 at hkp
  obtain ⟨r, hr, hkp⟩ := bind_eq_ok hkp
  rcases r with key | err
  · obtain ⟨c, hc⟩ := signing_from_pkcs1_ok hr
    exact ⟨c, fun hP => key_pair_of_unsigned h hheld hifma hfp16 hc hP hkp⟩
  · simp at hkp

/-- `KeyPair::from_pkcs8`: a key pair it returns holds the two-prime RSA
private key of the integers its PKCS#8 DER, which the ✓ leaves out, encodes,
which meet RFC 8017's relations but for the primes' primality, given
Montgomery products at the wider prime's width. -/
theorem rsa_key_pair_from_pkcs8_spec (h : Runs) (hheld : low.entry.Entry.assert_held = ok ())
    (hifma : IfmaCheckReturns) (hfp16 : ∀ t, ∃ b, low.x86_64.cpu.HaveAvx512ForRsa.fp16 t = ok b)
    (der : Slice U8) (kp : high.signature.rsa.KeyPair)
    (hkp : high.signature.rsa.KeyPair.from_pkcs8 der = ok (.Ok kp)) :
    ∃ c : high.rsa.Components, MontProducts (keyWords (beNat c.p.val) (beNat c.q.val)) →
      KeyPairOf kp (beNat c.n.val) (beNat c.e.val) (beNat c.d.val) (beNat c.p.val) (beNat c.q.val)
        (beNat c.dp.val) (beNat c.dq.val) (beNat c.qi.val) := by
  unfold high.signature.rsa.KeyPair.from_pkcs8 at hkp
  obtain ⟨r, hr, hkp⟩ := bind_eq_ok hkp
  rcases r with key | err
  · unfold high.rsa.SigningKey.from_pkcs8_der at hr
    obtain ⟨_, -, hr⟩ := bind_eq_ok hr
    obtain ⟨r2, -, hr⟩ := bind_eq_ok hr
    obtain ⟨cf, hcf, hr⟩ := bind_eq_ok hr
    rcases r2 with inner | err
    · simp only [core.result.Result.Insts.CoreOpsTry.branch, ok.injEq] at hcf
      subst hcf
      obtain ⟨c, hc⟩ := signing_from_pkcs1_ok hr
      exact ⟨c, fun hP => key_pair_of_unsigned h hheld hifma hfp16 hc hP hkp⟩
    · simp only [core.result.Result.Insts.CoreOpsTry.branch, ok.injEq] at hcf
      subst hcf
      simp [core.result.Result.Insts.CoreOpsTry_traitFromResidualResult.from_residual,
        core.convert.FromSame.from] at hr
  · simp at hkp
/-- `KeyPair::sign(&sign::PKCS1_SHA256, ..)` with a key pair holding `(n, e,
d, p, q, dP, dQ, qInv)`: RSASSA-PKCS1-V1_5-SIGN with SHA-256 and RSASP1 by
the CRT, over Montgomery products at the modulus's width and, where rind's
CRT runs, the primes'. It refuses only with `Fault`, where RSASP1's result
raised to `e` modulo `n` is not the encoded message's representative, which
two primes rule out. -/
theorem rsa_pkcs1_sha256_sign_spec (h : Runs) (hb : Sha256Blocks)
    (t : low.x86_64.cpu.HaveBmi2Adx) (hadx : low.x86_64.cpu.HaveBmi2Adx.check = ok (some t))
    (hifma : IfmaCheckReturns) (kp : high.signature.rsa.KeyPair) (N E D P Q DP DQ QINV : Nat)
    (hkp : KeyPairOf kp N E D P Q DP DQ QINV) (hPn : MontProducts ((N.size + 63) / 64))
    (hcrt : kp.key.ifma.w = 0#usize → MontProducts (keyWords P Q) ∧
      (keyWords P Q = 16 ∨ keyWords P Q = 32) ∧ NoRsazPair (keyWords P Q))
    (message : Slice U8) (hm : message.length ≤ maxInput) :
    high.signature.rsa.KeyPair.sign kp high.signature.rsa.sign.PKCS1_SHA256 message ⦃ r =>
      (∀ sig, r = .Ok sig → high.signature.rsa.Signature.Insts.CoreConvertAsRefSliceU8.as_ref sig ⦃ b =>
        rsassaPkcs1v15Sign N P Q DP DQ QINV sha256.hash digestInfoSha256 (bv message.val) = some (bv b.val) ⦄) ∧
      ∀ e, r = .Err e → e = .Fault ∧ ∃ EM, emsaPkcs1v15Encode sha256.hash digestInfoSha256 (bv message.val)
        (octetLen N) = some EM ∧ rsasp1Crt P Q DP DQ QINV (os2ip EM) ^ E % N ≠ os2ip EM ⦄ := by
  obtain ⟨hinv, hpub, hkl, hD, hP, hQ, hDP, hDQ, hQI, hpw, hrel⟩ := hkp
  obtain ⟨-, hN, hE, hused⟩ := hkl
  rw [hpub] at hN hE hused
  have hkN : keyN kp.key = N := hN
  have hkey : ∀ c, keyRsasp1 kp.key c = rsasp1Crt P Q DP DQ QINV c := by
    intro c; unfold keyRsasp1; rw [hP, hQ, hDP, hDQ, hQI]
  have hs := key_pair_sign_of h kp hinv.1 high.signature.rsa.sign.PKCS1_SHA256 message
    (fun r => ∃ EM : List U8, emsaPkcs1v15Encode sha256.hash digestInfoSha256 (bv message.val)
      (octetLen (keyN kp.key)) = some (bv EM) ∧ SignedAs kp.key EM r)
    (fun out hout => by
      apply WP.spec_mono (sign_pkcs1_sha256_spec h hb t hadx hifma kp.key hinv (by rw [hused]; exact hPn)
        (by rw [hpw]; exact hcrt) out message hm (by omega))
      rintro ⟨r, sig'⟩ hr
      obtain ⟨EM, hEM, hSA, hok⟩ := hr
      exact ⟨⟨EM, hEM, hSA⟩, hok⟩)
  apply WP.spec_mono hs
  rintro r ⟨hok, herr⟩
  refine ⟨fun sig hsig => ?_, fun e he => ?_⟩
  · obtain ⟨s, ⟨EM, hEM, hSA⟩, has⟩ := hok sig hsig
    apply WP.spec_mono has
    intro b hb
    simp only [SignedAs] at hSA
    unfold rsassaPkcs1v15Sign
    rw [← hkN, hEM, Option.bind_some, os2ip_bv, ← hkey, hb]
    exact hSA
  · obtain ⟨EM, hEM, hSA⟩ := herr e he
    simp only [SignedAs] at hSA
    obtain ⟨rfl, hne⟩ := hSA
    refine ⟨rfl, bv EM, by rw [← hkN]; exact hEM, ?_⟩
    rw [os2ip_bv, ← hkey, ← hkN, ← hE]
    exact hne

/-- `KeyPair::sign(&sign::PSS_SHA256, ..)` with a key pair holding `(n, e, d,
p, q, dP, dQ, qInv)`: RSASSA-PSS-SIGN with SHA-256, MGF1 with SHA-256, a
32-byte salt the system random source drew, and RSASP1 by the CRT, over
Montgomery products at the modulus's width and, where rind's CRT runs, the
primes'. It refuses only a failed draw, with `RngFailed`, and with `Fault`
where RSASP1's result raised to `e` modulo `n` is not the encoded message's
representative, which two primes rule out. -/
theorem rsa_pss_sha256_sign_spec (h : Runs) (hb : Sha256Blocks) (hfill : Fills)
    (t : low.x86_64.cpu.HaveBmi2Adx) (hadx : low.x86_64.cpu.HaveBmi2Adx.check = ok (some t))
    (hifma : IfmaCheckReturns) (kp : high.signature.rsa.KeyPair) (N E D P Q DP DQ QINV : Nat)
    (hkp : KeyPairOf kp N E D P Q DP DQ QINV) (hPn : MontProducts ((N.size + 63) / 64))
    (hcrt : kp.key.ifma.w = 0#usize → MontProducts (keyWords P Q) ∧
      (keyWords P Q = 16 ∨ keyWords P Q = 32) ∧ NoRsazPair (keyWords P Q))
    (message : Slice U8) (hm : message.length ≤ maxInput) :
    high.signature.rsa.KeyPair.sign kp high.signature.rsa.sign.PSS_SHA256 message ⦃ r =>
      (∀ sig, r = .Ok sig → ∃ salt : List U8, salt.length = 32 ∧
        high.signature.rsa.Signature.Insts.CoreConvertAsRefSliceU8.as_ref sig ⦃ b =>
          rsassaPssSign N P Q DP DQ QINV sha256.hash 32 (bv message.val) (bv salt) = some (bv b.val) ⦄) ∧
      ∀ e, r = .Err e → e = .RngFailed ∨ e = .Fault ∧ ∃ salt : List U8, salt.length = 32 ∧
        ∃ EM, emsaPssEncode sha256.hash 32 (bv message.val) (bv salt) (N.size - 1) = some EM ∧
          rsasp1Crt P Q DP DQ QINV (os2ip EM) ^ E % N ≠ os2ip EM ⦄ := by
  obtain ⟨hinv, hpub, hkl, hD, hP, hQ, hDP, hDQ, hQI, hpw, hrel⟩ := hkp
  have hs1 := hinv.1.2.2.2.2.2.2.2.1
  obtain ⟨-, hN, hE, hused⟩ := hkl
  rw [hpub] at hN hE hused
  have hkN : keyN kp.key = N := hN
  have hkey : ∀ c, keyRsasp1 kp.key c = rsasp1Crt P Q DP DQ QINV c := by
    intro c; unfold keyRsasp1; rw [hP, hQ, hDP, hDQ, hQI]
  have hsalt : pssSaltLen (((keyN kp.key).size - 1 + 7) / 8) 32 .Hash = 32 := rfl
  have hs := key_pair_sign_of h kp hinv.1 high.signature.rsa.sign.PSS_SHA256 message
    (fun r => (∃ e, r = .Err e ∧ e = .RngFailed) ∨ ∃ salt : List U8, salt.length = 32 ∧
      ∃ EM : List U8, emsaPssEncode sha256.hash 32 (bv message.val) (bv salt) ((keyN kp.key).size - 1) =
        some (bv EM) ∧ SignedAs kp.key EM r)
    (fun out hout => by
      apply WP.spec_mono (sign_pss_sha256_spec h hb hfill t hadx hifma kp.key hinv (by rw [hused]; exact hPn)
        (by rw [hpw]; exact hcrt) .Hash out message hm (by omega))
      rintro ⟨r, sig'⟩ hr
      rw [hsalt] at hr
      rcases hr with ⟨e, he, hrng | ⟨-, hlt⟩⟩ | ⟨salt, hsl, EM, hEM, hSA, hok⟩
      · exact ⟨Or.inl ⟨e, he, hrng⟩, fun s h => by rw [he] at h; exact (nomatch h)⟩
      · exfalso; unfold keyN at hlt; omega
      · exact ⟨Or.inr ⟨salt, hsl, EM, hEM, hSA⟩, hok⟩)
  apply WP.spec_mono hs
  rintro r ⟨hok, herr⟩
  refine ⟨fun sig hsig => ?_, fun e he => ?_⟩
  · obtain ⟨s, hPs, has⟩ := hok sig hsig
    rcases hPs with ⟨e, he, -⟩ | ⟨salt, hsl, EM, hEM, hSA⟩
    · cases he
    refine ⟨salt, hsl, ?_⟩
    apply WP.spec_mono has
    intro b hb
    simp only [SignedAs] at hSA
    unfold rsassaPssSign
    rw [← hkN, hEM, Option.bind_some, os2ip_bv, ← hkey, hb]
    exact hSA
  · rcases herr e he with ⟨e', he', hrng⟩ | ⟨salt, hsl, EM, hEM, hSA⟩
    · cases he'; exact Or.inl hrng
    · simp only [SignedAs] at hSA
      obtain ⟨rfl, hne⟩ := hSA
      refine Or.inr ⟨rfl, salt, hsl, bv EM, by rw [← hkN]; exact hEM, ?_⟩
      rw [os2ip_bv, ← hkey, ← hkN, ← hE]
      exact hne
-- END x86_64

end rind.x86_64
