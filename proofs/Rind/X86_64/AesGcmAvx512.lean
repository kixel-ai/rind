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

/-! ## Bytes of 512-bit vectors -/

/-- Byte `k` of `Y`, zero past its end. -/
def yb (Y : List U8) (k : Nat) : BitVec 8 := (Y[k]?.map (·.bv)).getD 0

theorem byte_loadBytes (Y : List U8) {i : Nat} (hi : i < 16) : byte (loadBytes Y) i = yb Y i := by
  rw [loadBytes, byte_leBytesToQuad32 _ hi]
  simp only [yb, List.getElem!_eq_getElem?_getD, List.getElem?_map]
  rfl

theorem byte_lane_load512 (Y : List U8) {j i : Nat} (hj : j < 4) (hi : i < 16) :
    byte (lane128 (loadBytes512 Y) j) i = yb Y (16 * j + i) := by
  rw [loadBytes512, lane128_ofLanes128 _ _ hj, byte_loadBytes _ hi]
  simp [yb, List.getElem?_take, List.getElem?_drop, hi]

theorem yb_bytes (q : BitVec 128) {i : Nat} (hi : i < 16) : yb (low.x86_64.aes_gcm.bytes q) i = byte q i := by
  simp [yb, low.x86_64.aes_gcm.bytes, storeBytes, leQuad32ToBytes, hi, byte]

theorem yb_append (A B : List U8) (k : Nat) :
    yb (A ++ B) k = if k < A.length then yb A k else yb B (k - A.length) := by
  unfold yb
  split
  · rw [List.getElem?_append_left (by omega)]
  · rw [List.getElem?_append_right (by omega)]

theorem yb_bytes512 (v : BitVec 512) {k : Nat} (hk : k < 64) :
    yb (bytes512 v) k = byte (lane128 v (k / 16)) (k % 16) := by
  obtain ⟨g, rfl⟩ : ∃ g, v = ofLanes128 g := ⟨lane128 v, (ofLanes128_lane128 v).symm⟩
  rw [bytes512_four, lane128_ofLanes128 _ _ (by omega)]
  simp only [yb_append, List.length_append, length_bytes]
  rcases (by omega : k < 16 ∨ (16 ≤ k ∧ k < 32) ∨ (32 ≤ k ∧ k < 48) ∨ (48 ≤ k ∧ k < 64)) with h | h | h | h
  · rw [ite_eq_left (by omega), ite_eq_left (by omega), ite_eq_left h, yb_bytes _ (by omega),
      show k / 16 = 0 by omega, show k % 16 = k by omega]
  · rw [ite_eq_left (by omega), ite_eq_left (by omega), ite_eq_right (by omega), yb_bytes _ (by omega),
      show k / 16 = 1 by omega, show k - 16 = k % 16 by omega]
  · rw [ite_eq_left (by omega), ite_eq_right (by omega), yb_bytes _ (by omega),
      show k / 16 = 2 by omega, show k - (16 + 16) = k % 16 by omega]
  · rw [ite_eq_right (by omega), yb_bytes _ (by omega), show k / 16 = 3 by omega,
      show k - (16 + 16 + 16) = k % 16 by omega]

theorem eq_of_lanes {x y : BitVec 512} (h : ∀ j < 4, ∀ i < 16, byte (lane128 x j) i = byte (lane128 y j) i) :
    x = y := by
  rw [← ofLanes128_lane128 x, ← ofLanes128_lane128 y]
  exact ofLanes128_ext _ _ fun j hj => eq_of_byte_eq (h j hj)

