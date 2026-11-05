import Rind.Spec
import Mathlib.NumberTheory.LucasPrimality
import Mathlib.Tactic.ReduceModChar
import Mathlib.Tactic.NormNum.Prime

/-! That P-256's field prime and group order are prime, by Pratt certificates:
Lucas's test for each, with the factors of p - 1 proven prime the same way
down to ones `norm_num` checks directly. -/

namespace rind.spec

/-- Lucas's test, for `p - 1` the product of the primes `fs`. -/
theorem prime_of_lucas (p a : Nat) (fs : List Nat) (hfs : ∀ q ∈ fs, q.Prime)
    (hprod : fs.prod = p - 1) (ha : (a : ZMod p) ^ (p - 1) = 1)
    (hq : ∀ q ∈ fs, (a : ZMod p) ^ ((p - 1) / q) ≠ 1) : p.Prime :=
  lucas_primality p a ha fun q hqp hdvd => by
    rw [← hprod] at hdvd
    obtain ⟨r, hr, hqr⟩ := (Nat.Prime.prime hqp).dvd_prod_iff.mp hdvd
    rw [(Nat.prime_dvd_prime_iff_eq hqp (hfs r hr)).mp hqr]
    exact hq r hr

/-- Proves `Nat.Prime p` by `prime_of_lucas` with witness `a` and the factors
`fs` of `p - 1`, given each factor's primality as a hypothesis in context or
by `norm_num`. -/
macro "lucas " a:term:max fs:term:max : tactic => `(tactic|
  (refine prime_of_lucas _ $a $fs ?_ (by norm_num) (by reduce_mod_char) ?_ <;>
    simp only [List.mem_cons, List.not_mem_nil, or_false, forall_eq_or_imp, forall_eq] <;>
    (try and_intros) <;>
    first | assumption | (reduce_mod_char; decide +kernel) | norm_num))

theorem prime_6700417 : Nat.Prime 6700417 := by norm_num

theorem prime_66417393611 : Nat.Prime 66417393611 := by
  lucas 6 [2, 5, 53, 173, 197, 3677]

theorem prime_11290956913871 : Nat.Prime 11290956913871 := by
  have := prime_66417393611
  lucas 13 [2, 5, 17, 66417393611]

theorem prime_204061199 : Nat.Prime 204061199 := by
  lucas 11 [2, 11, 23, 107, 3769]

theorem prime_34282281433 : Nat.Prime 34282281433 := by
  have := prime_204061199
  lucas 17 [2, 2, 2, 3, 7, 204061199]

theorem prime_46076956964474543 : Nat.Prime 46076956964474543 := by
  lucas 5 [2, 23, 18169, 704251, 78283]

theorem prime_774023187263532362759620327192479577272145303 :
    Nat.Prime 774023187263532362759620327192479577272145303 := by
  have := prime_11290956913871
  have := prime_34282281433
  have := prime_46076956964474543
  lucas 3 [2, 3, 3, 2411, 11290956913871, 34282281433, 46076956964474543]

theorem prime_835945042244614951780389953367877943453916927241 :
    Nat.Prime 835945042244614951780389953367877943453916927241 := by
  have := prime_774023187263532362759620327192479577272145303
  lucas 11 [2, 2, 2, 3, 3, 3, 5, 774023187263532362759620327192479577272145303]

/-- `PRIME_P256`. -/
theorem prime_p256 : Nat.Prime p256 := by
  have := prime_6700417
  have := prime_835945042244614951780389953367877943453916927241
  unfold p256
  lucas 6 [2, 3, 5, 5, 17, 257, 641, 1531, 65537, 490463, 6700417,
    835945042244614951780389953367877943453916927241]

theorem prime_1002328039319 : Nat.Prime 1002328039319 := by
  lucas 19 [2, 126241, 3969899]

theorem prime_187019741 : Nat.Prime 187019741 := by
  lucas 2 [2, 2, 5, 9350987]

theorem prime_311245691 : Nat.Prime 311245691 := by
  lucas 2 [2, 5, 7, 17, 29, 29, 311]

theorem prime_622491383 : Nat.Prime 622491383 := by
  have := prime_311245691
  lucas 5 [2, 311245691]

theorem prime_191039911 : Nat.Prime 191039911 := by
  lucas 3 [2, 3, 5, 41, 155317]

theorem prime_208150935158385979 : Nat.Prime 208150935158385979 := by
  have := prime_191039911
  lucas 2 [2, 3, 11, 43, 127, 3023, 191039911]

theorem prime_2624747550333869278416773953 : Nat.Prime 2624747550333869278416773953 := by
  have := prime_208150935158385979
  lucas 7 [2, 2, 2, 2, 2, 2, 3, 3, 1297, 16879, 208150935158385979]

/-- `PRIME_N256`. -/
theorem prime_n256 : Nat.Prime n256 := by
  have := prime_1002328039319
  have := prime_187019741
  have := prime_622491383
  have := prime_2624747550333869278416773953
  unfold n256
  lucas 7 [2, 2, 2, 2, 3, 71, 131, 373, 3407, 17449, 38189, 1002328039319, 187019741, 622491383,
    2624747550333869278416773953]

end rind.spec
