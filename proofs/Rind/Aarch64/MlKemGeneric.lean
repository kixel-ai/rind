import Rind.Aarch64.MlKemCoding
open Aeneas Aeneas.Std Result rind.spec Spec Spec.MLKEM rind.spec.mlkem

/-!
# aarch64's ML-KEM compression and unpacking in Rust

s2n-bignum has no routine for ML-KEM's ciphertext compression or its 12-bit
unpacking on aarch64, so rind runs `low::generic::mlkem`'s Rust there; x86_64
runs it too without AVX2, and with AVX2 runs s2n-bignum's unpacking and
mlkem-native's compression instead:

* `compress_spec` and its four wrappers: `compress::<D, L>` writes FIPS 203's
  `ByteEncode_D(Compress_D(f))` for the 4, 5, 10, and 11 bits a ciphertext's
  halves take, given coefficients in `[0, q)` (`Holds 0 3328`). Its multiply
  and shift is `Compress_D` only on that range, which `compress_exact_4` and
  its siblings check value by value.
* `mlkem_frombytes_spec`: `mlkem_frombytes` unpacks each 12-bit field of its
  bytes as it is, so in `[0, 4096)`; each is congruent modulo `q` to
  `ByteDecode_12`'s coefficient (`Holds 0 4095`), which reduces it, and the
  `mlkem_reduce` that follows in `mid::mlkem` makes it canonical.

They rest on no axiom.
-/

namespace rind.aarch64

namespace MlKemGeneric

open MlKemCoding

/-- FIPS 203's `Compress_D(x)` of `x` in `[0, q)`, as `Compress_val` states it. -/
def compVal (D x : ℕ) : ℕ := (2 * (2 ^ D * x) + 3329) / (2 * 3329) % 2 ^ D

/-- A fact of each number below `q`, checked in 14 runs of 256, which keeps
`decide`'s recursion shallow. -/
theorem ball_3329 (P : ℕ → Prop) (h : ∀ c < 14, ∀ v < 256, 256 * c + v < 3329 → P (256 * c + v)) :
    ∀ v < 3329, P v := fun v hv => by
  have := h (v / 256) (by omega) (v % 256) (by omega) (by omega)
  rwa [Nat.div_add_mod] at this

/-- `compress_one`'s multiply and shift is `Compress_D` at each `D` over all
of `[0, q)`, as its Rust test `compress_is_exact` checks: the quotient by `q`
is exact only on that range. -/
theorem compress_exact_4 : ∀ v < 3329, (v * 2 ^ 4 + 1665) * 80635 / 2 ^ 28 % 2 ^ 4 = compVal 4 v :=
  ball_3329 _ (by decide +kernel)
theorem compress_exact_5 : ∀ v < 3329, (v * 2 ^ 5 + 1665) * 80635 / 2 ^ 28 % 2 ^ 5 = compVal 5 v :=
  ball_3329 _ (by decide +kernel)
theorem compress_exact_10 : ∀ v < 3329, (v * 2 ^ 10 + 1665) * 1290167 / 2 ^ 32 % 2 ^ 10 = compVal 10 v :=
  ball_3329 _ (by decide +kernel)
theorem compress_exact_11 : ∀ v < 3329, (v * 2 ^ 11 + 1665) * 5160669 / 2 ^ 34 % 2 ^ 11 = compVal 11 v :=
  ball_3329 _ (by decide +kernel)

theorem generic_Q_HALF_spec : low.generic.mlkem.Q_HALF ⦃ r => r = 1665#i16 ⦄ := by
  unfold low.generic.mlkem.Q_HALF
  simp only [low.generic.mlkem.Q]
  step as ⟨i, hi⟩
  step as ⟨r, hr⟩
  apply IScalar.eq_of_val_eq
  rw [hr, hi]
  decide