theorem lane128_xor (x y : BitVec 512) (j : Nat) : lane128 (x ^^^ y) j = lane128 x j ^^^ lane128 y j := by
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  simp [lane128, BitVec.getLsbD_extractLsb', hk]

theorem mask_bit (l k : Nat) (hl : l ≤ 64) (hk : k < 64) :
    (BitVec.allOnes 64 >>> (64 - l)).getLsbD k = decide (k < l) := by
  simp only [BitVec.getLsbD_ushiftRight, BitVec.getLsbD_allOnes, decide_eq_decide]
  omega

theorem u8_ext {a b : U8} (h : a.bv = b.bv) : a = b := by
  cases a; cases b; cases h; rfl

theorem yb_take (A : List U8) (n k : Nat) : yb (A.take n) k = if k < n then yb A k else 0 := by
  unfold yb
  rw [List.getElem?_take]
  split <;> rfl

theorem yb_replicate (n k : Nat) : yb (List.replicate n 0#u8) k = 0 := by
  unfold yb
  by_cases h : k < n
  · rw [List.getElem?_replicate_of_lt h]; rfl
  · rw [List.getElem?_eq_none (by simp; omega)]; rfl

theorem bytes512_load512 (Y : List U8) (hY : Y.length = 64) : bytes512 (loadBytes512 Y) = Y := by
  apply List.ext_getElem (by rw [length_bytes512, hY])
  intro k h1 h2
  rw [length_bytes512] at h1
  apply u8_ext
  have h := yb_bytes512 (loadBytes512 Y) h1
  rw [byte_lane_load512 _ (by omega) (by omega), show 16 * (k / 16) + k % 16 = k by omega] at h
  simp only [yb, List.getElem?_eq_getElem h2, List.getElem?_eq_getElem (show k < (bytes512 (loadBytes512 Y)).length by
    rw [length_bytes512]; exact h1), Option.map_some, Option.getD_some] at h
  exact h

/-- A masked 64-byte tail chunk: `VMOVDQU8` keeps the keystream's bytes under
the chunk, so the XOR is the chunk's CTR output followed by zeros. -/
theorem mask_chunk (K : BitVec 512) (C : List U8) (hl : C.length ≤ 64) :
    (ofLanes128 fun j => ofBytes fun i =>
        if (BitVec.allOnes 64 >>> (64 - C.length)).getLsbD (16 * j + i) then byte (lane128 K j) i else 0) ^^^
      loadBytes512 (C ++ List.replicate (64 - C.length) 0#u8) =
    loadBytes512 ((bytes512 (K ^^^ loadBytes512 (C ++ List.replicate (64 - C.length) 0#u8))).take C.length ++
      List.replicate (64 - C.length) 0#u8) := by
  apply eq_of_lanes; intro j hj i hi
  rw [lane128_xor, lane128_ofLanes128 _ _ hj, byte_xor, byte_ofBytes _ hi, byte_lane_load512 _ hj hi,
    byte_lane_load512 _ hj hi, mask_bit _ _ hl (by omega)]
  simp only [yb_append, yb_take, yb_replicate, List.length_take, length_bytes512, Nat.min_eq_left hl]
  by_cases h : 16 * j + i < C.length
  · rw [yb_bytes512 _ (by omega), show (16 * j + i) / 16 = j by omega, show (16 * j + i) % 16 = i by omega,
      lane128_xor, byte_xor, byte_lane_load512 _ hj hi, yb_append]
    simp only [h, ite_true, decide_true]
  · simp [h]

/-! ## The tail -/

/-- `PSHUFB` by `BYTESWAP_512` of a 64-byte load: each block's bytes reversed. -/
theorem shuffle_load512 (Y : List U8) :
    core.core_arch.x86.avx512bw._mm512_shuffle_epi8 (loadBytes512 Y) 0x303132333435363738393a3b3c3d3e3f202122232425262728292a2b2c2d2e2f101112131415161718191a1b1c1d1e1f000102030405060708090a0b0c0d0e0f#512 =
      ok (ofLanes128 fun j => blockBE ((Y.drop (16 * j)).take 16)) := by
  rw [loadBytes512, ← ofLanes128_lane128 0x303132333435363738393a3b3c3d3e3f202122232425262728292a2b2c2d2e2f101112131415161718191a1b1c1d1e1f000102030405060708090a0b0c0d0e0f#512, pshufb512_eq]
  exact congrArg ok (ofLanes128_ext _ _ fun j hj => by
    rw [pshufb_congr _ _ _ (lanes_byteswap j hj), pshufb_byteswap, blockBE])

/-- A tail chunk `C`'s output, from its counters' AES before the last round,
`f`, and the last round key `l`. -/
def tailOut (l : BitVec 128) (f : Nat → BitVec 128) (C : List U8) : List U8 :=
  (bytes512 ((ofLanes128 fun j => subBytes (shiftRows (f j)) ^^^ l) ^^^
    loadBytes512 (C ++ List.replicate (64 - C.length) 0#u8))).take C.length

theorem length_tailOut (l : BitVec 128) (f : Nat → BitVec 128) (C : List U8) (hC : C.length ≤ 64) :
    (tailOut l f C).length = C.length := by
  rw [tailOut, List.length_take, length_bytes512, Nat.min_eq_left hC]

/-- The vector `_cipher_avx512` hashes for a tail chunk `X`, its ciphertext or
plaintext: its blocks zero-padded, their bytes reversed. -/
def tailVec (X : List U8) : BitVec 512 :=
  ofLanes128 fun j => blockBE (((X ++ List.replicate (64 - X.length) 0#u8).drop (16 * j)).take 16)

theorem tail_loop_eq (ENC : Bool) (l : BitVec 128) : ∀ (fs : List (Nat → BitVec 128)) (chunks : List (List U8)),
    chunks.length ≤ fs.length → (∀ C ∈ chunks, C.length ≤ 64) →
    low.x86_64.aes_gcm.by16_tail_loop ENC (ofLanes128 fun _ => l) (fs.map ofLanes128) chunks =
      ok ((fs.zip chunks).map (fun p => tailVec (if ENC then tailOut l p.1 p.2 else p.2)),
        (fs.zip chunks).flatMap fun p => tailOut l p.1 p.2)
  | [], [], _, _ => rfl
  | _ :: _, [], _, _ => rfl
  | [], _ :: _, h, _ => absurd h (by simp)
  | f :: fs, C :: cs, h, hc => by
    have hC : C.length ≤ 64 := hc C (by simp)
    have hm := mask_chunk (ofLanes128 fun j => subBytes (shiftRows (f j)) ^^^ l) C hC
    have hm' : (ofLanes128 fun j => ofBytes fun i => if (BitVec.allOnes 64 >>> (64 - C.length)).getLsbD (16 * j + i)
          then byte (subBytes (shiftRows (f j)) ^^^ l) i else 0) ^^^
        loadBytes512 (C ++ List.replicate (64 - C.length) 0#u8) =
        loadBytes512 (tailOut l f C ++ List.replicate (64 - C.length) 0#u8) := by
      rw [tailOut, ← hm]
      exact congrArg (· ^^^ _) (ofLanes128_ext _ _ fun j hj => by rw [lane128_ofLanes128 _ _ hj])
    have ht := length_tailOut l f C hC
    rw [List.map_cons, low.x86_64.aes_gcm.by16_tail_loop]
    simp only [aesenclast512_eq, bind_ok, maskz512_eq, core.core_arch.x86.avx512f._mm512_xor_epi32, hm',
      low.x86_64.aes_gcm.BYTESWAP_512, tail_loop_eq ENC l fs cs (by simp at h; omega) (fun C h => hc C (by simp [h])),
      uncurry_apply_pair]
    rw [bytes512_load512 _ (by rw [List.length_append, List.length_replicate, ht]; omega), List.take_left' ht]
    cases ENC <;> simp only [ite_true, Bool.false_eq_true, ite_false, shuffle_load512, bind_ok, List.zip_cons_cons,
      List.map_cons, List.flatMap_cons, tailVec, ht]

/-! ## Chunks and blocks of the tail -/

theorem slice_chunk (Y : List U8) (N v b : Nat) (hb : b < 4) (hN : 64 * v + 64 ≤ Y.length + N) :
    ((((Y.drop (64 * v)).take 64) ++ List.replicate (64 - ((Y.drop (64 * v)).take 64).length) 0#u8).drop (16 * b)).take 16 =
      ((Y ++ List.replicate N 0#u8).drop (16 * (4 * v + b))).take 16 := by
  apply List.ext_getElem?; intro k
  simp only [List.getElem?_take, List.getElem?_drop, List.getElem?_append, List.length_take, List.length_drop,
    List.getElem?_replicate, List.length_replicate]
  by_cases hk : k < 16
  · simp only [hk, ite_true]
    by_cases h1 : 16 * b + k < min 64 (Y.length - 64 * v)
    · rw [ite_eq_left h1, ite_eq_left (by omega), ite_eq_left (by omega), show 64 * v + (16 * b + k) = 16 * (4 * v + b) + k by ring]
    · rw [ite_eq_right h1, ite_eq_right (show ¬ 16 * (4 * v + b) + k < Y.length by omega), ite_eq_left (by omega),
        ite_eq_left (by omega)]
  · simp only [hk, ite_false]

theorem flatten_chunks (Y : List U8) :
    ((List.range ((Y.length + 63) / 64)).map fun v => (Y.drop (64 * v)).take 64).flatten = Y := by
  induction h : Y.length using Nat.strong_induction_on generalizing Y with
  | _ n ih =>
    by_cases h0 : n = 0
    · subst h0; simp [List.eq_nil_of_length_eq_zero h]
    · have e : (n + 63) / 64 = ((Y.drop 64).length + 63) / 64 + 1 := by simp; omega
      rw [e, List.range_succ_eq_map, List.map_cons, List.flatten_cons, List.map_map]
      have := ih (Y.drop 64).length (by simp; omega) (Y.drop 64) rfl
      conv_rhs => rw [← List.take_append_drop 64 Y, ← this]
      simp only [Nat.mul_zero, List.drop_zero]
      congr 2
      apply List.map_congr_left; intro v _
      simp only [Function.comp, List.drop_drop]
      congr 2; omega

theorem chunksUpTo_range (Y : List U8) :
    chunksUpTo 64 Y = (List.range ((Y.length + 63) / 64)).map fun v => (Y.drop (64 * v)).take 64 := by
  rw [chunksUpTo, chunksOf, chunksRest]
  by_cases h : Y.length % 64 = 0
  · have : Y.drop (64 * (Y.length / 64)) = [] := List.drop_eq_nil_of_le (by omega)
    rw [this, ite_eq_left rfl, List.append_nil, show (Y.length + 63) / 64 = Y.length / 64 by omega]
  · have hne : Y.drop (64 * (Y.length / 64)) ≠ [] := by
      intro he; have := congrArg List.length he; simp at this; omega
    rw [ite_eq_right hne, show (Y.length + 63) / 64 = Y.length / 64 + 1 by omega, List.range_succ, List.map_append,
      List.map_singleton, List.take_of_length_le (by simp; omega)]

/-- GHASH's padded blocks of `X`, as 16-byte slices of `X` zero-extended. -/
theorem padBlocks_range (X : List U8) (N : Nat) (hN : 16 ≤ N) :
    padBlocks X = (List.range ((X.length + 15) / 16)).map fun b =>
      blockBE (((X ++ List.replicate N 0#u8).drop (16 * b)).take 16) := by
  have hw : ∀ b ∈ List.range (X.length / 16), blockBE ((X.drop (16 * b)).take 16) =
      blockBE (((X ++ List.replicate N 0#u8).drop (16 * b)).take 16) := fun b hb => by
    have := List.mem_range.1 hb
    rw [List.drop_append_of_le_length (by omega), List.take_append_of_le_length (by simp; omega)]
  rw [padBlocks, chunksOf, List.map_map]
  by_cases h : X.length % 16 = 0
  · have : chunksRest 16 X = [] := List.eq_nil_of_length_eq_zero (by rw [chunksRest_length]; exact h)
    rw [this, ite_eq_left rfl, List.append_nil, show (X.length + 15) / 16 = X.length / 16 by omega]
    exact List.map_congr_left hw
  · have hne : chunksRest 16 X ≠ [] := fun he => by
      have := congrArg List.length he; rw [chunksRest_length] at this; simp at this; omega
    rw [ite_eq_right hne, show (X.length + 15) / 16 = X.length / 16 + 1 by omega, List.range_succ, List.map_append,
      List.map_singleton]
    refine congrArg₂ (· ++ ·) (List.map_congr_left hw) ?_
    rw [tailBlock, chunksRest]
    congr 2
    congr 1
    apply List.ext_getElem?; intro k
    by_cases hk : k < X.length - 16 * (X.length / 16)
    · have h1 : 16 * (X.length / 16) + k < X.length := by omega
      simp [List.getElem?_take, List.getElem?_drop, List.getElem?_append, hk, h1, show k < 16 by omega]
    · by_cases hk' : k < 16
      · have h1 : ¬ 16 * (X.length / 16) + k < X.length := by omega
        have h2 : 16 * (X.length / 16) + k - X.length < N := by omega
        have h3 : k - (X.length - 16 * (X.length / 16)) < 16 - (X.length - 16 * (X.length / 16)) := by omega
        simp [List.getElem?_take, List.getElem?_drop, List.getElem?_append, List.getElem?_replicate, hk, hk', h1,
          h2, h3]
      · have h3 : ¬ k - (X.length - 16 * (X.length / 16)) < 16 - (X.length - 16 * (X.length / 16)) := by omega
        simp [List.getElem?_take, List.getElem?_drop, List.getElem?_append, List.getElem?_replicate, hk, hk', h3]

end rind.x86_64
