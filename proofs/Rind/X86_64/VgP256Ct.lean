import Cosim.ProgsX86_64
import VerifiedGarbage.Spec.Ecdh.P256
import VerifiedGarbage.Spec.EcKey.P256
import VerifiedGarbage.TCB.X86_64.Target

/-!
# The leakage of VG's P-256 ECDH with AVX512_IFMA on x86_64

On a CPU with AVX512_IFMA, rind's x86_64 P-256 ECDH runs
pyca/verified-garbage's (VG's) `vg_ecdh_p256_ifma`. `Rind.X86_64.VgP256`
restates what it returns. This axiom states the other half of VG's
`Verified`: that its leakage trace, its addresses and branches, depends only
on what its contract declares public, the peer's public key
(`VG.ConstantTime`, in the vendored `VerifiedGarbage/TCB/Code.lean`). It says
nothing about rind's Rust wrapper, which `admin/ct-binsec` checks with this
routine stubbed by its contract (`low::x86_64::p256_vg::ct_binsec_p256_ifma_ecdh`).

The code is VG's own term, written as `Cosim/ProgsX86_64.lean` writes the
`Prog` VG's `Artifacts/EcdhP256/X86_64.lean` registers:
`Impl.Ecdh.X86_64.exchangeP256Ifma`, then `scrub`, the clearing of the
registers and stack that VG's `RScrub.withScrubAllM` appends. The contract is
`exchangeContract` of VG's x86_64 calling convention for 16 bytes of stack,
which `ecdh_verified_ifma` proves the unscrubbed code for, and which the
scrubbed code, VG's registered one, keeps (`scrubRegF`'s
`contract := r.contract`).

What this rests on is what `Rind.X86_64.VgMlKem768Ct`'s axioms rest on: VG's
Lean proof, and that rind's object code is that `Prog`, which
`admin/vg-bytes --progs` checks through VG's printer and encoder, vendored and
in the trusted base.
-/

namespace rind.x86_64

open VG VG.Spec.Ecdh.Instance

/-- `vg_ecdh_p256_ifma` is constant time under `exchangeContract` for its 16
bytes of stack, whose public data are the peer's public key:
https://github.com/pyca/verified-garbage/blob/0aa40d6c21fd02943fe5b38a5b69b6213d07764d/lean/VerifiedGarbage/Artifacts/EcdhP256/X86_64.lean#L97 (the registration, `RScrub.withScrubAllM` of the code, whose `verified` is
`Verified` of the scrubbed code, by `RScrub.scrubRegF`'s proof, https://github.com/pyca/verified-garbage/blob/0aa40d6c21fd02943fe5b38a5b69b6213d07764d/lean/VerifiedGarbage/Proof/Framework/X86_64/ScrubOr.lean#L491, or
`Scrub.withScrubAll`'s) from
https://github.com/pyca/verified-garbage/blob/0aa40d6c21fd02943fe5b38a5b69b6213d07764d/lean/VerifiedGarbage/Proof/Ecdh/X86_64/VerifiedIfma.lean#L218 (`ecdh_verified_ifma`). -/
axiom vg_ecdh_p256_ifma_ct :
    ConstantTime X86_64.isa (exchangeContract Spec.EcKey.P256.inst X86_64.abi 16).pre
      (exchangeContract Spec.EcKey.P256.inst X86_64.abi 16).pub Cosim.ProgsX86_64.ecdhP256Ifma

end rind.x86_64
