import Rind.P256Group

/-! That P-256's group order is prime, by a Pratt certificate as
`Rind.P256Group` proves its field prime: ECDSA's scalars have inverses mod n
since it is. -/

namespace rind.spec

theorem prime_311245691 : Nat.Prime 311245691 :=
  prime_of_lucas 2 [(2, 1), (5, 1), (7, 1), (17, 1), (29, 2), (311, 1)] (by decide +kernel)
    ⟨by norm_num, by norm_num, by norm_num, by norm_num, by norm_num, by norm_num, trivial⟩

theorem prime_622491383 : Nat.Prime 622491383 :=
  prime_of_lucas 5 [(2, 1), (311245691, 1)] (by decide +kernel) ⟨by norm_num, prime_311245691, trivial⟩

theorem prime_1002328039319 : Nat.Prime 1002328039319 :=
  prime_of_lucas 19 [(2, 1), (126241, 1), (3969899, 1)] (by decide +kernel)
    ⟨by norm_num, by norm_num, by norm_num, trivial⟩

theorem prime_187019741 : Nat.Prime 187019741 :=
  prime_of_lucas 2 [(2, 2), (5, 1), (9350987, 1)] (by decide +kernel)
    ⟨by norm_num, by norm_num, by norm_num, trivial⟩

theorem prime_191039911 : Nat.Prime 191039911 :=
  prime_of_lucas 3 [(2, 1), (3, 1), (5, 1), (41, 1), (155317, 1)] (by decide +kernel)
    ⟨by norm_num, by norm_num, by norm_num, by norm_num, by norm_num, trivial⟩

theorem prime_208150935158385979 : Nat.Prime 208150935158385979 :=
  prime_of_lucas 2 [(2, 1), (3, 1), (11, 1), (43, 1), (127, 1), (3023, 1), (191039911, 1)]
    (by decide +kernel)
    ⟨by norm_num, by norm_num, by norm_num, by norm_num, by norm_num, by norm_num, prime_191039911, trivial⟩

theorem prime_2624747550333869278416773953 : Nat.Prime 2624747550333869278416773953 :=
  prime_of_lucas 7 [(2, 6), (3, 2), (1297, 1), (16879, 1), (208150935158385979, 1)] (by decide +kernel)
    ⟨by norm_num, by norm_num, by norm_num, by norm_num, prime_208150935158385979, trivial⟩

/-- `PRIME_N256`. -/
theorem prime_n256 : Nat.Prime n256 :=
  prime_of_lucas 7 [(2, 4), (3, 1), (71, 1), (131, 1), (373, 1), (3407, 1), (17449, 1), (38189, 1),
      (1002328039319, 1), (187019741, 1), (622491383, 1), (2624747550333869278416773953, 1)]
    (by decide +kernel)
    ⟨by norm_num, by norm_num, by norm_num, by norm_num, by norm_num, by norm_num, prime_17449,
      by norm_num, prime_1002328039319, prime_187019741, prime_622491383,
      prime_2624747550333869278416773953, trivial⟩

end rind.spec
