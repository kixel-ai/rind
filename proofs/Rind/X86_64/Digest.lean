module
public import Aeneas
public import Rind.Core
@[expose] public section
open Aeneas Aeneas.Std Result
set_option linter.dupNamespace false

/-!
# The digest module, modelled by hand

`high::digest`'s `Algorithm` holds function pointers, which Aeneas cannot
translate, so the translation leaves the module opaque and this file models
what the hashes and HMAC call of it. `admin/prove` fails unless these quotes
are still that Rust, so a change to it is a change to this model:

```rust
pub struct Algorithm {
    id: Id,
    output_len: usize,
    // The only paths to the hash's code, so a binary links only the hashes
    // whose algorithms it names.
    hash: fn(&[u8]) -> Digest,
    start: fn() -> State,
}

enum Id {
    Sha1,
    Sha256,
    Sha384,
    Sha512,
    Sha512_256,
}

pub static SHA1: Algorithm = Algorithm {
    id: Id::Sha1,
    output_len: sha1::Sha1Context::OUTPUT_SZ,
    hash: LegacySha1::hash,
    start: Hashing::<Sha1Context>::start,
};

pub static SHA256: Algorithm = Algorithm {
    id: Id::Sha256,
    output_len: sha2::Sha256Context::OUTPUT_SZ,
    hash: Sha256::hash,
    start: Hashing::<Sha256Context>::start,
};

pub struct Digest {
    algorithm: &'static Algorithm,
    value: [u8; MAX_OUTPUT_LEN],
}

impl Digest {
    /// A digest of `algorithm` holding `value`, which must be its output length.
    pub(crate) fn new(algorithm: &'static Algorithm, value: &[u8]) -> Self {
        let mut digest = Self::zeroed(algorithm);
        digest.as_mut().copy_from_slice(value);
        digest
    }

    /// A zeroed digest of `algorithm`, for building one in place.
    pub(crate) fn zeroed(algorithm: &'static Algorithm) -> Self {
        Self {
            algorithm,
            value: [0; MAX_OUTPUT_LEN],
        }
    }

    pub(crate) fn as_mut(&mut self) -> &mut [u8] {
        &mut self.value[..self.algorithm.output_len]
    }

    /// Constant-time equality, `other` may not be truncated.
    pub(crate) fn ct_equal(&self, other: &[u8]) -> bool {
        ct::into_public(ct_equal(self.as_ref(), other))
    }
}

impl AsRef<[u8]> for Digest {
    fn as_ref(&self) -> &[u8] {
        &self.value[..self.algorithm.output_len]
    }
}

```

The model departs from the Rust in two ways, and adds no axiom:

- `Algorithm` drops its `hash` and `start` pointers, which nothing modelled
  calls.
- `Digest` holds its `&'static Algorithm` by value.

Of the algorithm statics, only `SHA1` and `SHA256` are modelled, and
`MAX_OUTPUT_LEN` is SHA-512's output length, 64. `ct_equal` is not modelled
yet: nothing proven calls it.
-/

namespace rind.x86_64

/-- `Id`. -/
inductive high.digest.Id where
  | Sha1
  | Sha256
  | Sha384
  | Sha512
  | Sha512_256

/-- `Algorithm`, without its function pointers. -/
structure high.digest.Algorithm where
  id : high.digest.Id
  output_len : Std.Usize

/-- `Digest`. -/
structure high.digest.Digest where
  algorithm : high.digest.Algorithm
  value : Std.Array Std.U8 64#usize

/-- The `SHA1` static. -/
def high.digest.SHA1 : Result high.digest.Algorithm :=
  ok { id := .Sha1, output_len := 20#usize }

/-- The `SHA256` static. -/
def high.digest.SHA256 : Result high.digest.Algorithm :=
  ok { id := .Sha256, output_len := 32#usize }

/-- `Digest::zeroed`. -/
def high.digest.Digest.zeroed (algorithm : high.digest.Algorithm) : Result high.digest.Digest :=
  ok { algorithm, value := Std.Array.repeat 64#usize 0#u8 }

/-- `Digest::as_mut`. -/
def high.digest.Digest.as_mut (self : high.digest.Digest) :
    Result (Slice Std.U8 × (Slice Std.U8 → high.digest.Digest)) := do
  let (s, back) ←
    core.array.Array.index_mut
      (core.ops.index.IndexMutSlice (core.slice.index.SliceIndexRangeToUsizeSlice Std.U8))
      self.value { «end» := self.algorithm.output_len }
  ok (s, fun s1 => { self with value := back s1 })

/-- `Digest::new`. -/
def high.digest.Digest.new (algorithm : high.digest.Algorithm) (value : Slice Std.U8) :
    Result high.digest.Digest := do
  let digest ← high.digest.Digest.zeroed algorithm
  let (s, back) ← high.digest.Digest.as_mut digest
  let s1 ← core.slice.Slice.copy_from_slice core.marker.CopyU8 s value
  ok (back s1)

/-- `Digest`'s `AsRef<[u8]>`. -/
def high.digest.Digest.Insts.CoreConvertAsRefSliceU8.as_ref (self : high.digest.Digest) :
    Result (Slice Std.U8) :=
  core.array.Array.index
    (core.ops.index.IndexSlice (core.slice.index.SliceIndexRangeToUsizeSlice Std.U8))
    self.value { «end» := self.algorithm.output_len }

end rind.x86_64
