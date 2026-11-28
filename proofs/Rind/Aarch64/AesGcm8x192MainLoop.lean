import Rind.Aarch64.AesGcm8x192Loop

open VG VG.AArch64 VG.VectorCrypto Rind.AArch64 rind.aarch64.asm rind.vale rind.simd rind.s2n

/-!
# aws-lc's eight-way AES-192-GCM main loops, run to their end

`encMainLoop_ok` and `decMainLoop_ok`: each main loop of
`aesv8_gcm_8x_enc_192` and `aesv8_gcm_8x_dec_192`, run in place from a
state `LoopInv` holds of at iteration 0 until its `cmp x0, x5` says stop
after `m + 1` iterations, ends in one `LoopInv` holds of at iteration
`m + 1`: the buffer's first `128 (m + 1)` bytes hold the AES-192 CTR outputs
(`memAfter`), `v19` the GHASH of every group of eight blocks of ciphertext
the loop started or produced but the last (`accAfter`), `v8`–`v15` the
last group, and the counter blocks are `8 (m + 1)` on. `LoopStatic` holds
what the loop leaves alone: the round keys, the table, and the reduction
constant, readable and outside the buffer, and the buffer writable without
wrapping. Each iteration is `encLoop_ok` or `decLoop_ok`.
-/

namespace rind.aarch64.gcm8x192

/-! ## Loops whose traces need not be known -/

