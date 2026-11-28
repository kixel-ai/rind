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

end MlKemSample8x

end rind.x86_64