/-- What `compress_one` does after picking `D`'s multiplier and shift. -/
theorem compress_tail (D : Usize) (hD : 1 ≤ D.val ∧ D.val ≤ 11) (x : I16) (h0 : 0 ≤ x.val) (h1 : x.val < 3329)
    (m : U64) (s : I32) (hm : m.val ≤ 5160669) (hs0 : 0 ≤ s.val) (hs : s.val < 64)
    (hex : (x.val.toNat * 2 ^ D.val + 1665) * m.val / 2 ^ s.toNat % 2 ^ D.val = compVal D.val x.val.toNat) :
    (do
      let c ← lift (IScalar.hcast UScalarTy.U64 x)
      let c1 ← c <<< D
      let i ← low.generic.mlkem.Q_HALF
      let i1 ← lift (IScalar.hcast UScalarTy.U64 i)
      let c2 ← lift (core.num.U64.wrapping_add c1 i1)
      let c3 ← lift (core.num.U64.wrapping_mul c2 m)
      let c4 ← c3 >>> s
      let i2 ← 1#u64 <<< D
      let i3 ← i2 - 1#u64
      let i4 ← lift (c4 &&& i3)
      ok (UScalar.cast UScalarTy.U16 i4)) ⦃ r => r.val = compVal D.val x.val.toNat ⦄ := by
  have hv : (x.val.toNat : ℤ) = x.val := Int.toNat_of_nonneg h0
  have hvlt : x.val.toNat < 3329 := by omega
  have hpow : 2 ^ D.val ≤ 2 ^ 11 := Nat.pow_le_pow_right (by norm_num) hD.2
  have hpos : 2 ≤ 2 ^ D.val := by
    calc 2 = 2 ^ 1 := by norm_num
      _ ≤ 2 ^ D.val := Nat.pow_le_pow_right (by norm_num) hD.1
  step as ⟨c, hc⟩
  have hcv : c.val = x.val.toNat := by
    rw [hc, IScalar.hcast_val_eq]
    simp [UScalarTy.numBits]
    omega
  step as ⟨c1, hc1, _⟩
  have hb1 : x.val.toNat * 2 ^ D.val ≤ 3328 * 2 ^ 11 := Nat.mul_le_mul (by omega) hpow
  have hb3 : (x.val.toNat * 2 ^ D.val + 1665) * m.val ≤ (3328 * 2 ^ 11 + 1665) * 5160669 :=
    Nat.mul_le_mul (by omega) hm
  have hc1v : c1.val = x.val.toNat * 2 ^ D.val := by
    rw [hc1, hcv, Nat.shiftLeft_eq]
    exact Nat.mod_eq_of_lt (by simp [U64.size, U64.numBits]; omega)
  step with generic_Q_HALF_spec as ⟨i, hi⟩
  subst hi
  step as ⟨i1, hi1⟩
  have hi1v : i1.val = 1665 := by rw [hi1]; decide
  step as ⟨c2, hc2⟩
  have hc2v : c2.val = x.val.toNat * 2 ^ D.val + 1665 := by
    rw [hc2, core.num.U64.wrapping_add_val_eq, hc1v, hi1v]
    exact Nat.mod_eq_of_lt (by simp [U64.size, U64.numBits]; omega)
  step as ⟨c3, hc3⟩
  have hc3v : c3.val = (x.val.toNat * 2 ^ D.val + 1665) * m.val := by
    rw [hc3, core.num.U64.wrapping_mul_val_eq, hc2v]
    exact Nat.mod_eq_of_lt (by simp [U64.size, U64.numBits]; omega)
  step as ⟨c4, hc4, _⟩
  step as ⟨i2, hi2, _⟩
  have hi2v : i2.val = 2 ^ D.val := by
    rw [hi2, Nat.shiftLeft_eq, one_mul]
    exact Nat.mod_eq_of_lt (by simp [U64.size, U64.numBits]; omega)
  step as ⟨i3, hi3⟩
  step as ⟨i4, hi4, _⟩
  have hi4v : i4.val = compVal D.val x.val.toNat := by
    rw [hi4, UScalar.val_and, hi3, hi2v, Nat.and_two_pow_sub_one_eq_mod, hc4, hc3v,
      Nat.shiftRight_eq_div_pow, hex]
  rw [UScalar.cast_val_eq, hi4v]
  apply Nat.mod_eq_of_lt
  have : compVal D.val x.val.toNat < 2 ^ D.val := Nat.mod_lt _ (by positivity)
  simp [UScalarTy.numBits]
  omega

