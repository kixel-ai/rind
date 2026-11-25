import Rind.X86_64.RsaExp
import Rind.X86_64.RsaIfma
open Aeneas Aeneas.Std Result rind.spec rind.spec.rsa

/-!
# RSA's private operation on x86_64

`RsaPrivateKey::private_op` is RFC 8017's RSASP1 in its CRT form: two
exponentiations modulo the primes, by `PosInt::mod_exp_pair`, recombined by
Garner's formula, then checked by the public operation. This proves the
exponentiation at 16 and 32 words with BMI2 and ADX, where `mont_exp` runs
s2n-bignum's Karatsuba products, from the Montgomery conversions around it up.
-/

namespace rind.x86_64

/-- `fixed_one` is one at `n`'s width. -/
theorem fixed_one_spec {N : Usize} (n : low.posint.PosInt N) (hk : 1 ≤ n.used.val)
    (hkN : n.used.val ≤ N.val) :
    low.posint.PosInt.fixed_one n ⦃ r => r.used = n.used ∧ wordsNat (lowWords r n.used) = 1 ⦄ := by
  unfold low.posint.PosInt.fixed_one low.posint.PosInt.one low.posint.PosInt.zero
    low.posint.PosInt.expand
  step*
  subst x_post
  have hv : ((Array.repeat N 0#u64).set 0#usize 1#u64).val = (List.replicate N.val 0#u64).set 0 1#u64 := by
    simp [Array.repeat_val]
  obtain ⟨j, hj⟩ : ∃ j, N.val = j + 1 := ⟨N.val - 1, by omega⟩
  obtain ⟨i, hi⟩ : ∃ i, n.used.val = i + 1 := ⟨n.used.val - 1, by omega⟩
  simp only [lowWords, hv, hj, hi, List.replicate_succ, List.set_cons_zero, List.take_succ_cons,
    wordsNat_cons, List.take_replicate, wordsNat_replicate_zero]
  simp

/-- `PosInt::mont_mul`, a Montgomery product at `n`'s width. -/
theorem posint_mont_mul_spec {N : Usize} (self v n : low.posint.PosInt N) (n0 : U64)
    (hP : MontProducts n.used.val) (hk : n.used.val ≤ N.val)
    (hargs : MontArgs (lowWords self n.used) (lowWords v n.used) (lowWords n n.used) n0) :
    low.posint.PosInt.mont_mul self v n n0 ⦃ r => r.used = n.used ∧
      MontResult (lowWords self n.used) (lowWords v n.used) (lowWords n n.used) (lowWords r n.used) ⦄ := by
  unfold low.posint.PosInt.mont_mul low.posint.PosInt.zero
  simp only [bind_ok]
  apply WP.spec_mono (mont_mul_into_spec self v _ n n0 hP hk hargs)
  rintro r ⟨h1, h2, -⟩
  exact ⟨h1, h2⟩

/-- `to_montgomery` takes `self`, below `n`, into the Montgomery domain, given
`montifier`, which is `R² mod n`. -/
theorem to_montgomery_spec {N : Usize} (self montifier n : low.posint.PosInt N)
    (hP : MontProducts n.used.val) (hk2 : 2 ≤ n.used.val) (hk : n.used.val ≤ N.val)
    (hodd : wordsNat (lowWords n n.used) % 2 = 1)
    (hx : wordsNat (lowWords self n.used) < wordsNat (lowWords n n.used))
    (hmont : wordsNat (lowWords montifier n.used) = 2 ^ (128 * n.used.val) % wordsNat (lowWords n n.used)) :
    low.posint.PosInt.to_montgomery self montifier n ⦃ r => r.used = n.used ∧
      MontPow (wordsNat (lowWords n n.used)) (2 ^ (64 * n.used.val)) (wordsNat (lowWords self n.used)) 1
        (lowWords r n.used) ⦄ := by
  unfold low.posint.PosInt.to_montgomery
  step with mont_neg_inverse_spec n (by omega) hk hodd as ⟨i, hi⟩
  have hM0 : 0 < wordsNat (lowWords n n.used) := by omega
  step with posint_mont_mul_spec self montifier n i hP hk
    (mont_args_of self montifier n i hk hk2 hodd hi hx (by rw [hmont]; exact Nat.mod_lt _ hM0))
    as ⟨r, hru, hr⟩
  refine ⟨hru, hr.2.1, ?_⟩
  apply mont_cancel (coprime_two_pow_odd hodd (64 * n.used.val))
  have h2 := hr.2.2
  rw [lowWords_length n hk] at h2
  have hRR : 2 ^ (128 * n.used.val) = 2 ^ (64 * n.used.val) * 2 ^ (64 * n.used.val) := by
    rw [← pow_add]; ring_nf
  unfold Nat.ModEq
  rw [h2, hmont, Nat.mul_mod_mod, hRR, pow_one, mul_assoc]

/-- `from_montgomery` takes what stands for `C^t` in the Montgomery domain out
of it: `C^t mod n`. -/
theorem from_montgomery_spec {N : Usize} (self n : low.posint.PosInt N)
    (hP : MontProducts n.used.val) (hk2 : 2 ≤ n.used.val) (hk : n.used.val ≤ N.val)
    (hodd : wordsNat (lowWords n n.used) % 2 = 1) (hM1 : 1 < wordsNat (lowWords n n.used))
    (C t : Nat)
    (hx : MontPow (wordsNat (lowWords n n.used)) (2 ^ (64 * n.used.val)) C t (lowWords self n.used)) :
    low.posint.PosInt.from_montgomery self n ⦃ r => r.used = n.used ∧
      wordsNat (lowWords r n.used) = C ^ t % wordsNat (lowWords n n.used) ⦄ := by
  unfold low.posint.PosInt.from_montgomery
  step with fixed_one_spec n (by omega) hk as ⟨one, hou, hov⟩
  step with mont_neg_inverse_spec n (by omega) hk hodd as ⟨i, hi⟩
  step with posint_mont_mul_spec self one n i hP hk
    (mont_args_of self one n i hk hk2 hodd hi hx.1 (by rw [hov]; exact hM1)) as ⟨r, hru, hr⟩
  refine ⟨hru, ?_⟩
  have h2 := hr.2.2
  rw [lowWords_length n hk, hov, mul_one] at h2
  have hc : wordsNat (lowWords r n.used) ≡ C ^ t [MOD wordsNat (lowWords n n.used)] :=
    mont_cancel (coprime_two_pow_odd hodd (64 * n.used.val)) (h2.trans hx.2)
  rw [← Nat.mod_eq_of_lt hr.2.1]
  exact hc

/-- With BMI2 and ADX, aws-lc's RSAZ does not run. -/
theorem rsaz_none_spec {N : Usize} (t : low.x86_64.cpu.HaveBmi2Adx)
    (hadx : low.x86_64.cpu.HaveBmi2Adx.check = ok (some t)) (e n : low.posint.PosInt N) :
    low.posint.PosInt.rsaz e n ⦃ r => r = none ⦄ := by
  unfold low.posint.PosInt.rsaz low.x86_64.rsaz.Rsaz.check
  simp [hadx, core.option.Option.is_some, core.option.Option.Insts.CoreOpsTry_traitTry.branch,
    core.option.Option.Insts.CoreOpsTry_traitFromResidualOptionNever.from_residual]

/-- `mod_exp` at 16 and 32 words with BMI2 and ADX: `self^e mod n`, for `self`
below `n`, given `n`'s montifier, `R² mod n`, and `n0`, `-n⁻¹ mod 2^64`. -/
theorem mod_exp_spec {N : Usize} (havx : ∃ t, low.x86_64.cpu.HaveAvx2.check = ok t)
    (t : low.x86_64.cpu.HaveBmi2Adx) (hadx : low.x86_64.cpu.HaveBmi2Adx.check = ok (some t))
    (self e n montifier : low.posint.PosInt N) (n0 : U64)
    (hP : MontProducts n.used.val) (hk : n.used.val = 16 ∨ n.used.val = 32) (hN : n.used.val ≤ N.val)
    (he : e.used.val ≤ N.val) (hel : 64 * e.used.val ≤ Usize.max)
    (hodd : wordsNat (lowWords n n.used) % 2 = 1) (hM1 : 1 < wordsNat (lowWords n n.used))
    (hn0 : (wordsNat (lowWords n n.used) * n0.val + 1) % 2 ^ 64 = 0)
    (hmont : wordsNat (lowWords montifier n.used) = 2 ^ (128 * n.used.val) % wordsNat (lowWords n n.used))
    (hx : wordsNat (lowWords self n.used) < wordsNat (lowWords n n.used)) :
    low.posint.PosInt.mod_exp self e n montifier n0 ⦃ r => r.used = n.used ∧
      wordsNat (lowWords r n.used) =
        wordsNat (lowWords self n.used) ^ wordsNat (lowWords e e.used) % wordsNat (lowWords n n.used) ⦄ := by
  have hk2 : 2 ≤ n.used.val := by omega
  have hM0 : 0 < wordsNat (lowWords n n.used) := by omega
  have hR : Nat.Coprime (2 ^ (64 * n.used.val)) (wordsNat (lowWords n n.used)) :=
    coprime_two_pow_odd hodd _
  unfold low.posint.PosInt.mod_exp
  step with rsaz_none_spec t hadx e n as ⟨o, ho⟩
  subst ho
  simp only
  step with fixed_one_spec n (by omega) hN as ⟨one, hou, hov⟩
  step with posint_mont_mul_spec one montifier n n0 hP hN
    (mont_args_of one montifier n n0 hN hk2 hodd hn0 (by rw [hov]; exact hM1)
      (by rw [hmont]; exact Nat.mod_lt _ hM0)) as ⟨om, homu, hom⟩
  have homp : MontPow (wordsNat (lowWords n n.used)) (2 ^ (64 * n.used.val))
      (wordsNat (lowWords self n.used)) 0 (lowWords om n.used) := by
    refine ⟨hom.2.1, ?_⟩
    apply mont_cancel hR
    have h2 := hom.2.2
    rw [lowWords_length n hN, hov, one_mul, hmont, Nat.mod_mod] at h2
    have hRR : 2 ^ (128 * n.used.val) = 2 ^ (64 * n.used.val) * 2 ^ (64 * n.used.val) := by
      rw [← pow_add]; ring_nf
    unfold Nat.ModEq
    rw [h2, hRR, pow_zero, one_mul]
  step with to_montgomery_spec self montifier n hP hk2 hN hodd hx hmont as ⟨sm, hsmu, hsm⟩
  step with posint_mont_exp_spec havx t hadx sm om e n n0 (wordsNat (lowWords self n.used)) hP hk hN he hel
    hodd hn0 hsm homp as ⟨pe, hpeu, hpe⟩
  step with from_montgomery_spec pe n hP hk2 hN hodd hM1 _ _ hpe as ⟨r, hru, hr⟩
  exact ⟨hru, hr⟩

/-- aws-lc's dual RSAZ, which no proof covers, does not run at `k` words: it
takes only 24 and 32, and the CPU check for it returns, or the CPU lacks it. -/
def NoRsazPair (k : Nat) : Prop :=
  (k ≠ 24 ∧ k ≠ 32 ∧ IfmaCheckReturns) ∨ low.x86_64.cpu.HaveAvx512ForRsa.check = ok none

theorem rsaz_pair_none_spec {N : Usize} (x y : low.posint.ModExp N) (h : NoRsazPair x.n.used.val) :
    low.posint.PosInt.rsaz_pair x y ⦃ r => r = none ⦄ := by
  unfold low.posint.PosInt.rsaz_pair
  split
  · simp
  split
  · simp
  split
  · simp
  unfold low.x86_64.rsaz_avx512.RsazAvx512.check
  rcases h with ⟨h24, h32, o, ho⟩ | h
  · rw [ho]
    cases o with
    | none =>
      simp [core.option.Option.Insts.CoreOpsTry_traitTry.branch,
        core.option.Option.Insts.CoreOpsTry_traitFromResidualOptionNever.from_residual]
    | some tok =>
      simp only [bind_ok, core.option.Option.Insts.CoreOpsTry_traitTry.branch]
      simp [core.bool.Bool.then_some]
  · simp [h, core.option.Option.Insts.CoreOpsTry_traitTry.branch,
      core.option.Option.Insts.CoreOpsTry_traitFromResidualOptionNever.from_residual]

/-- What `mod_exp` takes, as `x` holds it: a modulus of 16 or 32 words, odd and
above one, whose Montgomery products return their results, its montifier,
`R² mod n`, and `n0`, `-n⁻¹ mod 2^64`, an exponent no wider than `N`, and a
base below the modulus. -/
def ModExpArgs {N : Usize} (x : low.posint.ModExp N) : Prop :=
  MontProducts x.n.used.val ∧ (x.n.used.val = 16 ∨ x.n.used.val = 32) ∧ x.n.used.val ≤ N.val ∧
    x.e.used.val ≤ N.val ∧ 64 * x.e.used.val ≤ Usize.max ∧
    wordsNat (lowWords x.n x.n.used) % 2 = 1 ∧ 1 < wordsNat (lowWords x.n x.n.used) ∧
    (wordsNat (lowWords x.n x.n.used) * x.n_0.val + 1) % 2 ^ 64 = 0 ∧
    wordsNat (lowWords x.n_montifier x.n.used) =
      2 ^ (128 * x.n.used.val) % wordsNat (lowWords x.n x.n.used) ∧
    wordsNat (lowWords x.base x.n.used) < wordsNat (lowWords x.n x.n.used)

/-- What `mod_exp` returns for `x`: `base^e mod n`, at `n`'s width. -/
def ModExpResult {N : Usize} (x : low.posint.ModExp N) (r : low.posint.PosInt N) : Prop :=
  r.used = x.n.used ∧ wordsNat (lowWords r x.n.used) =
    wordsNat (lowWords x.base x.n.used) ^ wordsNat (lowWords x.e x.e.used) % wordsNat (lowWords x.n x.n.used)

/-- `mod_exp_pair` at 16 and 32 words with BMI2 and ADX, where the dual RSAZ
does not run: each base to its exponent, modulo its modulus. -/
theorem mod_exp_pair_spec {N : Usize} (havx : ∃ t, low.x86_64.cpu.HaveAvx2.check = ok t)
    (t : low.x86_64.cpu.HaveBmi2Adx) (hadx : low.x86_64.cpu.HaveBmi2Adx.check = ok (some t))
    (x y : low.posint.ModExp N) (hx : ModExpArgs x) (hy : ModExpArgs y)
    (hpair : NoRsazPair x.n.used.val) :
    low.posint.PosInt.mod_exp_pair x y ⦃ r => ModExpResult x r.1 ∧ ModExpResult y r.2 ⦄ := by
  unfold low.posint.PosInt.mod_exp_pair
  step with rsaz_pair_none_spec x y hpair as ⟨o, ho⟩
  subst ho
  simp only
  obtain ⟨hP, hk, hN, he, hel, hodd, hM1, hn0, hmont, hb⟩ := hx
  step with mod_exp_spec havx t hadx x.base x.e x.n x.n_montifier x.n_0 hP hk hN he hel hodd hM1 hn0
    hmont hb as ⟨r1, h1u, h1v⟩
  obtain ⟨hP', hk', hN', he', hel', hodd', hM1', hn0', hmont', hb'⟩ := hy
  step with mod_exp_spec havx t hadx y.base y.e y.n y.n_montifier y.n_0 hP' hk' hN' he' hel' hodd' hM1'
    hn0' hmont' hb' as ⟨r2, h2u, h2v⟩
  exact ⟨⟨h1u, h1v⟩, ⟨h2u, h2v⟩⟩

/-- `mont_redc` at `n`'s width `k`: `self·R⁻¹ mod n`, for `self` below `R·n`,
where `R = 2^(64k)`. -/
theorem mont_redc_spec {N M : Usize} (self : low.posint.PosInt N) (n : low.posint.PosInt M)
    (hk : n.used.val ≤ M.val) (hk61 : n.used.val < 2 ^ 61) (hsu : self.used.val ≤ N.val)
    (hs61 : self.used.val < 2 ^ 61) (hodd : wordsNat (lowWords n n.used) % 2 = 1)
    (hX : wordsNat (lowWords self self.used) < 2 ^ (64 * n.used.val) * wordsNat (lowWords n n.used)) :
    low.posint.PosInt.mont_redc self n ⦃ r => r.used = n.used ∧
      ∀ i, 2 ^ (64 * n.used.val) * i % wordsNat (lowWords n n.used) = 1 % wordsNat (lowWords n n.used) →
        wordsNat (lowWords r n.used) = i * wordsNat (lowWords self self.used) % wordsNat (lowWords n n.used) ⦄ := by
  unfold low.posint.PosInt.mont_redc low.posint.PosInt.as_mut_words low.posint.PosInt.as_words
    low.posint.PosInt.zero
  step*
  obtain ⟨s, back⟩ := x
  dsimp only at *
  step as ⟨s1, hs1v, hs1l⟩
  step as ⟨s2, hs2v, hs2l⟩
  have hs1 : s1.val = lowWords self self.used := by simp [hs1v, lowWords]
  have hs2 : s2.val = lowWords n n.used := by simp [hs2v, lowWords]
  have hcv : (UScalar.cast UScalarTy.U64 s2.len).val = n.used.val := by
    simp only [UScalar.cast_val_eq, Slice.len_val, UScalarTy.numBits]
    rw [hs2l]; apply Nat.mod_eq_of_lt; scalar_tac
  simp only [lift, bind_ok]
  step with bignum_montredc_spec s s1 s2 (UScalar.cast UScalarTy.U64 s2.len) (by rw [hs2l, x_post1])
    (by rw [hcv]; omega) (by rw [hs1l]; omega) as ⟨s3, hs3l, hs3⟩
  intro i hi
  obtain ⟨h1, -⟩ := mont_into_post ({ n with words := Array.repeat M 0#u64 } : low.posint.PosInt M) n back
    x_post2 hk s3 (by rw [hs3l, x_post1])
  have hMR : wordsNat (lowWords n n.used) < 2 ^ (64 * n.used.val) := by
    have := wordsNat_lt' (lowWords n n.used); rwa [lowWords_length n hk] at this
  have hXR : wordsNat (lowWords self self.used) < 2 ^ (64 * (n.used.val + n.used.val)) := by
    rw [mul_add, pow_add]
    exact lt_of_lt_of_le hX (Nat.mul_le_mul_left _ hMR.le)
  rw [hcv, x_post1, hs1, hs2] at hs3
  rw [h1, hs3 hodd (by rw [Nat.mod_eq_of_lt hXR]; exact hX.le) i hi, Nat.mod_eq_of_lt hXR]

end rind.x86_64
