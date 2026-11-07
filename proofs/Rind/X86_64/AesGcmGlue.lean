import Rind.X86_64.ValeAesGcm
import Rind.X86_64.PartialBlock
import Rind.ValeBytes
open Aeneas Aeneas.Std Result rind.vale

namespace rind.x86_64

theorem setSlice!_zero {α : Type} (l l' : List α) (h : l'.length ≤ l.length) :
    l.setSlice! 0 l' = l' ++ l.drop l'.length := by
  simp [List.setSlice!, Nat.min_eq_left h]

theorem take12_nonce (nonce : List U8) (h : nonce.length = 12) :
    (bvs ((List.replicate 16 0#u8).setSlice! 0 nonce)).take 12 = bvs nonce := by
  rw [setSlice!_zero _ _ (by simp [h])]
  simp only [bvs, ← List.map_take, List.take_append_of_le_length (show 12 ≤ nonce.length by omega),
    List.take_of_length_le (show nonce.length ≤ 12 by omega)]

/-- Whole blocks then a partial block zero-padded to 16 bytes, cut to the
length, are the bytes they came from. -/
theorem take_blocks_partial (l : List U8) (n : Nat) (hn : n ≤ l.length) :
    (bvs (l.take n) ++ (bvs (l.drop n) ++ List.replicate (16 - (l.length - n)) 0#8)).take l.length =
      bvs l := by
  rw [← List.append_assoc]
  simp only [bvs, ← List.map_append, List.take_append_drop]
  exact List.take_append_of_le_length (by simp) |>.trans (List.take_of_length_le (by simp))

theorem messageBytes_of (b : low.x86_64.aes_gcm_avx.Buffers) (l : List U8) (n : Nat)
    (h1 : b.blocks.val = l.take n)
    (h2 : leQuad32ToBytes b.partial = bvs (l.drop n) ++ List.replicate (16 - (l.length - n)) 0#8)
    (hn : n ≤ l.length) : messageBytes b l.length = bvs l := by
  rw [messageBytes, h1, h2]; exact take_blocks_partial l n hn

theorem authBytes_of (b : low.x86_64.aes_gcm_avx.Buffers) (hw : b.aad_whole.val = b.aad.length / 16 * 16)
    (h2 : leQuad32ToBytes b.aad_partial =
      bvs (b.aad.val.drop b.aad_whole.val) ++ List.replicate (16 - (b.aad.length - b.aad_whole.val)) 0#8) :
    authBytes b = bvs b.aad.val := by
  rw [authBytes, h2]
  exact take_blocks_partial _ _ (by simp only [Slice.length] at hw ⊢; omega)

/-- The routine's whole blocks, then the first bytes of its partial block, are
the message it wrote, cut to its length. -/
theorem take_out (b p : List U8) (q : List (BitVec 8)) (n : Nat) (hn : b.length ≤ n)
    (hp : bvs p = q.take (n - b.length)) :
    bvs (b ++ p) = (bvs b ++ q).take n := by
  simp only [bvs, List.map_append] at hp ⊢
  rw [hp, List.take_append, List.take_of_length_le (show (b.map (·.bv)).length ≤ n by simp; omega),
    List.length_map]

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
  dsimp only at result_post1 result_post2
  first
  | exact ⟨hblen, Prod.ext (hout.trans result_post1) result_post2⟩
  | exact ⟨hblen, hout.trans result_post1, result_post2⟩))

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
  · rw [s3_post1, aad_whole_post, i3_post, Slice.len_val]
    have := Nat.lt_div_mul_add (a := aad.length) (b := 16) (by decide)
    omega
  · rw [blocks_post1, i5_post, i4_post, Slice.len_val]
    have := Nat.lt_div_mul_add (a := inout.length) (b := 16) (by decide)
    omega
  · simp only [ite_true, ite_false, Bool.false_eq_true, bind_ok, ↓reduceIte]
    rw [ite_ok, bind_ok]
    step as ⟨s4, _, hs4, _⟩
    have f1 : aad_whole.val = aad.length / 16 * 16 := by rw [aad_whole_post, i3_post, Slice.len_val]
    have f3 : blocks.length = inout.length / 16 * 16 := by rw [blocks_post, i5_post, i4_post, Slice.len_val]
    have f5 : s4.length = 144 := by rw [Slice.length, hs4]; simp
    have f6 : n.val = blocks.length / 96 * 6 := by rw [n_post, i7_post, Slice.len_val]
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
    have hiv : 1 ≤ (bvs nonce.val).length ∧ 8 * (bvs nonce.val).length < 2 ^ 64 := by simp [bvs]
    step with $ax k kw hkw hrk kernel.hkeys hh (bvs nonce.val) hiv
    · refine ⟨haad, f1, ?_, ⟨g1, g2, g3⟩, ⟨?_, ?_⟩, ?_, f5⟩ <;> dsimp only <;> omega
    · show leBytesToQuad32 (bvs iv2.val) = _
      rw [iv2_post, h2, reverseBytesQuad32_involutive, s_post2, s2_post, s1_post, Std.Array.repeat_val,
        Std.Array.val_to_slice]
      exact congrArg _ (take12_nonce nonce.val (by simp))
    · step*
      · rw [blocks_post1, i5_post, i4_post, Slice.len_val]; omega
      · have hm := messageBytes_of
          ⟨aad, aad_whole, iv2, aad_partial, blocks, (if n ≥ $m#usize then n else 0#usize), «partial»,
            inout.len, s4, tag⟩
          inout.val i5.val blocks_post2 (by rw [partial_post, blocks_post3, blocks_post1])
          (by simp only [Slice.length] at *; omega)
        have ha := authBytes_of
          ⟨aad, aad_whole, iv2, aad_partial, blocks, (if n ≥ $m#usize then n else 0#usize), «partial»,
            inout.len, s4, tag⟩
          f1 (by rw [aad_partial_post, s3_post, s3_post1])
        rw [f7] at result_post1 result_post2
        rw [hm, ha] at result_post1 result_post2
        obtain ⟨hback, hblen⟩ := blocks_post4 _ tail1 (result_post.trans blocks_post)
          (by rw [tail1_post, blocks_post1])
        have hout : bvs (split_at_mut_back (b2.blocks, tail1)).val = messageBytes b2 inout.length := by
          have hb2 : b2.blocks.val.length = i5.val := result_post.trans blocks_post
          rw [hback, messageBytes]
          refine take_out _ _ _ _ (by simp only [Slice.length] at *; omega) ?_
          rw [tail1_post1, blocks_post1, hb2]
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
