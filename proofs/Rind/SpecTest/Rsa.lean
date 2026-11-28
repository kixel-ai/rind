import Rind.Rsa
import Rind.Pratt

/-!
# RSA signatures, computed

`Rind.Rsa` states verification as propositions with existential witnesses,
and `rsavp1` and `rsasp1Crt` raise before they reduce. `rsavp1C` and
`rsasp1CrtC` reduce as they square, `pkcs1v15VerifyC` and `pssVerifyC`
decide the two verifications, and `pkcs1v15SignC` and `pssSignC` compute the
two signatures, each proven equal or equivalent to its spec. The spec tests
(`Rind.SpecTest.Server`) run these.
-/

namespace rind.spec.rsa

/-- `rsavp1`, by square-and-multiply mod `n`. -/
def rsavp1C (n e s : Nat) : Option Nat :=
  if s < n then some (powMod n (e.log2 + 1) s e) else none

theorem rsavp1_eq (n e s : Nat) : rsavp1 n e s = rsavp1C n e s := by
  rw [rsavp1, rsavp1C, powMod_eq n _ s e Nat.lt_log2_self]

/-- `emsaPssVerify`, decided, computing `DB` once: an instance unfolded from
the proposition substitutes its `let`s, which hashes MGF1 again for each
byte of the padding it checks. -/
def emsaPssVerifyC (H : List Byte → List Byte) (hLen : Nat) (M EM : List Byte) (emBits sLen : Nat) :
    Bool :=
  let mHash := H M
  let emLen := EM.length
  let top := 8 * emLen - emBits
  let maskedDB := EM.take (emLen - hLen - 1)
  let H' := (EM.drop (emLen - hLen - 1)).take hLen
  let dbMask := mgf1 H hLen H' (emLen - hLen - 1)
  let DB := (List.zipWith (· ^^^ ·) maskedDB dbMask).modifyHead
    fun b => b &&& BitVec.ofNat 8 (2 ^ (8 - top) - 1)
  let psLen := emLen - hLen - sLen - 2
  let salt := DB.drop (emLen - hLen - 1 - sLen)
  decide (hLen + sLen + 2 ≤ emLen) && EM.getLast? == some 0xbc &&
    decide ((maskedDB.headD 0).toNat < 2 ^ (8 - top)) && (DB.take psLen).all (· == 0x00) &&
    DB[psLen]? == some 0x01 && H (List.replicate 8 0x00 ++ mHash ++ salt) == H'

theorem emsaPssVerify_iff (H : List Byte → List Byte) (hLen : Nat) (M EM : List Byte) (emBits sLen : Nat) :
    emsaPssVerify H hLen M EM emBits sLen ↔ emsaPssVerifyC H hLen M EM emBits sLen = true := by
  simp [emsaPssVerify, emsaPssVerifyC, and_assoc]

instance (H : List Byte → List Byte) (hLen : Nat) (M EM : List Byte) (emBits sLen : Nat) :
    Decidable (emsaPssVerify H hLen M EM emBits sLen) :=
  decidable_of_iff _ (emsaPssVerify_iff H hLen M EM emBits sLen).symm

/-- `rsassaPkcs1v15Verify`, decided. -/
def pkcs1v15VerifyC (n e : Nat) (H : List Byte → List Byte) (digestInfo M S : List Byte) : Bool :=
  let k := octetLen n
  S.length == k &&
    match rsavp1C n e (os2ip S) with
    | none => false
    | some m =>
      match i2osp m k with
      | none => false
      | some EM => emsaPkcs1v15Encode H digestInfo M k == some EM

theorem pkcs1v15Verify_iff (n e : Nat) (H : List Byte → List Byte) (digestInfo M S : List Byte) :
    rsassaPkcs1v15Verify n e H digestInfo M S ↔ pkcs1v15VerifyC n e H digestInfo M S = true := by
  rw [rsassaPkcs1v15Verify, pkcs1v15VerifyC, rsavp1_eq]
  simp only [Bool.and_eq_true, beq_iff_eq]
  rcases rsavp1C n e (os2ip S) with _ | m
  · simp
  · rcases h : i2osp m (octetLen n) with _ | EM <;> simp [h]

