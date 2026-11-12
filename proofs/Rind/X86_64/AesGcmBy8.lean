import Rind.X86_64.GhashClmul
import Rind.X86_64.AesGcm
open Aeneas Aeneas.Std Result rind.vale rind.simd

/-!
# rind's SSE AES-GCM, `by8`

`Rind.X86_64.AesGcmModel`'s `by8` is Vale's `gctr_encrypt_LE` and
`ghash_LE`, without their bound of 2^32 bytes: its counter is the block's
64-bit halves swapped, which `PADDD` steps as `inc32` does, its rounds are
FIPS 197's, and its GHASH is `Rind.X86_64.GhashClmul`'s.
-/

local notation "P" => Polynomial (ZMod 2)

set_option maxRecDepth 20000

namespace rind.x86_64

/-! ## Bits of the vector operations -/

theorem getLsbD_ofLanes16 (f : Nat → BitVec 16) (k : Nat) :
    (ofLanes16 f).getLsbD k = (decide (k < 128) && (f (k / 16)).getLsbD (k % 16)) := by
  by_cases hk : k < 128
  · simp only [ofLanes16, BitVec.getLsbD_append]
    interval_cases k <;> simp
  · rw [BitVec.getLsbD_of_ge _ _ (by omega)]; simp [hk]

theorem getLsbD_ofLanes32 (f : Nat → BitVec 32) (k : Nat) :
    (ofLanes32 f).getLsbD k = (decide (k < 128) && (f (k / 32)).getLsbD (k % 32)) := by
  by_cases hk : k < 128
  · simp only [ofLanes32, BitVec.getLsbD_append]
    interval_cases k <;> simp
  · rw [BitVec.getLsbD_of_ge _ _ (by omega)]; simp [hk]

