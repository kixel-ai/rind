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

/-- `u64::from_le_bytes` reads its bytes as a little-endian number. -/
theorem val_of_fromLEBytes (a : List U8) (i : U64) {h}
    (hi : i.bv = (BitVec.fromLEBytes (a.map U8.bv)).cast h) : i.val = leNat a := by
  show i.bv.toNat = _
  rw [hi, BitVec.toNat_cast, toNat_fromLEBytes]
  simp [leNat, List.map_map, Function.comp_def]

/-- `u64::to_le_bytes` writes the number its word holds. -/
theorem leNat_toLEBytes (x : U64) :
    leNat (x.bv.toLEBytes.map (@UScalar.mk UScalarTy.U8)) = x.val := by
  show _ = x.bv.toNat
  rw [← ofDigits_toLEBytes x.bv]
  simp only [leNat, List.map_map, Function.comp_def]
  rfl

theorem toChunksExact_flatten {α : Type _} (n : Nat) (hn : 0 < n) (l : List α) :
    (List.toChunksExact n hn l).1.flatten ++ (List.toChunksExact n hn l).2 = l := by
  unfold List.toChunksExact
  split
  · simp
  · have := toChunksExact_flatten n hn (l.drop n)
    simp only [List.flatten_cons, List.append_assoc, this, List.take_append_drop]
termination_by l.length
decreasing_by simp; omega

theorem toChunksExact_length {α : Type _} (n : Nat) (hn : 0 < n) (l : List α) :
    ∀ c ∈ (List.toChunksExact n hn l).1, c.length = n := by
  unfold List.toChunksExact
  split
  · simp
  · rename_i h
    simp only [List.mem_cons]
    rintro c (rfl | hc)
    · simp; omega
    · exact toChunksExact_length n hn (l.drop n) c hc
termination_by l.length
decreasing_by simp; omega

theorem toChunksExact_remainder {α : Type _} (n : Nat) (hn : 0 < n) (l : List α) :
    (List.toChunksExact n hn l).2.length < n := by
  unfold List.toChunksExact
  split
  · simpa
  · exact toChunksExact_remainder n hn (l.drop n)
termination_by l.length
decreasing_by simp; omega

/-- Bytes in 8-byte chunks encode the number their chunks' values do as limbs. -/
theorem leNat_flatten (L : List (List U8)) (h : ∀ c ∈ L, c.length = 8) :
    leNat L.flatten = Nat.ofDigits (2 ^ 64) (L.map leNat) := by
  induction L with
  | nil => simp [leNat]
  | cons c L ih =>
    rw [List.flatten_cons, List.map_cons, Nat.ofDigits_cons, ← ih (fun c' hc' => h c' (by simp [hc']))]
    simp only [leNat, List.map_append, Nat.ofDigits_append, List.length_map, h c (by simp)]
    norm_num

theorem length_flatten_of_length {α : Type _} (L : List (List α)) (n : Nat)
    (h : ∀ c ∈ L, c.length = n) : L.flatten.length = n * L.length := by
  induction L with
  | nil => simp
  | cons c L ih =>
    rw [List.flatten_cons, List.length_append, h c (by simp), ih (fun c' hc' => h c' (by simp [hc']))]
    simp [Nat.mul_succ]; omega

theorem take_setSlice! {α : Type _} (r s : List α) (i : Nat) (hs : i + s.length ≤ r.length) :
    (r.setSlice! i s).take (i + s.length) = r.take i ++ s := by
  have hmin : min s.length (r.length - i) = s.length := by omega
  have hti : (r.take i).length = i := by simp; omega
  simp only [List.setSlice!, hmin, List.take_length, List.append_assoc, List.take_append, hti,
    Nat.add_sub_cancel_left, List.take_take]
  simp
