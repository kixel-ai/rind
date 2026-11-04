import Rind.Aarch64.X25519
import Rind.Aarch64.P256
import Rind.Aarch64.ChaCha20
open rind.aarch64

/-!
The axioms each theorem rests on, beyond Lean's own: s2n-bignum's contracts
in `Rind.Aarch64.S2nBignum` for X25519 and P-256, and nothing else. A change
here is a change to the trust base.
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

/-- info: 'rind.aarch64.p256_generate' depends on axioms: [propext,
 Classical.choice,
 Quot.sound,
 bignum_eq_spec,
 bignum_mod_n256_spec] -/
#guard_msgs in
#print axioms p256_generate

/-- info: 'rind.aarch64.p256_public_key' depends on axioms: [propext,
 Classical.choice,
 Quot.sound,
 bignum_add_p256_spec,
 bignum_demont_p256_spec,
 bignum_eq_spec,
 bignum_montmul_p256_spec,
 bignum_montsqr_p256_spec,
 bignum_tomont_p256_spec,
 p256_scalarmulbase_spec] -/
#guard_msgs in
#print axioms p256_public_key

/-- info: 'rind.aarch64.p256_agree' depends on axioms: [propext,
 Classical.choice,
 Quot.sound,
 bignum_add_p256_spec,
 bignum_demont_p256_spec,
 bignum_eq_spec,
 bignum_montmul_p256_spec,
 bignum_montsqr_p256_spec,
 bignum_tomont_p256_spec,
 p256_scalarmul_spec] -/
#guard_msgs in
#print axioms p256_agree

/-- info: 'rind.aarch64.p256_shared_secret' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms p256_shared_secret

/-- info: 'rind.aarch64.chacha20_new' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms chacha20_new

/-- info: 'rind.aarch64.chacha20_mask' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms chacha20_mask
