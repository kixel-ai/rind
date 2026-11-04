import Rind.Spec
open Aeneas Aeneas.Std

/-! How Rust's little-endian byte conversions relate to the numbers in `Rind.Spec`. -/

namespace rind.spec

theorem ofDigits_toLEBytes {w : Nat} (b : BitVec w) :
    Nat.ofDigits 256 (b.toLEBytes.map BitVec.toNat) = b.toNat := by
  unfold BitVec.toLEBytes
  split
  · rename_i hw
    simp only [List.map_cons, Nat.ofDigits_cons]
    rw [ofDigits_toLEBytes]
    simp only [BitVec.toNat_setWidth, BitVec.toNat_ushiftRight]
    have hb := b.isLt
    rw [Nat.shiftRight_eq_div_pow]
    have : b.toNat / 2 ^ 8 < 2 ^ (w - 8) := by
      rw [Nat.div_lt_iff_lt_mul (by positivity), ← Nat.pow_add]
      exact lt_of_lt_of_le hb (Nat.pow_le_pow_right (by norm_num) (by omega))
    rw [Nat.mod_eq_of_lt this]
    omega
  · have : w = 0 := by omega
    subst this
    simp [BitVec.toNat_of_zero_length]
termination_by w
decreasing_by omega

theorem toNat_fromLEBytes : ∀ (l : List (BitVec 8)),
    (BitVec.fromLEBytes l).toNat = Nat.ofDigits 256 (l.map BitVec.toNat)
  | [] => by simp [BitVec.fromLEBytes]
  | b :: l => by
    rw [BitVec.fromLEBytes, BitVec.toNat_or, BitVec.toNat_shiftLeft, BitVec.toNat_setWidth,
      BitVec.toNat_setWidth, toNat_fromLEBytes l]
    simp only [List.map_cons, Nat.ofDigits_cons, List.length_cons]
    have hb := b.isLt
    have hl := (BitVec.fromLEBytes l).isLt
    rw [toNat_fromLEBytes l] at hl
    set B := Nat.ofDigits 256 (List.map BitVec.toNat l)
    have hn : 8 * (l.length + 1) = 8 * l.length + 8 := by ring
    have h8 : 2 ^ 8 ≤ 2 ^ (8 * (l.length + 1)) := Nat.pow_le_pow_right (by norm_num) (by omega)
    have hB : B < 2 ^ (8 * (l.length + 1)) :=
      lt_of_lt_of_le hl (Nat.pow_le_pow_right (by norm_num) (by omega))
    have hBs : B * 2 ^ 8 < 2 ^ (8 * (l.length + 1)) := by
      rw [hn, Nat.pow_add]
      exact Nat.mul_lt_mul_of_pos_right hl (by positivity)
    rw [Nat.mod_eq_of_lt (lt_of_lt_of_le hb h8), Nat.mod_eq_of_lt hB, Nat.shiftLeft_eq,
      Nat.mod_eq_of_lt hBs, Nat.lor_comm, show B * 2 ^ 8 = 2 ^ 8 * B by ring,
      ← Nat.two_pow_add_eq_or_of_lt hb]
    ring
