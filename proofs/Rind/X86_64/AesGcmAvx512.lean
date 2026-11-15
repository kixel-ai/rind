import Rind.X86_64.AesGcmClmul
import Rind.X86_64.GhashAvx512
open Aeneas Aeneas.Std Result rind.vale rind.simd

/-!
# rind's AVX-512 AES-GCM, `_cipher_avx512`

`Rind.X86_64.AesGcmModel`'s `_cipher_avx512`, the by-16 AES-CTR and GHASH
for messages of 256 bytes on, is Vale's GCTR and GHASH as `by8` is: each lane
of its 512-bit counters, keys, and blocks runs `by8`'s 128-bit steps, and its
last chunk of up to 255 bytes runs masked 64-byte loads and `_mul_tail`.
-/

local notation "P" => Polynomial (ZMod 2)

set_option maxRecDepth 20000
set_option exponentiation.threshold 1024

namespace rind.x86_64

/-! ## The counters -/

/-- `Counter512`'s counters for the blocks `i` to `i + 3` from `icb`, each as
`Counter` keeps it. -/
def counter512 (icb : Quad32) (i : Nat) : BitVec 512 := ofLanes128 fun b => swap (inc32 icb (i + b))

/-- `PSHUFB` reads each selector byte's top bit and low four bits alone. -/
theorem pshufb_congr (a b b' : BitVec 128)
    (h : ∀ i < 16, (byte b i).msb = (byte b' i).msb ∧ (byte b i).toNat % 16 = (byte b' i).toNat % 16) :
    pshufb a b = pshufb a b' := by
  unfold pshufb ofBytes
  congr 1
  apply List.map_congr_left; intro i hi
  obtain ⟨h1, h2⟩ := h i (List.mem_range.1 hi)
  rw [h1, h2]

theorem lanes_byteswap_epi64 : ∀ j < 4, ∀ i < 16,
    (byte (lane128 0x38393a3b3c3d3e3f303132333435363728292a2b2c2d2e2f202122232425262718191a1b1c1d1e1f101112131415161708090a0b0c0d0e0f0001020304050607#512 j) i).msb =
      (byte 0x08090a0b_0c0d0e0f_00010203_04050607#128 i).msb ∧
    (byte (lane128 0x38393a3b3c3d3e3f303132333435363728292a2b2c2d2e2f202122232425262718191a1b1c1d1e1f101112131415161708090a0b0c0d0e0f0001020304050607#512 j) i).toNat % 16 =
      (byte 0x08090a0b_0c0d0e0f_00010203_04050607#128 i).toNat % 16 := by
  decide

theorem lanes_byteswap : ∀ j < 4, ∀ i < 16,
    (byte (lane128 0x303132333435363738393a3b3c3d3e3f202122232425262728292a2b2c2d2e2f101112131415161718191a1b1c1d1e1f000102030405060708090a0b0c0d0e0f#512 j) i).msb =
      (byte 0x00010203_04050607_08090a0b_0c0d0e0f#128 i).msb ∧
    (byte (lane128 0x303132333435363738393a3b3c3d3e3f202122232425262728292a2b2c2d2e2f101112131415161718191a1b1c1d1e1f000102030405060708090a0b0c0d0e0f#512 j) i).toNat % 16 =
      (byte 0x00010203_04050607_08090a0b_0c0d0e0f#128 i).toNat % 16 := by
  decide

theorem counter_512_4 : (0x00000000000000040000000000000000000000000000000400000000000000000000000000000004000000000000000000000000000000040000000000000000#512 : BitVec 512) =
    ofLanes128 fun _ => 0x4_00000000_00000000#128 := by
  decide

/-- `PADDD` of four in the counter word steps the swapped counter as `inc32`. -/
theorem add_counter4 (q : Quad32) : paddd (swap q) 0x4_00000000_00000000#128 = swap (inc32 q 4) := by
  unfold paddd
  conv_rhs => rw [← ofLanes32_lane32 (swap (inc32 q 4))]
  apply ofLanes32_ext
  intro i hi
  have c0 : lane32 0x4_00000000_00000000#128 0 = 0#32 := by decide
  have c1 : lane32 0x4_00000000_00000000#128 1 = 0#32 := by decide
  have c2 : lane32 0x4_00000000_00000000#128 2 = 4#32 := by decide
  have c3 : lane32 0x4_00000000_00000000#128 3 = 0#32 := by decide
  rw [lane32_swap _ hi, lane32_swap _ hi]
  interval_cases i
  · rw [c0, BitVec.add_zero]; exact (lane32_inc32 q 4 (by omega) (by omega)).symm
  · rw [c1, BitVec.add_zero]; exact (lane32_inc32 q 4 (by omega) (by omega)).symm
  · rw [c2, show (2 + 2) % 4 = 0 by rfl, lane32_inc32_zero]
  · rw [c3, BitVec.add_zero]; exact (lane32_inc32 q 4 (by omega) (by omega)).symm

theorem pshufb_byteswap_epi64 (v : BitVec 128) :
    pshufb v 0x08090a0b_0c0d0e0f_00010203_04050607#128 = reverseBytesQuad32 (swap v) := by
  have h := shuffle_byteswap_epi64 v
  simp only [shuffle_epi8_eq, Result.ok.injEq] at h
  exact h

theorem next4_eq (icb : Quad32) (i : Nat) :
    low.x86_64.aes_gcm.Counter512.next4 (counter512 icb i) =
      ok (ofLanes128 fun b => reverseBytesQuad32 (inc32 icb (i + b)), counter512 icb (i + 4)) := by
  unfold low.x86_64.aes_gcm.Counter512.next4 low.x86_64.aes_gcm.BYTESWAP_512_EPI64
    low.x86_64.aes_gcm.COUNTER_512_4 counter512
  rw [bind_ok, ← ofLanes128_lane128
    0x38393a3b3c3d3e3f303132333435363728292a2b2c2d2e2f202122232425262718191a1b1c1d1e1f101112131415161708090a0b0c0d0e0f0001020304050607#512,
    pshufb512_eq, bind_ok, counter_512_4, bind_ok, add512_eq, bind_ok]
  refine congrArg ok (Prod.ext ?_ ?_) <;> dsimp only
  · apply ofLanes128_ext; intro b hb
    rw [pshufb_congr _ _ _ (lanes_byteswap_epi64 b hb), pshufb_byteswap_epi64, swap_swap]
  · apply ofLanes128_ext; intro b hb
    rw [add_counter4, inc32_inc32, show i + b + 4 = i + 4 + b by omega]

theorem counter512_new (j0 : Quad32) (y0 : Std.Array U8 16#usize)
    (hy : loadBytes y0.val = reverseBytesQuad32 j0) :
    low.x86_64.aes_gcm.Counter512.new y0 = ok (counter512 (inc32 j0 1) 0) := by
  have hq : ∀ q : Quad32, pshufb (reverseBytesQuad32 q) 0x08090a0b_0c0d0e0f_00010203_04050607#128 = swap q :=
    fun q => by rw [pshufb_byteswap_epi64, rev_swap_rev]
  obtain ⟨i0, i1, i2, i3, -⟩ := imm_facts
  rw [low.x86_64.aes_gcm.Counter512.new, counter_new j0 y0 hy, bind_ok]
  simp only [counter_next, bind_ok, uncurry_apply_pair, low.x86_64.aes_gcm.BYTESWAP_EPI64, setzero512_eq,
    shuffle_epi8_eq, hq, insert512_eq, i0, i1, i2, i3]
  refine congrArg ok (ofLanes128_ext _ _ fun b hb => ?_)
  rcases (by omega : b = 0 ∨ b = 1 ∨ b = 2 ∨ b = 3) with rfl | rfl | rfl | rfl <;>
    simp [inc32_inc32, inc32_zero]

/-! ## The rounds -/

/-- `AESENC`'s round, as both widths run it on a lane. -/
def encRound (c k : BitVec 128) : BitVec 128 := mixColumns (subBytes (shiftRows c)) ^^^ k

theorem foldlM_aesenc : ∀ (rks : List (BitVec 128)) (c : BitVec 128),
    rks.foldlM core.core_arch.x86.aes._mm_aesenc_si128 c = ok (rks.foldl encRound c)
  | [], _ => rfl
  | k :: rks, c => by
    simp only [List.foldlM_cons, core.core_arch.x86.aes._mm_aesenc_si128, foldlM_aesenc rks, bind_tc_ok,
      List.foldl_cons, encRound]

theorem foldlM_aesenc512 : ∀ (rks : List (BitVec 128)) (f : Nat → BitVec 128),
    (rks.map fun k => ofLanes128 fun _ => k).foldlM core.core_arch.x86.vaes._mm512_aesenc_epi128 (ofLanes128 f) =
      ok (ofLanes128 fun j => rks.foldl encRound (f j))
  | [], _ => rfl
  | k :: rks, f => by
    simp only [List.map_cons, List.foldlM_cons, aesenc512_eq, bind_tc_ok, foldlM_aesenc512 rks, List.foldl_cons,
      encRound]

theorem mapM_broadcast : ∀ rks : List (BitVec 128),
    rks.mapM core.core_arch.x86.avx512f._mm512_broadcast_i32x4 = ok (rks.map fun k => ofLanes128 fun _ => k)
  | [] => rfl
  | k :: ks => by
    simp only [List.mapM_cons, broadcast512_eq, mapM_broadcast ks, bind_tc_ok, List.map_cons]
    rfl

theorem round_keys_512_eq (hk : low.x86_64.aes.HwKey) :
    low.x86_64.aes.HwKey.round_keys_512 hk = ok (ofLanes128 (fun _ => hk.round_keys.1),
      hk.round_keys.2.1.map (fun k => ofLanes128 fun _ => k), ofLanes128 fun _ => hk.round_keys.2.2) := by
  obtain ⟨⟨f, rks, l⟩, hrk⟩ : ∃ r, hk.round_keys = r := ⟨_, rfl⟩
  simp only [low.x86_64.aes.HwKey.round_keys_512, hrk, broadcast512_eq, mapM_broadcast, bind_ok]
  rfl

/-- Vale's AES, as `HwKey::round_keys`' rounds before the last, then the last. -/
theorem aesEncrypt_rounds (hk : low.x86_64.aes.HwKey) (alg : Algorithm) (kw : List (BitVec 32))
    (h : HwKeyIs alg kw hk) (c : BitVec 128) :
    aesEncrypt alg kw c =
      subBytes (shiftRows (hk.round_keys.2.1.foldl encRound (c ^^^ hk.round_keys.1))) ^^^ hk.round_keys.2.2 := by
  have := encrypt_eq hk alg kw h c
  simp only [low.x86_64.aes_gcm.encrypt, core.core_arch.x86.sse2._mm_xor_si128, bind_ok, foldlM_aesenc,
    core.core_arch.x86.aes._mm_aesenclast_si128, Result.ok.injEq] at this
  exact this.symm

theorem rounds512_eq (f : Nat → BitVec 128) (rf : BitVec 128) (rks : List (BitVec 128)) :
    low.x86_64.aes_gcm.rounds512 (ofLanes128 f) (ofLanes128 fun _ => rf) (rks.map fun k => ofLanes128 fun _ => k) =
      ok (ofLanes128 fun j => rks.foldl encRound (f j ^^^ rf)) := by
  rw [low.x86_64.aes_gcm.rounds512, xor512_eq, bind_ok, foldlM_aesenc512]

/-- `encrypt512` with `HwKey::round_keys_512`' keys is Vale's AES in each lane. -/
theorem encrypt512_eq (hk : low.x86_64.aes.HwKey) (alg : Algorithm) (kw : List (BitVec 32))
    (h : HwKeyIs alg kw hk) (f : Nat → BitVec 128) :
    low.x86_64.aes_gcm.encrypt512 (ofLanes128 f) (ofLanes128 fun _ => hk.round_keys.1)
      (hk.round_keys.2.1.map fun k => ofLanes128 fun _ => k) (ofLanes128 fun _ => hk.round_keys.2.2) =
      ok (ofLanes128 fun j => aesEncrypt alg kw (f j)) := by
  rw [low.x86_64.aes_gcm.encrypt512, rounds512_eq, bind_ok, aesenclast512_eq]
  refine congrArg ok (ofLanes128_ext _ _ fun j _ => ?_)
  rw [aesEncrypt_rounds hk alg kw h]

/-! ## 512-bit loads and stores -/

theorem bytes512_eq (v : BitVec 512) :
    bytes512 v = (List.range 4).flatMap fun j => low.x86_64.aes_gcm.bytes (lane128 v j) := rfl

theorem bytes512_ofLanes128 (g : Nat → BitVec 128) :
    bytes512 (ofLanes128 g) = (List.range 4).flatMap fun j => low.x86_64.aes_gcm.bytes (g j) := by
  rw [bytes512_eq]
  apply List.flatMap_congr; intro j hj
  rw [lane128_ofLanes128 g j (List.mem_range.1 hj)]

theorem bytes512_four (g : Nat → BitVec 128) :
    bytes512 (ofLanes128 g) = low.x86_64.aes_gcm.bytes (g 0) ++ low.x86_64.aes_gcm.bytes (g 1) ++
      low.x86_64.aes_gcm.bytes (g 2) ++ low.x86_64.aes_gcm.bytes (g 3) := by
  rw [bytes512_ofLanes128]
  simp [List.range_succ, List.append_assoc]

theorem length_bytes512 (v : BitVec 512) : (bytes512 v).length = 64 := by
  rw [← ofLanes128_lane128 v, bytes512_four]
  simp only [List.length_append, length_bytes]

theorem load_bytes (q : BitVec 128) : loadBytes (low.x86_64.aes_gcm.bytes q) = q := load_store q

theorem load_store512 (v : BitVec 512) : loadBytes512 (bytes512 v) = v := by
  obtain ⟨g, rfl⟩ : ∃ g, v = ofLanes128 g := ⟨lane128 v, (ofLanes128_lane128 v).symm⟩
  rw [bytes512_four, loadBytes512]
  apply ofLanes128_ext; intro j hj
  have l := length_bytes
  rcases (by omega : j = 0 ∨ j = 1 ∨ j = 2 ∨ j = 3) with rfl | rfl | rfl | rfl <;>
    simp [List.drop_append, List.take_append, l, load_bytes, List.take_of_length_le]

theorem chunksOf_flatMap_bytes512 : ∀ (vs : List (BitVec 512)),
    chunksOf 64 (vs.flatMap bytes512) = vs.map bytes512
  | [] => rfl
  | v :: vs => by
    rw [List.flatMap_cons, chunksOf_append (by omega) 1 _ _ (by rw [length_bytes512]),
      chunksOf_self _ (by omega) (length_bytes512 v), chunksOf_flatMap_bytes512 vs, List.map_cons,
      List.singleton_append]

/-- `hash16` reads its mask's selector bytes as `PSHUFB` does, so `BYTESWAP_512` hashes as `BYTESWAP`
broadcast. -/
theorem hash16_byteswap512 (t : low.x86_64.ghash.GhashTableAvx512) (m : List (BitVec 512)) (current : BitVec 128) :
    low.x86_64.ghash.hash16 t
      0x303132333435363738393a3b3c3d3e3f202122232425262728292a2b2c2d2e2f101112131415161718191a1b1c1d1e1f000102030405060708090a0b0c0d0e0f#512
      m current =
    low.x86_64.ghash.hash16 t (ofLanes128 fun _ => 0x00010203_04050607_08090a0b_0c0d0e0f#128) m current := by
  have h : ∀ v : BitVec 512, core.core_arch.x86.avx512bw._mm512_shuffle_epi8 v
      0x303132333435363738393a3b3c3d3e3f202122232425262728292a2b2c2d2e2f101112131415161718191a1b1c1d1e1f000102030405060708090a0b0c0d0e0f#512 =
      core.core_arch.x86.avx512bw._mm512_shuffle_epi8 v (ofLanes128 fun _ => 0x00010203_04050607_08090a0b_0c0d0e0f#128) := by
    intro v
    rw [← ofLanes128_lane128 v, ← ofLanes128_lane128
      0x303132333435363738393a3b3c3d3e3f202122232425262728292a2b2c2d2e2f101112131415161718191a1b1c1d1e1f000102030405060708090a0b0c0d0e0f#512,
      pshufb512_eq, pshufb512_eq]
    exact congrArg ok (ofLanes128_ext _ _ fun j hj => pshufb_congr _ _ _ (lanes_byteswap j hj))
  simp only [low.x86_64.ghash.hash16, h]

/-! ## The loop over 256-byte chunks -/

/-- Block `q` of `c`'s GCTR from block `i`. -/
def gBlock (icb : Quad32) (alg : Algorithm) (kw : List (BitVec 32)) (c : List U8) (i q : Nat) : BitVec 128 :=
  gctrEncryptBlock icb (loadBytes ((c.drop (16 * q)).take 16)) alg kw (i + q)

theorem gctr_chunk (icb : Quad32) (alg : Algorithm) (kw : List (BitVec 32)) (c : List U8) (hc : c.length = 256)
    (i : Nat) :
    gctrEncryptRecursive icb alg kw ((chunksOf 16 c).map loadBytes) i =
      (List.range 16).map fun q => gBlock icb alg kw c i q := by
  simp [chunksOf, hc, List.range_succ, gctrEncryptRecursive, gBlock]

theorem loads_stores512 (V : List (BitVec 512)) : (chunksOf 64 (V.flatMap bytes512)).map loadBytes512 = V := by
  rw [chunksOf_flatMap_bytes512, List.map_map]
  conv_rhs => rw [← List.map_id V]
  exact List.map_congr_left fun v _ => load_store512 v

theorem length_flatMap_bytes512 : ∀ (V : List (BitVec 512)), (V.flatMap bytes512).length = 64 * V.length
  | [] => rfl
  | v :: V => by
    rw [List.flatMap_cons, List.length_append, length_bytes512, length_flatMap_bytes512 V, List.length_cons]; ring

/-- `hash16` of four vectors: GHASH of their bytes' blocks. -/
theorem hash16_vecs (H : P) (hH : Small H) (t : low.x86_64.ghash.GhashTableAvx512) (ht : Avx512Powers H t)
    (V : List (BitVec 512)) (hV : V.length = 4) (current : BitVec 128) :
    ∃ y, low.x86_64.ghash.hash16 t (ofLanes128 fun _ => 0x00010203_04050607_08090a0b_0c0d0e0f#128) V current = ok y ∧
      toPoly y = ghashPoly H (toPoly current) ((padBlocks (V.flatMap bytes512)).map toPoly) := by
  have h := hash16_spec H hH t ht (V.flatMap bytes512) (by rw [length_flatMap_bytes512, hV]) current
  rwa [loads_stores512] at h

section loop
variable {hk : low.x86_64.aes.HwKey} {alg : Algorithm} {kw : List (BitVec 32)} (hkey : HwKeyIs alg kw hk)
include hkey

theorem by16_loop_eq (ENC : Bool) (H : P) (hH : Small H) (t : low.x86_64.ghash.GhashTableAvx512)
    (ht : Avx512Powers H t) (icb : Quad32) :
    ∀ (chunks : List (List U8)), (∀ c ∈ chunks, c.length = 256) → ∀ (i : Nat) (current : BitVec 128),
      ∃ y, low.x86_64.aes_gcm.by16_loop ENC t (ofLanes128 fun _ => hk.round_keys.1)
          (hk.round_keys.2.1.map fun k => ofLanes128 fun _ => k) (ofLanes128 fun _ => hk.round_keys.2.2) chunks
          (counter512 icb i) current =
        ok (counter512 icb (i + 16 * chunks.length), y,
          (gctrEncryptRecursive icb alg kw (blocksAll chunks) i).flatMap low.x86_64.aes_gcm.bytes) ∧
        toPoly y = ghashPoly H (toPoly current) ((padBlocks (if ENC then
          (gctrEncryptRecursive icb alg kw (blocksAll chunks) i).flatMap low.x86_64.aes_gcm.bytes
          else chunks.flatten)).map toPoly)
  | [], _, i, current => ⟨current, by simp [low.x86_64.aes_gcm.by16_loop, blocksAll, gctrEncryptRecursive],
      by cases ENC <;> simp [blocksAll, gctrEncryptRecursive, padBlocks_nil, ghashPoly_nil]⟩
  | c :: cs, hc, i, current => by
    have hc0 : c.length = 256 := hc c (by simp)
    have hcs : ∀ c ∈ cs, c.length = 256 := fun c h => hc c (by simp [h])
    have hp : ∀ v < 4, ((chunksOf 64 c).map loadBytes512)[v]! =
        ofLanes128 fun b => loadBytes ((c.drop (16 * (4 * v + b))).take 16) := fun v hv => by
      simp [chunksOf, hc0, hv, loadBytes512_chunk]
    have hvec : ∀ v m, m = i + 4 * v → (ofLanes128 fun j => aesEncrypt alg kw (reverseBytesQuad32 (inc32 icb (m + j))) ^^^
        loadBytes (List.take 16 (List.drop (16 * (4 * v + j)) c))) = ofLanes128 fun j => gBlock icb alg kw c i (4 * v + j) :=
      fun v m hm => ofLanes128_ext _ _ fun j _ => by
        rw [gBlock, gctrEncryptBlock, BitVec.xor_comm, hm, Nat.add_assoc]
    simp only [low.x86_64.aes_gcm.by16_loop, next4_eq, bind_ok, uncurry_apply_pair, encrypt512_eq hk alg kw hkey,
      hp 0 (by omega), hp 1 (by omega), hp 2 (by omega), hp 3 (by omega), xor512_eq,
      low.x86_64.aes_gcm.BYTESWAP_512, hash16_byteswap512]
    rw [hvec 0 i (by omega), hvec 1 (i + 4) (by omega), hvec 2 (i + 4 + 4) (by omega), hvec 3 (i + 4 + 4 + 4) (by omega),
      show i + 4 + 4 + 4 + 4 = i + 16 by omega]
    have hblocks : blocksAll (c :: cs) = (chunksOf 16 c).map loadBytes ++ blocksAll cs := by
      rw [blocksAll, List.flatMap_cons, ← blocksAll]
    have hl16 : ((chunksOf 16 c).map loadBytes).length = 16 := by rw [List.length_map, chunksOf_length, hc0]
    have hout : List.flatMap bytes512 [ofLanes128 fun j => gBlock icb alg kw c i (4 * 0 + j),
        ofLanes128 fun j => gBlock icb alg kw c i (4 * 1 + j), ofLanes128 fun j => gBlock icb alg kw c i (4 * 2 + j),
        ofLanes128 fun j => gBlock icb alg kw c i (4 * 3 + j)] =
        (gctrEncryptRecursive icb alg kw ((chunksOf 16 c).map loadBytes) i).flatMap low.x86_64.aes_gcm.bytes := by
      rw [gctr_chunk icb alg kw c hc0]
      simp [bytes512_four, List.range_succ]
    rw [hout]
    obtain ⟨y, hy, hyp⟩ : ∃ y, low.x86_64.ghash.hash16 t
        (ofLanes128 fun _ => 0x00010203_04050607_08090a0b_0c0d0e0f#128)
        (if ENC = true then [ofLanes128 fun j => gBlock icb alg kw c i (4 * 0 + j),
          ofLanes128 fun j => gBlock icb alg kw c i (4 * 1 + j), ofLanes128 fun j => gBlock icb alg kw c i (4 * 2 + j),
          ofLanes128 fun j => gBlock icb alg kw c i (4 * 3 + j)] else (chunksOf 64 c).map loadBytes512) current = ok y ∧
        toPoly y = ghashPoly H (toPoly current) ((padBlocks (if ENC then
          (gctrEncryptRecursive icb alg kw ((chunksOf 16 c).map loadBytes) i).flatMap low.x86_64.aes_gcm.bytes
          else c)).map toPoly) := by
      cases ENC
      · exact hash16_spec H hH t ht c hc0 current
      · obtain ⟨y, hy, hyp⟩ := hash16_vecs H hH t ht [ofLanes128 fun j => gBlock icb alg kw c i (4 * 0 + j),
          ofLanes128 fun j => gBlock icb alg kw c i (4 * 1 + j), ofLanes128 fun j => gBlock icb alg kw c i (4 * 2 + j),
          ofLanes128 fun j => gBlock icb alg kw c i (4 * 3 + j)] rfl current
        rw [hout] at hyp
        exact ⟨y, hy, hyp⟩
    obtain ⟨z, hz, hzp⟩ := by16_loop_eq ENC H hH t ht icb cs hcs (i + 16) y
    have hlo : ((gctrEncryptRecursive icb alg kw ((chunksOf 16 c).map loadBytes) i).flatMap
        low.x86_64.aes_gcm.bytes).length % 16 = 0 := by rw [length_flatMap_bytes]; omega
    refine ⟨z, ?_, ?_⟩
    · rw [hy, bind_ok, hz, bind_ok, uncurry_apply_pair, uncurry_apply_pair, hblocks, gctr_append, hl16,
        List.flatMap_append, List.length_cons, show i + 16 + 16 * cs.length = i + 16 * (cs.length + 1) by ring]
    · rw [hzp, hyp, ← ghashPoly_append, ← List.map_append, hblocks, gctr_append, hl16, List.flatMap_append]
      cases ENC
      · simp only [Bool.false_eq_true, ite_false, List.flatten_cons]
        rw [padBlocks_append _ _ (by rw [hc0])]
      · simp only [ite_true]
        rw [padBlocks_append _ _ hlo]

end loop

end rind.x86_64
