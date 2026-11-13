import Rind.X86_64.P256Agree
open Aeneas Aeneas.Std Result rind.spec

/-!
# x86_64's P-256 generator multiplication

What the shared key generation and ECDSA proofs, `Rind.X86_64.P256` and
those above it, take of each target's generator multiplication and table:
`base_multiply_spec`, the generator times a scalar below n, and `first_row`,
that the table's first row holds G to 32G. x86_64 multiplies by rind's Booth
driver over aws-lc's mixed addition and a 37-row table of 64 points each, and
`jac_base_multiply_spec` states its Jacobian result, which the signing
key's check of an uncompressed public key compares, `Rind.X86_64.P256KeyCheck`.
-/

namespace rind.x86_64

namespace P256

-- PLACEHOLDER: fork C
-- These three state what the proof of x86_64's generator multiplication and
-- table will prove; until it lands, they are axioms.

/-- The generator times `k`, in Jacobian Montgomery form, for `k` below n. -/
axiom jac_base_multiply_spec (k : mid.p256.Scalar) (hk : wordsNat k.val < n256) :
    mid.p256.JacobianMontPoint.base_multiply k ⦃ r =>
      p256Represents (p256Pow p256G (wordsNat k.val)) (tripleNat r.xyz.val) ⦄

/-- The generator times `k`, in affine Montgomery form, zeros for infinity,
for `k` below n. -/
@[step]
axiom base_multiply_spec (_hr : Runs) (k : mid.p256.Scalar) (hk : wordsNat k.val < n256) :
    mid.p256.AffineMontPoint.base_multiply k ⦃ q =>
      ∃ rx ry, p256AffineZ (rx, ry) (p256Pow p256G (wordsNat k.val)) ∧
        pairNat q.xy.val = (2 ^ 256 * rx % p256, 2 ^ 256 * ry % p256) ⦄

/-- The generator table's first row holds G to 32G. -/
axiom first_row : ∀ j, 1 ≤ j → j ≤ 32 →
    p256Represents2 (p256Pow p256G j) (pairNat ((mid.p256.precomp.CURVE_GENERATOR_PRECOMP.val[0]!).val.drop (8 * (j - 1))))

-- END PLACEHOLDER: fork C

end P256

end rind.x86_64
