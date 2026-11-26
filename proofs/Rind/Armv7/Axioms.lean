import Rind.Armv7.ChaCha20
import Rind.Armv7.AesNohwKey
import Rind.Armv7.AesGcm
open rind.armv7

/-!
The axioms each theorem rests on, beyond Lean's own: none. A change here is a
change to the trust base.
-/

/-- info: 'rind.armv7.chacha20_new' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms chacha20_new

/-- info: 'rind.armv7.chacha20_mask' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms chacha20_mask

/-!
The bitsliced AES's theorems rest on Lean's own axioms and on the ones
`bv_decide` adds, one a call: each states that Lean's compiled LRAT checker
accepted a SAT solver's certificate for one bit-vector identity of the S-box
circuit, a round step, a key schedule step, the batch layout, or a counter or
GHASH step. `#bv_axioms` fails on any other but the ones it names after the
theorem: AES-GCM's tag check also rests on `Rind.Armv7.CtEqual`'s
restatement of rind's HOL Light proofs of its constant-time compares.
-/

open Lean Elab Command in
/-- Fails unless the theorem rests only on Lean's axioms, `bv_decide`'s, and
the ones named after it. -/
elab "#bv_axioms " id:ident extra:ident* : command => do
  let thm ← liftCoreM <| realizeGlobalConstNoOverloadWithInfo id
  let allowed ← liftCoreM <| extra.toList.mapM realizeGlobalConstNoOverloadWithInfo
  let axs ← liftCoreM <| collectAxioms thm
  let other := axs.filter fun a =>
    a != ``propext && a != ``Classical.choice && a != ``Quot.sound && !allowed.contains a &&
      (a.toString.splitOn "._native.bv_decide.ax_").length != 2
  unless other.isEmpty do throwError "{thm} depends on axioms: {other}"

#bv_axioms encrypt_batch_spec
#bv_axioms encrypt_block_spec
#bv_axioms new_schedule_spec
#bv_axioms schedule_encrypt_block
#bv_axioms aes_gcm_new_spec
#bv_axioms aes_gcm_encrypt_spec
#bv_axioms aes_gcm_decrypt_spec ct_compare_16_spec ct_compare_bytes_spec
#bv_axioms aes_gcm_encrypt_any_spec
#bv_axioms aes_gcm_decrypt_any_spec ct_compare_16_spec ct_compare_bytes_spec