/-- `rsassaPssVerify`, decided. -/
def pssVerifyC (n e : Nat) (H : List Byte → List Byte) (hLen : Nat) (M S : List Byte) (sLen : Nat) :
    Bool :=
  let modBits := n.size
  let emLen := (modBits - 1 + 7) / 8
  S.length == octetLen n &&
    match rsavp1C n e (os2ip S) with
    | none => false
    | some m =>
      match i2osp m emLen with
      | none => false
      | some EM => decide (emsaPssVerify H hLen M EM (modBits - 1) sLen)

theorem pssVerify_iff (n e : Nat) (H : List Byte → List Byte) (hLen : Nat) (M S : List Byte)
    (sLen : Nat) : rsassaPssVerify n e H hLen M S sLen ↔ pssVerifyC n e H hLen M S sLen = true := by
  rw [rsassaPssVerify, pssVerifyC, rsavp1_eq]
  simp only [Bool.and_eq_true, beq_iff_eq]
  rcases rsavp1C n e (os2ip S) with _ | m
  · simp
  · rcases h : i2osp m ((n.size - 1 + 7) / 8) with _ | EM <;> simp [h]

/-- `rsasp1Crt`, by square-and-multiply mod each prime. -/
def rsasp1CrtC (p q dP dQ qInv m : Nat) : Nat :=
  let s₁ := powMod p (dP.log2 + 1) m dP
  let s₂ := powMod q (dQ.log2 + 1) m dQ
  let h := (((s₁ : Int) - s₂) * qInv % (p : Int)).toNat
  s₂ + q * h

theorem rsasp1Crt_eq (p q dP dQ qInv m : Nat) : rsasp1Crt p q dP dQ qInv m = rsasp1CrtC p q dP dQ qInv m := by
  rw [rsasp1Crt, rsasp1CrtC, powMod_eq p _ m dP Nat.lt_log2_self, powMod_eq q _ m dQ Nat.lt_log2_self]

/-- `rsassaPkcs1v15Sign`, by `rsasp1CrtC`. -/
def pkcs1v15SignC (n p q dP dQ qInv : Nat) (H : List Byte → List Byte) (digestInfo M : List Byte) :
    Option (List Byte) :=
  (emsaPkcs1v15Encode H digestInfo M (octetLen n)).bind fun EM =>
    i2osp (rsasp1CrtC p q dP dQ qInv (os2ip EM)) (octetLen n)

theorem pkcs1v15Sign_eq (n p q dP dQ qInv : Nat) (H : List Byte → List Byte) (digestInfo M : List Byte) :
    rsassaPkcs1v15Sign n p q dP dQ qInv H digestInfo M = pkcs1v15SignC n p q dP dQ qInv H digestInfo M := by
  simp only [rsassaPkcs1v15Sign, pkcs1v15SignC, rsasp1Crt_eq]

/-- `rsassaPssSign`, by `rsasp1CrtC`. -/
def pssSignC (n p q dP dQ qInv : Nat) (H : List Byte → List Byte) (hLen : Nat) (M salt : List Byte) :
    Option (List Byte) :=
  (emsaPssEncode H hLen M salt (n.size - 1)).bind fun EM =>
    i2osp (rsasp1CrtC p q dP dQ qInv (os2ip EM)) (octetLen n)

theorem pssSign_eq (n p q dP dQ qInv : Nat) (H : List Byte → List Byte) (hLen : Nat) (M salt : List Byte) :
    rsassaPssSign n p q dP dQ qInv H hLen M salt = pssSignC n p q dP dQ qInv H hLen M salt := by
  simp only [rsassaPssSign, pssSignC, rsasp1Crt_eq]

end rind.spec.rsa