/-- `compress_one::<D>` is FIPS 203's `Compress_D`, for a coefficient in `[0, q)`. -/
theorem compress_one_spec (D : Usize) (hD : D.val = 4 ∨ D.val = 5 ∨ D.val = 10 ∨ D.val = 11) (x : I16)
    (h0 : 0 ≤ x.val) (h1 : x.val < 3329) :
    low.generic.mlkem.compress_one D x ⦃ r => r.val = compVal D.val x.val.toNat ⦄ := by
  unfold low.generic.mlkem.compress_one low.ct.into_public
  have hle : 0#i16 ≤ x := by scalar_tac
  have hlt : x < low.generic.mlkem.Q := by simp [low.generic.mlkem.Q]; scalar_tac
  apply spec_bind_ok x
  simp only [massert, hle, hlt, ite_true, bind_ok]
  have hvlt : x.val.toNat < 3329 := by omega
  split
  · simp only [bind_ok]
    exact compress_tail D (by omega) x h0 h1 _ _ (by decide) (by decide) (by decide)
      (by rename_i h; rw [h]; exact compress_exact_4 _ hvlt)
  · simp only [bind_ok]
    exact compress_tail D (by omega) x h0 h1 _ _ (by decide) (by decide) (by decide)
      (by rename_i h; rw [h]; exact compress_exact_5 _ hvlt)
  · simp only [bind_ok]
    exact compress_tail D (by omega) x h0 h1 _ _ (by decide) (by decide) (by decide)
      (by rename_i h; rw [h]; exact compress_exact_10 _ hvlt)
  · simp only [bind_ok]
    exact compress_tail D (by omega) x h0 h1 _ _ (by decide) (by decide) (by decide)
      (by rename_i h; rw [h]; exact compress_exact_11 _ hvlt)
  · rename_i _ h4 h5 h10 h11
    exfalso
    rcases hD with h | h | h | h
    exacts [h4 h, h5 h, h10 h, h11 h]

/-- `u128::to_le_bytes` writes the number its word holds. -/
theorem leNat_toLEBytes128 (x : U128) :
    leNat (x.bv.toLEBytes.map (@UScalar.mk UScalarTy.U8)) = x.val := by
  show _ = x.bv.toNat
  rw [← ofDigits_toLEBytes x.bv]
  simp only [leNat, List.map_map, Function.comp_def]
  rfl

/-- Bit `t` of the `D`-bit field `t / D` of a run of fields: the run's bits
below `D * n`, nothing above. -/
def fieldBit (D n : ℕ) (cv : ℕ → ℕ) (t : ℕ) : Bool := decide (t < D * n) && (cv (t / D)).testBit (t % D)