/-- A loop run `m + 1` times from `Inv j`: each iteration in range keeps
`Inv` and leaves the loop's condition `go j`. -/
theorem loop_ex {body : VG.Prog I} {c : Rind.AArch64.Cond} (Inv : Nat → S → Prop) (R : Nat → Prop)
    (go : Nat → Bool)
    (hstep : ∀ j s, Inv j s → R j → ∃ s' t, Exec I body s t s' ∧ I.eval c s' = some (go j) ∧
      Inv (j + 1) s') :
    ∀ m j s, Inv j s → (∀ i ≤ m, R (j + i)) → (∀ i < m, go (j + i) = true) → go (j + m) = false →
      ∃ s' t, Exec I (.loop body c) s t s' ∧ Inv (j + m + 1) s' := by
  intro m
  induction m with
  | zero =>
    intro j s hI hR _ hg
    obtain ⟨s', t, hx, hc, hI'⟩ := hstep j s hI (by simpa using hR 0 (by omega))
    exact ⟨s', _, Exec.loopExit hx (by rw [hc]; simpa using hg), by simpa using hI'⟩
  | succ m ih =>
    intro j s hI hR hgo hg
    obtain ⟨s₁, t₁, hx, hc, hI₁⟩ := hstep j s hI (by simpa using hR 0 (by omega))
    obtain ⟨s', t', hx', hI'⟩ := ih (j + 1) s₁ hI₁
      (fun i hi => by have := hR (i + 1) (by omega); rwa [show j + (i + 1) = j + 1 + i by omega] at this)
      (fun i hi => by have := hgo (i + 1) (by omega); rwa [show j + (i + 1) = j + 1 + i by omega] at this)
      (by rwa [show j + (m + 1) = j + 1 + m by omega] at hg)
    refine ⟨s', _, Exec.loopNext hx (by rw [hc]; simpa using hgo 0 (by omega)) hx', ?_⟩
    rwa [show j + (m + 1) + 1 = j + 1 + m + 1 by omega]

/-! ## Memory the loops write -/

theorem write8_other (m : Mem) (b : Addr) (o : Nat → BitVec 128) (x : Addr) (h : 128 ≤ (x - b).toNat) :
    write8 m b o x = m x := by
  simp only [write8]
  repeat rw [write_other _ _ _ _ _ (by bv_omega)]

theorem write8_congr (m : Mem) (b : Addr) {o o' : Nat → BitVec 128} (h : ∀ i < 8, o i = o' i) :
    write8 m b o = write8 m b o' := by
  simp only [write8, h 0 (by omega), h 1 (by omega), h 2 (by omega), h 3 (by omega), h 4 (by omega),
    h 5 (by omega), h 6 (by omega), h 7 (by omega)]

/-- Memory after the first `j` iterations wrote their outputs from `p` on:
block `i` of iteration `g` is `out g i`. -/
def memAfter (m : Mem) (p : Addr) (out : Nat → Nat → BitVec 128) : Nat → Mem
  | 0 => m
  | j + 1 => write8 (memAfter m p out j) (p + BitVec.ofNat 64 (128 * j)) (out j)

/-- A byte `128 j` or more past `p`, modulo `2^64`, is as it was. -/
theorem memAfter_other (m : Mem) (p : Addr) (out : Nat → Nat → BitVec 128) (x : Addr) :
    ∀ j, 128 * j < 2 ^ 64 → 128 * j ≤ (x - p).toNat → memAfter m p out j x = m x
  | 0, _, _ => rfl
  | j + 1, hb, h => by
    rw [memAfter, write8_other _ _ _ _ (by bv_omega), memAfter_other m p out x j (by omega) (by omega)]

theorem read_memAfter (m : Mem) (p : Addr) (out : Nat → Nat → BitVec 128) (j : Nat) (a : Addr) (n : Nat)
    (hb : 128 * j < 2 ^ 64) (h : ∀ q < n, 128 * j ≤ (a + BitVec.ofNat 64 q - p).toNat) :
    (memAfter m p out j).read a n = m.read a n :=
  read_congr _ _ _ _ fun q hq => memAfter_other m p out _ j hb (h q hq)

/-! ## The invariant -/

/-- What the main loops leave alone of the state `s0` they start in: the
round keys `k` at `x11`, the table of the twisted key `H`'s powers at
`x6`, and the reduction constant at `x10`, readable and outside the first
`128 N` bytes from `x0`, which are writable, the output pointer `x2` the
input pointer, and `128 N` below `2^64`. -/
structure LoopStatic (s0 : S) (k : Nat → BitVec 128) (H : BitVec 128) (N : Nat) : Prop where
  keys : ∀ i < 13, s0.vg.mem.read (s0.vg.gpr .x11 + BitVec.ofNat 64 (16 * i)) 16 = k i
  table : ∀ i < 12, s0.vg.mem.read (s0.vg.gpr .x6 + BitVec.ofNat 64 (16 * i)) 16 = (htable8 (ghashTwist H))[i]!
  modc : s0.vg.mem.read (s0.vg.gpr .x10) 8 = 0xc200000000000000#64
  rkeys : ∀ i < 13, InRegions (s0.vg.rd ++ s0.vg.wr) (s0.vg.gpr .x11 + BitVec.ofNat 64 (16 * i)) 16
  rtable : ∀ i < 12, InRegions (s0.vg.rd ++ s0.vg.wr) (s0.vg.gpr .x6 + BitVec.ofNat 64 (16 * i)) 16
  rmod : InRegions (s0.vg.rd ++ s0.vg.wr) (s0.vg.gpr .x10) 8
  rbuf : ∀ n < 8 * N, InRegions s0.vg.wr (s0.vg.gpr .x0 + BitVec.ofNat 64 (16 * n)) 16
  inPlace : s0.vg.gpr .x2 = s0.vg.gpr .x0
  bound : 128 * N < 2 ^ 64
  dkeys : ∀ q < 208, 128 * N ≤ (s0.vg.gpr .x11 + BitVec.ofNat 64 q - s0.vg.gpr .x0).toNat
  dtable : ∀ q < 192, 128 * N ≤ (s0.vg.gpr .x6 + BitVec.ofNat 64 q - s0.vg.gpr .x0).toNat
  dmod : ∀ q < 8, 128 * N ≤ (s0.vg.gpr .x10 + BitVec.ofNat 64 q - s0.vg.gpr .x0).toNat

/-- The eight blocks iteration `g` hashes: `C0` for the first, then the
blocks the iteration before left in `v8`–`v15`. -/
def hashed (C0 : Nat → BitVec 128) (nxt : Nat → Nat → BitVec 128) : Nat → Nat → BitVec 128
  | 0 => C0
  | g + 1 => nxt g

/-- GHASH after the first `j` iterations, from `acc`, of the blocks `v g`
each iteration `g` started with. -/
def accAfter (H acc : BitVec 128) (v : Nat → Nat → BitVec 128) : Nat → BitVec 128
  | 0 => acc
  | j + 1 => nistGhash H (accAfter H acc v j) ((List.range 8).map fun i => reverseBytesQuad32 (v j i))

/-- Iteration `g`'s outputs: its input blocks, from `s0`'s memory, XORed
with the keystream of counters `c + 8 g` on. -/
def outs (s0 : S) (nonce : BitVec 96) (c : Nat) (k : Nat → BitVec 128) (g : Nat) (i : Nat) : BitVec 128 :=
  block s0.vg.mem (s0.vg.gpr .x0 + BitVec.ofNat 64 (128 * g)) i ^^^ keystream nonce (c + 8 * g) k i

/-- Iteration `g`'s input blocks, from `s0`'s memory. -/
def ins (s0 : S) (g : Nat) (i : Nat) : BitVec 128 :=
  block s0.vg.mem (s0.vg.gpr .x0 + BitVec.ofNat 64 (128 * g)) i

/-- The state at the start of iteration `j` of a main loop begun in `s0`,
which leaves the blocks `nxt g` in `v8`–`v15` after iteration `g`. -/
structure LoopInv (s0 s : S) (nonce : BitVec 96) (c : Nat) (k : Nat → BitVec 128) (H : BitVec 128)
    (nxt : Nat → Nat → BitVec 128) (j : Nat) : Prop where
  x0 : s.vg.gpr .x0 = s0.vg.gpr .x0 + BitVec.ofNat 64 (128 * j)
  x2 : s.vg.gpr .x2 = s0.vg.gpr .x0 + BitVec.ofNat 64 (128 * j)
  gpr : ∀ r, r ≠ .x0 → r ≠ .x2 → s.vg.gpr r = s0.vg.gpr r
  others : others s.vg = others s0.vg
  sp : s.vg.sp = s0.vg.sp
  x29 : s.x29 = s0.x29
  mem : s.vg.mem = memAfter s0.vg.mem (s0.vg.gpr .x0) (outs s0 nonce c k) j
  blocks : ∀ i < 8, s.vg.v (blockReg i) = hashed (fun i => s0.vg.v (blockReg i)) nxt j i
  ghash : s.vg.v .v19 = accAfter H (s0.vg.v .v19) (hashed (fun i => s0.vg.v (blockReg i)) nxt) j
  ctr : ∀ i < 5, s.vg.v (ctrReg i) = ctrLane nonce (c + 8 * j + i)
  ctr30 : s.vg.v .v30 = VRevOp.rev32b.eval (ctrLane nonce (c + 8 * j + 5))
  inc : s.vg.v .v31 = ctrInc

/-- The loop's condition after iteration `j`: `x0`, then `128 (j + 1)` past
where it started, below `x5`, as `cmp` and `b.lt` compare them. -/
def goOn (s0 : S) (j : Nat) : Bool :=
  CondCode.lt.holds (s0.vg.flagsAdd (s0.vg.gpr .x0 + BitVec.ofNat 64 (128 * (j + 1))) (~~~(s0.vg.gpr .x5)) true)

theorem rd_of_others {g g' : VG.AArch64.State} (h : others g = others g') : g.rd = g'.rd :=
  congrArg (fun o => o.2.1) h
theorem wr_of_others {g g' : VG.AArch64.State} (h : others g = others g') : g.wr = g'.wr :=
  congrArg (fun o => o.2.2.1) h

theorem inRegions_append {rs rs' : List Region} {a : Addr} {n : Nat} (h : InRegions rs' a n) :
    InRegions (rs ++ rs') a n := by
  obtain ⟨r, hr, hc⟩ := h
  exact ⟨r, List.mem_append_right _ hr, hc⟩

theorem add_128 (p : Addr) (j i : Nat) :
    p + BitVec.ofNat 64 (128 * j) + BitVec.ofNat 64 (16 * i) = p + BitVec.ofNat 64 (16 * (8 * j + i)) := by
  rw [add_ofNat]; congr 2; ring

/-- An iteration in range starts from what `LoopPre` asks. -/
theorem loopPre_of_inv {s0 s : S} {nonce : BitVec 96} {c : Nat} {k : Nat → BitVec 128} {H : BitVec 128}
    {nxt : Nat → Nat → BitVec 128} {N j : Nat} (hs : LoopStatic s0 k H N) (hI : LoopInv s0 s nonce c k H nxt j)
    (hj : j < N) : LoopPre s nonce (c + 8 * j) k H := by
  have hb : 128 * j < 2 ^ 64 := by have := hs.bound; omega
  have hrd := rd_of_others hI.others
  have hwr := wr_of_others hI.others
  have g11 := hI.gpr .x11 (by decide) (by decide)
  have g6 := hI.gpr .x6 (by decide) (by decide)
  have g10 := hI.gpr .x10 (by decide) (by decide)
  refine ⟨fun i hi => ?_, fun i hi => ?_, ?_, hI.ctr, hI.ctr30, hI.inc, fun i hi => ?_, fun i hi => ?_, ?_,
    fun i hi => ?_, fun i hi => ?_⟩
  · rw [hI.mem, g11, read_memAfter _ _ _ _ _ _ hb fun q hq => by
      have := hs.dkeys (16 * i + q) (by omega); rw [add_ofNat]; omega]
    exact hs.keys i hi
  · rw [hI.mem, g6, read_memAfter _ _ _ _ _ _ hb fun q hq => by
      have := hs.dtable (16 * i + q) (by omega); rw [add_ofNat]; omega]
    exact hs.table i hi
  · rw [hI.mem, g10, read_memAfter _ _ _ _ _ _ hb fun q hq => by
      have := hs.dmod q hq; omega]
    exact hs.modc
  · rw [hrd, hwr, g11]; exact hs.rkeys i hi
  · rw [hrd, hwr, g6]; exact hs.rtable i hi
  · rw [hrd, hwr, g10]; exact hs.rmod
  · rw [hrd, hwr, hI.x0, add_128]; exact inRegions_append (hs.rbuf _ (by omega))
  · rw [hwr, hI.x2, add_128]; exact hs.rbuf _ (by omega)

/-- Block `i` at iteration `j`'s input pointer is still `s0`'s. -/
theorem block_inv {s0 s : S} {nonce : BitVec 96} {c : Nat} {k : Nat → BitVec 128} {H : BitVec 128}
    {nxt : Nat → Nat → BitVec 128} {N j : Nat} (hs : LoopStatic s0 k H N) (hI : LoopInv s0 s nonce c k H nxt j)
    (hj : j < N) {i : Nat} (hi : i < 8) : block s.vg.mem (s.vg.gpr .x0) i = ins s0 j i := by
  have hb : 128 * j < 2 ^ 64 := by have := hs.bound; omega
  rw [block, ins, block, hI.mem, hI.x0, read_memAfter _ _ _ _ _ _ hb fun q hq => by
    have := hs.bound
    rw [add_128, add_ofNat, add_sub_left, BitVec.toNat_ofNat, Nat.mod_eq_of_lt (by omega)]
    omega]

theorem holds_lt_of_flags {g g' : VG.AArch64.State} (h : flags g = flags g') :
    CondCode.lt.holds g = CondCode.lt.holds g' := by
  simp only [flags, Prod.mk.injEq] at h
  simp only [CondCode.holds, h]

theorem holds_flagsAdd (g g' : VG.AArch64.State) (a b : BitVec 64) :
    CondCode.lt.holds (g.flagsAdd a b true) = CondCode.lt.holds (g'.flagsAdd a b true) := rfl

/-- `x0` after iteration `j`: `128 (j + 1)` past where the loop began. -/
theorem x0_step (p : Addr) (j : Nat) :
    p + BitVec.ofNat 64 (128 * j) + 128#64 = p + BitVec.ofNat 64 (128 * (j + 1)) := by
  rw [show (128#64 : BitVec 64) = BitVec.ofNat 64 128 from rfl, add_ofNat, show 128 * (j + 1) = 128 * j + 128 by ring]

/-- The start of a main loop, in place, with the counter blocks in their
registers, is iteration 0 of it. -/
theorem loopInv_zero {s0 : S} {nonce : BitVec 96} {c : Nat} {k : Nat → BitVec 128} {H : BitVec 128}
    {nxt : Nat → Nat → BitVec 128} (hp : s0.vg.gpr .x2 = s0.vg.gpr .x0)
    (hctr : ∀ i < 5, s0.vg.v (ctrReg i) = ctrLane nonce (c + i))
    (h30 : s0.vg.v .v30 = VRevOp.rev32b.eval (ctrLane nonce (c + 5))) (h31 : s0.vg.v .v31 = ctrInc) :
    LoopInv s0 s0 nonce c k H nxt 0 := by
  refine ⟨by simp, by simp [hp], fun _ _ _ => rfl, rfl, rfl, rfl, rfl,
    fun _ _ => rfl, rfl, fun i hi => by simpa using hctr i hi, by simpa using h30, h31⟩

set_option maxHeartbeats 1000000 in
/-- An iteration of the encrypt loop keeps `LoopInv`. -/
theorem encStep {s0 : S} {nonce : BitVec 96} {c : Nat} {k : Nat → BitVec 128} {H : BitVec 128} {N : Nat}
    (hs : LoopStatic s0 k H N) (j : Nat) (s : S) (hI : LoopInv s0 s nonce c k H (outs s0 nonce c k) j)
    (hj : j < N) :
    ∃ s' t, Exec I (.block AesGcm8x192.encLoop) s t s' ∧ I.eval (.flags .lt) s' = some (goOn s0 j) ∧
      LoopInv s0 s' nonce c k H (outs s0 nonce c k) (j + 1) := by
  obtain ⟨s', t, hx, hb, hg, hc, h30, hx0, hx2, hm, hf, hfr⟩ :=
    encLoop_ok s nonce (c + 8 * j) k H (loopPre_of_inv hs hI hj)
  have hblk : ∀ i < 8, block s.vg.mem (s.vg.gpr .x0) i ^^^ keystream nonce (c + 8 * j) k i =
      outs s0 nonce c k j i := fun i hi => by rw [block_inv hs hI hj hi]; rfl
  refine ⟨s', t, Exec.block hx, ?_, ?_⟩
  · show some (CondCode.lt.holds s'.vg) = some (goOn s0 j)
    rw [holds_lt_of_flags hf, goOn, hI.x0, hI.gpr .x5 (by decide) (by decide), x0_step, holds_flagsAdd s.vg s0.vg]
  refine ⟨by rw [hx0, hI.x0, x0_step], by rw [hx2, hI.x2, x0_step], fun r h0 h2 => ?_,
    hfr.others.trans hI.others, hfr.sp.trans hI.sp, hfr.x29.trans hI.x29, ?_, fun i hi => ?_, ?_,
    fun i hi => ?_, ?_, ?_⟩
  · rw [hfr.gpr r (by simp [h0, h2]), hI.gpr r h0 h2]
  · rw [hm, write8_congr _ _ (o' := outs s0 nonce c k j) hblk, hI.mem, hI.x2]; rfl
  · rw [hb i hi, hblk i hi]; rfl
  · rw [hg, hI.ghash]
    exact congrArg _ (List.map_congr_left fun i hi => by rw [hI.blocks i (List.mem_range.1 hi)])
  · rw [hc i hi, show c + 8 * (j + 1) + i = c + 8 * j + 8 + i by ring]
  · rw [h30, show c + 8 * (j + 1) + 5 = c + 8 * j + 13 by ring]
  · rw [hfr.v .v31 (by decide), hI.inc]

set_option maxHeartbeats 1000000 in
/-- An iteration of the decrypt loop keeps `LoopInv`. -/
theorem decStep {s0 : S} {nonce : BitVec 96} {c : Nat} {k : Nat → BitVec 128} {H : BitVec 128} {N : Nat}
    (hs : LoopStatic s0 k H N) (j : Nat) (s : S) (hI : LoopInv s0 s nonce c k H (ins s0) j)
    (hj : j < N) :
    ∃ s' t, Exec I (.block AesGcm8x192.decLoop) s t s' ∧ I.eval (.flags .lt) s' = some (goOn s0 j) ∧
      LoopInv s0 s' nonce c k H (ins s0) (j + 1) := by
  obtain ⟨s', t, hx, hb, hg, hc, h30, hx0, hx2, hm, hf, hfr⟩ :=
    decLoop_ok s nonce (c + 8 * j) k H (loopPre_of_inv hs hI hj)
  have hblk : ∀ i < 8, block s.vg.mem (s.vg.gpr .x0) i ^^^ keystream nonce (c + 8 * j) k i =
      outs s0 nonce c k j i := fun i hi => by rw [block_inv hs hI hj hi]; rfl
  refine ⟨s', t, Exec.block hx, ?_, ?_⟩
  · show some (CondCode.lt.holds s'.vg) = some (goOn s0 j)
    rw [holds_lt_of_flags hf, goOn, hI.x0, hI.gpr .x5 (by decide) (by decide), x0_step, holds_flagsAdd s.vg s0.vg]
  refine ⟨by rw [hx0, hI.x0, x0_step], by rw [hx2, hI.x2, x0_step], fun r h0 h2 => ?_,
    hfr.others.trans hI.others, hfr.sp.trans hI.sp, hfr.x29.trans hI.x29, ?_, fun i hi => ?_, ?_,
    fun i hi => ?_, ?_, ?_⟩
  · rw [hfr.gpr r (by simp [h0, h2]), hI.gpr r h0 h2]
  · rw [hm, write8_congr _ _ (o' := outs s0 nonce c k j) hblk, hI.mem, hI.x2]; rfl
  · rw [hb i hi, block_inv hs hI hj hi]; rfl
  · rw [hg, hI.ghash]
    exact congrArg _ (List.map_congr_left fun i hi => by rw [hI.blocks i (List.mem_range.1 hi)])
  · rw [hc i hi, show c + 8 * (j + 1) + i = c + 8 * j + 8 + i by ring]
  · rw [h30, show c + 8 * (j + 1) + 5 = c + 8 * j + 13 by ring]
  · rw [hfr.v .v31 (by decide), hI.inc]

/-- The encrypt main loop, from iteration 0 in place until its compare says
stop after `m + 1` iterations, all within the `N` groups `LoopStatic`
allows: the first `m + 1` groups of the buffer hold their AES-192 CTR
outputs (`memAfter`), `v8`–`v15` the last of them, `v19` the GHASH of the
groups before it from the blocks `v8`–`v15` held at the start
(`accAfter`), and the counter blocks are `8 (m + 1)` further on. -/
theorem encMainLoop_ok {s0 : S} {nonce : BitVec 96} {c : Nat} {k : Nat → BitVec 128} {H : BitVec 128}
    {N : Nat} (hs : LoopStatic s0 k H N) (h0 : LoopInv s0 s0 nonce c k H (outs s0 nonce c k) 0) (m : Nat)
    (hm : m < N) (hgo : ∀ i < m, goOn s0 i = true) (hstop : goOn s0 m = false) :
    ∃ s' t, Exec I (.loop (.block AesGcm8x192.encLoop) (.flags .lt)) s0 t s' ∧
      LoopInv s0 s' nonce c k H (outs s0 nonce c k) (m + 1) := by
  have := loop_ex (fun j s => LoopInv s0 s nonce c k H (outs s0 nonce c k) j) (· < N) (goOn s0)
    (fun j s hI hj => encStep hs j s hI hj) m 0 s0 h0 (fun i hi => by omega)
    (fun i hi => by simpa using hgo i hi) (by simpa using hstop)
  simpa using this

/-- The decrypt main loop, as `encMainLoop_ok`: the buffer's first
`m + 1` groups hold their outputs, and `v8`–`v15` the last group of
ciphertext it read. -/
theorem decMainLoop_ok {s0 : S} {nonce : BitVec 96} {c : Nat} {k : Nat → BitVec 128} {H : BitVec 128}
    {N : Nat} (hs : LoopStatic s0 k H N) (h0 : LoopInv s0 s0 nonce c k H (ins s0) 0) (m : Nat)
    (hm : m < N) (hgo : ∀ i < m, goOn s0 i = true) (hstop : goOn s0 m = false) :
    ∃ s' t, Exec I (.loop (.block AesGcm8x192.decLoop) (.flags .lt)) s0 t s' ∧
      LoopInv s0 s' nonce c k H (ins s0) (m + 1) := by
  have := loop_ex (fun j s => LoopInv s0 s nonce c k H (ins s0) j) (· < N) (goOn s0)
    (fun j s hI hj => decStep hs j s hI hj) m 0 s0 h0 (fun i hi => by omega)
    (fun i hi => by simpa using hgo i hi) (by simpa using hstop)
  simpa using this

end rind.aarch64.gcm8x192

/-- info: 'rind.aarch64.gcm8x192.encMainLoop_ok' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms rind.aarch64.gcm8x192.encMainLoop_ok

/-- info: 'rind.aarch64.gcm8x192.decMainLoop_ok' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms rind.aarch64.gcm8x192.decMainLoop_ok
