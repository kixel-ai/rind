import Rind.X86_64.ValeAesGcm
import Rind.ValeBytes
open Aeneas Aeneas.Std Result rind.vale

namespace rind.x86_64

theorem setSlice!_zero {α : Type} (l l' : List α) (h : l'.length ≤ l.length) :
    l.setSlice! 0 l' = l' ++ l.drop l'.length := by
  simp [List.setSlice!, Nat.min_eq_left h]

/-- Whole blocks then the partial block, zero-padded into 16 bytes, cut to
the length, are the bytes they came from. -/
theorem take_blocks_partial (l p : List U8) (n : Nat) (hp : p.length = 16) (hn : l.length - n ≤ 16)
    (_ : n ≤ l.length) :
    (bvs (l.take n) ++ bvs (p.setSlice! 0 (l.drop n))).take l.length = bvs l := by
  rw [setSlice!_zero _ _ (by simp; omega)]
  simp only [bvs, ← List.map_append, ← List.map_take]
  congr 1
  rw [← List.append_assoc, List.take_append_drop, List.take_append_of_le_length (by simp)]
  simp

theorem take_out (b p : List U8) (n : Nat) (hn : b.length ≤ n) :
    bvs (b ++ p.take (n - b.length)) = (bvs b ++ bvs p).take n := by
  simp only [bvs, ← List.map_append, ← List.map_take, List.take_append, List.take_of_length_le hn]

