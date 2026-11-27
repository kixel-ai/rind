import Rind.X86_64.RsaPrivate
open Aeneas Aeneas.Std Result rind.spec rind.spec.rsa

/-!
# RSA private key loading on x86_64

`RsaPrivateKey::new` checks a key's components as aws-lc's `RSA_check_key`
does, all but primality, and computes the Montgomery constants the private
operation takes. This proves that a key it returns meets `PrivKeyInv`, which
`private_op_spec` takes, and `CrtKey`, RFC 8017's relations between the
components: `dP = d mod (p - 1)`, `dP·e ≡ 1 (mod p - 1)`, the same for `q`,
and `qInv·q ≡ 1 (mod p)`. Its components are the values it was given, and
pyca/verified-garbage's IFMA CRT does not run for it on a CPU without
AVX-512 IFMA.
-/

namespace rind.x86_64

namespace PrivKey

/-! ## The `PosInt` helpers key loading runs -/

/-- `p`'s words above its width are zero: the whole array is its value. Every
`PosInt` rind makes keeps this. -/
def Clean {N : Usize} (p : low.posint.PosInt N) : Prop :=
  wordsNat p.words.val = wordsNat (lowWords p p.used)

theorem clean_lowWords {N : Usize} {p : low.posint.PosInt N} (hc : Clean p) (hu : p.used.val ≤ N.val)
    {k : Nat} (hk : p.used.val ≤ k) :
    wordsNat (lowWords p k) = wordsNat (lowWords p p.used) := by
  have hlt := wordsNat_lt' (lowWords p p.used)
  rw [lowWords_length p hu] at hlt
  have h : wordsNat (lowWords p k) = wordsNat p.words.val % 2 ^ (64 * k) := wordsNat_take_mod _ _
  rw [h, hc]
  exact Nat.mod_eq_of_lt (lt_of_lt_of_le hlt (Nat.pow_le_pow_right (by norm_num) (by omega)))

/-- The words of a clean value above its width are zeros. -/
theorem clean_drop {N : Usize} {p : low.posint.PosInt N} (hc : Clean p) (hu : p.used.val ≤ N.val) :
    p.words.val.drop p.used.val = List.replicate (N.val - p.used.val) 0#u64 := by
  have hsplit := wordsNat_take_drop p.words.val p.used.val
  have hlen : (p.words.val.take p.used.val).length = p.used.val := by simp; omega
  have h0 : wordsNat (p.words.val.drop p.used.val) = 0 := by
    have : wordsNat p.words.val = wordsNat (p.words.val.take p.used.val) := hc
    rw [hlen] at hsplit
    have hpos : 0 < 2 ^ (64 * p.used.val) := by positivity
    rcases Nat.mul_eq_zero.mp (show 2 ^ (64 * p.used.val) * wordsNat (p.words.val.drop p.used.val) = 0 by
      omega) with h | h
    · omega
    · exact h
  apply wordsNat_inj
  · simp
  · rw [h0, wordsNat_replicate_zero]

theorem wordsNat_take_add (l : List U64) (a b : Nat) :
    wordsNat (l.take (a + b)) = wordsNat (l.take a) + 2 ^ (64 * min a l.length) * wordsNat ((l.drop a).take b) := by
  rw [List.take_add, wordsNat_append]
  simp

theorem wordsNat_eq_zero_iff (l : List U64) : wordsNat l = 0 ↔ ∀ x ∈ l, x.val = 0 := by
  induction l with
  | nil => simp [wordsNat_nil]
  | cons y l ih =>
    rw [wordsNat_cons, List.forall_mem_cons, ← ih]
    have : (0 : Nat) < 2 ^ 64 := by norm_num
    constructor
    · intro h
      refine ⟨by omega, ?_⟩
      rcases Nat.mul_eq_zero.mp (show 2 ^ 64 * wordsNat l = 0 by omega) with h' | h'
      · omega
      · exact h'
    · rintro ⟨h1, h2⟩; rw [h1, h2]; simp

