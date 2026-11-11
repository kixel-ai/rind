import Rind.X86_64.RsaPublic
import Rind.X86_64.Blockwise
import Rind.Bytes
open Aeneas Aeneas.Std Result rind.spec rind.spec.rsa

/-!
# RSA's integer encodings on x86_64

`PosInt::from_bytes` is RFC 8017's OS2IP, and `PosInt::to_bytes` with
`i2osp` its I2OSP.
-/

namespace rind.x86_64

theorem os2ip_bv (l : List U8) : os2ip (bv l) = beNat l := by
  induction l using List.reverseRecOn with
  | nil => rfl
  | append_singleton l b ih =>
    simp only [bv, List.map_append, List.map_cons, List.map_nil] at ih ⊢
    rw [os2ip, List.foldl_append, ← os2ip, ih, beNat_append]
    simp [beNat, leNat, Nat.mul_comm]

theorem beNat_zeros (l : List U8) (h : ∀ x ∈ l, x = 0#u8) : beNat l = 0 := by
  induction l with
  | nil => rfl
  | cons a t ih =>
    rw [show a :: t = [a] ++ t from rfl, beNat_append, ih (fun x hx => h x (by simp [hx]))]
    simp [h a (by simp), beNat, leNat]

/-- Leading zeros add nothing. -/
theorem beNat_drop_zeros (l : List U8) (n : Nat) (h : ∀ x ∈ l.take n, x = 0#u8) :
    beNat (l.drop n) = beNat l := by
  conv_rhs => rw [← List.take_append_drop n l, beNat_append, beNat_zeros _ h]
  simp

theorem trim_leading_zeroes_spec (bytes : Slice U8) :
    low.posint.trim_leading_zeroes bytes ⦃ s =>
      beNat s.val = beNat bytes.val ∧ s.length ≤ bytes.length ⦄ := by
  unfold low.posint.trim_leading_zeroes low.posint.trim_leading_zeroes_loop
  step with loop.spec_decr_nat (fun st : Usize => bytes.length - st.val)
    (fun st : Usize => st.val ≤ bytes.length ∧ ∀ x ∈ bytes.val.take st.val, x = 0#u8)
    (fun st : Usize => st.val ≤ bytes.length ∧ ∀ x ∈ bytes.val.take st.val, x = 0#u8) as ⟨start, hle, hz⟩
  · intro st ⟨hle, hz⟩
    unfold low.posint.trim_leading_zeroes_loop.body
    step*
    · refine ⟨by scalar_tac, ?_, by scalar_tac⟩
      intro x hx
      rw [start1_post, List.take_add_one] at hx
      simp only [List.mem_append] at hx
      rcases hx with hx | hx
      · exact hz x hx
      · simp [List.getElem?_eq_getElem (by scalar_tac : st.val < bytes.val.length)] at hx
        rw [hx, ← i1_post]; assumption
    all_goals exact ⟨hle, hz⟩
  · exact ⟨by simp, by simp⟩
  · step*
    refine ⟨?_, by scalar_tac⟩
    rw [s_post]; exact beNat_drop_zeros _ _ hz

theorem set_append_replicate {α : Type} (ws : List α) (n : Nat) (z x : α) (hn : 1 ≤ n) :
    (ws ++ List.replicate n z).set ws.length x = (ws ++ [x]) ++ List.replicate (n - 1) z := by
  obtain ⟨m, rfl⟩ : ∃ m, n = m + 1 := ⟨n - 1, by omega⟩
  simp [List.replicate_succ, List.set_append_right]

theorem take_eq_take_append_slice {α : Type} (l : List α) (a e : Nat) (hae : a ≤ e) :
    l.take e = l.take a ++ l.slice a e := by
  have := slice_append_slice l 0 a e (by omega) hae
  simp only [List.slice_zero_j] at this
  exact this.symm

/-- What `from_bytes`'s word loop keeps, with `i` words read from the back of
`b`: they are the words below `i`, the rest are zero, and `b` reads as the
bytes left over, then those words. -/
def FromBytesInv (b : List U8) (i : Nat) (r : RsaInt) : Prop :=
  r.used.val = 0 ∧ ∃ ws : List U64, ws.length = i ∧ r.words.val = ws ++ List.replicate (128 - i) 0#u64 ∧
    beNat b = beNat (b.take (b.length - 8 * i)) * 2 ^ (64 * i) + wordsNat ws

theorem from_bytes_loop0_spec (b : Slice U8) (hlen : b.length ≤ 1024)
    (iter : core.ops.range.Range Usize) (hend : iter.end.val = b.length / 8)
    (hstart : iter.start.val ≤ iter.end.val) (r : RsaInt) (hinv : FromBytesInv b.val iter.start.val r) :
    low.posint.PosInt.from_bytes_loop0 iter b r ⦃ r' => FromBytesInv b.val (b.length / 8) r' ⦄ := by
  unfold low.posint.PosInt.from_bytes_loop0
  apply loop.spec_decr_nat (fun x => x.1.end.val - x.1.start.val)
    (fun x => x.1.end = iter.end ∧ x.1.start.val ≤ x.1.end.val ∧ FromBytesInv b.val x.1.start.val x.2)
  · rintro ⟨it, r1⟩ ⟨he, hs, hinv⟩
    simp only at he hs hinv
    unfold low.posint.PosInt.from_bytes_loop0.body
    step as ⟨o, iter1, ho, hend1⟩
    cases o with
    | none =>
      have h2 : it.end.val = iter.end.val := by rw [he]
      have : it.start.val = b.length / 8 := by
        split at ho
        · simp at ho
        · omega
      rw [this] at hinv
      simpa using hinv
    | some i =>
      have hlt : it.start.val < it.end.val := by
        by_contra hc; simp [hc] at ho
      simp only [hlt, ↓reduceIte, Option.some.injEq] at ho
      obtain ⟨rfl, hst⟩ := ho
      obtain ⟨hu, ws, hwl, hws, hval⟩ := hinv
      have h2 : it.end.val = iter.end.val := by rw [he]
      have hi : it.start.val < b.length / 8 := by omega
      have hbl : b.len.val = b.length := rfl
      have hbL : b.length = b.val.length := rfl
      step as ⟨i2, hi2⟩
      step as ⟨e, he1, he2⟩
      step as ⟨i3, hi3, hi3'⟩
      step as ⟨sl, hsl, hsl'⟩
      step as ⟨r2, hr2⟩
      cases r2 with
      | Err _ => exfalso; simp at hr2; scalar_tac
      | Ok a =>
        obtain ⟨haval, halen⟩ := hr2
        step as ⟨a', ha'⟩
        simp only [core.result.Result.Ok.injEq] at ha'
        subst ha'
        step as ⟨w, hw⟩
        have hwv : w.val = beNat sl.val := by rw [← haval]; exact val_of_fromBEBytes _ w hw
        step as ⟨nw, hnw⟩
        have h3 : iter1.end.val = it.end.val := by rw [hend1]
        refine ⟨by rw [hend1, he], by omega, ⟨hu, ws ++ [w], by simp [hwl, hst], ?_, ?_⟩, by omega⟩
        · rw [hnw, Array.set_val_eq, hws, ← hwl, set_append_replicate _ _ _ _ (by omega)]
          simp only [List.append_assoc, List.cons_append, List.nil_append, hwl, hst]
          rw [Nat.sub_sub]
        · have hsplit := take_eq_take_append_slice b.val i3.val e.val (by omega)
          have hsl8 : sl.val.length = 8 := by simpa [Slice.length] using hsl'.trans (by omega)
          rw [hst, wordsNat_append, hwl, show (b.val.length - 8 * (it.start.val + 1)) = i3.val by omega]
          rw [show b.val.length - 8 * it.start.val = e.val by omega,
            hsplit, beNat_append, ← hsl, hsl8] at hval
          rw [hval, show wordsNat [w] = w.val by simp [wordsNat], hwv]
          rw [show (256 : Nat) ^ 8 = 2 ^ 64 by norm_num]
          ring
  · exact ⟨rfl, hstart, hinv⟩

theorem from_bytes_loop1_spec (b : Slice U8) (iter : core.ops.range.Range Usize)
    (hend : iter.end.val < 8) (hle : iter.end.val ≤ b.length) (hstart : iter.start.val ≤ iter.end.val)
    (top : U64) (htop : top.val = beNat (b.val.take iter.start.val)) :
    low.posint.PosInt.from_bytes_loop1 iter b top ⦃ t => t.val = beNat (b.val.take iter.end.val) ⦄ := by
  unfold low.posint.PosInt.from_bytes_loop1
  apply loop.spec_decr_nat (fun x => x.1.end.val - x.1.start.val)
    (fun x => x.1.end = iter.end ∧ x.1.start.val ≤ x.1.end.val ∧ x.2.val = beNat (b.val.take x.1.start.val))
  · rintro ⟨it, t⟩ ⟨he, hs, ht⟩
    simp only at he hs ht
    have h2 : it.end.val = iter.end.val := by rw [he]
    unfold low.posint.PosInt.from_bytes_loop1.body
    step as ⟨o, iter1, ho, hend1⟩
    cases o with
    | none =>
      have : it.start.val = iter.end.val := by
        split at ho
        · simp at ho
        · omega
      rw [this] at ht
      simpa using ht
    | some i =>
      have hlt : it.start.val < it.end.val := by
        by_contra hc; simp [hc] at ho
      simp only [hlt, ↓reduceIte, Option.some.injEq] at ho
      obtain ⟨rfl, hst⟩ := ho
      have h3 : iter1.end.val = it.end.val := by rw [hend1]
      have hbL : b.length = b.val.length := rfl
      have htlt : t.val < 2 ^ 56 := by
        rw [ht]
        have := beNat_lt (b.val.take it.start.val)
        calc _ < 256 ^ (b.val.take it.start.val).length := this
          _ ≤ 256 ^ 7 := Nat.pow_le_pow_right (by norm_num) (by simp; omega)
          _ = 2 ^ 56 := by norm_num
      step*
      refine ⟨by rw [hend1, he], by omega, ?_, by omega⟩
      rw [hst, List.take_add_one, beNat_append, ← ht]
      have hi1 : i1.val = t.val * 256 := by
        rw [i1_post, Nat.shiftLeft_eq, Nat.mod_eq_of_lt] <;> simp [U64.size, U64.numBits] <;> try omega
      have hi3 : i3.val = i2.val := by
        rw [i3_post, UScalar.cast_val_eq]; exact Nat.mod_eq_of_lt (by have := i2.hBounds; simp at this ⊢; omega)
      have htop1 : top1.val = t.val * 256 + i2.val := by
        rw [top1_post, UScalar.val_or, hi1, hi3, show t.val * 256 = t.val <<< 8 by rw [Nat.shiftLeft_eq],
          ← Nat.shiftLeft_add_eq_or_of_lt (by have := i2.hBounds; simpa using this)]
      rw [List.getElem?_eq_getElem (by omega)]
      simp [beNat, leNat, htop1, i2_post]
  · exact ⟨rfl, hstart, htop⟩

/-- OS2IP: `from_bytes` reads big-endian bytes, up to 1024 of them, as the
number they encode, with no words set above its length. -/
theorem from_bytes_spec (bytes : Slice U8) (hlen : bytes.length ≤ 1024) :
    low.posint.PosInt.from_bytes 128#usize bytes ⦃ r => ∃ p, r = .Ok p ∧ p.used.val ≤ 128 ∧
      wordsNat (p.words.val.drop p.used.val) = 0 ∧ wordsNat (lowWords p p.used) = beNat bytes.val ⦄ := by
  unfold low.posint.PosInt.from_bytes low.posint.PosInt.zero
  step with trim_leading_zeroes_spec as ⟨b1, hb1v, hb1l⟩
  have hbL : b1.length = b1.val.length := rfl
  step*
  have hfull : full.val = b1.length / 8 := by rw [full_post]; rfl
  step with from_bytes_loop0_spec b1 (by omega) { start := 0#usize, «end» := full } hfull (by scalar_tac)
    { words := Array.repeat 128#usize 0#u64, used := 0#usize } ⟨by first | rfl | scalar_tac, [], rfl, by simp, by simp [wordsNat_nil]⟩ as ⟨r1, hr1⟩
  obtain ⟨hu, ws, hwl, hws, hval⟩ := hr1
  step as ⟨i4, hi4⟩
  have hi4' : i4.val = b1.length % 8 := by rw [hi4]; rfl
  step with from_bytes_loop1_spec b1 { start := 0#usize, «end» := i4 } (by simp; omega) (by simp; omega)
    (by scalar_tac) 0#u64 (by simp [beNat, leNat]) as ⟨top, htop⟩
  rw [show b1.val.length - 8 * (b1.length / 8) = i4.val by omega, ← htop] at hval
  have hz : wordsNat (List.replicate (128 - b1.length / 8) 0#u64) = 0 := wordsNat_replicate_zero _
  split
  · rename_i hne
    have htop0 : top.val ≠ 0 := by
      intro h0; apply absurd hne; simp [UScalar.eq_equiv, h0]
    have hf128 : full.val < 128 := by
      by_contra hc
      have : i4.val = 0 := by omega
      rw [this] at htop; simp [beNat, leNat] at htop; omega
    unfold low.posint.PosInt.push_word
    split
    · rename_i h; rw [UScalar.eq_equiv] at h; simp at h; omega
    step as ⟨nw, hnw⟩
    step as ⟨u1, hu1⟩
    step*
    have hfw : full.val = ws.length := by rw [hfull, hwl]
    have hnwv : nw.val = (ws ++ [top]) ++ List.replicate (128 - ws.length - 1) 0#u64 := by
      rw [hnw, Array.set_val_eq, hws, hfw, ← hwl, set_append_replicate _ _ _ _ (by omega)]
    have hu1' : u1.val = (ws ++ [top]).length := by simp [hu1, hfw]
    refine ⟨_, rfl, by scalar_tac, ?_, ?_⟩
    · simp only [hnwv, hu1', List.drop_left]
      exact wordsNat_replicate_zero _
    · simp only [lowWords, hnwv, hu1', List.take_left]
      rw [wordsNat_append, ← hb1v, hval, hwl]
      simp [wordsNat]; ring
  · rename_i heq
    have htop0 : top.val = 0 := by simpa [UScalar.eq_equiv] using heq
    simp only [WP.spec_ok]
    refine ⟨_, rfl, by scalar_tac, ?_, ?_⟩
    · simp only [hws, show full.val = ws.length by rw [hfull, hwl], List.drop_left]
      exact hz
    · simp only [lowWords, hws, show full.val = ws.length by rw [hfull, hwl], List.take_left]
      rw [← hb1v, hval, htop0]; simp

end rind.x86_64
