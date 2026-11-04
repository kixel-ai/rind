import Rind.Aarch64.X25519
import Rind.Aarch64.Sha512
open rind.aarch64

/-!
The axioms each theorem rests on, beyond Lean's own: s2n-bignum's contracts
in `Rind.Aarch64.S2nBignum` for X25519, aws-lc's in `Rind.Aarch64.AwsLc` for the
SHA-512 family, and nothing else. A change here is a change
to the trust base.
-/

/-- info: 'rind.aarch64.x25519_generate' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms x25519_generate

/-- info: 'rind.aarch64.x25519_public_key' depends on axioms: [propext, Classical.choice, Quot.sound, curve25519_x25519base_spec] -/
#guard_msgs in
#print axioms x25519_public_key

/-- info: 'rind.aarch64.x25519_agree' depends on axioms: [propext,
 Classical.choice,
 Quot.sound,
 bignum_eq_spec,
 curve25519_x25519_spec] -/
#guard_msgs in
#print axioms x25519_agree

/-- info: 'rind.aarch64.x25519_shared_secret' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms x25519_shared_secret

/-- info: 'rind.aarch64.sha512_family_digest' depends on axioms: [propext, Classical.choice, Quot.sound, compress_nohw_spec] -/
#guard_msgs in
#print axioms sha512_family_digest

/-- info: 'rind.aarch64.sha512_family_context' depends on axioms: [propext, Classical.choice, Quot.sound, compress_nohw_spec] -/
#guard_msgs in
#print axioms sha512_family_context
