import Rind.X86_64.MlKemTail
import Rind.X86_64.Keccak8Avx512
import Rind.X86_64.MlKemCbd
open Aeneas Aeneas.Std Result rind.spec Spec Spec.MLKEM rind.spec.mlkem rind.simd

/-!
# ML-KEM-1024's eight-way AVX-512 matrix sampling

On x86_64 with AVX-512, `sample_ntt` samples ML-KEM-1024's sixteen
polynomials eight at a time: `low::x86_64::mlkem_sample_poly_ntt_8x` absorbs
eight SHAKE128 inputs into the eight-way Keccak-f's vectors, squeezes three
blocks of each, and keeps each block's 12-bit candidates below `q` with
`VPERMB`, `VPSRLVW`, `VPCMPUW`, and `VPCOMPRESSW`, over
`Rind.X86_64.Simd`'s models of them and `Rind.X86_64.FunsExternal`'s of its
load and stores, and `Rind.X86_64.Keccak8Avx512`'s proof of the permutation.
`sample_poly_ntt_8x_avx512_spec` proves each polynomial then holds the first
candidates of SHAKE128's first 504 bytes on its input, up to 256 (`Filled`),
and the tail sponge of each with fewer continues after them;
`sample_poly_ntt_8x_spec` that `tail_case` then fills the rest, so each
polynomial is SHAKE128's first 256 candidates (`Sampled`), which
`sampleNTT_sampled` shows is FIPS 203's `SampleNTT`; and `sample_ntt_spec`
that `sample_ntt` writes ML-KEM-1024's matrix, or its transpose, so.
Each assumes the CPU has what the sampler needs (`RunsMlKem8x`), since the
four-way path it falls back to runs aws-lc's rejection sampling, which no
x86_64 proof covers yet, and that `SampleNTT` finishes on each input
(`Halts`), as `Rind.Aarch64.MlKemSample`'s do.
-/

namespace rind.x86_64

namespace MlKemSample8x

open MlKemCoding MlKemTail keccak8

/-! ## Lanes of 512-bit vectors -/

theorem getLsbD_ofLanesLE (w n : ℕ) (f : ℕ → BitVec w) (k : ℕ) :
    (ofLanesLE w n f).getLsbD k = (decide (k < w * n) && (f (k / w)).getLsbD (k % w)) := by
  unfold ofLanesLE
  rw [BitVec.getLsbD_cast, BitVec.getLsbD_ofBoolListLE, List.getD_eq_getElem?_getD]
  by_cases hk : k < w * n
  · rw [List.getElem?_map, List.getElem?_range hk]; simp [hk]
  · rw [List.getElem?_eq_none (by simp; omega)]; simp [hk]