theorem take12_nonce (nonce : List U8) (h : nonce.length = 12) :
    (bvs ((List.replicate 16 0#u8).setSlice! 0 nonce)).take 12 = bvs nonce := by
  rw [setSlice!_zero _ _ (by simp [h])]
  simp only [bvs, ← List.map_take, List.take_append_of_le_length (show 12 ≤ nonce.length by omega),
    List.take_of_length_le (show nonce.length ≤ 12 by omega)]

theorem messageBytes_of (b : low.x86_64.aes_gcm_avx.Buffers) (l p : List U8) (n : Nat)
    (h1 : b.blocks.val = l.take n) (h2 : b.partial.val = p.setSlice! 0 (l.drop n)) (hp : p.length = 16)
    (hn : l.length - n ≤ 16) (hn' : n ≤ l.length) : messageBytes b l.length = bvs l := by
  rw [messageBytes, h1, h2]; exact take_blocks_partial l p n hp hn hn'

theorem authBytes_of (b : low.x86_64.aes_gcm_avx.Buffers) (q : List U8)
    (h2 : b.aad_partial.val = q.setSlice! 0 (b.aad.val.drop b.aad_whole.val)) (hq : q.length = 16)
    (hw : b.aad_whole.val = b.aad.length / 16 * 16) : authBytes b = bvs b.aad.val := by
  have := Nat.div_mul_le_self b.aad.length 16
  have := Nat.lt_div_mul_add (a := b.aad.length) (b := 16) (by decide)
  rw [authBytes, h2]
  exact take_blocks_partial _ q _ hq (by simp only [Slice.length] at *; omega)
    (by simp only [Slice.length] at *; omega)

/-- The kernel's key and GHASH key powers are Vale's for the AES key `kw`. -/
def KernelKeys (alg : Algorithm) (key : low.x86_64.aes.HwKey) (kw : List (BitVec 32))
    (kernel : low.x86_64.aes_gcm_avx.AvxKernel) : Prop :=
  kw.length = nk alg ∧
  (match key with
    | .Aes128 k => alg = .AES_128 ∧ k.round_keys.val = keyToRoundKeys .AES_128 kw
    | .Aes256 k => alg = .AES_256 ∧ k.round_keys.val = keyToRoundKeys .AES_256 kw) ∧
  hkeysReqsPub kernel.hkeys.val (reverseBytesQuad32 (aesEncrypt alg kw (mkfour 0 0 0 0)))

-- The ciphertext and tag in place, or the plaintext in place and the tag's
-- check, are AES-GCM's.
set_option hygiene false in
macro "cipher_finish" : tactic => `(tactic| (
  dsimp only at result_post2 result_post3
  first
  | exact ⟨hblen, Prod.ext (hout.trans result_post2) result_post3⟩
  | exact ⟨hblen, hout.trans result_post2, result_post3⟩))

theorem ite_ok {α : Type} (c : Prop) [Decidable c] (a b : α) :
    (if c then ok a else ok b : Result α) = ok (if c then a else b) := by
  split <;> rfl

-- `AvxKernel::cipher` around Vale's routine `ax`, whose six-block loop needs at
-- least `m` blocks: its buffers meet the routine's preconditions, its counter
-- block is `compute_iv`'s for the nonce, and its output is copied back in
-- place. `step*` names the hypotheses after the translation's `let`s.
set_option hygiene false in
macro "cipher_glue " ax:term:max " with " m:num : tactic => `(tactic| (
  unfold low.x86_64.aes_gcm_avx.AvxKernel.cipher
  step*
  · have : s3.length = 176 := by
      rw [Slice.length, s3_post, Std.Array.repeat_val, List.length_replicate]; rfl
    rw [aad_partial_post1, this]; decide
  · have := blocks_post1; simp only [Slice.length] at *; scalar_tac
  · have hiv : 1 ≤ (bvs nonce.val).length ∧ 8 * (bvs nonce.val).length < 2 ^ 64 := by simp [bvs]
    split
    all_goals first
      | (exfalso; assumption)
      | (exfalso; exact ‹¬True› trivial)
      | (exact absurd ‹false = true› (by decide))
      | skip
    step*
    try (rw [bind_ok]; split; rename_i heq; simp only [Prod.mk.injEq] at heq; obtain ⟨rfl, rfl, rfl⟩ := heq)
    rw [ite_ok, bind_ok]
    have hs3 : s3.length = 176 := by
      rw [Slice.length, s3_post, Std.Array.repeat_val, List.length_replicate]; rfl
    have f1 : aad_whole.val = aad.length / 16 * 16 := by rw [aad_whole_post, i3_post, Slice.len_val]
    have f2 : (index_mut_back1 s6).length = 16 := by
      simp only [Slice.length, s4_post2, List.length_setSlice!]; exact aad_partial_post
    have f3 : blocks.length = inout.length / 16 * 16 := by rw [blocks_post, i7_post, i6_post, Slice.len_val]
    have f4 : (index_mut_back2 s8).length = 16 := by
      simp only [Slice.length, s7_post2, List.length_setSlice!]; exact partial_post
    have f5 : scratch1.length = 144 := by rw [partial_post1, aad_partial_post1, hs3]
    have f6 : n.val = blocks.length / 96 * 6 := by rw [n_post, i10_post, Slice.len_val]
    have f7 : inout.len.val = inout.length := Slice.len_val _
    have d1 := Nat.div_mul_le_self inout.length 16
    have d2 := Nat.lt_div_mul_add (a := inout.length) (b := 16) (by decide)
    have d3 := Nat.div_mul_le_self blocks.length 96
    have hsix : ∀ six : Usize, (six = if n ≥ $m#usize then n else 0#usize) →
        six.val % 6 = 0 ∧ 16 * six.val ≤ blocks.length ∧ (0 < six.val → $m ≤ six.val) := by
      intro six h; subst h; split
      · refine ⟨by omega, by omega, fun _ => by scalar_tac⟩
      · simp
    obtain ⟨g1, g2, g3⟩ := hsix _ rfl
    step with $ax k kw hkw hrk kernel.hkeys hh (bvs nonce.val) hiv
    · refine ⟨haad, f1, f2, ?_, ⟨g1, g2, g3⟩, f4, ⟨?_, ?_⟩, ?_, f5⟩ <;> dsimp only <;> omega
    · show leBytesToQuad32 (bvs iv2.val) = _
      rw [iv2_post, h2, reverseBytesQuad32_involutive, s_post2, s2_post, s1_post, Std.Array.repeat_val,
        Std.Array.val_to_slice]
      exact congrArg _ (take12_nonce nonce.val (by simp))
    · step*
      · have := blocks_post1; simp only [Slice.length] at *; scalar_tac
      · have hm := messageBytes_of
          ⟨aad, aad_whole, iv2, index_mut_back1 s6, blocks, (if n ≥ $m#usize then n else 0#usize),
            index_mut_back2 s8, inout.len, scratch1, tag⟩
          inout.val «partial».val i7.val blocks_post2 (by rw [s7_post2, s8_post, blocks_post3]) partial_post
          (by simp only [Slice.length] at *; omega) (by simp only [Slice.length] at *; omega)
        have ha := authBytes_of
          ⟨aad, aad_whole, iv2, index_mut_back1 s6, blocks, (if n ≥ $m#usize then n else 0#usize),
            index_mut_back2 s8, inout.len, scratch1, tag⟩
          aad_partial.val (by rw [s4_post2, s6_post, s5_post]) aad_partial_post
          (by rw [aad_whole_post, i3_post, Slice.len_val])
        rw [f7] at result_post2 result_post3
        rw [hm, ha] at result_post2 result_post3
        obtain ⟨hback, hblen⟩ := blocks_post4 _ tail1 (result_post.trans blocks_post)
          (by rw [tail1_post, s9_post1, Slice.len_val]; exact blocks_post1)
        have hx := result_post.trans blocks_post
        have hout : bvs (split_at_mut_back (b2.blocks, tail1)).val = messageBytes b2 inout.length := by
          rw [hback, tail1_post, s9_post, List.slice, List.drop_zero, Nat.sub_zero, messageBytes,
            Slice.len_val, blocks_post1, ← hx]
          exact take_out _ _ _ (by simp only [Slice.length] at *; omega)
        cipher_finish))

set_option maxHeartbeats 2000000 in
theorem cipher_encrypt_spec (alg : Algorithm) (key : low.x86_64.aes.HwKey) (kw : List (BitVec 32))
    (kernel : low.x86_64.aes_gcm_avx.AvxKernel) (hk : KernelKeys alg key kw kernel)
    (nonce : Std.Array U8 12#usize) (aad inout : Slice U8) (tag : Std.Array U8 16#usize)
    (haad : aad.length < 2 ^ 32) (hin : inout.length < 2 ^ 32) :
    low.x86_64.aes_gcm_avx.AvxKernel.cipher true kernel key nonce aad inout tag ⦃ r =>
      r.2.1.length = inout.length ∧ (bvs r.2.1.val, bvs r.2.2.val) =
        gcmEncrypt alg (seqNat32ToSeqNat8LE kw) (bvs nonce.val) (bvs inout.val) (bvs aad.val) ⦄ := by
  obtain ⟨hkw, hkey, hh⟩ := hk
  have h2 : kernel.hkeys.val[2]! = reverseBytesQuad32 (aesEncrypt alg kw (mkfour 0 0 0 0)) := hh.2.2.2.1
  have hcb : hkeysReqsPub kernel.hkeys.val (reverseBytesQuad32 (reverseBytesQuad32 kernel.hkeys.val[2]!)) := by
    rw [reverseBytesQuad32_involutive]; exact h2 ▸ hh
  cases key with
  | Aes128 k =>
    obtain ⟨rfl, hrk⟩ := hkey
    cipher_glue gcm128_encrypt_opt_spec with 18
  | Aes256 k =>
    obtain ⟨rfl, hrk⟩ := hkey
    cipher_glue gcm256_encrypt_opt_spec with 18

set_option maxHeartbeats 2000000 in
theorem cipher_decrypt_spec (alg : Algorithm) (key : low.x86_64.aes.HwKey) (kw : List (BitVec 32))
    (kernel : low.x86_64.aes_gcm_avx.AvxKernel) (hk : KernelKeys alg key kw kernel)
    (nonce : Std.Array U8 12#usize) (aad inout : Slice U8) (tag : Std.Array U8 16#usize)
    (haad : aad.length < 2 ^ 32) (hin : inout.length < 2 ^ 32) :
    low.x86_64.aes_gcm_avx.AvxKernel.cipher false kernel key nonce aad inout tag ⦃ r =>
      let out := gcmDecrypt alg (seqNat32ToSeqNat8LE kw) (bvs nonce.val) (bvs inout.val) (bvs aad.val)
        (bvs tag.val)
      r.2.1.length = inout.length ∧ bvs r.2.1.val = out.1 ∧ (r.1.val = 0 ↔ out.2 = true) ⦄ := by
  obtain ⟨hkw, hkey, hh⟩ := hk
  have h2 : kernel.hkeys.val[2]! = reverseBytesQuad32 (aesEncrypt alg kw (mkfour 0 0 0 0)) := hh.2.2.2.1
  have hcb : hkeysReqsPub kernel.hkeys.val (reverseBytesQuad32 (reverseBytesQuad32 kernel.hkeys.val[2]!)) := by
    rw [reverseBytesQuad32_involutive]; exact h2 ▸ hh
  cases key with
  | Aes128 k =>
    obtain ⟨rfl, hrk⟩ := hkey
    cipher_glue gcm128_decrypt_opt_spec with 6
  | Aes256 k =>
    obtain ⟨rfl, hrk⟩ := hkey
    cipher_glue gcm256_decrypt_opt_spec with 6

end rind.x86_64
