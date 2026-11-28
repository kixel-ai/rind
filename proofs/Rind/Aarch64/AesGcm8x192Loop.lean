import RindIsa.AArch64.AesGcm8x192
import Rind.Aarch64.Asm
import Rind.Aarch64.AesGcm8x192Ops

open VG VG.AArch64 VG.VectorCrypto Rind.AArch64 rind.aarch64.asm rind.vale rind.simd rind.s2n

/-!
# One iteration of aws-lc's eight-way AES-192-GCM main loops, proven
-/

namespace rind.aarch64.gcm8x192

/-- The registers of the eight blocks of data, `v8` to `v15`. -/
def blockReg (i : Nat) : VReg := [.v8, .v9, .v10, .v11, .v12, .v13, .v14, .v15][i]!

/-- The registers of the counter blocks an iteration starts from, `v0` to `v4`. -/
def ctrReg (i : Nat) : VReg := [.v0, .v1, .v2, .v3, .v4][i]!

/-- The vector registers an iteration writes: all but `v31`. -/
def clobbered : List VReg :=
  [.v0, .v1, .v2, .v3, .v4, .v5, .v6, .v7, .v8, .v9, .v10, .v11, .v12, .v13, .v14, .v15, .v16, .v17,
   .v18, .v19, .v20, .v21, .v22, .v23, .v24, .v25, .v26, .v27, .v28, .v29, .v30]

