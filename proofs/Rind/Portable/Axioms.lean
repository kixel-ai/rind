import Rind.Portable.Sha512
import Rind.Portable.Pbkdf2
import Rind.Portable.ChaCha20
import Rind.Portable.RsaDispatch
open rind.portable

/-!
The axioms each theorem rests on: Lean's own, and nothing else. The SHA-2
block functions are proven here; `RunsSha512` and `Sha256Blocks`, hypotheses
of the SHA-512 family's theorems and of HMAC's, HKDF's, and PBKDF2's, state
only their entry checks, as `Runs` does for RSA verification's. The compares
behind HMAC's and PBKDF2's `verify` and RSASSA-PSS's, ChaCha20's rounds, and
RSA's word routines and Montgomery products are proven here too, the last
in `rsa2048_mont_products`, which discharges RSA's `MontProducts`. A change
here is a change to the trust base.
-/

/-- info: 'rind.portable.sha512_family_digest' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms sha512_family_digest

/-- info: 'rind.portable.sha512_family_context' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms sha512_family_context

/-- info: 'rind.portable.key_new_spec' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms key_new_spec

/-- info: 'rind.portable.sign_spec' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms sign_spec

/-- info: 'rind.portable.verify_spec' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms verify_spec

/-- info: 'rind.portable.context_with_key_spec' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms context_with_key_spec

/-- info: 'rind.portable.context_update_spec'' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms context_update_spec'

/-- info: 'rind.portable.context_sign_spec' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms context_sign_spec

/-- info: 'rind.portable.kdf.salt_extract_spec' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms kdf.salt_extract_spec

/-- info: 'rind.portable.kdf.prk_fill_spec' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms kdf.prk_fill_spec

/-- info: 'rind.portable.kdf.hkdf_fill' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms kdf.hkdf_fill

/-- info: 'rind.portable.kdf.prk_new_fill' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms kdf.prk_new_fill

/-- info: 'rind.portable.kdf.derive_spec' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms kdf.derive_spec

/-- info: 'rind.portable.kdf.verify_spec' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms kdf.verify_spec

/-- info: 'rind.portable.chacha20_new' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms chacha20_new

/-- info: 'rind.portable.chacha20_mask' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms chacha20_mask

/-- info: 'rind.portable.rsa_signature_new_spec' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms rsa_signature_new_spec

/-- info: 'rind.portable.rsa_signature_from_spki_spec' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms rsa_signature_from_spki_spec

/-- info: 'rind.portable.rsa_signature_from_components_spec' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms rsa_signature_from_components_spec

/-- info: 'rind.portable.rsa_pkcs1_sha256_verify_spec' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms rsa_pkcs1_sha256_verify_spec

/-- info: 'rind.portable.rsa_pss_sha256_verify_spec' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms rsa_pss_sha256_verify_spec

/-- info: 'rind.portable.rsa2048_mont_products' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms rsa2048_mont_products