theorem compress_inner_spec (D : Usize) (hD : D.val = 4 ∨ D.val = 5 ∨ D.val = 10 ∨ D.val = 11)
    (a : Array I16 256#usize) (i : Usize) (hi : i.val < 32)
    (ha : ∀ p < 256, 0 ≤ (a.val[p]!).val ∧ (a.val[p]!).val < 3329)
    (iter : core.ops.range.Range Usize) (he : iter.end.val = 8) (hs : iter.start.val = 0) :
    low.generic.mlkem.compress_loop0_loop0 D iter a i 0#u128 ⦃ bits =>
      ∀ t, bits.val.testBit t =
        fieldBit D.val 8 (fun k => compVal D.val (a.val[8 * i.val + k]!).val.toNat) t ⦄ := by
  have hD1 : 1 ≤ D.val ∧ D.val ≤ 11 := by omega
  unfold low.generic.mlkem.compress_loop0_loop0
  apply range_loop 8 (fun j (bits : U128) => ∀ t, bits.val.testBit t =
      fieldBit D.val j (fun k => compVal D.val (a.val[8 * i.val + k]!).val.toNat) t)
    _ _ iter 0#u128 he (by omega)
  · rw [hs]
    intro t
    simp [fieldBit]
  · intro it bits he hs hinv
    simp only
    unfold low.generic.mlkem.compress_loop0_loop0.body
    step as ⟨o', it1, ho, he1⟩
    split_ifs at ho with hlt
    · obtain ⟨rfl, hst⟩ := ho
      simp only
      step as ⟨i1, hi1⟩
      step as ⟨i2, hi2⟩
      step as ⟨i3, hi3⟩
      have hidx : i2.val = 8 * i.val + it.start.val := by rw [hi2, hi1]
      have hrange := ha (8 * i.val + it.start.val) (by omega)
      have hget : a.val[8 * i.val + it.start.val]! = i3 := by
        rw [hi3, ← hidx]; exact getElem!_pos a.val i2.val (by scalar_tac)
      rw [hget] at hrange
      step with compress_one_spec D hD i3 hrange.1 hrange.2 as ⟨i4, hi4⟩
      step as ⟨i5, hi5⟩
      step as ⟨i6, hi6⟩
      have hcv : compVal D.val i3.val.toNat < 2 ^ D.val := Nat.mod_lt _ (by positivity)
      have hpowD : 2 ^ D.val ≤ 2048 := by
        calc 2 ^ D.val ≤ 2 ^ 11 := Nat.pow_le_pow_right (by norm_num) hD1.2
          _ = 2048 := by norm_num
      have hDj : D.val * it.start.val ≤ 11 * 7 := Nat.mul_le_mul hD1.2 (by omega)
      have hm1 : D.val * (it.start.val + 1) = D.val * it.start.val + D.val := by ring
      have hpowj : 2 ^ D.val * 2 ^ (D.val * it.start.val) ≤ 2 ^ 88 := by
        rw [← Nat.pow_add]; exact Nat.pow_le_pow_right (by norm_num) (by omega)
      step as ⟨i7, hi7, _⟩
      step as ⟨bits1, hbits1, _⟩
      have hi5v : i5.val = compVal D.val i3.val.toNat := by
        rw [hi5, UScalar.cast_val_eq, hi4]
        exact Nat.mod_eq_of_lt (by simp [UScalarTy.numBits]; omega)
      have hi7v : i7.val = compVal D.val i3.val.toNat * 2 ^ (D.val * it.start.val) := by
        rw [hi7, hi5v, hi6, Nat.shiftLeft_eq]
        apply Nat.mod_eq_of_lt
        have : compVal D.val i3.val.toNat * 2 ^ (D.val * it.start.val) < 2 ^ D.val * 2 ^ (D.val * it.start.val) :=
          Nat.mul_lt_mul_of_pos_right hcv (by positivity)
        simp [U128.size, U128.numBits]
        omega
      refine ⟨by rw [he1]; exact he, hst, by omega, fun t => ?_⟩
      rw [hbits1, UScalar.val_or, Nat.testBit_or, hinv t, hi7v, Nat.testBit_mul_two_pow, hst]
      simp only [fieldBit]
      by_cases h1 : t < D.val * it.start.val
      · have : ¬ (D.val * it.start.val ≤ t) := by omega
        simp [h1, this, show t < D.val * (it.start.val + 1) by omega]
      · have h1' : D.val * it.start.val ≤ t := by omega
        by_cases h2 : t < D.val * (it.start.val + 1)
        · have hdiv : t / D.val = it.start.val :=
            Nat.div_eq_of_lt_le (by rw [Nat.mul_comm]; omega) (by rw [Nat.mul_comm]; omega)
          have hmod : t % D.val = t - D.val * it.start.val := by
            rw [Nat.mod_def, hdiv]
          simp [h1, h1', h2, hdiv, hmod, hget]
        · have hbig : compVal D.val i3.val.toNat < 2 ^ (t - D.val * it.start.val) :=
            lt_of_lt_of_le hcv (Nat.pow_le_pow_right (by norm_num) (by omega))
          simp [h1, h1', h2, Nat.testBit_lt_two_pow hbig]
    · obtain ⟨rfl, hst⟩ := ho
      simp only [WP.spec_ok]
      have : it.start.val = 8 := by omega
      rw [this] at hinv
      exact hinv

theorem compress_loop_spec (D : Usize) (hD : D.val = 4 ∨ D.val = 5 ∨ D.val = 10 ∨ D.val = 11)
    {L : Usize} (hL : L.val = 32 * D.val) (a : Array I16 256#usize)
    (ha : ∀ p < 256, 0 ≤ (a.val[p]!).val ∧ (a.val[p]!).val < 3329)
    (iter : core.ops.range.Range Usize) (r : Array U8 L) (he : iter.end.val = 32) (hs : iter.start.val = 0) :
    low.generic.mlkem.compress_loop0 D iter r a ⦃ r' => ∀ k < 8 * (D.val * 32),
      (r'.val[k / 8]!).val.testBit (k % 8) = (compVal D.val (a.val[k / D.val]!).val.toNat).testBit (k % D.val) ⦄ := by
  have hD1 : 1 ≤ D.val ∧ D.val ≤ 11 := by omega
  unfold low.generic.mlkem.compress_loop0
  apply range_loop 32 (fun i (r : Array U8 L) => ∀ k < 8 * (D.val * i),
      (r.val[k / 8]!).val.testBit (k % 8) = (compVal D.val (a.val[k / D.val]!).val.toNat).testBit (k % D.val))
    _ _ iter r he (by omega)
  · rw [hs]
    intro k hk
    omega
  · intro it r he hs hinv
    simp only
    unfold low.generic.mlkem.compress_loop0.body
    step as ⟨o', it1, ho, he1⟩
    split_ifs at ho with hlt
    · obtain ⟨rfl, hst⟩ := ho
      simp only
      step with compress_inner_spec D hD a it.start (by omega) ha { start := 0#usize, «end» := 8#usize } rfl rfl
        as ⟨bits, hbits⟩
      have hDj : D.val * it.start.val + D.val ≤ 32 * D.val := by
        have : D.val * (it.start.val + 1) ≤ D.val * 32 := Nat.mul_le_mul_left _ (by omega)
        rw [Nat.mul_add, Nat.mul_one] at this; omega
      step as ⟨i1, hi1⟩
      step as ⟨i2, hi2⟩
      step as ⟨s, back, hs1, hs2, hback⟩
      step as ⟨a1, ha1⟩
      step as ⟨s1, hs1v, hs1l⟩
      have hlen : s.length = s1.length := by rw [hs2, hs1l, hi2, hi1]; omega
      step as ⟨s2, hs2v⟩
      subst hs2v
      refine ⟨by rw [he1]; exact he, hst, by omega, fun k hk => ?_⟩
      rw [hst] at hk
      have hrl : r.val.length = 32 * D.val := by rw [← hL]; exact r.property
      rw [hback]
      by_cases hk' : k < 8 * (D.val * it.start.val)
      · rw [List.getElem!_setSlice!_prefix _ _ _ _ (by rw [hi1]; omega)]
        exact hinv k hk'
      · have hm1 : D.val * (it.start.val + 1) = D.val * it.start.val + D.val := by ring
        have h8 : D.val * (8 * it.start.val) = 8 * (D.val * it.start.val) := by ring
        have hlo : D.val * it.start.val ≤ k / 8 := by omega
        have hhi : k / 8 < D.val * it.start.val + D.val := by omega
        have hs1len : s2.val.length = D.val := by
          rw [show s2.val.length = s2.length from rfl, hs1l]
        rw [List.getElem!_setSlice!_middle _ _ _ _ ⟨by rw [hi1]; omega, by rw [hi1, hs1len]; omega,
            by rw [hrl]; omega⟩, hs1v, hi1, List.getElem!_slice _ _ _ _ ⟨by simp [Array.to_slice]; omega, by omega⟩]
        have hts : a1.to_slice.val = a1.val := by simp [Array.to_slice]
        rw [hts, Nat.zero_add]
        -- The bytes' bit is the word's bit `k - 8 * (D * j)`.
        have hword := leNat_testBit a1.val (8 * (k / 8 - D.val * it.start.val) + k % 8)
        rw [ha1, leNat_toLEBytes128, ← ha1, show (8 * (k / 8 - D.val * it.start.val) + k % 8) / 8 =
            k / 8 - D.val * it.start.val by omega, show (8 * (k / 8 - D.val * it.start.val) + k % 8) % 8 =
            k % 8 by omega] at hword
        rw [← hword, show 8 * (k / 8 - D.val * it.start.val) + k % 8 = k - D.val * (8 * it.start.val) by omega,
          hbits, fieldBit]
        have hge : D.val * (8 * it.start.val) ≤ k := by omega
        have hdivge : 8 * it.start.val ≤ k / D.val := (Nat.le_div_iff_mul_le (by omega)).2 (by rw [Nat.mul_comm]; exact hge)
        rw [Nat.sub_mul_div, Nat.sub_mul_mod hge, show 8 * it.start.val + (k / D.val - 8 * it.start.val) =
          k / D.val by omega]
        simp only [show k - D.val * (8 * it.start.val) < D.val * 8 by omega, decide_true, Bool.true_and]
    · obtain ⟨rfl, hst⟩ := ho
      simp only [WP.spec_ok]
      have : it.start.val = 32 := by omega
      rw [this] at hinv
      exact hinv

/-- `compress::<D, L>` writes FIPS 203's `ByteEncode_D(Compress_D(f))` of a
polynomial `f` whose coefficients it holds in `[0, q)`. -/
theorem compress_spec (D : Usize) (hD : D.val = 4 ∨ D.val = 5 ∨ D.val = 10 ∨ D.val = 11) {L : Usize}
    (hL : L.val = 32 * D.val) (r : Array U8 L) (a : Array I16 256#usize) (f : Polynomial)
    (ha : Holds 0 3328 256 a.val f) :
    low.generic.mlkem.compress D r a ⦃ r' =>
      toVec (32 * D.val) r'.val (by rw [← hL]; exact r'.property) =
        ByteEncode D.val (Polynomial.Compress D.val f (by omega)) (by omega) ⦄ := by
  have hD1 : 1 ≤ D.val ∧ D.val ≤ 11 := by omega
  have hrange : ∀ p < 256, 0 ≤ (a.val[p]!).val ∧ (a.val[p]!).val < 3329 := fun p hp => by
    obtain ⟨h0, h1, _⟩ := ha p hp
    exact ⟨h0, by omega⟩
  unfold low.generic.mlkem.compress
  step as ⟨x, hx⟩
  step as ⟨i, hi⟩
  have hiv : L = i := by
    apply UScalar.eq_of_val_eq
    rw [hL, hi]
    simp [Usize.wrapping_mul]
    exact (Nat.mod_eq_of_lt (by rw [← hx]; scalar_tac)).symm
  simp only [massert, hiv, ite_true, bind_ok]
  subst hiv
  apply WP.spec_mono (compress_loop_spec D hD hL a hrange { start := 0#usize, «end» := 32#usize } r rfl rfl)
  intro r' hr'
  apply eq_of_bit
  intro k hk
  have hkD : k / D.val < 256 := by
    rw [Nat.div_lt_iff_lt_mul (by omega)]; nlinarith
  rw [bit_toVec, hr' k (by nlinarith), ByteEncode_bit _ _ k (by nlinarith)]
  obtain ⟨h0, h1, hf⟩ := ha (k / D.val) hkD
  unfold Polynomial.Compress
  rw [Vector.getElem!_map_eq _ _ _ hkD, Compress_val, ← hf]
  have hval : ((((a.val[k / D.val]!).val : ℤ) : Zq)).val = (a.val[k / D.val]!).val.toNat := by
    rw [← Int.toNat_of_nonneg h0, Int.cast_natCast, ZMod.val_natCast, Int.toNat_natCast]
    exact Nat.mod_eq_of_lt (by rw [show q = 3329 from rfl]; omega)
  have hm : m D.val = 2 ^ D.val := by simp [m]; omega
  rw [hval, ZMod.val_natCast, hm, compVal, show q = 3329 from rfl]

/-- `mlkem_compress_d4` is `ByteEncode_4(Compress_4(f))`. -/
theorem mlkem_compress_d4_spec (r : Array U8 128#usize) (a : Array I16 256#usize) (f : Polynomial)
    (ha : Holds 0 3328 256 a.val f) :
    low.generic.mlkem.mlkem_compress_d4 r a ⦃ r' =>
      toVec (32 * 4) r'.val r'.property = ByteEncode 4 (Polynomial.Compress 4 f) ⦄ :=
  compress_spec 4#usize (by decide) (by decide) r a f ha

/-- `mlkem_compress_d5` is `ByteEncode_5(Compress_5(f))`. -/
theorem mlkem_compress_d5_spec (r : Array U8 160#usize) (a : Array I16 256#usize) (f : Polynomial)
    (ha : Holds 0 3328 256 a.val f) :
    low.generic.mlkem.mlkem_compress_d5 r a ⦃ r' =>
      toVec (32 * 5) r'.val r'.property = ByteEncode 5 (Polynomial.Compress 5 f) ⦄ :=
  compress_spec 5#usize (by decide) (by decide) r a f ha

/-- `mlkem_compress_d10` is `ByteEncode_10(Compress_10(f))`. -/
theorem mlkem_compress_d10_spec (r : Array U8 320#usize) (a : Array I16 256#usize) (f : Polynomial)
    (ha : Holds 0 3328 256 a.val f) :
    low.generic.mlkem.mlkem_compress_d10 r a ⦃ r' =>
      toVec (32 * 10) r'.val r'.property = ByteEncode 10 (Polynomial.Compress 10 f) ⦄ :=
  compress_spec 10#usize (by decide) (by decide) r a f ha

/-- `mlkem_compress_d11` is `ByteEncode_11(Compress_11(f))`. -/
theorem mlkem_compress_d11_spec (r : Array U8 352#usize) (a : Array I16 256#usize) (f : Polynomial)
    (ha : Holds 0 3328 256 a.val f) :
    low.generic.mlkem.mlkem_compress_d11 r a ⦃ r' =>
      toVec (32 * 11) r'.val r'.property = ByteEncode 11 (Polynomial.Compress 11 f) ⦄ :=
  compress_spec 11#usize (by decide) (by decide) r a f ha

/-- An `i16` whose bits, as a number, are below `2^15` holds that number. -/
theorem i16_val_of_lt (x : I16) (h : x.bv.toNat < 2 ^ 15) : x.val = x.bv.toNat := by
  show x.bv.toInt = _
  exact BitVec.toInt_eq_toNat_of_lt (by omega)

/-- A byte, widened to an `i16`, holds its value. -/
theorem hcast_toNat (x : U8) : (UScalar.hcast .I16 x).bv.toNat = x.val := by
  rw [UScalar.hcast_bv_eq, BitVec.toNat_setWidth]
  exact Nat.mod_eq_of_lt (lt_of_lt_of_le x.bv.isLt (by simp [IScalarTy.numBits]))

/-- The `i16` `mlkem_frombytes` writes at coefficient `p`: in `[0, 2^12)`,
its bits those of the bytes from bit `12 * p`. -/
def Unpacked (B : List U8) (p : ℕ) (v : I16) : Prop :=
  0 ≤ v.val ∧ v.val < 4096 ∧
    ∀ j < 12, v.val.toNat.testBit j = (B[(12 * p + j) / 8]!).val.testBit ((12 * p + j) % 8)

theorem frombytes_loop_spec (a : Array U8 384#usize)
    (iter : core.ops.range.Range Usize) (r : Array I16 256#usize) (he : iter.end.val = 128)
    (hs : iter.start.val = 0) :
    low.generic.mlkem.mlkem_frombytes_loop iter r a ⦃ r' => ∀ p < 256, Unpacked a.val p (r'.val[p]!) ⦄ := by
  unfold low.generic.mlkem.mlkem_frombytes_loop
  apply WP.spec_mono (range_loop 128 (fun i (r : Array I16 256#usize) =>
    ∀ p < 2 * i, Unpacked a.val p (r.val[p]!)) _ _ iter r he (by omega) (by rw [hs]; intro p hp; omega))
  · intro r' hr'
    exact hr'
  · intro it r he hs hinv
    simp only
    unfold low.generic.mlkem.mlkem_frombytes_loop.body
    step as ⟨o', it1, ho, he1⟩
    split_ifs at ho with hlt
    · obtain ⟨rfl, hst⟩ := ho
      simp only
      step*
      have hlen : a.val.length = 384 := a.property
      have hb0 : a.val[3 * it.start.val]! = a0 := by
        rw [a0_post, ← i1_post]; exact getElem!_pos a.val i1.val (by scalar_tac)
      have hb1 : a.val[3 * it.start.val + 1]! = a1 := by
        rw [a1_post, ← i1_post, ← i2_post]; exact getElem!_pos a.val i2.val (by scalar_tac)
      have hb2 : a.val[3 * it.start.val + 2]! = a2 := by
        rw [a2_post, ← i1_post, ← i3_post]; exact getElem!_pos a.val i3.val (by scalar_tac)
      have ha0 : a0.val < 256 := by scalar_tac
      have ha1 : a1.val < 256 := by scalar_tac
      have ha2 : a2.val < 256 := by scalar_tac
      have h15 : a1.val &&& 15 ≤ 15 := Nat.and_le_right
      have hi4 : i4.bv.toNat = a0.val := by rw [i4_post]; exact hcast_toNat a0
      have hi6 : i6.bv.toNat = a1.val &&& 15 := by rw [i6_post, hcast_toNat, i5_post, UScalar.val_and]; rfl
      have hi7 : i7.bv.toNat = (a1.val &&& 15) * 2 ^ 8 := by
        simp only [i7_post1, BitVec.toNat_shiftLeft, hi6, Nat.shiftLeft_eq]
        exact Nat.mod_eq_of_lt (by omega)
      have hi11 : i11.bv.toNat = a1.val >>> 4 := by rw [i11_post, hcast_toNat, i10_post]
      have hi12 : i12.bv.toNat = a2.val := by rw [i12_post]; exact hcast_toNat a2
      have hi13 : i13.bv.toNat = a2.val * 2 ^ 4 := by
        simp only [i13_post1, BitVec.toNat_shiftLeft, hi12, Nat.shiftLeft_eq]
        exact Nat.mod_eq_of_lt (by omega)
      have hn9 : i9.bv.toNat = a0.val ||| (a1.val &&& 15) * 2 ^ 8 := by
        simp only [i9_post1, BitVec.toNat_or, hi4, hi7]
      have hn15 : i15.bv.toNat = (a1.val >>> 4) ||| a2.val * 2 ^ 4 := by
        simp only [i15_post1, BitVec.toNat_or, hi11, hi13]
      have hlt9 : i9.bv.toNat < 2 ^ 12 := by
        rw [hn9]; exact Nat.or_lt_two_pow (by omega) (by omega)
      have hlt15 : i15.bv.toNat < 2 ^ 12 := by
        rw [hn15, Nat.shiftRight_eq_div_pow]; exact Nat.or_lt_two_pow (by omega) (by omega)
      have hv9 := i16_val_of_lt i9 (by omega)
      have hv15 := i16_val_of_lt i15 (by omega)
      have hu9 : Unpacked a.val (2 * it.start.val) i9 := by
        refine ⟨by rw [hv9]; positivity, by rw [hv9]; omega, fun j hj => ?_⟩
        rw [hv9, Int.toNat_natCast, hn9, Nat.testBit_or, Nat.testBit_mul_two_pow, Nat.testBit_and]
        by_cases hj8 : j < 8
        · rw [show (12 * (2 * it.start.val) + j) / 8 = 3 * it.start.val by omega,
            show (12 * (2 * it.start.val) + j) % 8 = j by omega, hb0]
          simp [show ¬ 8 ≤ j by omega]
        · rw [show (12 * (2 * it.start.val) + j) / 8 = 3 * it.start.val + 1 by omega,
            show (12 * (2 * it.start.val) + j) % 8 = j - 8 by omega, hb1,
            Nat.testBit_lt_two_pow (lt_of_lt_of_le ha0 (by
              calc 256 = 2 ^ 8 := by norm_num
                _ ≤ 2 ^ j := Nat.pow_le_pow_right (by norm_num) (by omega)))]
          have h15b : (15 : ℕ).testBit (j - 8) = true := by
            have : j - 8 < 4 := by omega
            interval_cases (j - 8) <;> decide
          simp [show 8 ≤ j by omega, h15b]
      have hu15 : Unpacked a.val (2 * it.start.val + 1) i15 := by
        refine ⟨by rw [hv15]; positivity, by rw [hv15]; omega, fun j hj => ?_⟩
        rw [hv15, Int.toNat_natCast, hn15, Nat.testBit_or, Nat.testBit_mul_two_pow, Nat.testBit_shiftRight]
        by_cases hj4 : j < 4
        · rw [show (12 * (2 * it.start.val + 1) + j) / 8 = 3 * it.start.val + 1 by omega,
            show (12 * (2 * it.start.val + 1) + j) % 8 = 4 + j by omega, hb1]
          simp [show ¬ 4 ≤ j by omega]
        · rw [show (12 * (2 * it.start.val + 1) + j) / 8 = 3 * it.start.val + 2 by omega,
            show (12 * (2 * it.start.val + 1) + j) % 8 = j - 4 by omega, hb2,
            Nat.testBit_lt_two_pow (lt_of_lt_of_le ha1 (by
              calc 256 = 2 ^ 8 := by norm_num
                _ ≤ 2 ^ (4 + j) := Nat.pow_le_pow_right (by norm_num) (by omega)))]
          simp [show 4 ≤ j by omega]
      refine ⟨by rw [he1]; exact he, hst, by omega, fun p hp => ?_⟩
      rw [hst] at hp
      have hidx8 : i8.val = 2 * it.start.val := i8_post
      have hidx14 : i14.val = 2 * it.start.val + 1 := by rw [i14_post, i8_post]
      rw [a3_post, r1_post, Array.set_val_eq, Array.set_val_eq, hidx8, hidx14]
      by_cases hp1 : p = 2 * it.start.val + 1
      · subst hp1
        rw [getElem!_set_self _ _ _ (by simp; omega)]
        exact hu15
      · rw [getElem!_set_ne _ _ _ _ (Ne.symm hp1)]
        by_cases hp0 : p = 2 * it.start.val
        · subst hp0
          rw [getElem!_set_self _ _ _ (by simp; omega)]
          exact hu9
        · rw [getElem!_set_ne _ _ _ _ (Ne.symm hp0)]
          exact hinv p (by omega)
    · obtain ⟨rfl, hst⟩ := ho
      simp only [WP.spec_ok]
      have : it.start.val = 128 := by omega
      rw [this] at hinv
      exact hinv

/-- `mlkem_frombytes` unpacks each coefficient of FIPS 203's `ByteDecode_12`
as its raw 12-bit field: in `[0, 4096)`, so congruent to the spec's modulo
`q` but not yet reduced, which the `mlkem_reduce` after it does. -/
theorem mlkem_frombytes_spec (r : Array I16 256#usize) (a : Array U8 384#usize) :
    low.generic.mlkem.mlkem_frombytes r a ⦃ r' =>
      Holds 0 4095 256 r'.val (ByteDecode (toVec (32 * 12) a.val a.property) (by omega)) ⦄ := by
  unfold low.generic.mlkem.mlkem_frombytes
  apply WP.spec_mono (frombytes_loop_spec a _ r rfl rfl)
  intro r' hr' p hp
  obtain ⟨h0, h1, hbits⟩ := hr' p hp
  refine ⟨h0, by omega, ?_⟩
  rw [ByteDecode_get _ _ _ hp]
  have hsum : (∑ j : Fin 12, (bit (toVec (32 * 12) a.val a.property) (p * 12 + j)).toNat * 2 ^ j.val) =
      (r'.val[p]!).val.toNat := by
    rw [← Nat.mod_eq_of_lt (show (r'.val[p]!).val.toNat < 2 ^ 12 by omega), mod_two_pow_eq_sum]
    refine Finset.sum_congr rfl fun j _ => ?_
    rw [bit_toVec, hbits j j.isLt, Nat.mul_comm p]
  rw [hsum, ← Int.toNat_of_nonneg h0]
  simp [m]

end MlKemGeneric

end rind.aarch64