/-- Memory with the blocks `o 0` to `o 7` written from `a` on, in order. -/
def write8 (m : Mem) (a : Addr) (o : Nat → BitVec 128) : Mem :=
  ((((((((m.write a 16 (o 0)).write (a + 16#64) 16 (o 1)).write (a + 32#64) 16 (o 2)).write (a + 48#64) 16
    (o 3)).write (a + 64#64) 16 (o 4)).write (a + 80#64) 16 (o 5)).write (a + 96#64) 16 (o 6)).write
    (a + 112#64) 16 (o 7))

/-- Block `i` of the 128 bytes at `a`. -/
def block (m : Mem) (a : Addr) (i : Nat) : BitVec 128 := m.read (a + BitVec.ofNat 64 (16 * i)) 16

/-- The keystream for counter block `c + i`, under the lane round keys `k`. -/
def keystream (nonce : BitVec 96) (c : Nat) (k : Nat → BitVec 128) (i : Nat) : BitVec 128 :=
  evalCipher .AES_192 (ctrLane nonce (c + i)) (keys13 k)

/-- With round keys `rk` in SP 800-38D's byte order, reversed into lanes as
LDP loads them, the keystream is s2n-bignum's `aes_ctr_block` of AES-192,
the block `GcmKernelOut` states its kernels' outputs over. -/
theorem keystream_eq (nonce : BitVec 96) (c : Nat) (rk : List (BitVec 128)) (hrk : rk.length = 13) (i : Nat) :
    keystream nonce c (fun j => reverseBytesQuad32 rk[j]!) i = aesCtrBlock aes192Cipher c nonce rk i := by
  have hk : keys13 (fun j => reverseBytesQuad32 rk[j]!) = rk.map reverseBytesQuad32 := by
    apply List.ext_getElem (by simp [keys13, hrk])
    intro n h1 h2
    simp only [keys13, List.getElem_map, List.getElem_range]
    rw [List.getElem!_eq_getElem?_getD, List.getElem?_eq_getElem (by simp_all), Option.getD_some]
  rw [keystream, hk, ctrLane, ← aes192Cipher_eq, aesCtrBlock, wordReversefields8, Nat.add_comm]

/-- What an iteration of either main loop needs of the state it starts in:
the round keys `k` at `x11`, the table of powers of the twisted key `H` at
`x6`, the reduction constant at `x10`, counter blocks `c` to `c + 4` in `v0`
to `v4` and `c + 5` reversed by words in `v30`, the counter's step in `v31`,
and the eight input blocks at `x0` readable and the eight output blocks at
`x2` writable. -/
structure LoopPre (s : S) (nonce : BitVec 96) (c : Nat) (k : Nat → BitVec 128) (H : BitVec 128) : Prop where
  keys : ∀ i < 13, s.vg.mem.read (s.vg.gpr .x11 + BitVec.ofNat 64 (16 * i)) 16 = k i
  table : ∀ i < 12, s.vg.mem.read (s.vg.gpr .x6 + BitVec.ofNat 64 (16 * i)) 16 = (htable8 (ghashTwist H))[i]!
  modc : s.vg.mem.read (s.vg.gpr .x10) 8 = 0xc200000000000000#64
  ctr : ∀ i < 5, s.vg.v (ctrReg i) = ctrLane nonce (c + i)
  ctr30 : s.vg.v .v30 = VRevOp.rev32b.eval (ctrLane nonce (c + 5))
  inc : s.vg.v .v31 = ctrInc
  rkeys : ∀ i < 13, InRegions (s.vg.rd ++ s.vg.wr) (s.vg.gpr .x11 + BitVec.ofNat 64 (16 * i)) 16
  rtable : ∀ i < 12, InRegions (s.vg.rd ++ s.vg.wr) (s.vg.gpr .x6 + BitVec.ofNat 64 (16 * i)) 16
  rmod : InRegions (s.vg.rd ++ s.vg.wr) (s.vg.gpr .x10) 8
  rin : ∀ i < 8, InRegions (s.vg.rd ++ s.vg.wr) (s.vg.gpr .x0 + BitVec.ofNat 64 (16 * i)) 16
  rout : ∀ i < 8, InRegions s.vg.wr (s.vg.gpr .x2 + BitVec.ofNat 64 (16 * i)) 16

theorem ex2_of_eq {α : Type} {o : Option (α × List Leak)} {x : α} {t : List Leak} {P : α → Prop}
    (h : o = some (x, t)) (hp : P x) : ∃ s' t', o = some (s', t') ∧ P s' :=
  ⟨x, t, h, hp⟩

theorem add_zero64 (a : Addr) : a + 0#64 = a := BitVec.add_zero a

/-- The condition flags. -/
def flags (g : VG.AArch64.State) : Bool × Bool × Bool × Bool := (g.nf, g.zf, g.c, g.vf)

@[simp] theorem nf_setMem (g : VG.AArch64.State) (m : Mem) : (setMem g m).nf = g.nf := rfl
@[simp] theorem zf_setMem (g : VG.AArch64.State) (m : Mem) : (setMem g m).zf = g.zf := rfl
@[simp] theorem vf_setMem (g : VG.AArch64.State) (m : Mem) : (setMem g m).vf = g.vf := rfl

set_option maxHeartbeats 20000000 in
set_option maxRecDepth 200000 in
theorem encLoop_ok (s : S) (nonce : BitVec 96) (c : Nat) (k : Nat → BitVec 128) (H : BitVec 128)
    (pre : LoopPre s nonce c k H) :
    ∃ s' t, execBlock I AesGcm8x192.encLoop s = some (s', t) ∧
      (∀ i < 8, s'.vg.v (blockReg i) = block s.vg.mem (s.vg.gpr .x0) i ^^^ keystream nonce c k i) ∧
      s'.vg.v .v19 = nistGhash H (s.vg.v .v19)
        ((List.range 8).map fun i => reverseBytesQuad32 (s.vg.v (blockReg i))) ∧
      (∀ i < 5, s'.vg.v (ctrReg i) = ctrLane nonce (c + 8 + i)) ∧
      s'.vg.v .v30 = VRevOp.rev32b.eval (ctrLane nonce (c + 13)) ∧
      s'.vg.gpr .x0 = s.vg.gpr .x0 + 128#64 ∧ s'.vg.gpr .x2 = s.vg.gpr .x2 + 128#64 ∧
      s'.vg.mem = write8 s.vg.mem (s.vg.gpr .x2)
        (fun i => block s.vg.mem (s.vg.gpr .x0) i ^^^ keystream nonce c k i) ∧
      flags s'.vg = flags (s.vg.flagsAdd (s.vg.gpr .x0 + 128#64) (~~~(s.vg.gpr .x5)) true) ∧
      Frame s s' clobbered [.x0, .x2] := by
  have k0 := pre.rkeys 0 (by decide); have k1 := pre.rkeys 1 (by decide); have k2 := pre.rkeys 2 (by decide)
  have k3 := pre.rkeys 3 (by decide); have k4 := pre.rkeys 4 (by decide); have k5 := pre.rkeys 5 (by decide)
  have k6 := pre.rkeys 6 (by decide); have k7 := pre.rkeys 7 (by decide); have k8 := pre.rkeys 8 (by decide)
  have k9 := pre.rkeys 9 (by decide); have k10 := pre.rkeys 10 (by decide)
  have k11 := pre.rkeys 11 (by decide); have k12 := pre.rkeys 12 (by decide)
  have t0 := pre.rtable 0 (by decide); have t1 := pre.rtable 1 (by decide); have t2 := pre.rtable 2 (by decide)
  have t3 := pre.rtable 3 (by decide); have t4 := pre.rtable 4 (by decide); have t5 := pre.rtable 5 (by decide)
  have t6 := pre.rtable 6 (by decide); have t7 := pre.rtable 7 (by decide); have t8 := pre.rtable 8 (by decide)
  have t9 := pre.rtable 9 (by decide); have t10 := pre.rtable 10 (by decide)
  have t11 := pre.rtable 11 (by decide)
  have i0 := pre.rin 0 (by decide); have i1 := pre.rin 1 (by decide); have i2 := pre.rin 2 (by decide)
  have i3 := pre.rin 3 (by decide); have i4 := pre.rin 4 (by decide); have i5 := pre.rin 5 (by decide)
  have i6 := pre.rin 6 (by decide); have i7 := pre.rin 7 (by decide)
  have o0 := pre.rout 0 (by decide); have o1 := pre.rout 1 (by decide); have o2 := pre.rout 2 (by decide)
  have o3 := pre.rout 3 (by decide); have o4 := pre.rout 4 (by decide); have o5 := pre.rout 5 (by decide)
  have o6 := pre.rout 6 (by decide); have o7 := pre.rout 7 (by decide)
  have rm := pre.rmod
  simp only [Nat.reduceMul] at k0 k1 k2 k3 k4 k5 k6 k7 k8 k9 k10 k11 k12 t0 t1 t2 t3 t4 t5 t6 t7 t8 t9 t10 t11
  simp only [Nat.reduceMul] at i0 i1 i2 i3 i4 i5 i6 i7 o0 o1 o2 o3 o4 o5 o6 o7
  simp only [add_zero64] at i0 o0
  have K0 := pre.keys 0 (by decide); have K1 := pre.keys 1 (by decide); have K2 := pre.keys 2 (by decide)
  have K3 := pre.keys 3 (by decide); have K4 := pre.keys 4 (by decide); have K5 := pre.keys 5 (by decide)
  have K6 := pre.keys 6 (by decide); have K7 := pre.keys 7 (by decide); have K8 := pre.keys 8 (by decide)
  have K9 := pre.keys 9 (by decide); have K10 := pre.keys 10 (by decide)
  have K11 := pre.keys 11 (by decide); have K12 := pre.keys 12 (by decide)
  simp only [Nat.reduceMul] at K0 K1 K2 K3 K4 K5 K6 K7 K8 K9 K10 K11 K12
  simp only [add_zero64] at K0
  have C0 := pre.ctr 0 (by decide); have C1 := pre.ctr 1 (by decide); have C2 := pre.ctr 2 (by decide)
  have C3 := pre.ctr 3 (by decide); have C4 := pre.ctr 4 (by decide)
  simp only [ctrReg, List.getElem!_cons_zero, List.getElem!_cons_succ, Nat.add_zero] at C0 C1 C2 C3 C4
  have C30 := pre.ctr30
  have C31 := pre.inc
  have T0 := pre.table 0 (by decide); have T1 := pre.table 1 (by decide); have T2 := pre.table 2 (by decide)
  have T3 := pre.table 3 (by decide); have T4 := pre.table 4 (by decide); have T5 := pre.table 5 (by decide)
  have T6 := pre.table 6 (by decide); have T7 := pre.table 7 (by decide); have T8 := pre.table 8 (by decide)
  have T9 := pre.table 9 (by decide); have T10 := pre.table 10 (by decide)
  have T11 := pre.table 11 (by decide)
  simp only [Nat.reduceMul, htable8, htable4, List.cons_append, List.nil_append, List.getElem!_cons_zero,
    List.getElem!_cons_succ, byteswap128_eq] at T0 T1 T2 T3 T4 T5 T6 T7 T8 T9 T10 T11
  have M := pre.modc
  apply ex2_of_eq
  · rw [execBlock_acc]
    a64_run [AesGcm8x192.encLoop, AesGcm8x192.vop, add_ofNat, VG.AArch64.addr, Rind.AArch64.ldQ,
      Rind.AArch64.stQ]
    rfl
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · intro i hi
    interval_cases i <;>
    · simp only [blockReg, List.getElem!_cons_zero, List.getElem!_cons_succ, v_setV, v_write, v_flagsAdd,
        v_setMem, reduceCtorEq, ↓reduceIte]
      rw [keystream, ← aesRounds192_eq]
      simp only [block, aesRounds192, aesRound, Nat.reduceMul, add_zero64, K0, K1, K2, K3, K4, K5, K6, K7, K8,
        K9, K10, K11, K12, C0, C1, C2, C3, C4, C30, C31, rev32b_rev32b, add_ctr, Nat.add_assoc, Nat.reduceAdd,
        Nat.add_zero, BitVec.xor_assoc]
  · simp only [v_setV, v_write, v_flagsAdd, v_setMem, reduceCtorEq, ↓reduceIte]
    simp only [List.range_succ, List.range_zero, List.nil_append, List.cons_append, List.map_cons, List.map_nil,
      blockReg, List.getElem!_cons_zero, List.getElem!_cons_succ]
    rw [nistGhash_reduceAll]
    simp only [M, rev64b_eq, ext_swap, vdword_zero, vdword_one, polyMul_eq, lo_setWidth]
    rw [code_reduce]
    simp only [pows, List.length_cons, List.length_nil, Nat.reduceAdd, reduceAll, accum]
    congr 1 <;>
    · simp only [karaTerms, T0, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, karatsubaMid_eq, trn1_d2,
        trn2_d2, lo_xor, hi_xor, lo_swap, hi_swap, lo_append, hi_append]
      ac_rfl
  · intro i hi
    interval_cases i <;>
    · simp only [ctrReg, List.getElem!_cons_zero, List.getElem!_cons_succ, v_setV, v_write, v_flagsAdd,
        v_setMem, reduceCtorEq, ↓reduceIte, C0, C1, C2, C3, C4, C30, C31, rev32b_rev32b, add_ctr, Nat.add_assoc,
        Nat.reduceAdd, Nat.add_zero]
  · simp only [v_setV, v_write, v_flagsAdd, v_setMem, reduceCtorEq, ↓reduceIte, C30, C31, add_ctr, Nat.add_assoc,
      Nat.reduceAdd]
  · simp only [gpr_write, gpr_setV, gpr_flagsAdd, gpr_setMem, reduceCtorEq, ↓reduceIte]
  · simp only [gpr_write, ↓reduceIte]
  · simp only [mem_write, mem_setMem]
    simp only [write8, block, keystream, ← aesRounds192_eq]
    simp only [aesRounds192, aesRound, Nat.reduceMul, add_zero64, K0, K1, K2, K3, K4, K5, K6, K7, K8, K9, K10,
      K11, K12, C0, C1, C2, C3, C4, C30, C31, rev32b_rev32b, add_ctr, Nat.add_assoc, Nat.reduceAdd, Nat.add_zero,
      BitVec.xor_assoc]
  · simp only [flags, nf_setMem, zf_setMem, vf_setMem, c_setMem, nf_write, zf_write, vf_write, c_write]
    rfl
  · unfold clobbered
    a64_out

set_option maxHeartbeats 20000000 in
set_option maxRecDepth 200000 in
theorem decLoop_ok (s : S) (nonce : BitVec 96) (c : Nat) (k : Nat → BitVec 128) (H : BitVec 128)
    (pre : LoopPre s nonce c k H) :
    ∃ s' t, execBlock I AesGcm8x192.decLoop s = some (s', t) ∧
      (∀ i < 8, s'.vg.v (blockReg i) = block s.vg.mem (s.vg.gpr .x0) i) ∧
      s'.vg.v .v19 = nistGhash H (s.vg.v .v19)
        ((List.range 8).map fun i => reverseBytesQuad32 (s.vg.v (blockReg i))) ∧
      (∀ i < 5, s'.vg.v (ctrReg i) = ctrLane nonce (c + 8 + i)) ∧
      s'.vg.v .v30 = VRevOp.rev32b.eval (ctrLane nonce (c + 13)) ∧
      s'.vg.gpr .x0 = s.vg.gpr .x0 + 128#64 ∧ s'.vg.gpr .x2 = s.vg.gpr .x2 + 128#64 ∧
      s'.vg.mem = write8 s.vg.mem (s.vg.gpr .x2)
        (fun i => block s.vg.mem (s.vg.gpr .x0) i ^^^ keystream nonce c k i) ∧
      flags s'.vg = flags (s.vg.flagsAdd (s.vg.gpr .x0 + 128#64) (~~~(s.vg.gpr .x5)) true) ∧
      Frame s s' clobbered [.x0, .x2] := by
  have k0 := pre.rkeys 0 (by decide); have k1 := pre.rkeys 1 (by decide); have k2 := pre.rkeys 2 (by decide)
  have k3 := pre.rkeys 3 (by decide); have k4 := pre.rkeys 4 (by decide); have k5 := pre.rkeys 5 (by decide)
  have k6 := pre.rkeys 6 (by decide); have k7 := pre.rkeys 7 (by decide); have k8 := pre.rkeys 8 (by decide)
  have k9 := pre.rkeys 9 (by decide); have k10 := pre.rkeys 10 (by decide)
  have k11 := pre.rkeys 11 (by decide); have k12 := pre.rkeys 12 (by decide)
  have t0 := pre.rtable 0 (by decide); have t1 := pre.rtable 1 (by decide); have t2 := pre.rtable 2 (by decide)
  have t3 := pre.rtable 3 (by decide); have t4 := pre.rtable 4 (by decide); have t5 := pre.rtable 5 (by decide)
  have t6 := pre.rtable 6 (by decide); have t7 := pre.rtable 7 (by decide); have t8 := pre.rtable 8 (by decide)
  have t9 := pre.rtable 9 (by decide); have t10 := pre.rtable 10 (by decide)
  have t11 := pre.rtable 11 (by decide)
  have i0 := pre.rin 0 (by decide); have i1 := pre.rin 1 (by decide); have i2 := pre.rin 2 (by decide)
  have i3 := pre.rin 3 (by decide); have i4 := pre.rin 4 (by decide); have i5 := pre.rin 5 (by decide)
  have i6 := pre.rin 6 (by decide); have i7 := pre.rin 7 (by decide)
  have o0 := pre.rout 0 (by decide); have o1 := pre.rout 1 (by decide); have o2 := pre.rout 2 (by decide)
  have o3 := pre.rout 3 (by decide); have o4 := pre.rout 4 (by decide); have o5 := pre.rout 5 (by decide)
  have o6 := pre.rout 6 (by decide); have o7 := pre.rout 7 (by decide)
  have rm := pre.rmod
  simp only [Nat.reduceMul] at k0 k1 k2 k3 k4 k5 k6 k7 k8 k9 k10 k11 k12 t0 t1 t2 t3 t4 t5 t6 t7 t8 t9 t10 t11
  simp only [Nat.reduceMul] at i0 i1 i2 i3 i4 i5 i6 i7 o0 o1 o2 o3 o4 o5 o6 o7
  simp only [add_zero64] at i0 o0
  have K0 := pre.keys 0 (by decide); have K1 := pre.keys 1 (by decide); have K2 := pre.keys 2 (by decide)
  have K3 := pre.keys 3 (by decide); have K4 := pre.keys 4 (by decide); have K5 := pre.keys 5 (by decide)
  have K6 := pre.keys 6 (by decide); have K7 := pre.keys 7 (by decide); have K8 := pre.keys 8 (by decide)
  have K9 := pre.keys 9 (by decide); have K10 := pre.keys 10 (by decide)
  have K11 := pre.keys 11 (by decide); have K12 := pre.keys 12 (by decide)
  simp only [Nat.reduceMul] at K0 K1 K2 K3 K4 K5 K6 K7 K8 K9 K10 K11 K12
  simp only [add_zero64] at K0
  have C0 := pre.ctr 0 (by decide); have C1 := pre.ctr 1 (by decide); have C2 := pre.ctr 2 (by decide)
  have C3 := pre.ctr 3 (by decide); have C4 := pre.ctr 4 (by decide)
  simp only [ctrReg, List.getElem!_cons_zero, List.getElem!_cons_succ, Nat.add_zero] at C0 C1 C2 C3 C4
  have C30 := pre.ctr30
  have C31 := pre.inc
  have T0 := pre.table 0 (by decide); have T1 := pre.table 1 (by decide); have T2 := pre.table 2 (by decide)
  have T3 := pre.table 3 (by decide); have T4 := pre.table 4 (by decide); have T5 := pre.table 5 (by decide)
  have T6 := pre.table 6 (by decide); have T7 := pre.table 7 (by decide); have T8 := pre.table 8 (by decide)
  have T9 := pre.table 9 (by decide); have T10 := pre.table 10 (by decide)
  have T11 := pre.table 11 (by decide)
  simp only [Nat.reduceMul, htable8, htable4, List.cons_append, List.nil_append, List.getElem!_cons_zero,
    List.getElem!_cons_succ, byteswap128_eq] at T0 T1 T2 T3 T4 T5 T6 T7 T8 T9 T10 T11
  have M := pre.modc
  apply ex2_of_eq
  · rw [execBlock_acc]
    a64_run [AesGcm8x192.decLoop, AesGcm8x192.vop, add_ofNat, VG.AArch64.addr, Rind.AArch64.ldQ,
      Rind.AArch64.stQ]
    rfl
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · intro i hi
    interval_cases i <;>
    · simp only [blockReg, List.getElem!_cons_zero, List.getElem!_cons_succ, v_setV, v_write, v_flagsAdd,
        v_setMem, reduceCtorEq, ↓reduceIte, block, Nat.reduceMul, add_zero64]
  · simp only [v_setV, v_write, v_flagsAdd, v_setMem, reduceCtorEq, ↓reduceIte]
    simp only [List.range_succ, List.range_zero, List.nil_append, List.cons_append, List.map_cons, List.map_nil,
      blockReg, List.getElem!_cons_zero, List.getElem!_cons_succ]
    rw [nistGhash_reduceAll]
    simp only [M, rev64b_eq, ext_swap, vdword_zero, vdword_one, polyMul_eq, lo_setWidth]
    rw [code_reduce']
    simp only [pows, List.length_cons, List.length_nil, Nat.reduceAdd, reduceAll, accum]
    congr 1 <;>
    · simp only [karaTerms, T0, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, karatsubaMid_eq, trn1_d2,
        trn2_d2, lo_xor, hi_xor, lo_swap, hi_swap, lo_append, hi_append]
      ac_rfl
  · intro i hi
    interval_cases i <;>
    · simp only [ctrReg, List.getElem!_cons_zero, List.getElem!_cons_succ, v_setV, v_write, v_flagsAdd,
        v_setMem, reduceCtorEq, ↓reduceIte, C0, C1, C2, C3, C4, C30, C31, rev32b_rev32b, add_ctr, Nat.add_assoc,
        Nat.reduceAdd, Nat.add_zero]
  · simp only [v_setV, ↓reduceIte, C30, C31, add_ctr, Nat.add_assoc, Nat.reduceAdd]
  · simp only [gpr_write, gpr_setV, gpr_flagsAdd, gpr_setMem, reduceCtorEq, ↓reduceIte]
  · simp only [gpr_write, gpr_setV, ↓reduceIte]
  · simp only [mem_write, mem_setV, mem_setMem]
    simp only [write8, block, keystream, ← aesRounds192_eq]
    simp only [aesRounds192, aesRound, Nat.reduceMul, add_zero64, K0, K1, K2, K3, K4, K5, K6, K7, K8, K9, K10,
      K11, K12, C0, C1, C2, C3, C4, C30, C31, rev32b_rev32b, add_ctr, Nat.add_assoc, Nat.reduceAdd, Nat.add_zero,
      BitVec.xor_assoc]
  · simp only [flags, nf_setMem, zf_setMem, vf_setMem, c_setMem, nf_write, zf_write, vf_write, c_write, nf_setV,
      zf_setV, vf_setV, c_setV]
    rfl
  · unfold clobbered
    a64_out

end rind.aarch64.gcm8x192