theorem extract_ofLanesLE (w n : ℕ) (f : ℕ → BitVec w) (i : ℕ) (hi : i < n) :
    (ofLanesLE w n f).extractLsb' (w * i) w = f i := by
  apply BitVec.eq_of_getLsbD_eq; intro t ht
  have hw : 0 < w := by omega
  have h1 : (w * i + t) / w = i := by
    rw [Nat.add_comm, Nat.add_mul_div_left _ _ hw, Nat.div_eq_of_lt ht, Nat.zero_add]
  have h2 : (w * i + t) % w = t := by
    rw [Nat.add_comm, Nat.add_mul_mod_self_left, Nat.mod_eq_of_lt ht]
  have h3 : w * i + t < w * n := by
    have := Nat.mul_le_mul_left w (show i + 1 ≤ n by omega)
    rw [Nat.mul_succ] at this; omega
  simp only [BitVec.getLsbD_extractLsb', ht, decide_true, Bool.true_and, getLsbD_ofLanesLE, h1, h2, h3]

theorem ofLanesLE_and (w n : ℕ) (f g : ℕ → BitVec w) :
    ofLanesLE w n f &&& ofLanesLE w n g = ofLanesLE w n fun i => f i &&& g i := by
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  simp only [BitVec.getLsbD_and, getLsbD_ofLanesLE]
  cases decide (k < w * n) <;> simp

theorem lane16x32_and (x y : BitVec 512) (k : ℕ) :
    lane16x32 (x &&& y) k = lane16x32 x k &&& lane16x32 y k := by
  apply BitVec.eq_of_getLsbD_eq; intro t ht
  simp only [lane16x32, BitVec.getLsbD_extractLsb', BitVec.getLsbD_and, ht, decide_true, Bool.true_and]

theorem byte64_ofBytes64 (f : ℕ → BitVec 8) (i : ℕ) (hi : i < 64) : byte64 (ofBytes64 f) i = f i :=
  extract_ofLanesLE 8 64 f i hi

theorem lane16x32_ofLanes16x32 (f : ℕ → BitVec 16) (i : ℕ) (hi : i < 32) :
    lane16x32 (ofLanes16x32 f) i = f i :=
  extract_ofLanesLE 16 32 f i hi

/-- A 16-bit element of a vector of bytes is its two bytes, the first low. -/
theorem toNat_lane16x32_ofBytes64 (f : ℕ → BitVec 8) (k : ℕ) (hk : k < 32) :
    (lane16x32 (ofBytes64 f) k).toNat = (f (2 * k)).toNat + 256 * (f (2 * k + 1)).toNat := by
  have : lane16x32 (ofBytes64 f) k = f (2 * k + 1) ++ f (2 * k) := by
    apply BitVec.eq_of_getLsbD_eq; intro t ht
    simp only [lane16x32, ofBytes64, BitVec.getLsbD_extractLsb', ht, decide_true, Bool.true_and,
      getLsbD_ofLanesLE, BitVec.getLsbD_append]
    by_cases h8 : t < 8
    · simp [h8, show 16 * k + t < 8 * 64 by omega, show (16 * k + t) / 8 = 2 * k by omega,
        show (16 * k + t) % 8 = t by omega]
    · simp [h8, show 16 * k + t < 8 * 64 by omega, show (16 * k + t) / 8 = 2 * k + 1 by omega,
        show (16 * k + t) % 8 = t - 8 by omega]
  rw [this, BitVec.toNat_append, ← Nat.shiftLeft_add_eq_or_of_lt (f (2 * k)).isLt, Nat.shiftLeft_eq]
  ring

/-- A 16-bit element of a vector of 32-bit elements is a half of one. -/
theorem lane16x32_ofLanes32x16 (f : ℕ → BitVec 32) (k : ℕ) (hk : k < 32) :
    lane16x32 (ofLanes32x16 f) k = (f (k / 2)).extractLsb' (16 * (k % 2)) 16 := by
  apply BitVec.eq_of_getLsbD_eq; intro t ht
  simp only [lane16x32, ofLanes32x16, BitVec.getLsbD_extractLsb', ht, decide_true, Bool.true_and,
    getLsbD_ofLanesLE]
  simp [show 16 * k + t < 32 * 16 by omega, show (16 * k + t) / 32 = k / 2 by omega,
    show (16 * k + t) % 32 = 16 * (k % 2) + t by omega]

/-! ## The candidates of a vector pass -/

/-- Candidate `k` of the bytes `g` from three-byte groups, as FIPS 203's
`SampleNTT` reads them: of group `j = k / 2`, the low 12 bits of its first
two bytes for even `k`, and the high 12 bits of its last two for odd. -/
def cand (g : ℕ → Byte) (k : ℕ) : ℕ :=
  if k % 2 = 0 then (g (3 * (k / 2))).val + 256 * ((g (3 * (k / 2) + 1)).val % 16)
  else (g (3 * (k / 2) + 1)).val / 16 + 16 * (g (3 * (k / 2) + 2)).val

theorem cand_lt (g : ℕ → Byte) (k : ℕ) : cand g k < 4096 := by
  have h0 := (g (3 * (k / 2))).isLt
  have h1 := (g (3 * (k / 2) + 1)).isLt
  have h2 := (g (3 * (k / 2) + 2)).isLt
  unfold cand; simp only [Byte.val] at *; split <;> omega

theorem cand_shift (g : ℕ → Byte) (x : ℕ) : cand g (2 + x) = cand (fun m => g (3 + m)) x := by
  unfold cand
  rw [show (2 + x) % 2 = x % 2 by omega, show 3 * ((2 + x) / 2) = 3 + 3 * (x / 2) by omega]
  simp only [Nat.add_assoc]

/-- The candidates below `q` of `3m` bytes are those of their `2m` candidates. -/
theorem accepted_cand (m : ℕ) : ∀ (g : ℕ → Byte),
    accepted ((List.range (3 * m)).map g) = ((List.range (2 * m)).map (cand g)).filter (· < 3329) := by
  induction m with
  | zero => intro g; simp [accepted]
  | succ m ih =>
    intro g
    have e1 : (List.range (3 * (m + 1))).map g =
        g 0 :: g 1 :: g 2 :: (List.range (3 * m)).map (fun x => g (3 + x)) := by
      rw [show 3 * (m + 1) = 3 + 3 * m by ring, List.range_add, List.map_append, List.map_map]
      simp [List.range_succ, Function.comp_def]
    have e2 : (List.range (2 * (m + 1))).map (cand g) =
        cand g 0 :: cand g 1 :: (List.range (2 * m)).map (cand fun x => g (3 + x)) := by
      rw [show 2 * (m + 1) = 2 + 2 * m by ring, List.range_add, List.map_append, List.map_map]
      simp only [List.range_succ, List.range_zero, List.nil_append, List.map_cons, List.map_nil,
        List.cons_append, List.nil_append, Function.comp_def, cand_shift]
    rw [e1, e2, accepted, ih]
    simp only [keep, cand, q, List.filter_cons]
    simp only [show (1 : ℕ) % 2 = 1 from rfl, show (1 : ℕ) / 2 = 0 from rfl, Nat.mul_zero,
      Nat.zero_add, ite_true, show ¬ (1 = 0) by decide, ite_false]
    simp only [Byte.val] at *
    split_ifs <;> (try simp only [decide_eq_true_eq] at *) <;> first | omega | simp_all

/-! ## Writing candidates after those an output holds -/

/-- Writing the candidates `K` that follow `W` where `out` has room. -/
theorem filled_append (W K : List ℕ) (out vals : List I16) (d : ℕ) (hd : d < out.length)
    (h : Filled W 0 out d) (hv : vals.length = min K.length (out.length - d))
    (hvals : ∀ t < vals.length, (vals[t]!).val = ((K[t]! : ℕ) : ℤ)) :
    Filled (W ++ K) 0 (out.setSlice! d vals) (d + vals.length) := by
  obtain ⟨h1, h2, h3⟩ := h
  have hW : W.length = d := by omega
  refine ⟨by simp; omega, by simp; omega, fun k hk => ?_⟩
  by_cases hkd : k < d
  · rw [List.getElem!_setSlice!_prefix _ _ _ _ hkd, h3 k hkd, Nat.zero_add,
      getElem!_append_left' _ _ _ (by omega)]
  · have e := getElem!_append_length W K (k - d)
    rw [show W.length + (k - d) = k by omega] at e
    rw [List.getElem!_setSlice!_middle _ _ _ _ ⟨by omega, by omega, by omega⟩, hvals _ (by omega),
      Nat.zero_add, e]

/-! ## The sampler's constants and vectors -/

theorem rate_words_spec : low.x86_64.mlkem_sample_poly_ntt_8x.RATE_WORDS ⦃ r => r.val = 21 ⦄ := by
  unfold low.x86_64.mlkem_sample_poly_ntt_8x.RATE_WORDS; step*

theorem group_bytes_spec : low.x86_64.mlkem_sample_poly_ntt_8x.GROUP_BYTES ⦃ r => r.val = 48 ⦄ := by
  unfold low.x86_64.mlkem_sample_poly_ntt_8x.GROUP_BYTES low.x86_64.mlkem_sample_poly_ntt_8x.GROUP_CANDIDATES
  step*

theorem rate_bytes_spec : low.x86_64.mlkem_sample_poly_ntt_8x.RATE_BYTES ⦃ r => r.val = 168 ⦄ := by
  unfold low.x86_64.mlkem_sample_poly_ntt_8x.RATE_BYTES
  step with rate_words_spec as ⟨i, hi⟩
  step*

theorem groups_spec : low.x86_64.mlkem_sample_poly_ntt_8x.GROUPS ⦃ r => r.val = 4 ⦄ := by
  unfold low.x86_64.mlkem_sample_poly_ntt_8x.GROUPS
  step with rate_bytes_spec as ⟨i, hi⟩
  step with group_bytes_spec as ⟨i1, hi1⟩
  unfold core.num.Usize.div_ceil
  rw [dif_neg (by omega)]
  simp only [WP.spec_ok, UScalar.ofNatCore_val_eq, hi, hi1]

theorem last_group_spec : low.x86_64.mlkem_sample_poly_ntt_8x.LAST_GROUP ⦃ r => r.val = 65535 ⦄ := by
  unfold low.x86_64.mlkem_sample_poly_ntt_8x.LAST_GROUP
  step with groups_spec as ⟨i, hi⟩
  step as ⟨i1, hi1⟩
  step with group_bytes_spec as ⟨i2, hi2⟩
  step as ⟨i3, hi3⟩
  step with rate_bytes_spec as ⟨i4, hi4⟩
  step*

/-- `SPREAD` as the vector `load` reads. -/
abbrev spreadV : BitVec 512 :=
  ofBytes64 fun i => (low.x86_64.mlkem_sample_poly_ntt_8x.SPREAD.val[i]!).bv

/-- The shift counts: none in even 16-bit elements, four in odd. -/
abbrev shiftsV : BitVec 512 := ofLanes32x16 fun _ => (262144#i32).bv

/-- The 12-bit mask in each 16-bit element. -/
abbrev twelveV : BitVec 512 := ofLanes16x32 fun _ => (4095#i16).bv

/-- `q` in each 16-bit element. -/
abbrev qV : BitVec 512 :=
  ofLanes16x32 fun _ => (UScalar.hcast .I16 low.x86_64.mlkem_sample_poly_ntt_8x.Q).bv

/-- `SPREAD` gathers group `k / 2`'s first two bytes into element `k` for even
`k`, its last two for odd. -/
theorem spread_bytes (k : ℕ) (hk : k < 32) :
    (byte64 spreadV (2 * k)).toNat = 3 * (k / 2) + k % 2 ∧
      (byte64 spreadV (2 * k + 1)).toNat = 3 * (k / 2) + k % 2 + 1 := by
  rw [byte64_ofBytes64 _ _ (by omega), byte64_ofBytes64 _ _ (by omega)]
  unfold low.x86_64.mlkem_sample_poly_ntt_8x.SPREAD
  interval_cases k <;> decide

/-- The candidates of the 64 bytes `raw`, as `VPERMB`, `VPSRLVW`, and `VPANDQ`
compute them. -/
def candV (raw : BitVec 512) : BitVec 512 :=
  (ofLanes16x32 fun i => if (lane16x32 shiftsV i).toNat > 15 then 0 else
    lane16x32 (ofBytes64 fun i => byte64 raw ((byte64 spreadV i).toNat % 64)) i >>>
      (lane16x32 shiftsV i).toNat) &&& twelveV

theorem candV_lane (raw : BitVec 512) (k : ℕ) (hk : k < 32) :
    (lane16x32 (candV raw) k).toNat = cand (byte64 raw) k := by
  unfold candV twelveV
  rw [lane16x32_and, lane16x32_ofLanes16x32 _ _ hk, lane16x32_ofLanes16x32 _ _ hk]
  have hsh : lane16x32 shiftsV k = (262144#i32).bv.extractLsb' (16 * (k % 2)) 16 :=
    lane16x32_ofLanes32x16 _ k hk
  have hb := toNat_lane16x32_ofBytes64 (fun i => byte64 raw ((byte64 spreadV i).toNat % 64)) k hk
  obtain ⟨hs0, hs1⟩ := spread_bytes k hk
  simp only [hs0, hs1, Nat.mod_eq_of_lt (show 3 * (k / 2) + k % 2 < 64 by omega),
    Nat.mod_eq_of_lt (show 3 * (k / 2) + k % 2 + 1 < 64 by omega)] at hb
  have h12 : ((4095#i16 : I16).bv).toNat = 2 ^ 12 - 1 := by decide
  rw [hsh, BitVec.toNat_and, h12, Nat.and_two_pow_sub_one_eq_mod]
  have e0 := (byte64 raw (3 * (k / 2))).isLt
  have e1 := (byte64 raw (3 * (k / 2) + 1)).isLt
  have e2 := (byte64 raw (3 * (k / 2) + 2)).isLt
  unfold cand
  rcases Nat.mod_two_eq_zero_or_one k with h | h
  · have : ((262144#i32 : I32).bv.extractLsb' (16 * 0) 16).toNat = 0 := by decide
    simp only [h, this, Nat.add_zero, show ¬ (0 > 15) by omega, ite_false, BitVec.ushiftRight_zero, ite_true] at hb ⊢
    simp only [Byte.val]
    rw [hb]; omega
  · have : ((262144#i32 : I32).bv.extractLsb' (16 * 1) 16).toNat = 4 := by decide
    simp only [h, this, show ¬ (4 > 15) by omega, ite_false, show ¬ (1 = 0) by omega,
      show 3 * (k / 2) + 1 + 1 = 3 * (k / 2) + 2 by omega] at hb ⊢
    simp only [Byte.val]
    rw [BitVec.toNat_ushiftRight, Nat.shiftRight_eq_div_pow, hb]; omega

/-- Bit `i` of a `VPCMPUW` mask. -/
theorem cmplt_bit (a b : BitVec 512) (i : ℕ) (hi : i < 32) :
    (ofLanesLE 1 32 fun j => BitVec.ofBool (lane16x32 a j < lane16x32 b j)).getLsbD i =
      decide ((lane16x32 a i).toNat < (lane16x32 b i).toNat) := by
  rw [getLsbD_ofLanesLE]
  simp [show i < 1 * 32 by omega, BitVec.lt_def, Nat.mod_one]

theorem lane_qV (i : ℕ) (hi : i < 32) : (lane16x32 qV i).toNat = 3329 := by
  unfold qV
  rw [lane16x32_ofLanes16x32 _ _ hi]
  unfold low.x86_64.mlkem_sample_poly_ntt_8x.Q
  decide

/-- The lanes a mask selects from 32, those of the first `n` that `p` holds of. -/
theorem filter_bits (x : U32) (n : ℕ) (hn : n ≤ 32) (p : ℕ → Bool)
    (hx : ∀ i < 32, x.bv.getLsbD i = (decide (i < n) && p i)) :
    (List.range 32).filter (fun i => x.bv.getLsbD i) = (List.range n).filter p := by
  have hr : List.range 32 = List.range n ++ (List.range (32 - n)).map (n + ·) := by
    rw [← List.range_add, show n + (32 - n) = 32 by omega]
  rw [hr, List.filter_append]
  have h2 : ((List.range (32 - n)).map (n + ·)).filter (fun i => x.bv.getLsbD i) = [] := by
    rw [List.filter_eq_nil_iff]
    intro a ha
    simp only [List.mem_map, List.mem_range] at ha
    obtain ⟨b, hb, rfl⟩ := ha
    rw [hx _ (by omega)]; simp
  rw [h2, List.append_nil]
  apply List.filter_congr
  intro a ha
  simp only [List.mem_range] at ha
  rw [hx _ (by omega)]; simp [ha]

/-! ## The intrinsics' results -/

theorem load_spec (b : Std.Array U8 64#usize) :
    low.x86_64.mlkem_sample_poly_ntt_8x.load b ⦃ r => r = ofBytes64 fun j => (b.val[j]!).bv ⦄ := by
  simp [low.x86_64.mlkem_sample_poly_ntt_8x.load, WP.spec_ok]

theorem permutexvar_spec (idx a : BitVec 512) :
    core.core_arch.x86.avx512vbmi._mm512_permutexvar_epi8 idx a ⦃ r =>
      r = ofBytes64 fun i => byte64 a ((byte64 idx i).toNat % 64) ⦄ := by
  simp [core.core_arch.x86.avx512vbmi._mm512_permutexvar_epi8, WP.spec_ok]

theorem srlv_spec (a cnt : BitVec 512) :
    core.core_arch.x86.avx512bw._mm512_srlv_epi16 a cnt ⦃ r =>
      r = ofLanes16x32 fun i => if (lane16x32 cnt i).toNat > 15 then 0 else
        lane16x32 a i >>> (lane16x32 cnt i).toNat ⦄ := by
  simp [core.core_arch.x86.avx512bw._mm512_srlv_epi16, WP.spec_ok]

theorem and_spec (a b : BitVec 512) :
    core.core_arch.x86.avx512f._mm512_and_si512 a b ⦃ r => r = a &&& b ⦄ := by
  simp [core.core_arch.x86.avx512f._mm512_and_si512, WP.spec_ok]

theorem cmplt_spec (a b : BitVec 512) :
    core.core_arch.x86.avx512bw._mm512_cmplt_epu16_mask a b ⦃ r =>
      ∀ i < 32, r.bv.getLsbD i = decide ((lane16x32 a i).toNat < (lane16x32 b i).toNat) ⦄ := by
  simp only [core.core_arch.x86.avx512bw._mm512_cmplt_epu16_mask, WP.spec_ok]
  exact fun i hi => cmplt_bit a b i hi

theorem count_ones_spec (x : U32) :
    core.num.U32.count_ones x ⦃ r => r.val = ((List.range 32).filter fun i => x.bv.getLsbD i).length ⦄ := by
  simp only [core.num.U32.count_ones, WP.spec_ok]
  have : ((List.range 32).filter fun i => x.bv.getLsbD i).length ≤ 32 :=
    (List.length_filter_le _ _).trans (by simp)
  show (BitVec.ofNat 32 _).toNat = _
  rw [BitVec.toNat_ofNat, Nat.mod_eq_of_lt (by omega)]

theorem compress_spec (k : U32) (a : BitVec 512) :
    core.core_arch.x86.avx512vbmi2._mm512_maskz_compress_epi16 k a ⦃ r =>
      ∀ t < 32, lane16x32 r t = (((List.range 32).filter fun j => k.bv.getLsbD j).map (lane16x32 a)).getD t 0 ⦄ := by
  simp only [core.core_arch.x86.avx512vbmi2._mm512_maskz_compress_epi16, WP.spec_ok]
  exact fun t ht => lane16x32_ofLanes16x32 _ t ht

theorem store_low_spec (out : Slice I16) (v : BitVec 512) (h : out.length ≤ 32) :
    low.x86_64.mlkem_sample_poly_ntt_8x.store_low out v ⦃ r =>
      r.length = out.length ∧ ∀ t < out.length, r.val[t]! = ⟨lane16x32 v t⟩ ⦄ := by
  simp only [low.x86_64.mlkem_sample_poly_ntt_8x.store_low, WP.spec_ok]
  refine ⟨by simp [Slice.length, Slice.from_val], fun t ht => ?_⟩
  have ht' : t < out.val.length := ht
  rw [Slice.from_val, getElem!_pos _ t (by simp; omega), List.getElem_mapIdx, if_pos (by omega)]

/-! ## A vector pass -/

/-- `bytes` holds block `c` of SHAKE128 on `M`. -/
def RateBytes (M : List Byte) (c : ℕ) (bytes : List U8) : Prop :=
  ∀ m < 168, (bytes[m]!).bv = xofByte M (168 * c + m)

/-- The bytes of the block the passes before pass `t` read. -/
def gend (t : ℕ) : ℕ := min (48 * t) 168

/-- Pass `t` reads the next 48 bytes, or the block's last 24. -/
theorem acc_pass (M : List Byte) (c t : ℕ) (ht : t < 4) :
    acc M (168 * c + gend (t + 1)) = acc M (168 * c + gend t) ++
      accepted ((List.range (if t = 3 then 24 else 48)).map fun j => xofByte M (168 * c + 48 * t + j)) := by
  have h1 : gend t = 48 * t := by unfold gend; omega
  have h2 : gend (t + 1) = 48 * t + (if t = 3 then 24 else 48) := by unfold gend; split <;> omega
  rw [h1, h2, ← Nat.add_assoc, acc, shake128_add, accepted_append _ _ (by simp [shake128_map]; omega)]

/-- The passes over polynomial `i` before pass `t`: it holds the candidates
of the bytes they read, and the rest are as they were. -/
def GroupInv (M : List Byte) (c i : ℕ) (out0 : Std.Array (Std.Array I16 256#usize) 8#usize)
    (used0 : Std.Array Usize 8#usize) (t : ℕ)
    (s : Std.Array (Std.Array I16 256#usize) 8#usize × Std.Array Usize 8#usize) : Prop :=
  Filled (acc M (168 * c + gend t)) 0 (s.1.val[i]!).val (s.2.val[i]!).val ∧
    ∀ p < 8, p ≠ i → s.1.val[p]! = out0.val[p]! ∧ s.2.val[p]! = used0.val[p]!

theorem i16_val_of_lt (x : BitVec 16) (h : x.toNat < 2 ^ 15) : (⟨x⟩ : I16).val = x.toNat := by
  show x.toInt = _
  rw [BitVec.toInt_eq_toNat_of_lt (by omega)]

set_option maxHeartbeats 1000000 in
/-- The passes over polynomial `i` of block `c` keep its candidates below `q`,
as many as fit. -/
theorem passes_spec (M : List Byte) (c : ℕ) (bytes : Std.Array U8 232#usize) (hb : RateBytes M c bytes.val)
    (i : Usize) (hi : i.val < 8) (four : Usize) (h4 : four.val = 4)
    (out0 : Std.Array (Std.Array I16 256#usize) 8#usize) (used0 : Std.Array Usize 8#usize)
    (hinv : GroupInv M c i.val out0 used0 0 (out0, used0)) :
    low.x86_64.mlkem_sample_poly_ntt_8x.squeeze_rate_and_reject_loop1_loop1 four
      { start := 0#usize, «end» := four } out0 used0 spreadV qV twelveV shiftsV bytes i ⦃ r =>
      GroupInv M c i.val out0 used0 4 r ⦄ := by
  unfold low.x86_64.mlkem_sample_poly_ntt_8x.squeeze_rate_and_reject_loop1_loop1
  apply range_loop 4 (GroupInv M c i.val out0 used0) _ ?_ { start := 0#usize, «end» := four } (out0, used0)
    (by simp [h4]) (by simp) hinv
  rintro it ⟨out, used⟩ he hs ⟨hf, hother⟩
  simp only at hf hother
  unfold low.x86_64.mlkem_sample_poly_ntt_8x.squeeze_rate_and_reject_loop1_loop1.body
  step as ⟨o', it1, ho, he1⟩
  split_ifs at ho with hlt
  · obtain ⟨rfl, hst⟩ := ho
    simp only
    have ht : it.start.val < 4 := by omega
    step as ⟨u, hu⟩
    have huv : u = used.val[i.val]! := by rw [hu, getElem!_pos]
    split
    · rename_i hlt256
      have hu256 : u.val < 256 := by scalar_tac
      step with group_bytes_spec as ⟨gb, hgb⟩
      step as ⟨offset, hoff⟩
      step as ⟨i4, hi4⟩
      step with core.slice.index.SliceIndexRangeUsizeSlice.index.step_spec as ⟨sl, hsl, hsll⟩
      rw [MlKemCbd.try_from_eq 64#usize sl (by rw [hsll]; simp; omega)]
      simp only [bind_ok, core.result.Result.unwrap]
      step with load_spec as ⟨raw, hraw⟩
      step with permutexvar_spec as ⟨mi, hmi⟩
      step with srlv_spec as ⟨mi1, hmi1⟩
      step with and_spec as ⟨cands, hcands⟩
      have hcv : cands = candV raw := by rw [hcands, hmi1, hmi]; rfl
      -- The bytes the pass reads.
      have hoffv : offset.val = 48 * it.start.val := by rw [hoff, hgb]; ring
      have hg (j : ℕ) (hj : j < (if it.start.val = 3 then 24 else 48)) :
          byte64 raw j = xofByte M (168 * c + 48 * it.start.val + j) := by
        have hj64 : j < 64 := by split at hj <;> omega
        rw [hraw, byte64_ofBytes64 _ _ hj64, Std.Array.from_val, hsl,
          List.getElem!_slice _ _ _ _ ⟨by simp; scalar_tac, by scalar_tac⟩, hoffv, Std.Array.val_to_slice,
          hb (48 * it.start.val + j) (by split at hj <;> omega), Nat.add_assoc]
      have hlanes (k : ℕ) (hk : k < 32) : (lane16x32 cands k).toNat = cand (byte64 raw) k := by
        rw [hcv]; exact candV_lane raw k hk
      step with cmplt_spec as ⟨acc0, hacc0⟩
      have hacc0' (k : ℕ) (hk : k < 32) : acc0.bv.getLsbD k = decide (cand (byte64 raw) k < 3329) := by
        rw [hacc0 k hk, hlanes k hk, lane_qV k hk]
      step as ⟨i5, hi5⟩
      have hA : (if it.start = i5 then (do
          let i6 ← low.x86_64.mlkem_sample_poly_ntt_8x.LAST_GROUP
          ok (acc0 &&& i6)) else ok acc0) ⦃ (a : U32) => ∀ k < 32, a.bv.getLsbD k =
            (decide (k < (if it.start.val = 3 then 16 else 32)) && decide (cand (byte64 raw) k < 3329)) ⦄ := by
        split
        · rename_i hg3
          have h3 : it.start.val = 3 := by have := congrArg UScalar.val hg3; scalar_tac
          apply WP.spec_bind last_group_spec
          intro lg hlg
          apply (WP.spec_ok _).2
          intro k hk
          have hbit : lg.bv.getLsbD k = decide (k < 16) := by
            have : lg.bv.toNat = 2 ^ 16 - 1 := hlg
            rw [BitVec.getLsbD, this, Nat.testBit_two_pow_sub_one]
          change (UScalar.bv (acc0 &&& lg)).getLsbD k = _
          rw [UScalar.bv_and, BitVec.getLsbD_and, hacc0' k hk, hbit]
          simp only [h3, ite_true]
          rw [Bool.and_comm]
        · rename_i hg3
          have h3 : it.start.val ≠ 3 := by intro h; exact hg3 (by scalar_tac)
          apply (WP.spec_ok _).2
          intro k hk
          rw [hacc0' k hk]
          simp [h3, hk]
      apply WP.spec_bind hA
      intro acc1 hacc1
      -- The candidates the pass keeps.
      set valid := if it.start.val = 3 then 16 else 32 with hvalid
      set g := byte64 raw with hgdef
      have hL := filter_bits acc1 valid (by rw [hvalid]; split <;> omega)
        (fun k => decide (cand g k < 3329)) hacc1
      set L := (List.range 32).filter fun j => acc1.bv.getLsbD j with hLdef
      have hLlen : L.length ≤ 32 := (List.length_filter_le _ _).trans (by simp)
      have hLlt : ∀ x ∈ L, x < 32 := by
        intro x hx; rw [hLdef, List.mem_filter, List.mem_range] at hx; exact hx.1
      -- The candidates as bytes of the stream.
      set K := L.map (cand g) with hKdef
      have hK : accepted ((List.range (if it.start.val = 3 then 24 else 48)).map
          fun j => xofByte M (168 * c + 48 * it.start.val + j)) = K := by
        rw [List.map_congr_left (fun j hj => (hg j (List.mem_range.mp hj)).symm)]
        have hm : (if it.start.val = 3 then 24 else 48) = 3 * (valid / 2) := by
          rw [hvalid]; split <;> rfl
        rw [hm, accepted_cand, show 2 * (valid / 2) = valid by rw [hvalid]; split <;> rfl,
          hKdef, hL, List.filter_map]
        rfl
      step as ⟨room, hroom⟩
      step with count_ones_spec as ⟨n1, hn1⟩
      step as ⟨accepted', hacc'⟩
      have haccv : accepted'.val = L.length := by
        rw [hacc', UScalar.cast_val_eq, hn1]; exact Nat.mod_eq_of_lt (by scalar_tac)
      have hT : (if accepted' < room then ok accepted' else ok room : Result Usize) ⦃ (tk : Usize) =>
          tk.val = min L.length (256 - u.val) ⦄ := by
        split
        · apply (WP.spec_ok _).2; scalar_tac
        · apply (WP.spec_ok _).2; scalar_tac
      apply WP.spec_bind hT
      intro take htake
      step with compress_spec as ⟨comp, hcomp⟩
      step as ⟨a1, back, ha1, hback⟩
      step as ⟨i7, hi7⟩
      step with Array.index_mut_SliceIndexRangeUsizeSlice.step a1 { start := u, «end» := i7 }
        (by simp only; scalar_tac) (by simp only; scalar_tac) as ⟨s1, back1, hs1, hs1l, hback1⟩
      step with store_low_spec s1 comp (by rw [hs1l]; scalar_tac) as ⟨s2, hs2l, hs2⟩
      step as ⟨i8, hi8⟩
      step as ⟨a2, ha2⟩
      refine ⟨by rw [he1]; exact he, hst, ht, ?_, ?_⟩
      · simp only
        have ha1v : a1 = out.val[i.val]! := by rw [ha1, getElem!_pos]
        rw [hback, Std.Array.set_val_eq, MlKemCoding.getElem!_set_self _ _ _ (by simp; omega),
          hback1, ha2, Std.Array.set_val_eq, MlKemCoding.getElem!_set_self _ _ _ (by simp; omega),
          hst, acc_pass M c _ ht, hK, hi8]
        have hd : u.val < a1.val.length := by simp; omega
        have hf' : Filled (acc M (168 * c + gend it.start.val)) 0 a1.val u.val := by
          rw [ha1v, huv]; exact hf
        have hs2v : s2.val.length = take.val := by
          have : s2.val.length = s2.length := rfl
          rw [this, hs2l, hs1l]; scalar_tac
        have := filled_append _ K a1.val s2.val u.val hd hf'
          (by rw [hs2v, htake, hKdef, List.length_map]; simp)
          (fun t htt => by
            rw [hs2v] at htt
            have htt' : t < s1.length := by rw [hs1l, hi7]; omega
            have htL : t < L.length := by rw [htake] at htt; omega
            rw [hs2 t htt', hcomp t (by omega), List.getD_eq_getElem?_getD, List.getElem?_map,
              List.getElem?_eq_getElem htL, Option.map_some, Option.getD_some]
            have hLt := hLlt _ (List.getElem_mem htL)
            have hlt4 := cand_lt g L[t]
            rw [i16_val_of_lt _ (by rw [hlanes _ hLt]; omega), hlanes _ hLt, hKdef,
              getElem!_pos _ t (by simp; omega), List.getElem_map])
        rw [hs2v] at this
        exact this
      · intro p hp hpi
        simp only
        rw [hback, Std.Array.set_val_eq, MlKemCoding.getElem!_set_ne _ _ _ _ (Ne.symm hpi), ha2,
          Std.Array.set_val_eq, MlKemCoding.getElem!_set_ne _ _ _ _ (Ne.symm hpi)]
        exact hother p hp hpi
    · rename_i hge
      have hu256 : ¬ u.val < 256 := by scalar_tac
      apply (WP.spec_ok _).2
      refine ⟨by rw [he1]; exact he, hst, ht, ?_, hother⟩
      obtain ⟨K, hK⟩ := acc_prefix M (show 168 * c + gend it.start.val ≤ 168 * c + gend (it.start.val + 1) by
        unfold gend; omega)
      rw [hst, ← hK]
      exact filled_full _ _ _ _ _ hf (by rw [← huv]; simp; omega)
  · obtain ⟨rfl, hst⟩ := ho
    apply (WP.spec_ok _).2
    have : it.start.val = 4 := by omega
    rw [this] at hf
    exact ⟨hf, hother⟩

/-! ## `squeeze_rate_and_reject` -/

theorem store_spec (v : BitVec 512) :
    low.x86_64.mlkem_sample_poly_ntt_8x.store v ⦃ r => ∀ p < 8, (r.val[p]!).bv = lane64x8 v p ⦄ := by
  simp only [low.x86_64.mlkem_sample_poly_ntt_8x.store, WP.spec_ok]
  intro p hp
  simp only [Array.make_val]
  rw [getElem!_pos _ p (by simp; omega), List.getElem_map, List.getElem_range]

/-- `squeeze_rate_and_reject`'s first loop stores each vector of the rate. -/
theorem rate_loop_spec (state : Std.Array core.core_arch.x86.__m512i 25#usize) (n : Usize) (hn : n.val = 21)
    (rate : Std.Array (Std.Array U64 8#usize) 21#usize) :
    low.x86_64.mlkem_sample_poly_ntt_8x.squeeze_rate_and_reject_loop0 { start := 0#usize, «end» := n } state rate
      ⦃ r => ∀ l < 21, ∀ p < 8, ((r.val[l]!).val[p]!).bv = lane64x8 (state.val[l]!) p ⦄ := by
  unfold low.x86_64.mlkem_sample_poly_ntt_8x.squeeze_rate_and_reject_loop0
  apply range_loop 21 (fun t (r : Std.Array (Std.Array U64 8#usize) 21#usize) =>
    ∀ l < t, ∀ p < 8, ((r.val[l]!).val[p]!).bv = lane64x8 (state.val[l]!) p) _ ?_
    { start := 0#usize, «end» := n } rate (by simp [hn]) (by simp) (fun l hl => absurd hl (by simp))
  rintro it r he hs hr
  unfold low.x86_64.mlkem_sample_poly_ntt_8x.squeeze_rate_and_reject_loop0.body
  step as ⟨o', it1, ho, he1⟩
  split_ifs at ho with hlt
  · obtain ⟨rfl, hst⟩ := ho
    simp only
    step as ⟨v, hv⟩
    step with store_spec as ⟨a, ha⟩
    step as ⟨r1, hr1⟩
    refine ⟨by rw [he1]; exact he, hst, by omega, fun l hl p hp => ?_⟩
    rw [hr1, Std.Array.set_val_eq]
    by_cases hlt' : l = it.start.val
    · subst hlt'
      rw [MlKemCoding.getElem!_set_self _ _ _ (by simp; omega), ha p hp, hv, getElem!_pos]
    · rw [MlKemCoding.getElem!_set_ne _ _ _ _ (Ne.symm hlt')]
      exact hr l (by omega) p hp
  · obtain ⟨rfl, hst⟩ := ho
    apply (WP.spec_ok _).2
    have : it.start.val = 21 := by omega
    rw [this] at hr
    exact hr

/-- `squeeze_rate_and_reject`'s second loop lays polynomial `i`'s rate out as bytes. -/
theorem bytes_loop_spec (rate : Std.Array (Std.Array U64 8#usize) 21#usize) (n : Usize) (hn : n.val = 21)
    (i : Usize) (hi : i.val < 8) (bytes : Std.Array U8 232#usize) :
    low.x86_64.mlkem_sample_poly_ntt_8x.squeeze_rate_and_reject_loop1_loop0 { start := 0#usize, «end» := n }
      rate bytes i ⦃ r => ∀ m < 168, (r.val[m]!).bv = ((rate.val[m / 8]!).val[i.val]!).bv.toLEBytes[m % 8]! ⦄ := by
  unfold low.x86_64.mlkem_sample_poly_ntt_8x.squeeze_rate_and_reject_loop1_loop0
  apply WP.spec_mono (range_loop 21 (fun t (r : Std.Array U8 232#usize) =>
    ∀ m < 8 * t, (r.val[m]!).bv = ((rate.val[m / 8]!).val[i.val]!).bv.toLEBytes[m % 8]!) _ ?_
    { start := 0#usize, «end» := n } bytes (by simp [hn]) (by simp) (fun m hm => absurd hm (by simp)))
  · intro r hr m hm; exact hr m (by omega)
  rintro it r he hs hr
  unfold low.x86_64.mlkem_sample_poly_ntt_8x.squeeze_rate_and_reject_loop1_loop0.body
  step as ⟨o', it1, ho, he1⟩
  split_ifs at ho with hlt
  · obtain ⟨rfl, hst⟩ := ho
    simp only
    step as ⟨i1, hi1⟩
    step as ⟨i2, hi2⟩
    step with Array.index_mut_SliceIndexRangeUsizeSlice.step r { start := i1, «end» := i2 }
      (by simp only; scalar_tac) (by simp only; scalar_tac) as ⟨s, back, hs, hsl, hback⟩
    step as ⟨a, ha⟩
    step as ⟨x, hx⟩
    step as ⟨a1, ha1⟩
    step as ⟨s1, hs1⟩
    step with core.slice.Slice.copy_from_slice.step_spec as ⟨s2, hs2⟩
    refine ⟨by rw [he1]; exact he, hst, by omega, fun m hm => ?_⟩
    rw [hback, hs2, hs1, Std.Array.val_to_slice]
    have hxa : x = (rate.val[it.start.val]!).val[i.val]! := by
      subst ha
      rw [getElem!_pos rate.val it.start.val (by simp; omega), getElem!_pos _ i.val (by simp; omega)]
      exact hx
    by_cases hmt : m < 8 * it.start.val
    · rw [List.getElem!_setSlice!_prefix _ _ _ _ (by omega)]
      exact hr m hmt
    · have hm8 : m / 8 = it.start.val := by omega
      rw [List.getElem!_setSlice!_middle _ _ _ _ ⟨by omega, by simp [ha1]; omega, by simp; omega⟩,
        ← getElem!_bv, ha1, show bv (List.map UScalar.mk x.bv.toLEBytes) = x.bv.toLEBytes by
          simp [bv, List.map_map, Function.comp_def], hm8, ← hxa, show m - i1.val = m % 8 by omega]
  · obtain ⟨rfl, hst⟩ := ho
    apply (WP.spec_ok _).2
    have : it.start.val = 21 := by omega
    rw [this] at hr
    exact hr

theorem getElem!_stateBytes (L : List (BitVec 64)) (j : ℕ) :
    (stateBytes L)[j]! = (L[j / 8]!).toLEBytes[j % 8]! := by
  have h := getElem!_sbl (L.map fun x => (⟨x⟩ : U64)) j
  have e : sbl (L.map fun x => (⟨x⟩ : U64)) = stateBytes L := by
    simp [sbl, List.map_map, Function.comp_def]
  rw [e] at h
  rw [h]
  by_cases hj : j / 8 < L.length
  · rw [getElem!_pos (L.map fun x => (⟨x⟩ : U64)) (j / 8) (by rw [List.length_map]; exact hj),
      getElem!_pos L (j / 8) hj, List.getElem_map]
  · rw [getElem!_neg (L.map fun x => (⟨x⟩ : U64)) (j / 8) (by rw [List.length_map]; exact hj),
      getElem!_neg L (j / 8) hj]; rfl

/-- Eight states whose bytes are SHAKE128's on `M p` after `c` blocks. -/
def AtBlock (M : ℕ → List Byte) (S : ℕ → List (BitVec 64)) (c : ℕ) : Prop :=
  ∀ p < 8, (S p).length = 25 ∧ stateBytes (S p) = keccakF^[c] (shake128Absorbed (M p))

/-- Byte `m` of block `c` is byte `m` of the state that yields it. -/
theorem xofByte_block (M : List Byte) (c m : ℕ) (hm : m < 168) :
    xofByte M (168 * c + m) = (keccakF^[c] (shake128Absorbed M))[m]! := by
  unfold xofByte
  rw [show (168 * c + m) / 168 = c by omega, show (168 * c + m) % 168 = m by omega]

set_option maxHeartbeats 1000000 in
/-- The polynomials' loop: each takes the candidates of its block. -/
theorem polys_spec (M : ℕ → List Byte) (S : ℕ → List (BitVec 64)) (c : ℕ) (hS : AtBlock M S c)
    (n : Usize) (hn : n.val = 21) (rate : Std.Array (Std.Array U64 8#usize) 21#usize)
    (hrate : ∀ l < 21, ∀ p < 8, ((rate.val[l]!).val[p]!).bv = (S p)[l]!)
    (out : Std.Array (Std.Array I16 256#usize) 8#usize) (used : Std.Array Usize 8#usize)
    (hf : ∀ p < 8, Filled (acc (M p) (168 * c)) 0 (out.val[p]!).val (used.val[p]!).val)
    (bytes : Std.Array U8 232#usize) :
    low.x86_64.mlkem_sample_poly_ntt_8x.squeeze_rate_and_reject_loop1 n { start := 0#usize, «end» := 8#usize }
      out used rate spreadV qV twelveV shiftsV bytes ⦃ r =>
      ∀ p < 8, Filled (acc (M p) (168 * (c + 1))) 0 (r.1.val[p]!).val (r.2.val[p]!).val ⦄ := by
  unfold low.x86_64.mlkem_sample_poly_ntt_8x.squeeze_rate_and_reject_loop1
  apply range_loop' 8 (fun t (s : Std.Array (Std.Array I16 256#usize) 8#usize × Std.Array Usize 8#usize ×
      Std.Array U8 232#usize) =>
      (∀ p < t, Filled (acc (M p) (168 * (c + 1))) 0 (s.1.val[p]!).val (s.2.1.val[p]!).val) ∧
      ∀ p, t ≤ p → p < 8 → Filled (acc (M p) (168 * c)) 0 (s.1.val[p]!).val (s.2.1.val[p]!).val)
    (fun (r : Std.Array (Std.Array I16 256#usize) 8#usize × Std.Array Usize 8#usize) =>
      ∀ p < 8, Filled (acc (M p) (168 * (c + 1))) 0 (r.1.val[p]!).val (r.2.val[p]!).val) _ ?_
    { start := 0#usize, «end» := 8#usize } (out, used, bytes) (by simp) (by simp)
    ⟨fun p hp => absurd hp (by simp), fun p _ hp => hf p hp⟩
  rintro it ⟨o, u, b⟩ he hs ⟨hdone, hrest⟩
  simp only at hdone hrest
  unfold low.x86_64.mlkem_sample_poly_ntt_8x.squeeze_rate_and_reject_loop1.body
  step as ⟨o', it1, ho, he1⟩
  split_ifs at ho with hlt
  · obtain ⟨rfl, hst⟩ := ho
    simp only
    have ht : it.start.val < 8 := by omega
    step with bytes_loop_spec rate n hn it.start ht b as ⟨b1, hb1⟩
    step with groups_spec as ⟨g4, hg4⟩
    have hrb : RateBytes (M it.start.val) c b1.val := by
      intro m hm
      obtain ⟨hlen, hbytes⟩ := hS it.start.val ht
      rw [hb1 m hm, hrate _ (by omega) _ ht, xofByte_block _ _ _ hm, ← hbytes, getElem!_stateBytes]
    step with passes_spec (M it.start.val) c b1 hrb it.start ht g4 hg4 o u
      ⟨by rw [show gend 0 = 0 from rfl, Nat.add_zero]; exact hrest _ le_rfl ht,
        fun p _ _ => ⟨rfl, rfl⟩⟩ as ⟨o1, u1, hinv1⟩
    obtain ⟨hf1, hother⟩ := hinv1
    refine ⟨by rw [he1]; exact he, hst, ht, fun p hp => ?_, fun p hp1 hp2 => ?_⟩
    · by_cases hpi : p = it.start.val
      · subst hpi
        rw [show 168 * (c + 1) = 168 * c + gend 4 by unfold gend; omega]
        exact hf1
      · obtain ⟨e1, e2⟩ := hother p (by omega) hpi
        rw [e1, e2]; exact hdone p (by omega)
    · obtain ⟨e1, e2⟩ := hother p hp2 (by omega)
      rw [e1, e2]; exact hrest p (by omega) hp2
  · obtain ⟨rfl, hst⟩ := ho
    apply (WP.spec_ok _).2
    have : it.start.val = 8 := by omega
    rw [this] at hdone
    exact hdone

/-- `squeeze_rate_and_reject` of eight states at block `c` keeps each one's
candidates below `q` after those its polynomial holds, as many as fit. -/
theorem squeeze_rate_and_reject_spec (M : ℕ → List Byte) (S : ℕ → List (BitVec 64)) (c : ℕ)
    (hS : AtBlock M S c) (out : Std.Array (Std.Array I16 256#usize) 8#usize) (used : Std.Array Usize 8#usize)
    (hf : ∀ p < 8, Filled (acc (M p) (168 * c)) 0 (out.val[p]!).val (used.val[p]!).val) :
    low.x86_64.mlkem_sample_poly_ntt_8x.squeeze_rate_and_reject (vecs S) out used ⦃ r =>
      ∀ p < 8, Filled (acc (M p) (168 * (c + 1))) 0 (r.1.val[p]!).val (r.2.val[p]!).val ⦄ := by
  unfold low.x86_64.mlkem_sample_poly_ntt_8x.squeeze_rate_and_reject
  step with rate_words_spec as ⟨n, hn⟩
  step with rate_loop_spec (vecs S) n hn as ⟨rate, hrate⟩
  rw [show low.x86_64.mlkem_sample_poly_ntt_8x.load low.x86_64.mlkem_sample_poly_ntt_8x.SPREAD = ok spreadV
    from rfl, bind_ok]
  simp only [lift, bind_ok, core.core_arch.x86.avx512f._mm512_set1_epi16,
    core.core_arch.x86.avx512f._mm512_set1_epi32]
  apply polys_spec M S c hS n hn rate (fun l hl p hp => by
    rw [hrate l hl p hp, lane_vecs S l p (by omega) hp]) out used hf

/-! ## The states: one padded block each, then Keccak-f -/

/-- ML-KEM's eight SHAKE128 inputs: messages `M p` of 34 bytes, padded. -/
def Inputs8 (inputs : Std.Array (Std.Array U8 40#usize) 8#usize) (M : ℕ → List Byte) : Prop :=
  ∀ p < 8, (M p).length = 34 ∧ bv (inputs.val[p]!).val = M p ++ shakePad :: List.replicate 5 0

theorem word_spec (input : Std.Array U8 40#usize) (lane : Usize) (hl : lane.val < 5) :
    low.x86_64.mlkem_sample_poly_ntt_8x.word input lane ⦃ w =>
      ∀ t < 8, w.bv.toLEBytes[t]! = (input.val[8 * lane.val + t]!).bv ⦄ := by
  unfold low.x86_64.mlkem_sample_poly_ntt_8x.word
  step as ⟨i, hi⟩
  step as ⟨i1, hi1⟩
  step with core.slice.index.SliceIndexRangeUsizeSlice.index.step_spec as ⟨s, hs, hsl⟩
  step with core.array.TryFromArrayCopySlice.try_from.step as ⟨r, hr⟩
  rcases r with a | e
  · simp only at hr
    simp only [core.result.Result.unwrap, bind_ok]
    step as ⟨y, hy⟩
    intro t ht
    have hal : (a.val.map U8.bv).length = 8 := by simp [hr.1, hsl]; scalar_tac
    show (UScalar.hcast .I64 y).bv.toLEBytes[t]! = _
    rw [hcast_I64_bv, hy, toLEBytes_fromLEBytes _ hal]
    show (bv a.val)[t]! = _
    rw [getElem!_bv, hr.1, hs, Std.Array.val_to_slice,
      List.getElem!_slice _ _ _ _ ⟨by simp; scalar_tac, by scalar_tac⟩, hi, Nat.mul_comm]
  · simp at hr
    exfalso; apply hr; show s.length = 8; rw [hsl]; scalar_tac

/-- SHAKE128's state once `M`, of 34 bytes, is padded into a block. -/
def padded (M : List Byte) : List Byte := xorAt (xorAt (xorAt zeros 0 M) 34 [shakePad]) 167 [0x80]

theorem absorbed_padded (M : List Byte) (hM : M.length = 34) :
    shake128Absorbed M = keccakF (padded M) := by
  have h0 := absorb_keccakPad 168 ⟨by omega, by omega⟩ shakePad [] M rfl (by omega)
  rw [List.nil_append] at h0
  show absorb 168 zeros (keccakPad 168 shakePad M) = _
  rw [h0, padded, hM]
  simp [absorb, blocks_nil]

theorem getElem!_padded (M : List Byte) (hM : M.length = 34) (j : ℕ) (hj : j < 200) :
    (padded M)[j]! = if j < 34 then M[j]! else if j = 34 then shakePad else if j = 167 then 0x80 else 0 := by
  unfold padded
  rw [getElem!_xorAt _ _ _ _ (by simp; omega), getElem!_xorAt _ _ _ _ (by simp; omega),
    getElem!_xorAt _ _ _ _ (by simp; omega), getElem!_replicate_zero]
  simp only [List.length_singleton, hM, Nat.zero_le, true_and, Nat.sub_zero, Nat.zero_add]
  by_cases h1 : j < 34
  · simp [h1, show ¬ (34 ≤ j) by omega, show ¬ (167 ≤ j) by omega]
  · by_cases h2 : j = 34
    · subst h2; simp
    · by_cases h3 : j = 167
      · subst h3; simp
      · simp [h1, h2, h3]
        rw [if_neg (by omega), if_neg (by omega)]

/-- The lanes the setup gives a state: its input's five words `w`, the
padding's last bit, and zeros. -/
def setupLanes (w : ℕ → BitVec 64) : List (BitVec 64) :=
  (List.range 25).map fun l => if l < 5 then w l else if l = 20 then 0x8000000000000000#64 else 0

theorem toLEBytes_getElem! (x : BitVec 64) (i : ℕ) : x.toLEBytes[i]! = x.extractLsb' (8 * i) 8 := by
  apply Byte.ext_testBit
  intro t ht
  have := BitVec.toLEBytes_getElem!_testBit x i t ht
  simp only [Byte.testBit] at this
  rw [this, BitVec.getElem!_eq_testBit_toNat, BitVec.testBit_toNat, BitVec.testBit_toNat,
    BitVec.getLsbD_extractLsb']
  simp [ht]

theorem stateBytes_setup (M : List Byte) (hM : M.length = 34) (input : Std.Array U8 40#usize)
    (hin : bv input.val = M ++ shakePad :: List.replicate 5 0) (w : ℕ → BitVec 64)
    (hw : ∀ l < 5, ∀ t < 8, (w l).toLEBytes[t]! = (input.val[8 * l + t]!).bv) :
    stateBytes (setupLanes w) = padded M := by
  apply ext_getElem! (by simp [length_stateBytes, setupLanes, padded])
  intro j hj
  rw [length_stateBytes] at hj
  simp only [setupLanes, List.length_map, List.length_range] at hj
  rw [getElem!_stateBytes, getElem!_pos _ (j / 8) (by simp [setupLanes]; omega)]
  simp only [setupLanes, List.getElem_map, List.getElem_range]
  rw [getElem!_padded M hM j (by omega)]
  have hinj (k : ℕ) (hk : k < 40) : (input.val[k]!).bv =
      if k < 34 then M[k]! else if k = 34 then shakePad else 0 := by
    rw [← getElem!_bv, hin, getElem!_append_if, hM]
    split
    · rfl
    · rename_i h
      by_cases h34 : k = 34
      · subst h34; simp
      · rw [if_neg h34, show k - 34 = (k - 35) + 1 by omega, List.getElem!_cons_succ, getElem!_replicate_zero]
  by_cases h40 : j < 40
  · rw [if_pos (show j / 8 < 5 by omega), hw _ (by omega) _ (by omega), show 8 * (j / 8) + j % 8 = j by omega,
      hinj j h40]
    by_cases h34 : j < 34
    · simp [h34]
    · simp [h34, show j ≠ 167 by omega]
  · rw [if_neg (show ¬ j / 8 < 5 by omega), if_neg (show ¬ j < 34 by omega), if_neg (show j ≠ 34 by omega)]
    by_cases h20 : j / 8 = 20
    · rw [if_pos h20]
      have ht : j % 8 < 8 := Nat.mod_lt _ (by omega)
      have hj' : j = 160 + j % 8 := by omega
      rw [toLEBytes_getElem!]
      revert hj'
      generalize j % 8 = t at ht ⊢
      intro hj'
      subst hj'
      interval_cases t <;> decide
    · rw [if_neg h20, toLEBytes_getElem!, if_neg (show j ≠ 167 by omega)]
      simp

theorem keccakF_stateBytes (L : List (BitVec 64)) (hL : L.length = 25) :
    keccakF (stateBytes L) = stateBytes (keccak 24 L) := by
  rw [keccakF, stateLanes_stateBytes _ hL]

theorem atBlock_succ (M : ℕ → List Byte) (S : ℕ → List (BitVec 64)) (c : ℕ) (h : AtBlock M S c) :
    AtBlock M (fun p => keccak 24 (S p)) (c + 1) := by
  intro p hp
  obtain ⟨hl, hb⟩ := h p hp
  refine ⟨length_keccak24 _, ?_⟩
  rw [Function.iterate_succ_apply', ← hb, keccakF_stateBytes _ hl]

theorem rc8_bv : low.x86_64.sha3_keccak8_f1600.RC.val.map (·.bv) = keccakRoundConstants := by
  unfold low.x86_64.sha3_keccak8_f1600.RC
  simp [keccakRoundConstants]

theorem keccak8_spec (S : ℕ → List (BitVec 64)) :
    low.x86_64.sha3_keccak8_f1600.keccak8_f1600 (vecs S) low.x86_64.sha3_keccak8_f1600.RC ⦃ r =>
      r = vecs fun i => keccak 24 (S i) ⦄ := by
  unfold low.x86_64.sha3_keccak8_f1600.keccak8_f1600
  exact rounds_spec S _ rc8_bv _ (vecs S) (by simp) (by simp) rfl

/-- The setup's loop lays each input's five words into the vectors' lanes. -/
theorem words_loop_spec (inputs : Std.Array (Std.Array U8 40#usize) 8#usize)
    (states : Std.Array core.core_arch.x86.__m512i 25#usize) (hz : ∀ k < 25, states.val[k]! = 0) :
    low.x86_64.mlkem_sample_poly_ntt_8x.sample_poly_ntt_8x_avx512_loop0 { start := 0#usize, «end» := 5#usize }
      inputs states ⦃ r => (∀ k < 5, ∀ p < 8, ∀ t < 8,
        (lane64x8 (r.val[k]!) p).toLEBytes[t]! = ((inputs.val[p]!).val[8 * k + t]!).bv) ∧
        ∀ k, 5 ≤ k → k < 25 → r.val[k]! = 0 ⦄ := by
  unfold low.x86_64.mlkem_sample_poly_ntt_8x.sample_poly_ntt_8x_avx512_loop0
  apply range_loop 5 (fun n (r : Std.Array core.core_arch.x86.__m512i 25#usize) =>
    (∀ k < n, ∀ p < 8, ∀ t < 8, (lane64x8 (r.val[k]!) p).toLEBytes[t]! = ((inputs.val[p]!).val[8 * k + t]!).bv) ∧
      ∀ k, n ≤ k → k < 25 → r.val[k]! = 0) _ ?_ { start := 0#usize, «end» := 5#usize } states (by simp) (by simp)
    ⟨fun k hk => absurd hk (by simp), fun k _ hk => hz k hk⟩
  rintro it r he hs ⟨hw, hz'⟩
  unfold low.x86_64.mlkem_sample_poly_ntt_8x.sample_poly_ntt_8x_avx512_loop0.body
  step as ⟨o', it1, ho, he1⟩
  split_ifs at ho with hlt
  · obtain ⟨rfl, hst⟩ := ho
    simp only
    have hl5 : it.start.val < 5 := by omega
    step as ⟨a0, ha0⟩
    step with word_spec a0 it.start hl5 as ⟨w0, hw0⟩
    step as ⟨a1, ha1⟩
    step with word_spec a1 it.start hl5 as ⟨w1, hw1⟩
    step as ⟨a2, ha2⟩
    step with word_spec a2 it.start hl5 as ⟨w2, hw2⟩
    step as ⟨a3, ha3⟩
    step with word_spec a3 it.start hl5 as ⟨w3, hw3⟩
    step as ⟨a4, ha4⟩
    step with word_spec a4 it.start hl5 as ⟨w4, hw4⟩
    step as ⟨a5, ha5⟩
    step with word_spec a5 it.start hl5 as ⟨w5, hw5⟩
    step as ⟨a6, ha6⟩
    step with word_spec a6 it.start hl5 as ⟨w6, hw6⟩
    step as ⟨a7, ha7⟩
    step with word_spec a7 it.start hl5 as ⟨w7, hw7⟩
    rw [setr_Q, bind_ok]
    step as ⟨r1, hr1⟩
    refine ⟨by rw [he1]; exact he, hst, hl5, fun k hk p hp t ht => ?_, fun k hk1 hk2 => ?_⟩
    · rw [hr1, Std.Array.set_val_eq]
      by_cases hkk : k = it.start.val
      · subst hkk
        rw [MlKemCoding.getElem!_set_self _ _ _ (by simp; omega), lane_Q _ _ hp]
        have hget (j : ℕ) (hj : j < 8) (a : Std.Array U8 40#usize) (h : a = inputs.val[j]'(by simp; omega)) :
            a = inputs.val[j]! := by rw [h, getElem!_pos]
        interval_cases p <;> simp only [List.getElem!_cons_zero, List.getElem!_cons_succ]
        · rw [hw0 t ht, hget 0 (by decide) a0 ha0]
        · rw [hw1 t ht, hget 1 (by decide) a1 ha1]
        · rw [hw2 t ht, hget 2 (by decide) a2 ha2]
        · rw [hw3 t ht, hget 3 (by decide) a3 ha3]
        · rw [hw4 t ht, hget 4 (by decide) a4 ha4]
        · rw [hw5 t ht, hget 5 (by decide) a5 ha5]
        · rw [hw6 t ht, hget 6 (by decide) a6 ha6]
        · rw [hw7 t ht, hget 7 (by decide) a7 ha7]
      · rw [MlKemCoding.getElem!_set_ne _ _ _ _ (Ne.symm hkk)]
        exact hw k (by omega) p hp t ht
    · rw [hr1, Std.Array.set_val_eq, MlKemCoding.getElem!_set_ne _ _ _ _ (by omega)]
      exact hz' k (by omega) hk2
  · obtain ⟨rfl, hst⟩ := ho
    apply (WP.spec_ok _).2
    have : it.start.val = 5 := by omega
    rw [this] at hw hz'
    exact ⟨hw, hz'⟩

/-- `extract_state` collects state `index`'s lanes. -/
theorem extract_state_spec (states : Std.Array core.core_arch.x86.__m512i 25#usize) (index : Usize)
    (hi : index.val < 8) :
    low.x86_64.mlkem_sample_poly_ntt_8x.extract_state states index ⦃ r =>
      ∀ l < 25, (r.val[l]!).bv = lane64x8 (states.val[l]!) index.val ⦄ := by
  unfold low.x86_64.mlkem_sample_poly_ntt_8x.extract_state
  unfold low.x86_64.mlkem_sample_poly_ntt_8x.extract_state_loop
  apply range_loop 25 (fun n (r : Std.Array U64 25#usize) =>
    ∀ l < n, (r.val[l]!).bv = lane64x8 (states.val[l]!) index.val) _ ?_
    { start := 0#usize, «end» := 25#usize } (Std.Array.repeat 25#usize 0#u64) rfl (Nat.zero_le _)
    (fun l hl => absurd hl (Nat.not_lt_zero _))
  rintro it r he hs hr
  unfold low.x86_64.mlkem_sample_poly_ntt_8x.extract_state_loop.body
  step as ⟨o', it1, ho, he1⟩
  split_ifs at ho with hlt
  · obtain ⟨rfl, hst⟩ := ho
    simp only
    step as ⟨v, hv⟩
    step with store_spec as ⟨a, ha⟩
    step as ⟨x, hx⟩
    step as ⟨r1, hr1⟩
    refine ⟨by rw [he1]; exact he, hst, by omega, fun l hl => ?_⟩
    rw [hr1, Std.Array.set_val_eq]
    by_cases hll : l = it.start.val
    · subst hll
      rw [MlKemCoding.getElem!_set_self _ _ _ (by simp; omega), hx, ← getElem!_pos, ha _ hi, hv, getElem!_pos]
    · rw [MlKemCoding.getElem!_set_ne _ _ _ _ (Ne.symm hll)]
      exact hr l (by omega)
  · obtain ⟨rfl, hst⟩ := ho
    apply (WP.spec_ok _).2
    have : it.start.val = 25 := by omega
    rw [this] at hr
    exact hr

/-- A state whose lanes are those of `S`. -/
theorem sbl_of_lanes (r : Std.Array U64 25#usize) (S : List (BitVec 64)) (hS : S.length = 25)
    (h : ∀ l < 25, (r.val[l]!).bv = S[l]!) : sbl r.val = stateBytes S := by
  show stateBytes (r.val.map (·.bv)) = _
  congr 1
  apply ext_getElem! (by simp [hS])
  intro l hl
  have hrl : r.val.length = 25 := by simp
  rw [List.length_map, hrl] at hl
  rw [getElem!_pos _ l (by simp [hrl, hl]), List.getElem_map, ← getElem!_pos r.val l (by omega), h l hl]

/-- The loop that hands back the states of the polynomials not yet full. -/
theorem tails_loop_spec (M : ℕ → List Byte) (S : ℕ → List (BitVec 64)) (hS : AtBlock M S 2)
    (used : Std.Array Usize 8#usize) (a : Std.Array (Std.Array U64 25#usize) 8#usize) :
    low.x86_64.mlkem_sample_poly_ntt_8x.sample_poly_ntt_8x_avx512_loop1 { start := 0#usize, «end» := 8#usize }
      (vecs S) used a ⦃ r => ∀ p < 8, (used.val[p]!).val < 256 →
        keccakF (sbl (r.val[p]!).val) = keccakF^[3] (shake128Absorbed (M p)) ⦄ := by
  unfold low.x86_64.mlkem_sample_poly_ntt_8x.sample_poly_ntt_8x_avx512_loop1
  apply range_loop 8 (fun n (r : Std.Array (Std.Array U64 25#usize) 8#usize) =>
    ∀ p < n, (used.val[p]!).val < 256 →
      keccakF (sbl (r.val[p]!).val) = keccakF^[3] (shake128Absorbed (M p))) _ ?_
    { start := 0#usize, «end» := 8#usize } a rfl (Nat.zero_le _) (fun p hp => absurd hp (Nat.not_lt_zero _))
  rintro it r he hs hr
  unfold low.x86_64.mlkem_sample_poly_ntt_8x.sample_poly_ntt_8x_avx512_loop1.body
  step as ⟨o', it1, ho, he1⟩
  split_ifs at ho with hlt
  · obtain ⟨rfl, hst⟩ := ho
    simp only
    have ht : it.start.val < 8 := by omega
    step as ⟨u, hu⟩
    have huv : u = used.val[it.start.val]! := by rw [hu, getElem!_pos]
    split
    · rename_i hlt256
      step with extract_state_spec (vecs S) it.start ht as ⟨x, hx⟩
      step as ⟨r1, hr1⟩
      refine ⟨by rw [he1]; exact he, hst, ht, fun p hp hpu => ?_⟩
      rw [hr1, Std.Array.set_val_eq]
      by_cases hpi : p = it.start.val
      · subst hpi
        obtain ⟨hl, hb⟩ := hS _ ht
        rw [MlKemCoding.getElem!_set_self _ _ _ (by simp; omega),
          sbl_of_lanes x _ hl (fun l hl' => by rw [hx l hl', lane_vecs S l _ hl' ht]), hb,
          ← Function.iterate_succ_apply' keccakF]
      · rw [MlKemCoding.getElem!_set_ne _ _ _ _ (Ne.symm hpi)]
        exact hr p (by omega) hpu
    · rename_i hge
      apply (WP.spec_ok _).2
      refine ⟨by rw [he1]; exact he, hst, ht, fun p hp hpu => ?_⟩
      have hpi : p ≠ it.start.val := by
        intro h; subst h; rw [← huv] at hpu; exact hge (by scalar_tac)
      simp only at hp
      exact hr p (by omega) hpu
  · obtain ⟨rfl, hst⟩ := ho
    apply (WP.spec_ok _).2
    have : it.start.val = 8 := by omega
    rw [this] at hr
    exact hr

theorem getElem!_setupLanes (w : ℕ → BitVec 64) (k : ℕ) (hk : k < 25) :
    (setupLanes w)[k]! = if k < 5 then w k else if k = 20 then 0x8000000000000000#64 else 0 := by
  rw [setupLanes, getElem!_pos _ k (by simp; omega), List.getElem_map, List.getElem_range]

theorem ofLanes64x8_zero : ofLanes64x8 (fun _ => 0) = 0 := by decide

theorem i64_min_bv : core.num.I64.MIN.bv = 0x8000000000000000#64 := by decide

theorem filled_nil (out : List I16) : Filled (acc M 0) 0 out 0 := by
  refine ⟨Nat.zero_le _, ?_, fun k hk => absurd hk (Nat.not_lt_zero _)⟩
  simp [shake128_map, accepted]

/-- ML-KEM's eight-way sampler, with AVX-512: each polynomial holds the
candidates below `q` of SHAKE128's first three blocks on its input, as many
as fit, and each with fewer has the state that continues after them. -/
theorem sample_poly_ntt_8x_avx512_spec (M : ℕ → List Byte)
    (inputs : Std.Array (Std.Array U8 40#usize) 8#usize) (hin : Inputs8 inputs M)
    (outputs : Std.Array (Std.Array I16 256#usize) 8#usize) (t : low.x86_64.cpu.HaveAvx512ForMlKem) :
    low.x86_64.mlkem_sample_poly_ntt_8x.sample_poly_ntt_8x_avx512 inputs outputs t ⦃ r =>
      ∀ p < 8, Filled (acc (M p) 504) 0 (r.2.val[p]!).val (r.1.used.val[p]!).val ∧
        ((r.1.used.val[p]!).val < 256 →
          keccakF (sbl (r.1.states.val[p]!).val) = keccakF^[3] (shake128Absorbed (M p))) ⦄ := by
  unfold low.x86_64.mlkem_sample_poly_ntt_8x.sample_poly_ntt_8x_avx512
  simp only [core.core_arch.x86.avx512f._mm512_setzero_si512, bind_ok]
  step with words_loop_spec inputs _ (fun k hk => by
    rw [Std.Array.repeat_val, List.getElem!_replicate _ (by simp; omega)]) as ⟨st1, hw, hz⟩
  rw [set1_Q, bind_ok]
  step with rate_words_spec as ⟨n, hn⟩
  step as ⟨i1, hi1⟩
  step as ⟨st2, hst2⟩
  -- One padded block in each state.
  set S0 : ℕ → List (BitVec 64) := fun p => setupLanes fun k => lane64x8 (st1.val[k]!) p with hS0
  have hv2 : st2 = vecs S0 := by
    rw [hst2]
    apply Aeneas.Std.Array.ext
    apply ext_getElem! (by simp [vecs])
    intro k hk
    have hk25 : k < 25 := by simpa using hk
    rw [Std.Array.set_val_eq, vecs, Array.make_val,
      getElem!_pos (List.map (fun k => ofLanes64x8 fun i => (S0 i)[k]!) (List.range 25)) k (by simp; omega),
      List.getElem_map, List.getElem_range]
    by_cases h20 : k = 20
    · subst h20
      rw [show i1.val = 20 by omega, MlKemCoding.getElem!_set_self _ _ _ (by simp)]
      apply Q_congr
      intro p hp
      rw [hS0, getElem!_setupLanes _ _ (by omega), i64_min_bv]
      rfl
    · rw [MlKemCoding.getElem!_set_ne _ _ _ _ (by omega)]
      by_cases h5 : k < 5
      · conv_lhs => rw [← Q_lane (st1.val[k]!)]
        apply Q_congr
        intro p hp
        rw [hS0, getElem!_setupLanes _ _ hk25, if_pos h5]
      · rw [hz k (by omega) hk25, ← ofLanes64x8_zero]
        apply Q_congr
        intro p hp
        rw [hS0, getElem!_setupLanes _ _ hk25, if_neg h5, if_neg h20]
  have hA0 : AtBlock M (fun p => keccak 24 (S0 p)) 0 := by
    intro p hp
    obtain ⟨hMl, hinp⟩ := hin p hp
    refine ⟨length_keccak24 _, ?_⟩
    have hb : stateBytes (S0 p) = padded (M p) :=
      stateBytes_setup (M p) hMl (inputs.val[p]!) hinp (fun k => lane64x8 (st1.val[k]!) p)
        (fun l hl t ht => hw l hl p hp t ht)
    rw [Function.iterate_zero_apply, absorbed_padded _ hMl, ← hb,
      keccakF_stateBytes _ (by simp [hS0, setupLanes])]
  rw [hv2]
  step with keccak8_spec S0 as ⟨st3, hst3⟩
  rw [hst3]
  step with squeeze_rate_and_reject_spec M _ 0 hA0 outputs (Std.Array.repeat 8#usize 0#usize) (fun p hp => by
    rw [Std.Array.repeat_val, List.getElem!_replicate _ (by simp; omega), Nat.mul_zero]
    exact filled_nil _) as ⟨o1, u1, hf1⟩
  step with keccak8_spec _ as ⟨st4, hst4⟩
  rw [hst4]
  have hA1 := atBlock_succ M _ 0 hA0
  step with squeeze_rate_and_reject_spec M _ 1 hA1 o1 u1 hf1 as ⟨o2, u2, hf2⟩
  step with keccak8_spec _ as ⟨st5, hst5⟩
  rw [hst5]
  have hA2 := atBlock_succ M _ 1 hA1
  step with squeeze_rate_and_reject_spec M _ 2 hA2 o2 u2 hf2 as ⟨o3, u3, hf3⟩
  step with tails_loop_spec M _ hA2 u3 _ as ⟨a2, ha2⟩
  intro p hp
  exact ⟨hf3 p hp, ha2 p hp⟩

/-! ## `sample_poly_ntt_8x`: the tails -/

/-- The CPU has what the eight-way sampler needs: AVX-512 F, BW, VL, VBMI,
and VBMI2, with AVX2's kernels. -/
def RunsMlKem8x : Prop := ∃ t, low.x86_64.cpu.HaveAvx512ForMlKem.check = ok (some t)

theorem n_eq : mid.mlkem.N = 256#usize := by unfold mid.mlkem.N; rfl

/-- Where the CPU has what it needs, the eight-way sampler is its AVX-512 body. -/
theorem mlkem_sample_poly_ntt_8x_spec (h8 : RunsMlKem8x) (M : ℕ → List Byte)
    (inputs : Std.Array (Std.Array U8 40#usize) 8#usize) (hin : Inputs8 inputs M)
    (outputs : Std.Array (Std.Array I16 256#usize) 8#usize) :
    low.x86_64.mlkem_sample_poly_ntt_8x.mlkem_sample_poly_ntt_8x inputs outputs ⦃ r =>
      ∃ tails, r.1 = some tails ∧ ∀ p < 8, Filled (acc (M p) 504) 0 (r.2.val[p]!).val (tails.used.val[p]!).val ∧
        ((tails.used.val[p]!).val < 256 →
          keccakF (sbl (tails.states.val[p]!).val) = keccakF^[3] (shake128Absorbed (M p))) ⦄ := by
  obtain ⟨t, ht⟩ := h8
  unfold low.x86_64.mlkem_sample_poly_ntt_8x.mlkem_sample_poly_ntt_8x
  rw [ht, bind_ok]
  simp only
  step with sample_poly_ntt_8x_avx512_spec M inputs hin outputs t as ⟨tails, outs, hr⟩
  exact ⟨tails, rfl, hr⟩

/-- A polynomial that holds all 256 candidates of SHAKE128's first three
blocks holds SHAKE128's first 256. -/
theorem sampled_of_full (M : List Byte) (hH : Halts M) (out : List I16) (d : ℕ)
    (hf : Filled (acc M 504) 0 out d) (hl : out.length = 256) (hd : ¬ d < 256) : Sampled M out := by
  obtain ⟨T, hT⟩ := hH
  obtain ⟨h1, h2, h3⟩ := hf
  intro k hk
  rw [h3 k (by omega), Nat.zero_add, sampled_getElem! M T hT k hk, acc_agree M 504 (3 * T) k (by omega) (by omega)]

set_option maxHeartbeats 1000000 in
/-- The loop that fills each polynomial's rest from its tail. -/
theorem tails_fill_spec (h : RunsSha3) (M : ℕ → List Byte) (hH : ∀ p < 8, Halts (M p))
    (outputs : Std.Array (Std.Array I16 256#usize) 8#usize) (tails : low.x86_64.mlkem_sample_poly_ntt_8x.Tails)
    (ht : ∀ p < 8, Filled (acc (M p) 504) 0 (outputs.val[p]!).val (tails.used.val[p]!).val ∧
      ((tails.used.val[p]!).val < 256 →
        keccakF (sbl (tails.states.val[p]!).val) = keccakF^[3] (shake128Absorbed (M p)))) :
    mid.mlkem.sample_ntt.sample_poly_ntt_8x_loop { start := 0#usize, «end» := 8#usize } outputs tails ⦃ r =>
      ∀ p < 8, Sampled (M p) (r.val[p]!).val ⦄ := by
  unfold mid.mlkem.sample_ntt.sample_poly_ntt_8x_loop
  apply WP.spec_mono (range_loop 8 (fun n (o : Std.Array (Std.Array I16 256#usize) 8#usize) =>
    (∀ p < n, Sampled (M p) (o.val[p]!).val) ∧ ∀ p, n ≤ p → p < 8 → o.val[p]! = outputs.val[p]!) _ ?_
    { start := 0#usize, «end» := 8#usize } outputs rfl (Nat.zero_le _)
    ⟨fun p hp => absurd hp (Nat.not_lt_zero _), fun _ _ _ => rfl⟩)
  · intro r hr; exact hr.1
  rintro it o he hs ⟨hdone, hsame⟩
  unfold mid.mlkem.sample_ntt.sample_poly_ntt_8x_loop.body
  step as ⟨o', it1, ho, he1⟩
  split_ifs at ho with hlt
  · obtain ⟨rfl, hst⟩ := ho
    simp only
    have hp8 : it.start.val < 8 := by omega
    obtain ⟨hf, hstate⟩ := ht _ hp8
    have hop : o.val[it.start.val]! = outputs.val[it.start.val]! := hsame _ le_rfl hp8
    step as ⟨u, hu⟩
    have huv : u = tails.used.val[it.start.val]! := by rw [hu, getElem!_pos]
    rw [n_eq]
    split
    · rename_i hlt256
      have hu256 : u.val < 256 := by scalar_tac
      step as ⟨a, ha⟩
      have hav : a = tails.states.val[it.start.val]! := by rw [ha, getElem!_pos]
      simp only [mid.sha3.SqueezingSponge.new, bind_ok]
      step as ⟨a1, back, ha1, hback⟩
      have ha1v : a1 = o.val[it.start.val]! := by rw [ha1, getElem!_pos]
      step as ⟨s, back1, hs1, hs1l, hback1⟩
      obtain ⟨T, hT⟩ := hH _ hp8
      rw [← huv] at hf hstate
      have hlen : (acc (M it.start.val) 504).length = u.val := by
        obtain ⟨_, h2, _⟩ := hf; simp at h2; omega
      have hsq : Squeezing ({ s := a } : mid.sha3.SqueezingSponge 168#usize) shakePad (M it.start.val) 3 := by
        show keccakF (sbl a.val) = _
        rw [hav]; exact hstate hu256
      have hsl : s.length = 256 - u.val := by rw [hs1l]
      step with tail_case_spec h (M it.start.val) T 3 _ hsq s (by
        rw [show 168 * 3 = 504 from rfl, hlen, hsl]; omega) as ⟨sp, s1, hl1, hv1⟩
      refine ⟨by rw [he1]; exact he, hst, hp8, fun p hp => ?_, fun p hp1 hp2 => ?_⟩
      · rw [hback, Std.Array.set_val_eq]
        by_cases hpi : p = it.start.val
        · subst hpi
          rw [MlKemCoding.getElem!_set_self _ _ _ (by simp; omega)]
          intro k hk
          rw [sampled_getElem! _ T hT k hk, hback1]
          by_cases hku : k < u.val
          · rw [List.getElem!_setSlice!_prefix _ _ _ _ hku, ha1v, hop]
            obtain ⟨_, _, h3⟩ := hf
            rw [h3 k hku, Nat.zero_add, acc_agree _ 504 (3 * T) k (by omega) (by omega)]
          · rw [List.getElem!_setSlice!_middle _ _ _ _ ⟨by omega, by
                rw [← Slice.length, hl1, hsl]; omega, by simp; omega⟩,
              hv1 (k - u.val) (by rw [hsl]; omega), show 168 * 3 = 504 from rfl, hlen,
              show u.val + (k - u.val) = k by omega]
        · rw [MlKemCoding.getElem!_set_ne _ _ _ _ (Ne.symm hpi)]
          exact hdone p (by omega)
      · rw [hback, Std.Array.set_val_eq, MlKemCoding.getElem!_set_ne _ _ _ _ (by omega)]
        exact hsame p (by omega) hp2
    · rename_i hge
      apply (WP.spec_ok _).2
      refine ⟨by rw [he1]; exact he, hst, hp8, fun p hp => ?_, fun p hp1 hp2 => hsame p (by
        simp only at hp1; omega) hp2⟩
      by_cases hpi : p = it.start.val
      · subst hpi
        rw [hop]
        rw [← huv] at hf
        exact sampled_of_full _ (hH _ hp8) _ u.val hf (by simp) (by scalar_tac)
      · exact hdone p (by simp only at hp; omega)
  · obtain ⟨rfl, hst⟩ := ho
    apply (WP.spec_ok _).2
    have : it.start.val = 8 := by omega
    rw [this] at hdone hsame
    exact ⟨hdone, hsame⟩

/-- `sample_poly_ntt_8x`, on a CPU with what the eight-way sampler needs,
writes SHAKE128's first 256 candidates below `q` on each of its eight
inputs. -/
theorem sample_poly_ntt_8x_spec (h : RunsSha3) (h8 : RunsMlKem8x) (M : ℕ → List Byte)
    (hH : ∀ p < 8, Halts (M p)) (inputs : Std.Array (Std.Array U8 40#usize) 8#usize) (hin : Inputs8 inputs M)
    (outputs : Std.Array (Std.Array I16 256#usize) 8#usize) :
    mid.mlkem.sample_ntt.sample_poly_ntt_8x inputs outputs ⦃ r => ∀ p < 8, Sampled (M p) (r.val[p]!).val ⦄ := by
  unfold mid.mlkem.sample_ntt.sample_poly_ntt_8x
  step with mlkem_sample_poly_ntt_8x_spec h8 M inputs hin outputs as ⟨o, outs, tails, ho, ht⟩
  subst ho
  simp only
  exact tails_fill_spec h M hH outs tails ht

end MlKemSample8x

end rind.x86_64
