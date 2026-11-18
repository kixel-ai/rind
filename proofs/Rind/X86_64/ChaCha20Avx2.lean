import Rind.X86_64.VgChaCha20
import Rind.X86_64.AesGcmBy8
open Aeneas Aeneas.Std Result rind.spec rind.simd rind.vale rind.x86_64

/-!
# The two-block AVX2 kernel, proven to RFC 8439

`low::x86_64::chacha20::cipher_avx2` XORs ChaCha20's keystream into a buffer
128 bytes at a time with `core_2x`, which holds two consecutive blocks' states
in four 256-bit vectors, a row of the state each, the first block's in the
low 128-bit halves. `kernel` proves `Rind.X86_64.VgChaCha20`'s `Kernel`, the
kernel's contract, over `Rind.X86_64.Simd`'s models of the AVX2 intrinsics.
-/

namespace rind.x86_64.avx2

/-! ## Vectors as eight 32-bit lanes -/

local notation "V" => ofLanes32x8

theorem getLsbD_V (f : Nat → BitVec 32) (k : Nat) :
    (V f).getLsbD k = (decide (k < 256) && (f (k / 32)).getLsbD (k % 32)) := by
  by_cases hk : k < 256
  · simp only [ofLanes32x8, BitVec.getLsbD_append]
    interval_cases k <;> simp
  · rw [BitVec.getLsbD_of_ge _ _ (by omega)]; simp [hk]

theorem getLsbD_ofHalves (g : Nat → BitVec 128) (k : Nat) :
    (ofHalves g).getLsbD k = (decide (k < 256) && (g (k / 128)).getLsbD (k % 128)) := by
  by_cases hk : k < 256
  · simp only [ofHalves, BitVec.getLsbD_append]
    by_cases h0 : k < 128
    · simp [h0, hk, Nat.div_eq_of_lt h0, Nat.mod_eq_of_lt h0]
    · simp [h0, hk, show k / 128 = 1 by omega, show k % 128 = k - 128 by omega]
  · rw [BitVec.getLsbD_of_ge _ _ (by omega)]; simp [hk]

