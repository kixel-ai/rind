module
public import Aeneas
@[expose] public section
open Aeneas Aeneas.Std Result
set_option linter.dupNamespace false

/-!
# The digest API's algorithms, modelled by hand

`Algorithm` holds each hash's function pointers, which Aeneas cannot
translate, so the translation leaves it, its statics, and `output_len` opaque,
and this file models them, below the translation that reads them.
`admin/prove` fails unless this quote is still that Rust, so a change to it is
a change to this model:

```rust
pub struct Algorithm {
    id: Id,
    output_len: usize,
    // The only paths to the hash's code, so a binary links only the hashes
    // whose algorithms it names.
    hash: fn(&[u8]) -> Digest,
    start: fn() -> State,
}

impl Algorithm {
    /// The length of this algorithm's digest, in bytes.
    pub fn output_len(&self) -> usize {
        self.output_len
    }
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

pub static SHA384: Algorithm = Algorithm {
    id: Id::Sha384,
    output_len: sha2::Sha384Context::OUTPUT_SZ,
    hash: Sha384::hash,
    start: Hashing::<Sha384Context>::start,
};

pub static SHA512: Algorithm = Algorithm {
    id: Id::Sha512,
    output_len: sha2::Sha512Context::OUTPUT_SZ,
    hash: Sha512::hash,
    start: Hashing::<Sha512Context>::start,
};

pub static SHA512_256: Algorithm = Algorithm {
    id: Id::Sha512_256,
    output_len: sha2::Sha512_256Context::OUTPUT_SZ,
    hash: |data| {
        let output = sha2::Sha512_256Context::INITIAL.finish_with(data);
        Digest::new(&SHA512_256, &sha2::Sha512_256Context::truncate(&output))
    },
    start: Hashing::<Sha512_256Context>::start,
};

```

An `Algorithm` is which of these statics it is: its fields are private to
`high::digest`, which builds no other, and callers hold only `&'static`
references to them. `admin/prove` checks that the quote holds every
`= Algorithm {` in `high::digest`. Each output length is the `OUTPUT_SZ` the
static names, the length of the array its context's `finish` returns.
`Rind.X86_64.DigestDispatch` models `hash` and `start`, the function pointers.
-/

namespace rind.x86_64

/-- `&'static Algorithm`: which of `high::digest`'s statics. -/
inductive high.digest.Algorithm where
  | SHA1
  | SHA256
  | SHA384
  | SHA512
  | SHA512_256
deriving DecidableEq

/-- `Algorithm::output_len`. -/
def high.digest.Algorithm.output_len : high.digest.Algorithm → Result Std.Usize
  | .SHA1 => ok 20#usize
  | .SHA256 => ok 32#usize
  | .SHA384 => ok 48#usize
  | .SHA512 => ok 64#usize
  | .SHA512_256 => ok 32#usize

/-- The `SHA384` static. -/
def high.digest.SHA384 : Result high.digest.Algorithm := ok .SHA384

/-- The `SHA512` static. -/
def high.digest.SHA512 : Result high.digest.Algorithm := ok .SHA512

/-- The `SHA512_256` static. -/
def high.digest.SHA512_256 : Result high.digest.Algorithm := ok .SHA512_256

end rind.x86_64