/-- `fit`'s loop zeroes the words from `words` to the width, and `high` is zero
just when they all were. -/
theorem fit_loop_spec {N : Usize} (w0 : List U64) (hw0 : w0.length = N.val) (words used : Usize)
    (huN : used.val ≤ N.val) (iter : core.ops.range.Range Usize)
    (a : Std.Array U64 N) (high : U64) (hend : iter.end = used) (hs1 : words.val ≤ iter.start.val)
    (hs2 : iter.start.val ≤ used.val)
    (ha : a.val = w0.take words.val ++ List.replicate (iter.start.val - words.val) 0#u64 ++
      w0.drop iter.start.val)
    (hh : high.val = 0 ↔ ∀ x ∈ (w0.drop words.val).take (iter.start.val - words.val), x.val = 0) :
    low.posint.PosInt.fit_loop iter a high ⦃ r =>
      r.1.val = w0.take words.val ++ List.replicate (used.val - words.val) 0#u64 ++ w0.drop used.val ∧
      (r.2.val = 0 ↔ ∀ x ∈ (w0.drop words.val).take (used.val - words.val), x.val = 0) ⦄ := by
  unfold low.posint.PosInt.fit_loop
  apply loop.spec_decr_nat (fun st => used.val - st.1.start.val)
    (fun st : core.ops.range.Range Usize × Std.Array U64 N × U64 =>
      st.1.end = used ∧ words.val ≤ st.1.start.val ∧ st.1.start.val ≤ used.val ∧
      st.2.1.val = w0.take words.val ++ List.replicate (st.1.start.val - words.val) 0#u64 ++
        w0.drop st.1.start.val ∧
      (st.2.2.val = 0 ↔ ∀ x ∈ (w0.drop words.val).take (st.1.start.val - words.val), x.val = 0))
  · rintro ⟨it, a, h⟩ ⟨he, hs1, hs2, ha, hh⟩
    simp only at he hs1 hs2 ha hh ⊢
    unfold low.posint.PosInt.fit_loop.body
    by_cases hlt : it.start.val < it.end.val
    · step with core.iter.range.IteratorRange.next_Usize_some_spec as ⟨o, it', ho', hst, hen⟩
      subst ho'
      simp only
      rw [he] at hlt hen
      have hj : it.start.val < w0.length := by omega
      set P := w0.take words.val ++ List.replicate (it.start.val - words.val) 0#u64 with hP
      have hpre : P.length = it.start.val := by rw [hP]; simp; omega
      have hav : a.val = P ++ w0[it.start.val]'hj :: w0.drop (it.start.val + 1) := by
        rw [ha, List.drop_eq_getElem_cons hj]
      have hal : it.start.val < a.val.length := by
        rw [hav]; simp only [List.length_append, List.length_cons, List.length_drop, hpre]; omega
      step as ⟨x, hx⟩
      have hxv : x = w0[it.start.val]'hj := by
        rw [hx]
        simp only [List.getElem_of_eq hav]
        rw [List.getElem_append_right (le_of_eq hpre)]
        simp [hpre]
      step as ⟨h1, hh1, _⟩
      step as ⟨a1, ha1⟩
      have hn : it'.start.val - words.val = (it.start.val - words.val) + 1 := by omega
      refine ⟨by rw [hen], by omega, by omega, ?_, ?_, by omega⟩
      · rw [ha1, Std.Array.set_val_eq, hav, List.set_append_right _ _ (le_of_eq hpre), hpre,
          Nat.sub_self, List.set_cons_zero, hn, hst, List.replicate_succ', hP]
        simp
      · rw [hn, List.take_add_one, hh1, UScalar.val_or, Nat.or_eq_zero_iff, hh]
        have hget : (w0.drop words.val)[it.start.val - words.val]? = some (w0[it.start.val]'hj) := by
          rw [List.getElem?_drop]
          simp [show words.val + (it.start.val - words.val) = it.start.val by omega, hj]
        rw [hget, ← hxv]
        simp [or_imp, forall_and]
    · step with core.iter.range.IteratorRange.next_Usize_none_spec as ⟨o, it', ho', hit⟩
      subst ho'
      simp only [WP.spec_ok]
      have hu : it.start.val = used.val := by rw [he] at hlt; omega
      rw [hu] at ha hh
      exact ⟨ha, hh⟩
  · exact ⟨hend, hs1, hs2, ha, hh⟩

/-- `fit`'s loop over an empty range changes nothing. -/
theorem fit_loop_empty {N : Usize} (iter : core.ops.range.Range Usize) (a : Std.Array U64 N) (high : U64)
    (h : ¬ iter.start.val < iter.end.val) :
    low.posint.PosInt.fit_loop iter a high ⦃ r => r.1 = a ∧ r.2 = high ⦄ := by
  unfold low.posint.PosInt.fit_loop
  apply loop.spec_decr_nat (fun _ => 0)
    (fun st : core.ops.range.Range Usize × Std.Array U64 N × U64 => st = (iter, a, high))
  · rintro ⟨it, a', h'⟩ hst
    simp only [Prod.mk.injEq] at hst
    obtain ⟨rfl, rfl, rfl⟩ := hst
    unfold low.posint.PosInt.fit_loop.body
    step with core.iter.range.IteratorRange.next_Usize_none_spec as ⟨o, it', ho', hit⟩
    subst ho'
    simp [WP.spec_ok]
  · rfl

/-- `fit` sets a clean value's width to `words`, keeping its value modulo
`2^(64·words)`, and returns whether the value fits there. -/
theorem fit_spec {N : Usize} (self : low.posint.PosInt N) (words : Usize) (hw : words.val ≤ N.val)
    (hu : self.used.val ≤ N.val) (hc : Clean self) :
    low.posint.PosInt.fit self words ⦃ r => r.2.used = words ∧ Clean r.2 ∧
      wordsNat (lowWords r.2 words) = wordsNat (lowWords self self.used) % 2 ^ (64 * words.val) ∧
      (r.1 = true ↔ wordsNat (lowWords self self.used) < 2 ^ (64 * words.val)) ⦄ := by
  unfold low.posint.PosInt.fit
  have hwN : (words ≤ N) = true := by simp; scalar_tac
  simp only [massert, hwN, ↓reduceIte, bind_ok]
  have hw0 : self.words.val.length = N.val := by simp
  have hz := clean_drop hc hu
  set V := wordsNat (lowWords self self.used) with hV
  have hVlt : V < 2 ^ (64 * self.used.val) := by
    have := wordsNat_lt' (lowWords self self.used); rwa [lowWords_length self hu] at this
  have htake : wordsNat (self.words.val.take words.val) = V % 2 ^ (64 * words.val) := by
    rw [wordsNat_take_mod, hc]
  by_cases hwu : words.val ≤ self.used.val
  · step with fit_loop_spec self.words.val hw0 words self.used hu
      { start := words, «end» := self.used } self.words 0#u64 rfl le_rfl hwu
      (by simp) (by simp) as ⟨a, high, ha, hh⟩
    have ha' : a.val = self.words.val.take words.val ++ List.replicate (N.val - words.val) 0#u64 := by
      rw [ha, hz, List.append_assoc, List.replicate_append_replicate]; congr 2; omega
    have hlow : lowWords ({ words := a, used := words } : low.posint.PosInt N) words =
        self.words.val.take words.val := by
      show a.val.take words.val = _
      rw [ha', List.take_append_of_le_length (by simp; omega), List.take_of_length_le (by simp)]
    have hh0 : high = 0#u64 ↔ high.val = 0 := by
      constructor
      · intro h; rw [h]; rfl
      · intro h; exact (UScalar.eq_equiv high 0#u64).mpr (by rw [h]; rfl)
    refine ⟨?_, by rw [hlow, htake], ?_⟩
    · show wordsNat a.val = wordsNat (lowWords ({ words := a, used := words } : low.posint.PosInt N) words)
      rw [hlow, ha', wordsNat_append, wordsNat_replicate_zero, mul_zero, add_zero]
    · have hsplit := wordsNat_take_add self.words.val words.val (self.used.val - words.val)
      rw [show words.val + (self.used.val - words.val) = self.used.val by omega,
        Nat.min_eq_left (by omega)] at hsplit
      have hVu : V = wordsNat (self.words.val.take self.used.val) := rfl
      rw [← hVu] at hsplit
      have hwlt := wordsNat_lt' (self.words.val.take words.val)
      rw [List.length_take, Nat.min_eq_left (by omega)] at hwlt
      simp only [decide_eq_true_eq]
      rw [hh0, hh, ← wordsNat_eq_zero_iff]
      constructor
      · intro h0; rw [hsplit, h0]; omega
      · intro hlt
        by_contra hne
        have : 2 ^ (64 * words.val) ≤ 2 ^ (64 * words.val) * wordsNat ((self.words.val.drop words.val).take
            (self.used.val - words.val)) := Nat.le_mul_of_pos_right _ (Nat.pos_of_ne_zero hne)
        omega
  · step with fit_loop_empty { start := words, «end» := self.used } self.words 0#u64 (by simp; omega)
      as ⟨a, high, ha, hh⟩
    subst ha hh
    simp only
    have hmod : V % 2 ^ (64 * words.val) = V :=
      Nat.mod_eq_of_lt (lt_of_lt_of_le hVlt (Nat.pow_le_pow_right (by norm_num) (by omega)))
    refine ⟨?_, htake, ?_⟩
    · show wordsNat self.words.val = wordsNat (self.words.val.take words.val)
      rw [htake, hmod, hc]
    · constructor
      · intro _; rw [← hmod]; exact Nat.mod_lt _ (Nat.two_pow_pos _)
      · intro _; rfl

/-! ## `reduce_even`: a value modulo an even modulus -/

/-- The value `reduce_even` holds, in `b` when `in_b` and in `a` otherwise. -/
def held {M : Usize} (a b : low.posint.PosInt M) (in_b : Bool) : low.posint.PosInt M :=
  if in_b then b else a

/-- What one step of `reduce_even` adds to its value `x`: `addend`'s value, at
width `k`, or `x` itself without one. -/
def addendVal {M : Usize} (k : Usize) (x : Nat) : Option (low.posint.PosInt M) → Nat
  | none => x
  | some y => wordsNat (lowWords y k)

/-- One step of `reduce_even` adds to its value, at `m`'s width, `addend` or
the value itself, modulo `m`, into the other of `a` and `b`. -/
theorem reduce_step_spec {M : Usize} (a b m : low.posint.PosInt M) (in_b : Bool)
    (addend : Option (low.posint.PosInt M)) (hk : m.used.val ≤ M.val)
    (ha : a.used = m.used) (hb : b.used = m.used)
    (hx : wordsNat (lowWords (held a b in_b) m.used) < wordsNat (lowWords m m.used))
    (hy : ∀ y, addend = some y → y.used = m.used ∧ wordsNat (lowWords y m.used) < wordsNat (lowWords m m.used)) :
    low.posint.PosInt.reduce_step a b in_b addend m ⦃ r =>
      r.1.used = m.used ∧ r.2.used = m.used ∧
      wordsNat (lowWords (held r.1 r.2 !in_b) m.used) =
        (wordsNat (lowWords (held a b in_b) m.used) +
          addendVal m.used (wordsNat (lowWords (held a b in_b) m.used)) addend) %
          wordsNat (lowWords m m.used) ⦄ := by
  unfold low.posint.PosInt.reduce_step low.posint.PosInt.as_mut_words low.posint.PosInt.as_words
  step as ⟨x, hs, hsl, hback⟩
  obtain ⟨s, back⟩ := x
  dsimp only at *
  step as ⟨y, ht, htl, hback1⟩
  obtain ⟨t, back1⟩ := y
  dsimp only at *
  step as ⟨m1, hm1, hm1l⟩
  have hsv : s.val = lowWords a m.used := by simp [lowWords, hs, ha]
  have htv : t.val = lowWords b m.used := by simp [lowWords, ht, hb]
  have hmv : m1.val = lowWords m m.used := by simp [lowWords, hm1]
  rw [ha] at hsl
  rw [hb] at htl
  have hA := mont_into_post a m back hback hk
  have hB := mont_into_post b m back1 hback1 hk
  rw [ha]; rw [hb]
  cases in_b <;> cases addend <;>
    simp only [held, Bool.not_true, Bool.not_false, Bool.false_eq_true, ↓reduceIte, addendVal] at hx ⊢
  · step with bignum_modadd_spec t s s m1 (by rw [hsl, htl]) (by rw [hsl, htl]) (by rw [hm1l, htl])
      (by rw [hsv, hmv]; exact hx) (by rw [hsv, hmv]; exact hx) as ⟨b2, hb2l, hb2v⟩
    rw [(hB b2 (by rw [hb2l, htl])).1, hb2v, hsv, hmv]
  · rename_i y
    obtain ⟨hyu, hyv⟩ := hy y rfl
    step as ⟨s1, hs1, hs1l⟩
    have hs1v : s1.val = lowWords y m.used := by simp [lowWords, hs1, hyu]
    step with bignum_modadd_spec t s s1 m1 (by rw [hsl, htl]) (by rw [hs1l, hyu, htl]) (by rw [hm1l, htl])
      (by rw [hsv, hmv]; exact hx) (by rw [hs1v, hmv]; exact hyv) as ⟨b2, hb2l, hb2v⟩
    rw [(hB b2 (by rw [hb2l, htl])).1, hb2v, hsv, hs1v, hmv]
  · step with bignum_modadd_spec s t t m1 (by rw [hsl, htl]) (by rw [hsl, htl]) (by rw [hm1l, hsl])
      (by rw [htv, hmv]; exact hx) (by rw [htv, hmv]; exact hx) as ⟨a2, ha2l, ha2v⟩
    rw [(hA a2 (by rw [ha2l, hsl])).1, ha2v, htv, hmv]
  · rename_i y
    obtain ⟨hyu, hyv⟩ := hy y rfl
    step as ⟨s1, hs1, hs1l⟩
    have hs1v : s1.val = lowWords y m.used := by simp [lowWords, hs1, hyu]
    step with bignum_modadd_spec s t s1 m1 (by rw [htl, hsl]) (by rw [hs1l, hyu, hsl]) (by rw [hm1l, hsl])
      (by rw [htv, hmv]; exact hx) (by rw [hs1v, hmv]; exact hyv) as ⟨a2, ha2l, ha2v⟩
    rw [(hA a2 (by rw [ha2l, hsl])).1, ha2v, htv, hs1v, hmv]

/-- Doubling `Y mod M` modulo `M` is doubling `Y`. -/
theorem double_mod (Y M : Nat) : (Y % M + Y % M) % M = (Y + Y) % M := (Nat.add_mod Y Y M).symm

/-- `reduce_even`'s innermost loop doubles its value, modulo `m`, once for
each step left in `iter`. -/
theorem reduce_even_loop2_spec {M : Usize} (mw : Std.Array U64 M) (k : Usize)
    (iter : core.ops.range.Range Usize) (a b : low.posint.PosInt M) (in_b : Bool) (X : Nat)
    (hk : k.val ≤ M.val) (hM : 0 < wordsNat (mw.val.take k.val)) (ha : a.used = k) (hb : b.used = k)
    (hs : iter.start.val ≤ iter.end.val)
    (hv : wordsNat (lowWords (held a b in_b) k) = X * 2 ^ iter.start.val % wordsNat (mw.val.take k.val)) :
    low.posint.PosInt.reduce_even_loop0_loop0_loop0 iter mw k a b in_b ⦃ r =>
      r.1.used = k ∧ r.2.1.used = k ∧
      wordsNat (lowWords (held r.1 r.2.1 r.2.2) k) = X * 2 ^ iter.end.val % wordsNat (mw.val.take k.val) ⦄ := by
  unfold low.posint.PosInt.reduce_even_loop0_loop0_loop0
  set Mv := wordsNat (mw.val.take k.val) with hMv
  apply loop.spec_decr_nat (fun st => st.1.end.val - st.1.start.val)
    (fun st : core.ops.range.Range Usize × low.posint.PosInt M × low.posint.PosInt M × Bool =>
      st.1.end = iter.end ∧ st.1.start.val ≤ st.1.end.val ∧ st.2.1.used = k ∧ st.2.2.1.used = k ∧
      wordsNat (lowWords (held st.2.1 st.2.2.1 st.2.2.2) k) = X * 2 ^ st.1.start.val % Mv)
  · rintro ⟨it, a, b, in_b⟩ ⟨he, hs, ha, hb, hv⟩
    simp only at he hs ha hb hv ⊢
    unfold low.posint.PosInt.reduce_even_loop0_loop0_loop0.body
    by_cases hlt : it.start.val < it.end.val
    · step with core.iter.range.IteratorRange.next_Usize_some_spec as ⟨o, it', ho', hst, hen⟩
      subst ho'
      simp only
      have hm : ({ words := mw, used := k } : low.posint.PosInt M).used = k := rfl
      have hmv : wordsNat (lowWords ({ words := mw, used := k } : low.posint.PosInt M) k) = Mv := rfl
      step with reduce_step_spec a b { words := mw, used := k } in_b none hk ha hb
        (by rw [hmv, hv]; exact Nat.mod_lt _ hM) (by simp) as ⟨a', b', ha', hb', hv'⟩
      have hen' : it'.end.val = it.end.val := by rw [hen]
      refine ⟨by rw [hen, he], by omega, ha', hb', ?_, by omega⟩
      have hnot : (decide ¬in_b = true) = !in_b := by cases in_b <;> rfl
      rw [hnot, hv', hmv, addendVal, hv, double_mod, hst, pow_succ]
      congr 1; ring
    · step with core.iter.range.IteratorRange.next_Usize_none_spec as ⟨o, it', ho', hit⟩
      subst ho'
      simp only [WP.spec_ok]
      have hu : it.start.val = iter.end.val := by rw [← he]; omega
      rw [hu] at hv
      exact ⟨ha, hb, hv⟩
  · exact ⟨rfl, hs, ha, hb, hv⟩

/-- Shifting the next `b` bits of `w` into `Y`, modulo `M`. -/
theorem shift_in (Mv R0 w b e : Nat) (hbe : b * (e + 1) ≤ 64) :
    ((R0 * 2 ^ (64 - b * (e + 1)) + w / 2 ^ (b * (e + 1))) % Mv * 2 ^ b % Mv + w / 2 ^ (b * e) % 2 ^ b) % Mv =
      (R0 * 2 ^ (64 - b * e) + w / 2 ^ (b * e)) % Mv := by
  set Y := R0 * 2 ^ (64 - b * (e + 1)) + w / 2 ^ (b * (e + 1))
  rw [Nat.mod_add_mod]
  have h1 : (Y % Mv * 2 ^ b + w / 2 ^ (b * e) % 2 ^ b) % Mv = (Y * 2 ^ b + w / 2 ^ (b * e) % 2 ^ b) % Mv :=
    Nat.ModEq.add_right _ (Nat.ModEq.mul_right _ (Nat.mod_modEq Y Mv))
  rw [h1]
  congr 1
  have h2 : 2 ^ (64 - b * (e + 1)) * 2 ^ b = 2 ^ (64 - b * e) := by
    rw [← pow_add]; congr 1; rw [Nat.mul_succ] at hbe ⊢; omega
  have h3 : w / 2 ^ (b * (e + 1)) = w / 2 ^ (b * e) / 2 ^ b := by
    rw [Nat.div_div_eq_div_mul, ← pow_add, Nat.mul_succ]
  simp only [Y, add_mul, h3]
  rw [mul_assoc, h2, add_assoc, Nat.div_add_mod']

theorem rev_next_spec (r : core.iter.adapters.rev.Rev (core.ops.range.Range Usize)) :
    core.iter.adapters.rev.Rev.Insts.CoreIterTraitsIteratorIterator.next
      (core.ops.range.Range.Insts.DoubleEndedIterator core.iter.range.StepUsize) r ⦃ o r' =>
      r'.iter.start = r.iter.start ∧
        (if r.iter.start.val < r.iter.end.val then o = some r'.iter.end ∧ r'.iter.end.val + 1 = r.iter.end.val
          else o = none) ⦄ := by
  unfold core.iter.adapters.rev.Rev.Insts.CoreIterTraitsIteratorIterator.next
  simp only [
    core.ops.range.Range.Insts.CoreIterTraitsDoubleEndedIterator.next_back, core.iter.range.StepUsize,
    core.iter.range.UScalarStep, core.iter.range.UScalarStep.backward_checked]
  by_cases hlt : r.iter.start.val < r.iter.end.val
  · have hb : liftFun2 core.cmp.impls.PartialOrdUsize.lt r.iter.start r.iter.end = ok true := by
      simp [liftFun2, core.cmp.impls.PartialOrdUsize.lt, hlt]
    have h1 : (1#usize).val ≤ r.iter.end.val := by simp; omega
    simp only [hb, bind_ok, ↓reduceIte, h1, ↓reduceDIte, hlt]
    simp [UScalar.ofNatCore_val_eq]; omega
  · have hb : liftFun2 core.cmp.impls.PartialOrdUsize.lt r.iter.start r.iter.end = ok false := by
      simp [liftFun2, core.cmp.impls.PartialOrdUsize.lt, hlt]
    simp [hb, hlt, WP.spec_ok]

/-- A value whose words above the first are zero is its first word. -/
theorem wordsNat_first {M : Usize} (p : low.posint.PosInt M) (x : U64) (k : Nat) (hk1 : 1 ≤ k)
    (hp : p.words.val = x :: List.replicate (M.val - 1) 0#u64) :
    wordsNat (lowWords p k) = x.val := by
  obtain ⟨k', rfl⟩ : ∃ k', k = k' + 1 := ⟨k - 1, by omega⟩
  simp only [lowWords, hp, List.take_succ_cons, wordsNat_cons, List.take_replicate, wordsNat_replicate_zero]
  simp

/-- `reduce_even`'s middle loop shifts the word `w` into its value `R0`,
`bits` at a time from the top, modulo `m`. -/
theorem reduce_even_loop1_spec {N M : Usize} (sw : Std.Array U64 N) (mw : Std.Array U64 M) (k bits j : Usize)
    (iter : core.iter.adapters.rev.Rev (core.ops.range.Range Usize)) (a b addend : low.posint.PosInt M)
    (in_b : Bool) (R0 w : Nat)
    (hk : k.val ≤ M.val) (hk1 : 1 ≤ k.val) (hbits : bits.val = 64 ∨ bits.val = 1)
    (hbM : 2 ^ bits.val ≤ wordsNat (mw.val.take k.val)) (hjl : j.val < sw.val.length)
    (hw : (sw.val[j.val]'hjl).val = w)
    (hs : iter.iter.start.val = 0) (he : iter.iter.end.val * bits.val ≤ 64)
    (hR0 : R0 < wordsNat (mw.val.take k.val))
    (ha : a.used = k) (hb : b.used = k) (hau : addend.used = k)
    (had : addend.words.val.drop 1 = List.replicate (M.val - 1) 0#u64)
    (hv : wordsNat (lowWords (held a b in_b) k) =
      (R0 * 2 ^ (64 - bits.val * iter.iter.end.val) + w / 2 ^ (bits.val * iter.iter.end.val)) %
        wordsNat (mw.val.take k.val)) :
    low.posint.PosInt.reduce_even_loop0_loop0 iter sw mw k a b addend bits in_b j ⦃ r =>
      r.1.used = k ∧ r.2.1.used = k ∧ r.2.2.1.used = k ∧
      r.2.2.1.words.val.drop 1 = List.replicate (M.val - 1) 0#u64 ∧
      wordsNat (lowWords (held r.1 r.2.1 r.2.2.2) k) = (R0 * 2 ^ 64 + w) % wordsNat (mw.val.take k.val) ⦄ := by
  unfold low.posint.PosInt.reduce_even_loop0_loop0
  set Mv := wordsNat (mw.val.take k.val) with hMv
  have hM0 : 0 < Mv := lt_of_lt_of_le (Nat.two_pow_pos _) hbM
  have hb1 : 1 ≤ bits.val := by omega
  have hb64 : bits.val ≤ 64 := by omega
  apply loop.spec_decr_nat (fun st => st.1.iter.end.val)
    (fun st : core.iter.adapters.rev.Rev (core.ops.range.Range Usize) × low.posint.PosInt M ×
        low.posint.PosInt M × low.posint.PosInt M × Bool =>
      st.1.iter.start.val = 0 ∧ st.1.iter.end.val * bits.val ≤ 64 ∧
      st.2.1.used = k ∧ st.2.2.1.used = k ∧ st.2.2.2.1.used = k ∧
      st.2.2.2.1.words.val.drop 1 = List.replicate (M.val - 1) 0#u64 ∧
      wordsNat (lowWords (held st.2.1 st.2.2.1 st.2.2.2.2) k) =
        (R0 * 2 ^ (64 - bits.val * st.1.iter.end.val) + w / 2 ^ (bits.val * st.1.iter.end.val)) % Mv)
  · rintro ⟨it, a, b, addend, in_b⟩ ⟨hs, he, ha, hb, hau, had, hv⟩
    simp only at hs he ha hb hau had hv ⊢
    unfold low.posint.PosInt.reduce_even_loop0_loop0.body
    step with rev_next_spec as ⟨o, it1, hst, ho⟩
    split_ifs at ho with hlt
    · obtain ⟨rfl, he1⟩ := ho
      simp only
      set e := it1.iter.end.val with he_def
      have hbe : bits.val * (e + 1) ≤ 64 := by rw [he1, Nat.mul_comm]; exact he
      have hVlt : wordsNat (lowWords (held a b in_b) k) < Mv := by rw [hv]; exact Nat.mod_lt _ hM0
      step with reduce_even_loop2_spec mw k { start := 0#usize, «end» := bits } a b in_b
        (wordsNat (lowWords (held a b in_b) k)) hk (by rw [← hMv]; exact hM0) ha hb (by simp)
        (by show _ = _ * 2 ^ (0 : Nat) % _; rw [pow_zero, mul_one]; exact (Nat.mod_eq_of_lt hVlt).symm)
        as ⟨a3, b1, in_b1, ha3, hb1', hv3⟩
      step as ⟨i1, hi1⟩
      have hi1v : i1.val = w := by rw [hi1]; exact hw
      have heb : e * bits.val < 64 := by rw [Nat.mul_succ] at hbe; rw [Nat.mul_comm]; omega
      step as ⟨i2, hi2⟩
      step as ⟨i3, hi3, _⟩
      step as ⟨i4, hi4⟩
      step as ⟨i5, hi5, _⟩
      step as ⟨i6, hi6, _⟩
      step as ⟨a4, ha4⟩
      have hi5v : i5.val = 2 ^ bits.val - 1 := by
        rw [hi5, hi4]
        rcases hbits with h | h <;> rw [h] <;> decide
      have hi6v : i6.val = w / 2 ^ (bits.val * e) % 2 ^ bits.val := by
        rw [hi6, UScalar.val_and, hi3, hi5v, hi2, hi1v, Nat.shiftRight_eq_div_pow,
          Nat.and_two_pow_sub_one_eq_mod, Nat.mul_comm]
      have ha4v : a4.val = i6 :: List.replicate (M.val - 1) 0#u64 := by
        rw [ha4, Std.Array.set_val_eq]
        have hl := addend.words.property
        rcases hwd : addend.words.val with _ | ⟨x0, rest⟩
        · rw [hwd] at hl; simp only [List.length_nil] at hl; omega
        · rw [hwd] at had; simp only [List.drop_succ_cons, List.drop_zero] at had; subst had; simp
      have hadv : wordsNat (lowWords ({ words := a4, used := addend.used } : low.posint.PosInt M) k) = i6.val :=
        wordsNat_first _ i6 k hk1 ha4v
      have hV3 : wordsNat (lowWords (held a3 b1 in_b1) k) < Mv := by rw [hv3]; exact Nat.mod_lt _ hM0
      step with reduce_step_spec a3 b1 { words := mw, used := k } in_b1
        (some { words := a4, used := addend.used }) hk ha3 hb1' hV3
        (by
          intro y hy; cases hy
          exact ⟨hau, by rw [hadv, hi6v]; exact lt_of_lt_of_le (Nat.mod_lt _ (Nat.two_pow_pos _)) hbM⟩)
        as ⟨a5, b2, ha5, hb2, hv5⟩
      have hnot : (decide ¬in_b1 = true) = !in_b1 := by cases in_b1 <;> rfl
      refine ⟨by rw [hst]; exact hs, le_of_lt heb, ha5, hb2, hau, by rw [ha4v]; rfl, ?_, by omega⟩
      rw [hnot, hv5, addendVal, hadv, hi6v, hv3, hv, ← he1]
      exact shift_in Mv R0 w bits.val e hbe
    · obtain rfl := ho
      simp only [WP.spec_ok]
      have he0 : it.iter.end.val = 0 := by omega
      rw [he0, Nat.mul_zero, Nat.sub_zero, pow_zero, Nat.div_one] at hv
      exact ⟨ha, hb, hau, had, hv⟩
  · exact ⟨hs, he, ha, hb, hau, had, hv⟩

/-- The value of the words of `sw` from `e` up to `used`. -/
def topVal {N : Usize} (sw : Std.Array U64 N) (used e : Nat) : Nat :=
  wordsNat ((sw.val.take used).drop e)

theorem topVal_step {N : Usize} (sw : Std.Array U64 N) (used j : Nat) (hj : j < used) (hu : used ≤ N.val)
    (hjl : j < sw.val.length) :
    topVal sw used j = (sw.val[j]'hjl).val + 2 ^ 64 * topVal sw used (j + 1) := by
  unfold topVal
  have hlt : j < (sw.val.take used).length := by simp; omega
  rw [List.drop_eq_getElem_cons hlt, wordsNat_cons, List.getElem_take]

/-- `reduce_even`'s outer loop shifts in the words below `iter`'s end, one at
a time from the top, modulo `m`. -/
theorem reduce_even_loop0_spec {N M : Usize} (sw : Std.Array U64 N) (mw : Std.Array U64 M) (k bits : Usize)
    (iter : core.iter.adapters.rev.Rev (core.ops.range.Range Usize)) (a b addend : low.posint.PosInt M)
    (in_b : Bool) (used : Nat)
    (hk : k.val ≤ M.val) (hk1 : 1 ≤ k.val) (hbits : bits.val = 64 ∨ bits.val = 1)
    (hbM : 2 ^ bits.val ≤ wordsNat (mw.val.take k.val)) (hu : used ≤ N.val)
    (hs : iter.iter.start.val = 0) (he : iter.iter.end.val ≤ used)
    (ha : a.used = k) (hb : b.used = k) (hau : addend.used = k)
    (had : addend.words.val.drop 1 = List.replicate (M.val - 1) 0#u64)
    (hv : wordsNat (lowWords (held a b in_b) k) = topVal sw used iter.iter.end.val % wordsNat (mw.val.take k.val)) :
    low.posint.PosInt.reduce_even_loop0 iter sw mw k a b addend bits in_b ⦃ r =>
      r.1.used = k ∧ r.2.1.used = k ∧
      wordsNat (lowWords (held r.1 r.2.1 r.2.2) k) = topVal sw used 0 % wordsNat (mw.val.take k.val) ⦄ := by
  unfold low.posint.PosInt.reduce_even_loop0
  set Mv := wordsNat (mw.val.take k.val) with hMv
  have hM0 : 0 < Mv := lt_of_lt_of_le (Nat.two_pow_pos _) hbM
  have hb1 : 1 ≤ bits.val := by omega
  have hbP : bits.val * (64 / bits.val) = 64 := by rcases hbits with h | h <;> rw [h]
  apply loop.spec_decr_nat (fun st => st.1.iter.end.val)
    (fun st : core.iter.adapters.rev.Rev (core.ops.range.Range Usize) × low.posint.PosInt M ×
        low.posint.PosInt M × low.posint.PosInt M × Bool =>
      st.1.iter.start.val = 0 ∧ st.1.iter.end.val ≤ used ∧
      st.2.1.used = k ∧ st.2.2.1.used = k ∧ st.2.2.2.1.used = k ∧
      st.2.2.2.1.words.val.drop 1 = List.replicate (M.val - 1) 0#u64 ∧
      wordsNat (lowWords (held st.2.1 st.2.2.1 st.2.2.2.2) k) = topVal sw used st.1.iter.end.val % Mv)
  · rintro ⟨it, a, b, addend, in_b⟩ ⟨hs, he, ha, hb, hau, had, hv⟩
    simp only at hs he ha hb hau had hv ⊢
    unfold low.posint.PosInt.reduce_even_loop0.body
    step with rev_next_spec as ⟨o, it1, hst, ho⟩
    split_ifs at ho with hlt
    · obtain ⟨rfl, he1⟩ := ho
      simp only
      set j := it1.iter.end with hj_def
      have hjl : j.val < sw.val.length := by have := sw.property; omega
      step as ⟨i1, hi1⟩
      step as ⟨iter2, hiter2⟩
      have hR0 : wordsNat (lowWords (held a b in_b) k) < Mv := by rw [hv]; exact Nat.mod_lt _ hM0
      have hw64 : (sw.val[j.val]'hjl).val < 2 ^ 64 := (sw.val[j.val]'hjl).hBounds
      step with reduce_even_loop1_spec sw mw k bits j iter2 a b addend in_b
        (wordsNat (lowWords (held a b in_b) k)) (sw.val[j.val]'hjl).val hk hk1 hbits hbM hjl rfl
        (by rw [hiter2]; rfl) (by rw [hiter2, hi1, Nat.mul_comm, hbP])
        hR0 ha hb hau had
        (by
          rw [hiter2, hi1, hbP, Nat.sub_self, pow_zero, mul_one, Nat.div_eq_of_lt hw64, add_zero]
          exact (Nat.mod_eq_of_lt hR0).symm)
        as ⟨a3, b1, addend1, in_b1, ha3, hb3, hau3, had3, hv3⟩
      have hjv : it1.iter.end.val = j.val := rfl
      refine ⟨by rw [hst]; exact hs, by omega, ha3, hb3, hau3, had3, ?_, by omega⟩
      rw [hv3, hv, ← he1, topVal_step sw used j.val (by omega) hu hjl]
      have hmod : (topVal sw used (j.val + 1) % Mv * 2 ^ 64 + (sw.val[j.val]'hjl).val) % Mv =
          (topVal sw used (j.val + 1) * 2 ^ 64 + (sw.val[j.val]'hjl).val) % Mv :=
        Nat.ModEq.add_right _ (Nat.ModEq.mul_right _ (Nat.mod_modEq _ _))
      rw [hmod]; congr 1; ring
    · obtain rfl := ho
      simp only [WP.spec_ok]
      have he0 : it.iter.end.val = 0 := by omega
      rw [he0] at hv
      exact ⟨ha, hb, hv⟩
  · exact ⟨hs, he, ha, hb, hau, had, hv⟩

/-- `reduce_even` reduces `self` modulo `m`, which may be even, given `m`'s
top word is nonzero and `m` is at least two. -/
theorem reduce_even_spec {N M : Usize} (self : low.posint.PosInt N) (m : low.posint.PosInt M)
    (hMN : M.val < N.val) (hk1 : 1 ≤ m.used.val) (hk : m.used.val ≤ M.val) (hu : self.used.val ≤ N.val)
    (htop : 2 ^ (64 * (m.used.val - 1)) ≤ wordsNat (lowWords m m.used))
    (h2 : 2 ≤ wordsNat (lowWords m m.used)) :
    low.posint.PosInt.reduce_even self m ⦃ r => r.used = m.used ∧
      wordsNat (lowWords r m.used) = wordsNat (lowWords self self.used) % wordsNat (lowWords m m.used) ⦄ := by
  unfold low.posint.PosInt.reduce_even low.posint.PosInt.zero
  have hMN' : (M < N) = true := by simp; scalar_tac
  simp only [massert, hMN', ↓reduceIte, bind_ok]
  step with clone_spec as ⟨b, hb⟩
  simp only [lift, bind_ok]
  set Mv := wordsNat (lowWords m m.used) with hMv
  set i := core.num.Usize.saturating_sub self.used (core.num.Usize.saturating_sub m.used 1#usize) with hi_def
  have hiv : i.val = self.used.val - (m.used.val - 1) := by
    rw [hi_def, usize_saturating_sub_val, usize_saturating_sub_val]; rfl
  step*
  case h0 => show i ≤ self.used; scalar_tac
  case h =>
    have hl : top.length ≤ m.used.val - 1 := by rw [top_post1, hiv]; omega
    have := Slice.len_val top
    show top.len ≤ M
    scalar_tac
  have hl : top.length ≤ m.used.val - 1 := by rw [top_post1, hiv]; omega
  rw [show (if m.used > 1#usize then ok (index_mut_back s1, 64#usize) else ok (index_mut_back s1, 1#usize) :
      Result (Std.Array U64 M × Usize)) =
      ok (index_mut_back s1, if m.used > 1#usize then 64#usize else 1#usize) by split <;> rfl]
  simp only [bind_ok]
  set bits := (if m.used > 1#usize then 64#usize else 1#usize) with hbits_def
  have hbits : bits.val = 64 ∨ bits.val = 1 := by rw [hbits_def]; split <;> simp
  have hbM : 2 ^ bits.val ≤ Mv := by
    rw [hbits_def]
    split
    · rename_i hgt
      have hgt' : 1 < m.used.val := by scalar_tac
      exact le_trans (Nat.pow_le_pow_right (by norm_num) (by show (64 : Nat) ≤ _; omega)) htop
    · simpa using h2
  have htl : top.val.length ≤ m.used.val - 1 := hl
  -- The top words, below `m`, start the value.
  have htopv : topVal self.words self.used.val i.val = wordsNat top.val := by
    rw [topVal, top_post, List.slice, List.drop_take, Array.val_to_slice]
  have htoplt : wordsNat top.val < Mv := by
    have := wordsNat_lt' top.val
    exact lt_of_lt_of_le (lt_of_lt_of_le this (Nat.pow_le_pow_right (by norm_num) (by omega))) htop
  have hav : wordsNat (lowWords ({ words := index_mut_back s1, used := m.used } : low.posint.PosInt M) m.used) =
      wordsNat top.val := by
    have hlen' : top.val.length ≤ M.val := by omega
    have hlenk : top.val.length ≤ m.used.val := by omega
    simp only [lowWords, s_post2, s1_post, Array.repeat_val, List.setSlice!, List.take_zero, List.nil_append,
      List.length_replicate, Nat.sub_zero]
    rw [Nat.min_eq_left hlen', List.take_length, Nat.zero_add, List.drop_replicate,
      List.take_append, List.take_of_length_le hlenk, wordsNat_append, List.take_replicate,
      wordsNat_replicate_zero, mul_zero, add_zero]
  step as ⟨iter, hiter⟩
  have hb' : b.used = m.used := by rw [hb]
  have hbd : b.words.val.drop 1 = List.replicate (M.val - 1) 0#u64 := by rw [hb]; simp [Array.repeat_val]
  step with reduce_even_loop0_spec self.words m.words m.used bits iter
    { words := index_mut_back s1, used := m.used } b b false self.used.val hk hk1 hbits hbM hu
    (by rw [hiter]; rfl) (by rw [hiter]; show i.val ≤ _; omega) rfl hb' hb' hbd
    (by
      simp only [held, Bool.false_eq_true, ↓reduceIte, hiter]
      rw [hav, htopv]; exact (Nat.mod_eq_of_lt htoplt).symm)
    as ⟨a2, b1, in_b, ha2, hb1, hv⟩
  have htop0 : topVal self.words self.used.val 0 = wordsNat (lowWords self self.used) := by
    simp [topVal, lowWords]
  rw [htop0] at hv
  cases in_b
  · simp only [held, Bool.false_eq_true, ↓reduceIte] at hv
    simp only [Bool.false_eq_true, ↓reduceIte, WP.spec_ok]
    exact ⟨ha2, hv⟩
  · simp only [held, ↓reduceIte] at hv
    simp only [↓reduceIte, WP.spec_ok]
    exact ⟨hb1, hv⟩

end PrivKey

end rind.x86_64