theorem getLsbD_lane16 (a : BitVec 128) (j m : Nat) :
    (lane16 a j).getLsbD m = (decide (m < 16) && a.getLsbD (16 * j + m)) := by
  simp [lane16, BitVec.getLsbD_extractLsb']

theorem getLsbD_lane32 (a : BitVec 128) (j m : Nat) :
    (lane32 a j).getLsbD m = (decide (m < 32) && a.getLsbD (32 * j + m)) := by
  simp [lane32, BitVec.getLsbD_extractLsb']

theorem getLsbD_ite {w : Nat} (c : Prop) [Decidable c] (a b : BitVec w) (i : Nat) :
    (if c then a else b).getLsbD i = if c then a.getLsbD i else b.getLsbD i := by
  split <;> rfl

/-- `byte_reverse` reverses the bytes. -/
theorem byte_reverse_eq (x : BitVec 128) :
    low.x86_64.ghash.byte_reverse x = ok (reverseBytesQuad32 x) := by
  have e1 : (27#i32).bv.toNat = 27 := by decide
  have e2 : (177#i32).bv.toNat = 177 := by decide
  have e3 : (8#i32).bv.toNat = 8 := by decide
  simp only [low.x86_64.ghash.byte_reverse, core.core_arch.x86.sse2._mm_shuffle_epi32,
    core.core_arch.x86.sse2._mm_shufflelo_epi16, core.core_arch.x86.sse2._mm_shufflehi_epi16,
    core.core_arch.x86.sse2._mm_slli_epi16, core.core_arch.x86.sse2._mm_srli_epi16,
    core.core_arch.x86.sse2._mm_or_si128, bind_ok, e1, e2, e3]
  congr 1
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  rw [getLsbD_reverseBytesQuad32 _ hk]
  simp only [BitVec.getLsbD_or, getLsbD_ofLanes16, getLsbD_ite,
    BitVec.getLsbD_shiftLeft, BitVec.getLsbD_ushiftRight, getLsbD_lane16, getLsbD_ofLanes32, getLsbD_lane32,
    show ¬ (8 % 256 > 15) by decide, ite_false]
  interval_cases k <;> simp

theorem getLsbD_swap (v : BitVec 128) (k : Nat) :
    (swap v).getLsbD k = (decide (k < 128) && v.getLsbD ((k + 64) % 128)) := by
  by_cases hk : k < 128
  · simp only [swap, lo, hi, BitVec.getLsbD_append, BitVec.getLsbD_extractLsb']
    by_cases h : k < 64
    · simp [h, hk, show (k + 64) % 128 = 64 + k by omega]
    · simp [h, hk, show (k + 64) % 128 = k - 64 by omega]; omega
  · rw [BitVec.getLsbD_of_ge _ _ (by omega)]; simp [hk]

theorem swap_swap (v : BitVec 128) : swap (swap v) = v := by
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  rw [getLsbD_swap, getLsbD_swap]
  simp [hk, show (k + 64) % 128 < 128 by omega, show ((k + 64) % 128 + 64) % 128 = k by omega]

/-- `PSHUFB` by `BYTESWAP_EPI64` reverses each 64-bit half's bytes. -/
theorem shuffle_byteswap_epi64 (v : BitVec 128) :
    core.core_arch.x86.ssse3._mm_shuffle_epi8 v 0x08090a0b_0c0d0e0f_00010203_04050607#128 =
      ok (reverseBytesQuad32 (swap v)) := by
  simp only [core.core_arch.x86.ssse3._mm_shuffle_epi8]
  congr 1
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  rw [getLsbD_ofBytes _ hk, getLsbD_reverseBytesQuad32 _ hk, getLsbD_swap]
  simp only [getLsbD_byte _ _ (Nat.mod_lt _ (by omega : 8 > 0)), getLsbD_ite]
  interval_cases k <;> simp +decide [byte]

theorem load_store (v : BitVec 128) : low.x86_64.aes.load (low.x86_64.aes.store v).val = v := by
  apply eq_of_byte_eq; intro i hi
  simp only [low.x86_64.aes.load, low.x86_64.aes.store, Std.Array.from_val, List.map_map]
  rw [byte_leBytesToQuad32 _ hi]
  have hm : ∀ l : List (BitVec 8), l.map (fun x => U8.bv ⟨x⟩) = l := fun l => by
    conv_rhs => rw [← List.map_id l]
    rfl
  rw [Function.comp_def, hm, leQuad32ToBytes_getElem! _ hi]

/-! ## The counter -/

theorem lane32_inc32_zero (q : Quad32) (n : Nat) : lane32 (inc32 q n) 0 = lane32 q 0 + BitVec.ofNat 32 n := by
  have hz : ∀ x : Quad32, lane32 x 0 = x.extractLsb' 0 32 := fun _ => rfl
  apply BitVec.eq_of_getLsbD_eq; intro m hm
  rw [hz, hz, inc32, BitVec.getLsbD_extractLsb', BitVec.getLsbD_append]
  simp [hm]

theorem high_inc32 (q : Quad32) (n : Nat) : (inc32 q n).extractLsb' 32 96 = q.extractLsb' 32 96 := by
  apply BitVec.eq_of_getLsbD_eq; intro m hm
  simp only [inc32, BitVec.getLsbD_extractLsb', BitVec.getLsbD_append, hm, decide_true, Bool.true_and,
    show ¬ 32 + m < 32 by omega, ite_false, show 32 + m - 32 = m by omega]

theorem inc32_eq (q : Quad32) (n : Nat) :
    inc32 q n = q.extractLsb' 32 96 ++ (lane32 q 0 + BitVec.ofNat 32 n) := rfl

theorem inc32_inc32 (q : Quad32) (i j : Nat) : inc32 (inc32 q i) j = inc32 q (i + j) := by
  rw [inc32_eq (inc32 q i), high_inc32, lane32_inc32_zero, inc32_eq q (i + j), BitVec.add_assoc,
    BitVec.ofNat_add]

theorem inc32_zero (q : Quad32) : inc32 q 0 = q := by
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  simp only [inc32, BitVec.add_zero, BitVec.getLsbD_append, BitVec.getLsbD_extractLsb']
  by_cases h : k < 32
  · simp [h]
  · simp [h, show k - 32 < 96 by omega, show 32 + (k - 32) = k by omega]

theorem lane32_swap (v : BitVec 128) {i : Nat} (hi : i < 4) : lane32 (swap v) i = lane32 v ((i + 2) % 4) := by
  apply BitVec.eq_of_getLsbD_eq; intro m hm
  rw [getLsbD_lane32, getLsbD_lane32, getLsbD_swap]
  simp only [hm, decide_true, Bool.true_and, show 32 * i + m < 128 by omega]
  congr 1; omega

theorem lane32_inc32 (q : Quad32) (n : Nat) {i : Nat} (hi : 1 ≤ i) (hi' : i < 4) :
    lane32 (inc32 q n) i = lane32 q i := by
  apply BitVec.eq_of_getLsbD_eq; intro m hm
  rw [getLsbD_lane32, getLsbD_lane32]
  simp only [inc32, BitVec.getLsbD_append, BitVec.getLsbD_extractLsb', hm, decide_true, Bool.true_and,
    show ¬ 32 * i + m < 32 by omega, ite_false, show 32 * i + m - 32 < 96 by omega]
  congr 1; omega

theorem ofLanes32_ext (f g : Nat → BitVec 32) (h : ∀ i < 4, f i = g i) : ofLanes32 f = ofLanes32 g := by
  simp only [ofLanes32, h 0 (by omega), h 1 (by omega), h 2 (by omega), h 3 (by omega)]

theorem ofLanes32_lane32 (x : BitVec 128) : ofLanes32 (lane32 x) = x := by
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  rw [getLsbD_ofLanes32, getLsbD_lane32]
  simp only [hk, decide_true, Bool.true_and, Nat.mod_lt _ (by omega : 32 > 0)]
  congr 1; omega

/-- `PADDD` of `COUNTER_1` steps the swapped counter as `inc32`. -/
theorem add_counter (q : Quad32) :
    core.core_arch.x86.sse2._mm_add_epi32 (swap q) 0x1_00000000_00000000#128 = ok (swap (inc32 q 1)) := by
  simp only [core.core_arch.x86.sse2._mm_add_epi32]
  refine congrArg ok ?_
  conv_rhs => rw [← ofLanes32_lane32 (swap (inc32 q 1))]
  apply ofLanes32_ext
  intro i hi
  have c0 : lane32 0x1_00000000_00000000#128 0 = 0#32 := by decide
  have c1 : lane32 0x1_00000000_00000000#128 1 = 0#32 := by decide
  have c2 : lane32 0x1_00000000_00000000#128 2 = 1#32 := by decide
  have c3 : lane32 0x1_00000000_00000000#128 3 = 0#32 := by decide
  rw [lane32_swap _ hi, lane32_swap _ hi]
  interval_cases i
  · rw [c0, BitVec.add_zero]; exact (lane32_inc32 q 1 (by omega) (by omega)).symm
  · rw [c1, BitVec.add_zero]; exact (lane32_inc32 q 1 (by omega) (by omega)).symm
  · rw [c2, show (2 + 2) % 4 = 0 by rfl, lane32_inc32_zero]
  · rw [c3, BitVec.add_zero]; exact (lane32_inc32 q 1 (by omega) (by omega)).symm

theorem rev_swap_rev (q : Quad32) : reverseBytesQuad32 (swap (reverseBytesQuad32 q)) = swap q := by
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  rw [getLsbD_reverseBytesQuad32 _ hk, getLsbD_swap, getLsbD_swap, getLsbD_reverseBytesQuad32 _ (by omega)]
  simp only [hk, decide_true, Bool.true_and, show 8 * (15 - k / 8) + k % 8 < 128 by omega]
  congr 1; omega

/-- The counter `by8` keeps for the block `q`: its 64-bit halves swapped. -/
theorem counter_new (j0 : Quad32) (y0 : Std.Array U8 16#usize) (hy : low.x86_64.aes.load y0.val = reverseBytesQuad32 j0) :
    low.x86_64.aes_gcm.Counter.new y0 = ok (swap (inc32 j0 1)) := by
  simp only [low.x86_64.aes_gcm.Counter.new, low.x86_64.aes_gcm.BYTESWAP_EPI64, low.x86_64.aes_gcm.COUNTER_1,
    bind_ok, hy, shuffle_byteswap_epi64, rev_swap_rev, add_counter]

theorem counter_next (q : Quad32) :
    low.x86_64.aes_gcm.Counter.next (swap q) = ok (reverseBytesQuad32 q, swap (inc32 q 1)) := by
  simp only [low.x86_64.aes_gcm.Counter.next, low.x86_64.aes_gcm.BYTESWAP_EPI64, low.x86_64.aes_gcm.COUNTER_1,
    bind_ok, shuffle_byteswap_epi64, swap_swap, add_counter]

/-! ## The rounds -/

/-- `HwKey::round_keys`' first key, middle keys, and last key encrypt as Vale's AES. -/
theorem encrypt_eq (hk : low.x86_64.aes.HwKey) (alg : Algorithm) (kw : List (BitVec 32))
    (h : HwKeyIs alg kw hk) (c : BitVec 128) :
    low.x86_64.aes_gcm.encrypt c hk.round_keys.1 hk.round_keys.2.1 hk.round_keys.2.2 = ok (aesEncrypt alg kw c) := by
  cases hk with
  | Aes128 k =>
    obtain ⟨rfl, hrk⟩ := h
    have hl := k.round_keys.property
    rw [aesEncrypt, ← hrk]
    simp only [low.x86_64.aes.HwKey.round_keys]
    generalize k.round_keys.val = l at hl ⊢
    match l, hl with
    | [k0, k1, k2, k3, k4, k5, k6, k7, k8, k9, k10], _ =>
      simp [low.x86_64.aes_gcm.encrypt, aesenc_eq, aesenclast_eq, List.foldlM,
        core.core_arch.x86.sse2._mm_xor_si128, evalCipher, evalRounds, nr]
  | Aes192 k => exact h.elim
  | Aes256 k =>
    obtain ⟨rfl, hrk⟩ := h
    have hl := k.round_keys.property
    rw [aesEncrypt, ← hrk]
    simp only [low.x86_64.aes.HwKey.round_keys]
    generalize k.round_keys.val = l at hl ⊢
    match l, hl with
    | [k0, k1, k2, k3, k4, k5, k6, k7, k8, k9, k10, k11, k12, k13, k14], _ =>
      simp [low.x86_64.aes_gcm.encrypt, aesenc_eq, aesenclast_eq, List.foldlM,
        core.core_arch.x86.sse2._mm_xor_si128, evalCipher, evalRounds, nr]

end rind.x86_64
