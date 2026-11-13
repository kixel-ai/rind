import Rind.AesKw
import Rind.X86_64.AesCipher
import Rind.X86_64.CtEqual
open Aeneas Aeneas.Std Result rind.vale rind.simd

namespace rind.x86_64

/-- A word's 8 bytes as `to_ne_bytes` writes them, little-endian on rind's targets. -/
abbrev le8 (a : U64) : List (BitVec 8) := a.bv.toLEBytes

theorem le8_from (arr : Std.Array U8 8#usize) : le8 (core.num.U64.from_le_bytes arr) = bvs arr.val := by
  exact (toLEBytes_cast (by simp) _).trans (toLEBytes_fromLEBytes (List.map U8.bv arr.val))

theorem bvs_to_le (a : U64) : bvs (core.num.U64.to_le_bytes a).val = le8 a := by
  simp [core.num.U64.to_le_bytes, bvs, List.map_map, Function.comp_def]

theorem le8_xor (a b : U64) : le8 (a ^^^ b) = xorBytes (le8 a) (le8 b) := by
  exact toLEBytes_xor a.bv b.bv

theorem le8_to_be (t : U64) : le8 (core.num.U64.from_le_bytes (core.num.U64.to_be_bytes t)) = be64 t.val := by
  rw [le8_from]
  simp [core.num.U64.to_be_bytes, bvs, List.map_map, Function.comp_def, toBEBytes_64]

@[step]
theorem block_spec (a : U64) (ri : Std.Array U8 8#usize) :
    mid.aes_kw.block a ri ⦃ blk => bvs blk.val = le8 a ++ bvs ri.val ⦄ := by
  unfold mid.aes_kw.block
  simp only [core.num.U64.to_ne_bytes]
  step*
  set L := (core.num.U64.to_le_bytes a).val
  have hL : L.length = 8 := by simp [L]
  have e1 := rind.spec.setSlice!_append [] (List.replicate 8 0#u8) (List.replicate 8 0#u8) L (by simp [hL])
  have e2 := rind.spec.setSlice!_append L (List.replicate 8 0#u8) [] ri.val (by simp)
  simp only [List.length_nil, List.nil_append, List.append_nil, hL] at e1 e2
  have e0 : (Std.Array.repeat 16#usize 0#u8).val = List.replicate 8 0#u8 ++ List.replicate 8 0#u8 := by
    simp
  rw [s3_post2, s5_post, s4_post, s2_post, s_post2, e0, s1_post, Std.Array.val_to_slice, e1, Std.Array.val_to_slice, e2]
  simp [bvs, L, bvs_to_le a]

/-- An AES-NI decryption key holding `KeyExpansionEIC`'s round keys for the key
bytes `key`. -/
def AesDecIs (alg : Algorithm) (key : List (BitVec 8)) (k : low.x86_64.aes.AesDecKey) : Prop :=
  ∃ hk, k = .Hw hk ∧ HwDecKeyIs alg (seqNat8ToSeqNat32LE key) hk

theorem enc_bytes {alg : Algorithm} {key : List (BitVec 8)} {k : mid.aes.Aes} (hk : AesIs alg key k)
    (b : Std.Array U8 16#usize) :
    low.x86_64.aes.AesKey.encrypt_block k b ⦃ out => bvs out.val = aesBlock alg key (bvs b.val) ⦄ := by
  rw [aes_encrypt alg key k hk b, WP.spec_ok, store_bytes]; rfl

theorem dec_bytes {alg : Algorithm} {key : List (BitVec 8)} {k : low.x86_64.aes.AesDecKey}
    (hk : AesDecIs alg key k) (b : Std.Array U8 16#usize) :
    low.x86_64.aes.AesDecKey.decrypt_block k b ⦃ out => bvs out.val = aesBlockDecrypt alg key (bvs b.val) ⦄ := by
  obtain ⟨hwk, rfl, hwk_is⟩ := hk
  rw [hw_decrypt_block_spec hwk alg _ hwk_is b, WP.spec_ok, store_bytes]; rfl

/-- `mid::aes::expand_key` passes `AesKey::new` its key unchanged. -/
theorem expand_key_eq (key : Slice U8) (hk : key.length ≤ 32) :
    mid.aes.expand_key key = low.x86_64.aes.AesKey.new key := by
  have h1 : (Slice.len key).val ≤ (Std.Array.repeat 32#usize 0#u8).to_slice.length := by simpa using hk
  simp only [mid.aes.expand_key, core.array.Array.index_mut, core.ops.index.IndexMutSlice,
    core.slice.index.Slice.index_mut, core.slice.index.SliceIndexRangeToUsizeSlice,
    core.slice.index.SliceIndexRangeToUsizeSlice.index_mut, h1, ite_true, bind_ok,
    core.slice.Slice.copy_from_slice, low.ct.secret_slice]
  simp
  split
  · simp only [bind_ok]
  · rename_i hne
    exact absurd (by apply UScalar.eq_of_val_eq; simpa [List.slice] using hk) hne

theorem aes_key_new_spec (h : RunsAesHw) (alg : Algorithm) (key : Slice U8) (hk : key.length = 4 * nk alg) :
    low.x86_64.aes.AesKey.new key ⦃ k => AesIs alg (bvs key.val) k ⦄ := by
  rw [← expand_key_eq key (by cases alg <;> simp [nk] at hk ⊢ <;> omega)]
  have hl : (bvs key.val).length = 4 * nk alg := by simp [bvs, hk]
  cases alg
  · exact WP.spec_mono (expand_key128_spec h key (by simpa [nk] using hk))
      fun k ⟨k128, hk1, hk2⟩ => ⟨hl, _, hk1, rfl, hk2⟩
  · exact WP.spec_mono (expand_key192_spec h key (by simpa [nk] using hk))
      fun k ⟨k192, hk1, hk2⟩ => ⟨hl, _, hk1, rfl, hk2⟩
  · exact WP.spec_mono (expand_key256_spec h key (by simpa [nk] using hk))
      fun k ⟨k256, hk1, hk2⟩ => ⟨hl, _, hk1, rfl, hk2⟩

/-- The KEK holds the key bytes `kek`, which `alg` sizes. -/
def KekIs (alg : Algorithm) (kek : List (BitVec 8)) (self : mid.aes_kw.AesKek) : Prop :=
  self.key_len.val = 4 * nk alg ∧ bvs (self.key.val.take self.key_len.val) = kek

theorem kek_key_spec {alg : Algorithm} {kek : List (BitVec 8)} {self : mid.aes_kw.AesKek}
    (hk : KekIs alg kek self) :
    mid.aes_kw.AesKek.impl.key self ⦃ s => s.length = 4 * nk alg ∧ bvs s.val = kek ⦄ := by
  obtain ⟨hl, hb⟩ := hk
  have hnk : 4 * nk alg ≤ 32 := by cases alg <;> simp [nk]
  unfold mid.aes_kw.AesKek.impl.key
  step*
  refine ⟨by omega, ?_⟩
  rw [s_post, ← hb, Std.Array.val_to_slice]
  simp [List.slice]

theorem kek_new_spec (h : RunsAesHw) (alg : Algorithm) (algorithm : cipher.Algorithm)
    (hlen : algorithm.key_len.val = 4 * nk alg) (key : Slice U8) :
    mid.aes_kw.AesKek.new algorithm key ⦃ r =>
      if key.length = 4 * nk alg then ∃ k, r = .Ok k ∧ KekIs alg (bvs key.val) k
      else r = .Err .WrongLength ⦄ := by
  obtain ⟨⟨e, he⟩, -⟩ := h
  unfold mid.aes_kw.AesKek.new
  rw [he, bind_ok]
  by_cases hk : key.length = 4 * nk alg
  · have hne : ¬ (Slice.len key != algorithm.key_len) = true := by
      simp only [bne_iff_ne, ne_eq, not_not]; scalar_tac
    simp only [hne, ite_eq_left hk, Bool.false_eq_true, ite_false]
    have hnk : 4 * nk alg ≤ 32 := by cases alg <;> simp [nk]
    step*
    simp only [low.ct.secret_slice, bind_ok, WP.spec_ok]
    refine ⟨_, rfl, by simp; omega, ?_⟩
    have ht := rind.spec.take_setSlice! (Std.Array.repeat 32#usize 0#u8).val key.val 0
      (by simp only [Slice.length] at hk; simp; omega)
    simp only [Nat.zero_add, List.take_zero, List.nil_append] at ht
    simp only [s_post2, s1_post, Slice.len_val, ht]
  · have hne : (Slice.len key != algorithm.key_len) = true := by
      simp only [bne_iff_ne, ne_eq]; intro he; apply hk; rw [← hlen, ← he]; simp
    simp only [hne, ite_true, ite_eq_right hk, WP.spec_ok]

/-- The blocks of `r`, as bytes. -/
abbrev chunks (r : Slice (Std.Array U8 8#usize)) : List (List (BitVec 8)) := r.val.map fun x => bvs x.val

theorem wrap_pass_loop_spec {alg : Algorithm} {key : List (BitVec 8)} {aes : mid.aes.Aes} (hk : AesIs alg key aes)
    (n j : Nat) (iter : core.ops.range.Range Usize) (a t : U64) (r : Slice (Std.Array U8 8#usize))
    (hn : r.length = n) (he : iter.end.val = n) (hs : iter.start.val ≤ n)
    (ht : t.val = j * n + iter.start.val) (hb : j * n + n < 2 ^ 64) :
    mid.aes_kw.wrap_pass_loop iter aes a t r ⦃ res =>
      res.2.length = n ∧ (le8 res.1, chunks res.2) =
        (List.range' (j * n + iter.start.val) (n - iter.start.val)).foldl (wStep alg key n) (le8 a, chunks r) ⦄ := by
  unfold mid.aes_kw.wrap_pass_loop
  apply loop.spec_decr_nat (fun x => n - x.1.start.val)
    (fun x => x.1.start.val ≤ n ∧ x.1.end.val = n ∧ x.2.2.2.length = n ∧ x.2.2.1.val = j * n + x.1.start.val ∧
      (List.range' (j * n + x.1.start.val) (n - x.1.start.val)).foldl (wStep alg key n) (le8 x.2.1, chunks x.2.2.2) =
      (List.range' (j * n + iter.start.val) (n - iter.start.val)).foldl (wStep alg key n) (le8 a, chunks r))
  · rintro ⟨it, a, t, r⟩ ⟨hs, he, hn, ht, hf⟩
    simp only at hs he hn ht hf ⊢
    unfold mid.aes_kw.wrap_pass_loop.body
    by_cases hlt : it.start.val < it.end.val
    · step with core.iter.range.IteratorRange.next_Usize_some_spec as ⟨o, it', ho, hst, hen⟩
      subst ho
      simp only [core.num.U64.from_ne_bytes, core.num.U64.to_be]
      step*
      step with enc_bytes hk a2 as ⟨out, hout⟩
      have h8 : (8#usize : Usize).val ≤ out.to_slice.length := by simp
      simp only [lift, bind_ok, core.slice.Slice.first_chunk, core.slice.Slice.last_chunk, h8,
        core.option.Option.unwrap, Result.ofOption]
      simp only [↓reduceDIte, bind_ok]
      step*
      have hi : it.start.val < n := by omega
      have hl : s2.length = n := by simp [s2_post, hn]
      refine ⟨by omega, by rw [hen]; exact he, hl, by omega, ?_, by omega⟩
      rw [← hf]
      obtain ⟨m, hm⟩ : ∃ m, n - it.start.val = m + 1 := ⟨n - it.start.val - 1, by omega⟩
      rw [hm, List.range'_succ, List.foldl_cons, show n - it'.start.val = m by omega,
        show j * n + it.start.val + 1 = j * n + it'.start.val by omega]
      congr 1
      have hmod : (j * n + it.start.val) % n = it.start.val := by
        rw [Nat.add_comm, Nat.add_mul_mod_self_right, Nat.mod_eq_of_lt hi]
      have hri : (chunks r)[it.start.val]! = bvs a1.val := by
        rw [a1_post]; simp [chunks, getElem!_pos, hn, hi]
      simp only [wStep, hmod, hri, ← a2_post, ← hout]
      rw [le8_xor, le8_to_be, le8_from, t1_post, ht]
      congr 1
      · simp [bvs, List.map_take]
      · simp [s2_post, chunks, List.map_set, bvs, List.map_drop]
    · step with core.iter.range.IteratorRange.next_Usize_none_spec as ⟨o, it', ho, hit⟩
      subst ho
      simp only [WP.spec_ok]
      have : it.start.val = n := by omega
      refine ⟨hn, ?_⟩
      rw [← hf, this, Nat.sub_self, List.range'_zero, List.foldl_nil]
  · exact ⟨hs, he, hn, ht, rfl⟩

theorem usize_lt (x : Usize) : x.val < 2 ^ 64 := by
  have := x.hBounds
  rcases System.Platform.numBits_eq with h | h <;> simp only [UScalarTy.numBits, h] at this <;> omega

theorem cast_u64 (x : Usize) : (UScalar.cast .U64 x).val = x.val := by
  rw [UScalar.cast_val_eq]; simp only [UScalarTy.numBits]; exact Nat.mod_eq_of_lt (usize_lt x)

theorem wrap_pass_spec {alg : Algorithm} {key : List (BitVec 8)} {aes : mid.aes.Aes} (hk : AesIs alg key aes)
    (j : Nat) (a t : U64) (r : Slice (Std.Array U8 8#usize))
    (ht : t.val = j * r.length) (hb : j * r.length + r.length < 2 ^ 64) :
    mid.aes_kw.wrap_pass aes a t r ⦃ res =>
      res.2.length = r.length ∧ (le8 res.1, chunks res.2) =
        (List.range' (j * r.length) r.length).foldl (wStep alg key r.length) (le8 a, chunks r) ⦄ := by
  unfold mid.aes_kw.wrap_pass
  apply WP.spec_mono (wrap_pass_loop_spec hk r.length j _ a t r rfl (by simp) (by simp) (by simpa using ht) hb)
  intro res hres
  simpa using hres

theorem wrap_blocks_loop_spec {alg : Algorithm} {key : List (BitVec 8)} {aes : mid.aes.Aes}
    (hk : AesIs alg key aes) (n : Nat) (iter : core.ops.range.Range U64) (r : Slice (Std.Array U8 8#usize))
    (nn a : U64) (hn : r.length = n) (hnn : nn.val = n) (he : iter.end.val = 6) (hs : iter.start.val ≤ 6)
    (hb : 6 * n < 2 ^ 64) :
    mid.aes_kw.wrap_blocks_loop iter aes r nn a ⦃ res =>
      res.1.length = n ∧ (le8 res.2, chunks res.1) =
        (List.range' (iter.start.val * n) ((6 - iter.start.val) * n)).foldl (wStep alg key n) (le8 a, chunks r) ⦄ := by
  unfold mid.aes_kw.wrap_blocks_loop
  apply loop.spec_decr_nat (fun x => 6 - x.1.start.val)
    (fun x => x.1.start.val ≤ 6 ∧ x.1.end.val = 6 ∧ x.2.1.length = n ∧
      (List.range' (x.1.start.val * n) ((6 - x.1.start.val) * n)).foldl (wStep alg key n) (le8 x.2.2, chunks x.2.1) =
      (List.range' (iter.start.val * n) ((6 - iter.start.val) * n)).foldl (wStep alg key n) (le8 a, chunks r))
  · rintro ⟨it, r, a⟩ ⟨hs, he, hn, hf⟩
    simp only at hs he hn hf ⊢
    unfold mid.aes_kw.wrap_blocks_loop.body
    by_cases hlt : it.start.val < it.end.val
    · step with core.iter.range.IteratorRange.next_U64_some_spec as ⟨o, it', ho, hst, hen⟩
      subst ho
      have h6 : (it.start.val + 1) * n ≤ 6 * n := Nat.mul_le_mul_right _ (by omega)
      rw [Nat.add_mul, Nat.one_mul] at h6
      have hmul : it.start.val * nn.val ≤ U64.max := by
        have em : U64.max = 2 ^ 64 - 1 := by rw [U64.max_eq]; norm_num
        rw [hnn, em]; omega
      step as ⟨i, i_post⟩
      step with wrap_pass_spec hk it.start.val a i r (by rw [i_post, hnn, hn]) (by rw [hn]; omega)
        as ⟨ra, rr, hl, hres⟩
      try simp only [WP.spec_ok]
      refine ⟨by omega, by rw [hen]; exact he, by rw [hl, hn], ?_, by omega⟩
      rw [← hf]
      obtain ⟨m, hm⟩ : ∃ m, 6 - it.start.val = m + 1 := ⟨6 - it.start.val - 1, by omega⟩
      rw [hm, Nat.add_mul, Nat.one_mul, Nat.add_comm (m * n), ← List.range'_append_1, List.foldl_append]
      rw [hn] at hres
      rw [← hres, show 6 - it'.start.val = m by omega, hst, Nat.add_mul, Nat.one_mul]
    · step with core.iter.range.IteratorRange.next_U64_none_spec as ⟨o, it', ho, hit⟩
      subst ho
      simp only [WP.spec_ok]
      have : it.start.val = 6 := by omega
      refine ⟨hn, ?_⟩
      rw [← hf, this, Nat.sub_self, Nat.zero_mul, List.range'_zero, List.foldl_nil]
  · exact ⟨hs, he, hn, rfl⟩

/-- `wrap_blocks` is W's `6n` steps over the blocks. -/
theorem wrap_blocks_spec {alg : Algorithm} {key : List (BitVec 8)} {aes : mid.aes.Aes} (hk : AesIs alg key aes)
    (a : Std.Array U8 8#usize) (r : Slice (Std.Array U8 8#usize)) (hb : 6 * r.length < 2 ^ 64) :
    mid.aes_kw.wrap_blocks aes a r ⦃ res =>
      res.2.length = r.length ∧ (bvs res.1.val, chunks res.2) =
        (List.range (6 * r.length)).foldl (wStep alg key r.length) (bvs a.val, chunks r) ⦄ := by
  unfold mid.aes_kw.wrap_blocks
  simp only [core.num.U64.from_ne_bytes, core.num.U64.to_ne_bytes, bind_ok]
  step as ⟨nn, hnn⟩
  step with wrap_blocks_loop_spec hk r.length { start := 0#u64, «end» := 6#u64 } r nn _ rfl
    (by rw [hnn, cast_u64, Slice.len_val]) (by simp) (by simp) hb as ⟨rr, ra, hl, hres⟩
  try simp only [WP.spec_ok]
  refine ⟨hl, ?_⟩
  rw [bvs_to_le, hres, le8_from]
  simp [List.range_eq_range']

theorem unwrap_pass_loop_spec {alg : Algorithm} {key : List (BitVec 8)} {aes : low.x86_64.aes.AesDecKey}
    (hk : AesDecIs alg key aes) (n p : Nat) (iter : core.ops.range.Range Usize) (a t : U64)
    (r : Slice (Std.Array U8 8#usize)) (hn : r.length = n) (he : iter.end.val = n) (hs : iter.start.val ≤ n)
    (ht : t.val = p * n + n - iter.start.val) (hb : p * n + n < 2 ^ 64) :
    mid.aes_kw.unwrap_pass_loop iter aes a t r ⦃ res =>
      res.2.length = n ∧ (le8 res.1, chunks res.2) =
        (List.range' (p * n) (n - iter.start.val)).reverse.foldl (uStep alg key n) (le8 a, chunks r) ⦄ := by
  unfold mid.aes_kw.unwrap_pass_loop
  apply loop.spec_decr_nat (fun x => n - x.1.start.val)
    (fun x => x.1.start.val ≤ n ∧ x.1.end.val = n ∧ x.2.2.2.length = n ∧
      x.2.2.1.val = p * n + n - x.1.start.val ∧
      (List.range' (p * n) (n - x.1.start.val)).reverse.foldl (uStep alg key n) (le8 x.2.1, chunks x.2.2.2) =
      (List.range' (p * n) (n - iter.start.val)).reverse.foldl (uStep alg key n) (le8 a, chunks r))
  · rintro ⟨it, a, t, r⟩ ⟨hs, he, hn, ht, hf⟩
    simp only at hs he hn ht hf ⊢
    unfold mid.aes_kw.unwrap_pass_loop.body
    by_cases hlt : it.start.val < it.end.val
    · step with core.iter.range.IteratorRange.next_Usize_some_spec as ⟨o, it', ho, hst, hen⟩
      subst ho
      simp only [core.num.U64.from_ne_bytes, core.num.U64.to_be, bind_ok, lift]
      have hi : it.start.val < n := by omega
      step as ⟨i1, hi1⟩
      step as ⟨i2, hi2⟩
      step as ⟨a1, ha1⟩
      step as ⟨b, hbk⟩
      have ht1' : (1#u64 : U64).val ≤ t.val := by simp; omega
      step as ⟨t1, ht1⟩
      step with dec_bytes hk b as ⟨b1, hb1⟩
      have h8 : (8#usize : Usize).val ≤ b1.to_slice.length := by simp
      simp only [lift, bind_ok, core.slice.Slice.first_chunk, core.slice.Slice.last_chunk, h8,
        core.option.Option.unwrap, Result.ofOption]
      simp only [↓reduceDIte, bind_ok]
      step*
      have hi2' : i2.val = n - 1 - it.start.val := by simp only [Slice.len_val] at hi1; omega
      have hl : s2.length = n := by simp [s2_post, hn]
      refine ⟨by omega, by rw [hen]; exact he, hl, by omega, ?_, by omega⟩
      rw [← hf]
      obtain ⟨m, hm⟩ : ∃ m, n - it.start.val = m + 1 := ⟨n - it.start.val - 1, by omega⟩
      rw [hm, List.range'_concat, List.reverse_append, List.reverse_singleton, List.singleton_append,
        List.foldl_cons, show n - it'.start.val = m by omega]
      congr 1
      have hkk : p * n + 1 * m = p * n + i2.val := by omega
      have hmod : (p * n + i2.val) % n = i2.val := by
        rw [Nat.add_comm, Nat.add_mul_mod_self_right, Nat.mod_eq_of_lt (by omega)]
      have hri : (chunks r)[i2.val]! = bvs a1.val := by
        have hi2n : i2.val < n := by omega
        rw [ha1]; simp [chunks, getElem!_pos, hn, hi2n]
      rw [le8_xor, le8_to_be] at hbk
      simp only [uStep, hkk, hmod, hri]
      rw [show p * n + i2.val + 1 = t.val by omega, ← hbk, ← hb1, le8_from]
      congr 1
      · simp [bvs, List.map_take]
      · simp [s2_post, chunks, List.map_set, bvs, List.map_drop]
    · step with core.iter.range.IteratorRange.next_Usize_none_spec as ⟨o, it', ho, hit⟩
      subst ho
      simp only [WP.spec_ok]
      have : it.start.val = n := by omega
      refine ⟨hn, ?_⟩
      rw [← hf, this, Nat.sub_self, List.range'_zero, List.reverse_nil, List.foldl_nil]
  · exact ⟨hs, he, hn, ht, rfl⟩

theorem unwrap_pass_spec {alg : Algorithm} {key : List (BitVec 8)} {aes : low.x86_64.aes.AesDecKey}
    (hk : AesDecIs alg key aes) (p : Nat) (a t : U64) (r : Slice (Std.Array U8 8#usize))
    (ht : t.val = p * r.length + r.length) (hb : p * r.length + r.length < 2 ^ 64) :
    mid.aes_kw.unwrap_pass aes a t r ⦃ res =>
      res.2.length = r.length ∧ (le8 res.1, chunks res.2) =
        (List.range' (p * r.length) r.length).reverse.foldl (uStep alg key r.length) (le8 a, chunks r) ⦄ := by
  unfold mid.aes_kw.unwrap_pass
  apply WP.spec_mono (unwrap_pass_loop_spec hk r.length p _ a t r rfl (by simp) (by simp)
    (by simpa using ht) hb)
  intro res hres
  simpa using hres

theorem unwrap_blocks_loop_spec {alg : Algorithm} {key : List (BitVec 8)} {aes : low.x86_64.aes.AesDecKey}
    (hk : AesDecIs alg key aes) (n : Nat) (iter : core.ops.range.Range U64) (r : Slice (Std.Array U8 8#usize))
    (nn a : U64) (hn : r.length = n) (hnn : nn.val = n) (he : iter.end.val = 6) (hs : iter.start.val ≤ 6)
    (hb : 6 * n < 2 ^ 64) :
    mid.aes_kw.unwrap_blocks_loop iter aes r nn a ⦃ res =>
      res.1.length = n ∧ (le8 res.2, chunks res.1) =
        (List.range' 0 ((6 - iter.start.val) * n)).reverse.foldl (uStep alg key n) (le8 a, chunks r) ⦄ := by
  unfold mid.aes_kw.unwrap_blocks_loop
  apply loop.spec_decr_nat (fun x => 6 - x.1.start.val)
    (fun x => x.1.start.val ≤ 6 ∧ x.1.end.val = 6 ∧ x.2.1.length = n ∧
      (List.range' 0 ((6 - x.1.start.val) * n)).reverse.foldl (uStep alg key n) (le8 x.2.2, chunks x.2.1) =
      (List.range' 0 ((6 - iter.start.val) * n)).reverse.foldl (uStep alg key n) (le8 a, chunks r))
  · rintro ⟨it, r, a⟩ ⟨hs, he, hn, hf⟩
    simp only at hs he hn hf ⊢
    unfold mid.aes_kw.unwrap_blocks_loop.body
    by_cases hlt : it.start.val < it.end.val
    · step with core.iter.range.IteratorRange.next_U64_some_spec as ⟨o, it', ho, hst, hen⟩
      subst ho
      step as ⟨i, i_post⟩
      have hmul : i.val * nn.val ≤ U64.max := by
        have em : U64.max = 2 ^ 64 - 1 := by rw [U64.max_eq]; norm_num
        have : (6 - it.start.val) * n ≤ 6 * n := Nat.mul_le_mul_right _ (by omega)
        rw [hnn, em, i_post]; omega
      step as ⟨i1, i1_post⟩
      have h65 : (6 - it.start.val) * n = (5 - it.start.val) * n + n := by
        rw [show 6 - it.start.val = (5 - it.start.val) + 1 by omega, Nat.add_mul, Nat.one_mul]
      have h5 : (5 - it.start.val) * n ≤ 5 * n := Nat.mul_le_mul_right _ (by omega)
      step with unwrap_pass_spec hk (5 - it.start.val) a i1 r
        (by rw [i1_post, i_post, hnn, hn, ← h65]) (by rw [hn]; omega) as ⟨ra, rr, hl, hres⟩
      try simp only [WP.spec_ok]
      refine ⟨by omega, by rw [hen]; exact he, by rw [hl, hn], ?_, by omega⟩
      rw [← hf]
      obtain ⟨m, hm⟩ : ∃ m, 6 - it.start.val = m + 1 := ⟨6 - it.start.val - 1, by omega⟩
      rw [hm, Nat.add_mul, Nat.one_mul, ← List.range'_append_1, List.reverse_append, List.foldl_append,
        Nat.zero_add]
      rw [hn] at hres
      rw [show 5 - it.start.val = m by omega] at hres
      rw [← hres, show 6 - it'.start.val = m by omega]
    · step with core.iter.range.IteratorRange.next_U64_none_spec as ⟨o, it', ho, hit⟩
      subst ho
      simp only [WP.spec_ok]
      have : it.start.val = 6 := by omega
      refine ⟨hn, ?_⟩
      rw [← hf, this, Nat.sub_self, Nat.zero_mul, List.range'_zero, List.reverse_nil, List.foldl_nil]
  · exact ⟨hs, he, hn, rfl⟩

/-- `unwrap_blocks` is W⁻¹'s `6n` steps over the blocks, from the last. -/
theorem unwrap_blocks_spec {alg : Algorithm} {key : List (BitVec 8)} {aes : low.x86_64.aes.AesDecKey}
    (hk : AesDecIs alg key aes) (a : Std.Array U8 8#usize) (r : Slice (Std.Array U8 8#usize))
    (hb : 6 * r.length < 2 ^ 64) :
    mid.aes_kw.unwrap_blocks aes a r ⦃ res =>
      res.2.length = r.length ∧ (bvs res.1.val, chunks res.2) =
        (List.range (6 * r.length)).reverse.foldl (uStep alg key r.length) (bvs a.val, chunks r) ⦄ := by
  unfold mid.aes_kw.unwrap_blocks
  simp only [core.num.U64.from_ne_bytes, core.num.U64.to_ne_bytes, bind_ok]
  step as ⟨nn, hnn⟩
  step with unwrap_blocks_loop_spec hk r.length { start := 0#u64, «end» := 6#u64 } r nn _ rfl
    (by rw [hnn, cast_u64, Slice.len_val]) (by simp) (by simp) hb as ⟨rr, ra, hl, hres⟩
  try simp only [WP.spec_ok]
  refine ⟨hl, ?_⟩
  rw [bvs_to_le, hres, le8_from]
  simp [List.range_eq_range']

/-! ## The API -/

theorem bvs_IV : bvs mid.aes_kw.IV.val = icv1 := by
  simp [mid.aes_kw.IV, bvs, icv1]

theorem bvs_AIV : bvs mid.aes_kw.AIV.val = icv2 := by
  simp [mid.aes_kw.AIV, bvs, icv2, Std.Array.make]

theorem bvs_inj {l l' : List U8} : bvs l = bvs l' ↔ l = l' := by
  constructor
  · intro h
    exact List.map_injective_iff.mpr (fun x y hxy => by cases x; cases y; simp_all) h
  · rintro rfl; rfl

/-- `as_chunks_mut` of a whole number of 8-byte blocks views them as SP 800-38F's
semiblocks, and writes blocks of the same count back as their bytes in order. -/
theorem as_chunks_mut_8 (s : Slice U8) (h8 : s.length % 8 = 0) :
    core.slice.Slice.as_chunks_mut 8#usize s ⦃ res =>
      res.1.1.length = s.length / 8 ∧ chunks res.1.1 = semiblocks (bvs s.val) ∧
      ∀ c : Slice (Std.Array U8 8#usize), c.length = s.length / 8 →
        bvs (res.2 (c, res.1.2)).val = (chunks c).flatten ∧ (res.2 (c, res.1.2)).length = s.length ⦄ := by
  have hv : (8#usize : Usize).val = 8 := rfl
  simp only [core.slice.Slice.as_chunks_mut, core.slice.Slice.as_chunks, hv, OfNat.ofNat_ne_zero, ite_false,
    bind_ok, WP.spec_ok]
  refine ⟨by simp, ?_, ?_⟩
  · apply List.ext_getElem (by simp [chunks, semiblocks, bvs])
    intro i h1 h2
    simp [chunks, semiblocks, bvs, List.map_take, List.map_drop, Nat.mul_comm]
  · intro c hc
    have hrest : s.val.drop (s.length / 8 * 8) = [] := by
      simp only [List.drop_eq_nil_iff]; simp only [Slice.length] at h8 ⊢; omega
    have hflat : ∀ l : List (Std.Array U8 8#usize), (l.flatMap (·.val)).length = 8 * l.length := by
      intro l; induction l with
      | nil => simp
      | cons x l ih => simp [List.flatMap_cons, ih]; ring
    have hlen : (c.val.flatMap (·.val)).length = s.length := by
      rw [hflat]; simp only [Slice.length] at hc h8 ⊢; omega
    have hbf : ∀ l : List (Std.Array U8 8#usize), bvs (l.flatMap (·.val)) = (l.map fun x => bvs x.val).flatten := by
      intro l; induction l with
      | nil => simp
      | cons x l ih => rw [List.flatMap_cons, List.map_cons, List.flatten_cons, ← ih]; simp [bvs]
    split
    · rename_i hle
      simp [hrest, hbf, chunks, Slice.length, hlen]
    · rename_i hle
      exfalso; apply hle; simp [hrest, hlen]

/-- `wrap` refuses what the Rust refuses, and otherwise writes KW-AE of the key. -/
theorem kek_wrap_spec (h : RunsAesHw) {alg : Algorithm} {kek : List (BitVec 8)} {self : mid.aes_kw.AesKek}
    (hk : KekIs alg kek self) (key wrapped : Slice U8) (hroom : key.length + 8 ≤ Usize.max) :
    mid.aes_kw.AesKek.wrap self key wrapped ⦃ res =>
      if 16 ≤ key.length ∧ key.length % 8 = 0 ∧ wrapped.length = key.length + 8 then
        res.1 = .Ok () ∧ bvs res.2.val = kwAE alg kek (bvs key.val)
      else res = (.Err .WrongLength, wrapped) ⦄ := by
  obtain ⟨e, he⟩ := h.1
  unfold mid.aes_kw.AesKek.wrap
  rw [he, bind_ok]
  by_cases h16 : key.length < 16
  · have hlt : Slice.len key < 16#usize := by scalar_tac
    have hn : ¬ (16 ≤ key.length ∧ key.length % 8 = 0 ∧ wrapped.length = key.length + 8) := by omega
    simp only [hlt, ite_true, hn, ite_false, WP.spec_ok]
  have hlt : ¬ Slice.len key < 16#usize := by scalar_tac
  simp only [hlt, ite_false]
  step as ⟨b, hb⟩
  cases b
  · have h8 : ¬ key.length % 8 = 0 := by simpa using hb
    have hn : ¬ (16 ≤ key.length ∧ key.length % 8 = 0 ∧ wrapped.length = key.length + 8) := by omega
    simp only [hn, Bool.false_eq_true, ite_false, WP.spec_ok]
  have h8 : key.length % 8 = 0 := by simpa using hb
  simp only [ite_true]
  step as ⟨i4, hi4⟩
  by_cases hw : wrapped.length = key.length + 8
  swap
  · have hne : (Slice.len wrapped != i4) = true := by
      simp only [bne_iff_ne, ne_eq]; intro he; apply hw; rw [← Slice.len_val, he, hi4, Slice.len_val]
    have hn : ¬ (16 ≤ key.length ∧ key.length % 8 = 0 ∧ wrapped.length = key.length + 8) := by omega
    simp only [hne, hn, ite_true, ite_false, WP.spec_ok]
  have hne : ¬ (Slice.len wrapped != i4) = true := by
    simp only [bne_iff_ne, ne_eq, not_not]; apply UScalar.eq_of_val_eq; rw [hi4, Slice.len_val, Slice.len_val, hw]
  have hy : 16 ≤ key.length ∧ key.length % 8 = 0 ∧ wrapped.length = key.length + 8 := ⟨by omega, h8, hw⟩
  simp only [hne, Bool.false_eq_true, ite_false, hy, and_self, ite_true]
  step as ⟨ar, back, ha1, hr1, ha2, hr2, hback⟩
  step as ⟨r1, hr1'⟩
  subst r1
  simp only [low.ct.secret_slice, bind_ok]
  step with kek_key_spec hk as ⟨s, hsl, hsb⟩
  step with aes_key_new_spec h alg s hsl as ⟨ak, hak⟩
  rw [hsb] at hak
  simp only [core.mem.manually_drop.ManuallyDrop.new, core.mem.manually_drop.ManuallyDrop.Insts.CoreOpsDerefDeref.deref,
    bind_ok]
  step with as_chunks_mut_8 key h8 as ⟨ch, rest, cback, hcl, hch, hcback⟩
  step with wrap_blocks_spec hak mid.aes_kw.IV ch
    (by have := usize_lt key.len; rw [Slice.len_val] at this; rw [hcl]; omega)
    as ⟨wb, hwl, hwb⟩
  done

end rind.x86_64