theorem getLsbD_half (x : BitVec 256) (j m : Nat) :
    (half x j).getLsbD m = (decide (m < 128) && x.getLsbD (128 * j + m)) := by
  simp [half, BitVec.getLsbD_extractLsb']

theorem lane_V (f : Nat → BitVec 32) (i : Nat) (h : i < 8) : lane32x8 (V f) i = f i := by
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  simp only [lane32x8, BitVec.getLsbD_extractLsb', hk, decide_true, Bool.true_and, getLsbD_V]
  simp [show 32 * i + k < 256 by omega, show (32 * i + k) / 32 = i by omega,
    show (32 * i + k) % 32 = k by omega]

theorem V_lane (x : BitVec 256) : V (lane32x8 x) = x := by
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  simp only [getLsbD_V, hk, decide_true, Bool.true_and, lane32x8, BitVec.getLsbD_extractLsb']
  simp [show k % 32 < 32 by omega, show 32 * (k / 32) + k % 32 = k by omega]

theorem V_congr {f g : Nat → BitVec 32} (h : ∀ i < 8, f i = g i) : V f = V g := by
  simp only [ofLanes32x8, h 0 (by decide), h 1 (by decide), h 2 (by decide), h 3 (by decide),
    h 4 (by decide), h 5 (by decide), h 6 (by decide), h 7 (by decide)]

theorem add_V (f g : Nat → BitVec 32) :
    core.core_arch.x86.avx2._mm256_add_epi32 (V f) (V g) = ok (V fun i => f i + g i) := by
  simp only [core.core_arch.x86.avx2._mm256_add_epi32, ok.injEq]
  exact V_congr fun i hi => by rw [lane_V _ _ hi, lane_V _ _ hi]

theorem xor_V (f g : Nat → BitVec 32) :
    core.core_arch.x86.avx2._mm256_xor_si256 (V f) (V g) = ok (V fun i => f i ^^^ g i) := by
  simp only [core.core_arch.x86.avx2._mm256_xor_si256, ok.injEq]
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  simp only [BitVec.getLsbD_xor, getLsbD_V, hk, decide_true, Bool.true_and]

theorem or_V (f g : Nat → BitVec 32) :
    core.core_arch.x86.avx2._mm256_or_si256 (V f) (V g) = ok (V fun i => f i ||| g i) := by
  simp only [core.core_arch.x86.avx2._mm256_or_si256, ok.injEq]
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  simp only [BitVec.getLsbD_or, getLsbD_V, hk, decide_true, Bool.true_and]

theorem slli12_V (f : Nat → BitVec 32) :
    core.core_arch.x86.avx2._mm256_slli_epi32 12#i32 (V f) = ok (V fun i => f i <<< 12) := by
  simp only [core.core_arch.x86.avx2._mm256_slli_epi32, ok.injEq]
  exact V_congr fun i hi => by simp [lane_V _ _ hi]

theorem srli20_V (f : Nat → BitVec 32) :
    core.core_arch.x86.avx2._mm256_srli_epi32 20#i32 (V f) = ok (V fun i => f i >>> 20) := by
  simp only [core.core_arch.x86.avx2._mm256_srli_epi32, ok.injEq]
  exact V_congr fun i hi => by simp [lane_V _ _ hi]

theorem slli7_V (f : Nat → BitVec 32) :
    core.core_arch.x86.avx2._mm256_slli_epi32 7#i32 (V f) = ok (V fun i => f i <<< 7) := by
  simp only [core.core_arch.x86.avx2._mm256_slli_epi32, ok.injEq]
  exact V_congr fun i hi => by simp [lane_V _ _ hi]

theorem srli25_V (f : Nat → BitVec 32) :
    core.core_arch.x86.avx2._mm256_srli_epi32 25#i32 (V f) = ok (V fun i => f i >>> 25) := by
  simp only [core.core_arch.x86.avx2._mm256_srli_epi32, ok.injEq]
  exact V_congr fun i hi => by simp [lane_V _ _ hi]

theorem rotl12 (x : BitVec 32) : x <<< 12 ||| x >>> 20 = x.rotateLeft 12 := rotl x 12 (by decide)
theorem rotl7 (x : BitVec 32) : x <<< 7 ||| x >>> 25 = x.rotateLeft 7 := rotl x 7 (by decide)

/-- Lane `i` of `PSHUFD` in each half, by `k` lanes. -/
def rotLane (k i : Nat) : Nat := 4 * (i / 4) + (i % 4 + k) % 4

theorem shuffle_V (imm : Std.I32) (m : Nat) (hm : imm.bv.toNat = m) (f : Nat → BitVec 32) :
    core.core_arch.x86.avx2._mm256_shuffle_epi32 imm (V f) =
      ok (V fun i => f (4 * (i / 4) + m / 4 ^ (i % 4) % 4)) := by
  simp only [core.core_arch.x86.avx2._mm256_shuffle_epi32, ok.injEq, hm]
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  simp only [getLsbD_ofHalves, getLsbD_V, hk, decide_true, Bool.true_and, getLsbD_ofLanes32,
    getLsbD_lane32, getLsbD_half, show k % 128 < 128 by omega, Nat.mod_lt _ (by omega : 32 > 0)]
  rw [show k % 128 / 32 = k / 32 % 4 by omega]
  generalize hs : m / 4 ^ (k / 32 % 4) % 4 = s
  have h4 : s < 4 := hs ▸ Nat.mod_lt _ (by omega)
  rw [show (128 * (k / 128) + (32 * s + k % 128 % 32)) / 32 = 4 * (k / 32 / 4) + s by omega,
    show (128 * (k / 128) + (32 * s + k % 128 % 32)) % 32 = k % 32 by omega]
  simp [show 32 * s + k % 32 < 128 by omega, show 128 * (k / 128) + (32 * s + k % 32) < 256 by omega]

theorem shuffle57_V (f : Nat → BitVec 32) :
    core.core_arch.x86.avx2._mm256_shuffle_epi32 57#i32 (V f) = ok (V fun i => f (rotLane 1 i)) := by
  rw [shuffle_V _ 57 rfl]
  exact congrArg ok (V_congr fun i hi => by interval_cases i <;> rfl)

theorem shuffle78_V (f : Nat → BitVec 32) :
    core.core_arch.x86.avx2._mm256_shuffle_epi32 78#i32 (V f) = ok (V fun i => f (rotLane 2 i)) := by
  rw [shuffle_V _ 78 rfl]
  exact congrArg ok (V_congr fun i hi => by interval_cases i <;> rfl)

theorem shuffle147_V (f : Nat → BitVec 32) :
    core.core_arch.x86.avx2._mm256_shuffle_epi32 147#i32 (V f) = ok (V fun i => f (rotLane 3 i)) := by
  rw [shuffle_V _ 147 rfl]
  exact congrArg ok (V_congr fun i hi => by interval_cases i <;> rfl)

/-- The rotate-by-16 mask. -/
theorem m16_eq : core.core_arch.x86.avx._mm256_set_epi8 13#i8 12#i8 15#i8 14#i8 9#i8 8#i8
        11#i8 10#i8 5#i8 4#i8 7#i8 6#i8 1#i8 0#i8 3#i8 2#i8 13#i8 12#i8 15#i8
        14#i8 9#i8 8#i8 11#i8 10#i8 5#i8 4#i8 7#i8 6#i8 1#i8 0#i8 3#i8 2#i8 =
    ok 0x0d0c0f0e09080b0a0504070601000302_0d0c0f0e09080b0a0504070601000302#256 := by
  rfl

/-- The rotate-by-8 mask. -/
theorem m8_eq : core.core_arch.x86.avx._mm256_set_epi8 14#i8 13#i8 12#i8 15#i8 10#i8 9#i8
        8#i8 11#i8 6#i8 5#i8 4#i8 7#i8 2#i8 1#i8 0#i8 3#i8 14#i8 13#i8 12#i8
        15#i8 10#i8 9#i8 8#i8 11#i8 6#i8 5#i8 4#i8 7#i8 2#i8 1#i8 0#i8 3#i8 =
    ok 0x0e0d0c0f0a09080b0605040702010003_0e0d0c0f0a09080b0605040702010003#256 := by
  rfl

/-- `VPSHUFB` by a mask that moves each 32-bit lane's bytes within it. -/
theorem shuffle_bits (f : Nat → BitVec 32) (m : BitVec 256) (k : Nat) (hk : k < 256) :
    (ofHalves fun j => ofBytes fun i =>
      if (byte (half m j) i).msb then 0 else byte (half (V f) j) ((byte (half m j) i).toNat % 16)).getLsbD k =
      if (byte (half m (k / 128)) (k % 128 / 8)).msb then false else
        (f ((128 * (k / 128) + 8 * ((byte (half m (k / 128)) (k % 128 / 8)).toNat % 16) + k % 8) / 32)).getLsbD
          ((128 * (k / 128) + 8 * ((byte (half m (k / 128)) (k % 128 / 8)).toNat % 16) + k % 8) % 32) := by
  rw [getLsbD_ofHalves]
  simp only [hk, decide_true, Bool.true_and]
  rw [getLsbD_ofBytes _ (Nat.mod_lt _ (by omega))]
  split
  · simp
  · rw [getLsbD_byte _ _ (by omega), getLsbD_half, getLsbD_V]
    generalize (byte (half m (k / 128)) (k % 128 / 8)).toNat = t
    have h16 : t % 16 < 16 := Nat.mod_lt _ (by omega)
    rw [show k % 128 % 8 = k % 8 by omega]
    simp [show 8 * (t % 16) + k % 8 < 128 by omega, show 128 * (k / 128) + (8 * (t % 16) + k % 8) < 256 by omega,
      Nat.add_assoc]

theorem rot16_V (f : Nat → BitVec 32) :
    core.core_arch.x86.avx2._mm256_shuffle_epi8 (V f)
      0x0d0c0f0e09080b0a0504070601000302_0d0c0f0e09080b0a0504070601000302#256 =
    ok (V fun i => (f i).rotateLeft 16) := by
  simp only [core.core_arch.x86.avx2._mm256_shuffle_epi8, ok.injEq]
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  rw [shuffle_bits _ _ _ hk, getLsbD_V]
  simp only [hk, decide_true, Bool.true_and, BitVec.getLsbD_rotateLeft]
  interval_cases k <;> simp +decide [byte, half]

theorem rot8_V (f : Nat → BitVec 32) :
    core.core_arch.x86.avx2._mm256_shuffle_epi8 (V f)
      0x0e0d0c0f0a09080b0605040702010003_0e0d0c0f0a09080b0605040702010003#256 =
    ok (V fun i => (f i).rotateLeft 8) := by
  simp only [core.core_arch.x86.avx2._mm256_shuffle_epi8, ok.injEq]
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  rw [shuffle_bits _ _ _ hk, getLsbD_V]
  simp only [hk, decide_true, Bool.true_and, BitVec.getLsbD_rotateLeft]
  interval_cases k <;> simp +decide [byte, half]

/-! ## The double round -/

/-- The state of the block in half `h` of the four row vectors. -/
def rows (a b c d : BitVec 256) (h : Nat) : List (BitVec 32) :=
  [a, b, c, d].flatMap fun r => (List.range 4).map fun i => lane32x8 r (4 * h + i)

theorem body_V (it : core.ops.range.Range Usize) (hlt : it.start.val < it.end.val)
    (fa fb fc fd : Nat → BitVec 32) :
    low.x86_64.chacha20.core_2x_loop0.body it (V fa) (V fb) (V fc) (V fd) ⦃ r =>
      ∃ it' a b c d, r = .cont (it', a, b, c, d) ∧ it'.start.val = it.start.val + 1 ∧
        it'.end = it.end ∧
        ∀ h < 2, rows a b c d h = chacha20.innerBlock (rows (V fa) (V fb) (V fc) (V fd) h) ⦄ := by
  unfold low.x86_64.chacha20.core_2x_loop0.body
  step with core.iter.range.IteratorRange.next_Usize_some_spec as ⟨o, it', ho, hst, hen⟩
  subst ho
  simp only [add_V, xor_V, m16_eq, m8_eq, rot16_V, rot8_V, slli12_V, srli20_V, slli7_V, srli25_V,
    or_V, shuffle57_V, shuffle78_V, shuffle147_V, bind_ok, WP.spec_ok]
  refine ⟨_, _, _, _, _, rfl, hst, hen, ?_⟩
  intro h hh
  interval_cases h <;>
  · simp only [rows, List.flatMap_cons, List.flatMap_nil,
      show List.range 4 = [0, 1, 2, 3] from rfl, List.map_cons, List.map_nil, List.cons_append,
      List.nil_append, List.append_nil]
    simp (disch := omega) only [lane_V, Nat.reduceMul, Nat.reduceAdd]
    simp [chacha20.innerBlock, chacha20.quarterRound, chacha20.qr, rotLane, rotl12, rotl7]

end rind.x86_64.avx2
#print axioms rind.x86_64.avx2.body_V
#print axioms rind.x86_64.avx2.rot16_V
