module
public import Rind.X86_64.Funs
@[expose] public section
open Aeneas Aeneas.Std Result

/-!
# P-256's key generation, left opaque

The x86_64 translation leaves P-256's functions opaque, and no x86_64 theorem
is about P-256, so its key generation is the translation's opaque
`new_random`. `Rind.X86_64.Dispatch` uses it as P-256's `Agree::random` under
the name `Rind.Aarch64.P256Dispatch` models on aarch64, so the two targets
share that file.
-/

namespace rind.x86_64

/-- `p256::PrivateKey::generate(&mut SystemRandom)`, which `new_random` is. -/
def mid.p256.PrivateKey.generate :
    Result (core.result.Result mid.p256.PrivateKey error.Error) :=
  mid.p256.PrivateKey.new_random

end rind.x86_64
