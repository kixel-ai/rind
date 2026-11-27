import VerifiedGarbage.TCB.X86_64.Encode

/-!
# rind's extension of VG's x86_64 model

**Trusted.** VG's model (`VerifiedGarbage/TCB/X86_64/`) covers the
instructions VG's own code uses, and keeps the stack pointer to VG's nested
frames of under a page. aws-lc's Montgomery routines make their own frame:
they push the callee-saved registers, move `rsp` down past their scratch
space by `lea`, a page at a time with a probing load at each, and restore
`rsp` from a saved copy in one `lea`. They also use `neg`, `dec`, `ja`,
aligned `movdqa` to and from memory, `imul` of a memory operand, encodings
of VG's `mov` and `mulx` longer than VG's encoder emits, which aws-lc writes
as bytes, and padding the assembler lays out; aws-lc's Poly1305 also uses
`shrd`. aws-lc's ChaCha20-Poly1305 seal and open also pop the registers they
push, move `rsp` by `sub` and `add`, use `inc`, `cmovg`, the signed and
`jbe` branches, SSE4.1's byte inserts and extracts, `pextrq`, SSE and AVX
operands RIP-relative to a static, legacy SSE instructions with an aligned
memory source, and aligned `vmovdqa` to and from memory. This model is VG's
with those added: its state is VG's with the
lowest address the stack may reach, its instructions are VG's, run by VG's
semantics, and those below, each transcribing the pseudocode of the Intel
SDM Vol. 2 the docs cite, in VG's style, so that the leakage model of
`TCB/Code.lean` applies unchanged: every memory access faults outside the
state's regions, and leaks its address.

The stack: the region at the head of `wr` is the part of the stack the
function has claimed, from `rsp` up. A push or a `lea` that lowers `rsp`
grows it down to the new `rsp`, faulting below `lo`; a `lea` that raises
`rsp` shrinks it, and the bytes it releases are below the stack pointer,
where the system may change them, so they take values the model does not
know, as VG's `lose` gives them for a frame VG's model pops. So the
function reaches its stack only at or above `rsp`, as the System V ABI
lets it rely on, and only above `lo`, which its theorem states the stack
holds: a guard page below the stack is the system's, beyond the model.

A RIP-relative operand (`SymOp`) is the static's address in the state
(`syms`, which VG's `leaSym` reads) plus its displacement: the linker puts
the distance to it in the instruction's 32-bit displacement, which `layout`
leaves 0 with a relocation (`Reloc`) naming the static, as the object file
does.

`admin/prove vg` cosimulates each of these instructions against the CPU
(`Cosim/RindX86_64.lean`), and `admin/prove lean` checks that each program's
bytes and relocations (`layout`) are the ones rind's build emits.
-/

namespace Rind.X86_64

open VG VG.X86_64

/-- VG's machine state with `lo`, the lowest address the function's stack
may reach, which no instruction changes. -/
structure State where
  vg : VG.X86_64.State
  lo : Addr

/-- Branch conditions: VG's, and `ja`, `jbe`, `jg`, `jge`, `jl`, and `jle`. -/
inductive Cond
  | vg (c : VG.X86_64.Cond)
  /-- `ja`: CF = 0 and ZF = 0 -/
  | a
  /-- `jbe`: CF = 1 or ZF = 1 -/
  | be
  /-- `jg`: ZF = 0 and SF = OF -/
  | g
  /-- `jge`: SF = OF -/
  | ge
  /-- `jl`: SF ≠ OF -/
  | l
  /-- `jle`: ZF = 1 or SF ≠ OF -/
  | le
  deriving DecidableEq, Repr

/-- SDM Vol. 2, "Jcc": A, "above (CF=0 and ZF=0)"; BE, "below or equal (CF=1
or ZF=1)"; G, "greater (ZF=0 and SF=OF)"; GE, "greater or equal (SF=OF)"; L,
"less (SF≠ OF)"; LE, "less or equal (ZF=1 or SF≠ OF)"; VG's for its own. `none`, and so a fault, if a flag it reads
is undefined. -/
def eval : Cond → VG.X86_64.State → Option Bool
  | .vg c, s => VG.X86_64.eval c s
  | .a, s => s.cf.bind fun c => s.zf.map fun z => !c && !z
  | .be, s => s.cf.bind fun c => s.zf.map fun z => c || z
  | .g, s => s.zf.bind fun z => s.sf.bind fun f => s.of.map fun o => !z && f == o
  | .ge, s => s.sf.bind fun f => s.of.map fun o => f == o
  | .l, s => s.sf.bind fun f => s.of.map fun o => f != o
  | .le, s => s.zf.bind fun z => s.sf.bind fun f => s.of.map fun o => z || f != o

/-- A RIP-relative memory operand: `disp` bytes past the static `name`. -/
structure SymOp where
  name : String
  disp : Int
  deriving DecidableEq, Repr

/-- A memory operand: VG's `[base + index * scale + disp]`, or RIP-relative
to a static. -/
inductive Mem
  | op (m : MemOp)
  | sym (s : SymOp)
  deriving DecidableEq, Repr

/-- The address of a memory operand. -/
def Mem.ea (g : VG.X86_64.State) : Mem → Addr
  | .op m => g.ea m
  | .sym s => g.syms s.name + BitVec.ofInt 64 s.disp

inductive Instr
  /-- An instruction of VG's model, with VG's semantics. -/
  | vg (i : VG.X86_64.Instr)
  /-- `push r64` (`50+rd`), `r` not `rsp` -/
  | push (r : Reg)
  /-- `pop r64` (`58+rd`), `r` not `rsp` -/
  | pop (r : Reg)
  /-- `add` or `sub rsp, imm` (`REX.W 83 /0` or `/5 ib`, `81 /0` or `/5
  id`): moves the stack pointer -/
  | aluRsp (op : AluOp) (v : BitVec 32)
  /-- `lea r64, m` (`REX.W 8D /r`), `d` not `rsp` -/
  | lea (d : Reg) (m : MemOp)
  /-- `lea rsp, m` (`REX.W 8D /r`): moves the stack pointer -/
  | leaRsp (m : MemOp)
  /-- `neg r64` (`REX.W F7 /3`) -/
  | neg (d : Reg)
  /-- `dec r64` (`REX.W FF /1`) -/
  | dec (d : Reg)
  /-- `inc r64` (`REX.W FF /0`) -/
  | inc (d : Reg)
  /-- `cmovcc r64, r64` (`REX.W 0F 40+cc /r`) on one of this model's
  conditions -/
  | cmov (c : Cond) (d s : Reg)
  /-- `lea r64, [rip + s]` (`REX.W 8D /r`), `d` not `rsp` -/
  | leaSym (d : Reg) (s : SymOp)
  /-- `shrd r64, r64, imm8` (`REX.W 0F AC /r ib`): `d` shifted right by `n`,
  filled from the low bits of `s` -/
  | shrd (d s : Reg) (n : Nat)
  /-- `movdqa xmm, XMMWORD PTR m` (`66 0F 6F /r`) -/
  | movdqaLoad (d : XReg) (m : MemOp)
  /-- `movdqa XMMWORD PTR m, xmm` (`66 0F 7F /r`) -/
  | movdqaStore (m : MemOp) (s : XReg)
  /-- One of VG's legacy SSE instructions with its source the 16 bytes at
  `m` (`movdqa`, `paddd`, `pand`, `pxor`, `pshufb`, …), in VG's encoding
  with a memory operand -/
  | xload (op : XBinOp) (d : XReg) (m : Mem)
  /-- One of VG's VEX instructions with its second source RIP-relative
  (`vbinLoad`'s) -/
  | vbinSym (op : VBinOp) (l : VLen) (d a : XReg) (s : SymOp)
  /-- `vmovdqa xmm/ymm, m` (`VEX.128/256.66.0F.WIG 6F /r`) -/
  | vmovdqaLoad (l : VLen) (d : XReg) (m : Mem)
  /-- `vmovdqa m, xmm/ymm` (`VEX.128/256.66.0F.WIG 7F /r`) -/
  | vmovdqaStore (l : VLen) (m : MemOp) (s : XReg)
  /-- `pinsrb xmm, BYTE PTR m, imm8` (`66 0F 3A 20 /r ib`) -/
  | pinsrb (d : XReg) (m : MemOp) (i : Nat)
  /-- `pextrb BYTE PTR m, xmm, imm8` (`66 0F 3A 14 /r ib`) -/
  | pextrb (m : MemOp) (s : XReg) (i : Nat)
  /-- `pextrq r64, xmm, imm8` (`66 REX.W 0F 3A 16 /r ib`) -/
  | pextrq (d : Reg) (s : XReg) (i : Nat)
  /-- `imul r64, QWORD PTR m` (`REX.W 0F AF /r`) -/
  | imulMem (d : Reg) (m : MemOp)
  /-- `mov r64, r64` (`REX.W 89 /r`) after `n` address-size prefixes (`67`),
  which aws-lc writes as `.byte 0x67` to pad its code -/
  | movPad (n : Nat) (d s : Reg)
  /-- `mulx hi, lo, QWORD PTR [b + d]` (`VEX.LZ.F2.0F38.W1 F6 /r`) with a
  32-bit displacement (ModR/M `mod = 10`), however short `d` is, as aws-lc
  writes it in bytes -/
  | mulxD32 (hi lo : Reg) (m : MemOp)
  /-- The assembler's padding to the next multiple of `n` bytes, `n` a power
  of two up to 64, which runs as no instructions: see `padding`. -/
  | align (n : Nat)
  /-- `jmp` over the padding to the next multiple of `n` bytes (`EB cb`),
  then that padding: what aws-lc writes as `jmp L` before `.align n` and
  `L:`, which runs as no instructions. -/
  | jmpAlign (n : Nat)
  deriving DecidableEq, Repr

/-- The stack's claimed region, at the head of `wr`: its length, if it
starts at `rsp`. -/
def claimed (g : VG.X86_64.State) : Option Nat :=
  match g.wr with
  | r :: _ => if r.base = g.gpr .rsp then some r.len else none
  | [] => none

/-- Move `rsp` to `v`, growing or shrinking the claimed region (see the
module docs): `none` below `lo`, above the claimed region, or if it is not
at the head of `wr`. Released bytes are VG's `lose`'s, two of the state's
`unknowns` for each quadword or part of one. -/
def moveSp (s : State) (v : Addr) : Option State :=
  let g := s.vg
  let sp := g.gpr .rsp
  (claimed g).bind fun n =>
    if s.lo.toNat ≤ v.toNat ∧ v.toNat ≤ sp.toNat then
      some { s with vg := { g.setReg .rsp v with wr := ⟨v, n + (sp.toNat - v.toNat)⟩ :: g.wr.tail } }
    else if sp.toNat < v.toNat ∧ v.toNat - sp.toNat ≤ n then
      let d := v.toNat - sp.toNat
      some { s with vg := { g.setReg .rsp v with
        wr := ⟨v, n - d⟩ :: g.wr.tail, mem := lose g.mem sp d g.unknowns
        unknowns := fun i => g.unknowns (i + 2 * ((d + 7) / 8)) } }
    else none

/-- Semantics:
* VG's instructions: VG's `exec`, on VG's part of the state.
* "PUSH" (`50+rd`, 64-bit operand and stack address size): `RSP := RSP − 8;
  Memory[SS:RSP] := SRC`; no flags are affected. The stack grows to the new
  `rsp` (`moveSp`), then the store, which faults outside `wr`.
* "POP" (`58+rd`): `DEST := SS:RSP; RSP := RSP + 8`; no flags are affected.
  The load, which faults outside the readable regions, then the stack
  shrinks to the new `rsp` (`moveSp`).
* "ADD" and "SUB" of an immediate into `rsp`: VG's `alu`'s result and
  flags, the stack pointer moved through `moveSp`.
* "LEA" (`REX.W 8D /r`): `DEST := EffectiveAddress(SRC)`, modulo 2⁶⁴; no
  flags are affected and no memory is accessed. Into `rsp`, through
  `moveSp`. RIP-relative (`leaSym`), the static's address plus the
  displacement.
* "NEG": `IF DEST = 0 THEN CF := 0; ELSE CF := 1; FI; DEST := [– (DEST)]`;
  "The OF, SF, ZF, AF, and PF flags are set according to the result": those
  of the subtraction `0 - DEST`.
* "DEC": `DEST := DEST – 1`; "The CF flag is not affected. The OF, SF, ZF,
  AF, and PF flags are set according to the result": those of the
  subtraction `DEST - 1`. "INC": `DEST := DEST + 1`, likewise those of the
  addition `DEST + 1`.
* "CMOVcc": `IF condition TRUE THEN DEST := SRC FI`, 64-bit, the condition
  as `eval`'s, faulting where it reads an undefined flag.
* "SHRD" (`REX.W 0F AC /r ib`), for a count `n` from 1 to 63 (larger
  counts are not modelled: they fault): `DEST` is `DEST` shifted right `n`
  bits, filled from the right of `SRC`; "the CF flag is filled with the last
  bit shifted out of the destination operand"; "For a 1-bit shift, the OF
  flag is set if a sign change occurred; otherwise, it is cleared. For shifts
  greater than 1 bit, the OF flag is undefined"; "The SF, ZF, and PF flags are
  set according to the value of the result", as VG's `shld`.
* "MOVDQA" (`66 0F 6F /r`, `66 0F 7F /r`): `DEST := SRC`, 16 bytes,
  little-endian; "When the source or destination operand is a memory
  operand, the operand must be aligned on a 16-byte boundary or a
  general-protection exception (#GP) will be generated": so it faults
  unless the address is a multiple of 16. The legacy SSE form leaves bits
  511:128 of the register unchanged (`setXmm`).
* VG's legacy SSE instructions with a memory source (`xload`): as the
  register form, with the source the 16 bytes at the address; "the
  operand must be aligned on a 16-byte boundary or a general-protection
  exception (#GP) will be generated" (SDM Vol. 1 §11.4.1 and each page's
  "SIMD Floating-Point Exceptions", but MOVDQU's), so it faults unless the
  address is a multiple of 16.
* VG's VEX instructions with a RIP-relative source (`vbinSym`): VG's
  `vbinLoad` at the static's address plus the displacement.
* "MOVDQA" (VEX.128 and VEX.256 encoded VMOVDQA) to or from memory: VG's
  `vmovdquLoad` and `vmovdquStore`, and "When the source or destination
  operand is a memory operand, the operand must be aligned on a 16 (EVEX.128)
  /32 (EVEX.256)/64 (EVEX.512)-byte boundary", so it faults unless the
  address is a multiple of 16 or 32.
* "PINSRB" (`66 0F 3A 20 /r ib`): `SEL := COUNT[3:0]; MASK := (0FFH << (SEL *
  8)); TEMP := (((SRC[7:0] << (SEL * 8)) AND MASK); DEST := ((DEST AND NOT
  MASK) OR TEMP)`, bits 511:128 unchanged; "PEXTRB" (`66 0F 3A 14 /r ib`):
  the byte `SRC_Offset := imm8[3:0]` of the source to memory; "PEXTRQ" (`66
  REX.W 0F 3A 16 /r ib`): `SRC_Offset := imm8[0]; r64/m64 := (Src >>
  SRC_Offset * 64)`. An index past the register is not modelled: it
  faults.
* "IMUL" (`REX.W 0F AF /r`, `IMUL r64, r/m64`) with a memory source: as
  VG's `execImul` with the quadword at `m` for the register source,
  `TMP_XP := DEST ∗ SRC; DEST := TruncateToOperandSize(TMP_XP)`, CF and OF
  set if the sign-extended result differs from `TMP_XP`, SF and ZF
  undefined; it faults outside the readable regions.
* `movPad`: VG's `mov` between registers. "Using this prefix [67H] … when
  operands for the instruction do not reside in memory is reserved", SDM
  Vol. 2, §2.1.1: the model takes the prefix to change nothing, as aws-lc's
  use of it as padding assumes, and `admin/prove vg` checks on the CPU.
* `mulxD32`: VG's `mulx` of the memory operand, whose encoding (SDM Vol. 2,
  §2.1.5, "32-bit displacement") changes only the instruction's length.
* The padding (`align`, `jmpAlign`): no change. Its bytes are `padding`'s,
  long NOPs, which access no memory (SDM Vol. 2, "NOP": "The memory operand
  form of the instruction allows software to create a byte sequence of “no
  operation” as one instruction"), and the jump's target is the end of the
  padding. -/
def exec : Instr → State → Option State
  | .vg i, s => (VG.X86_64.exec i s.vg).map fun g => { s with vg := g }
  | .push r, s =>
    if r = .rsp then none
    else (moveSp s (s.vg.gpr .rsp - 8)).bind fun s' =>
      (s'.vg.store64 (s'.vg.gpr .rsp) (s.vg.gpr r)).map fun g => { s' with vg := g }
  | .pop r, s =>
    if r = .rsp then none
    else (s.vg.load64 (s.vg.gpr .rsp)).bind fun v =>
      (moveSp s (s.vg.gpr .rsp + 8)).map fun s' => { s' with vg := s'.vg.setReg r v }
  | .aluRsp op v, s =>
    if op = .add ∨ op = .sub then
      (VG.X86_64.exec (.alu op .rsp (.imm v)) s.vg).bind fun g =>
        moveSp { s with vg := s.vg.setFlags g.cf g.of g.zf g.sf } (g.gpr .rsp)
    else none
  | .lea d m, s => if d = .rsp then none else some { s with vg := s.vg.setReg d (s.vg.ea m) }
  | .leaSym d m, s => if d = .rsp then none else some { s with vg := s.vg.setReg d ((Mem.sym m).ea s.vg) }
  | .leaRsp m, s => moveSp s (s.vg.ea m)
  | .neg d, s =>
    let a := s.vg.gpr d
    let r := 0 - a
    some { s with vg := (arithFlags s.vg r (a ≠ 0) (subOverflow 0 a r)).setReg d r }
  | .dec d, s =>
    let a := s.vg.gpr d
    let r := a - 1
    some { s with vg := ({ arithFlags s.vg r false (subOverflow a 1 r) with cf := s.vg.cf }).setReg d r }
  | .inc d, s =>
    let a := s.vg.gpr d
    let r := a + 1
    some { s with vg := ({ arithFlags s.vg r false (addOverflow a 1 r) with cf := s.vg.cf }).setReg d r }
  | .cmov c d r, s => (eval c s.vg).map fun b => if b then { s with vg := s.vg.setReg d (s.vg.gpr r) } else s
  | .shrd d r n, s =>
    if 1 ≤ n ∧ n ≤ 63 then
      let a := s.vg.gpr d
      let v := (a >>> n) ||| (s.vg.gpr r <<< (64 - n))
      some { s with vg := (s.vg.setFlags (some (a.getLsbD (n - 1))) (if n = 1 then some (v.msb != a.msb) else none)
        (some (v == 0)) (some v.msb)).setReg d v }
    else none
  | .movdqaLoad d m, s =>
    let a := s.vg.ea m
    if a.toNat % 16 = 0 then (s.vg.load128 a).map fun v => { s with vg := s.vg.setXmm d v } else none
  | .movdqaStore m r, s =>
    let a := s.vg.ea m
    if a.toNat % 16 = 0 then (s.vg.store128 a (s.vg.xmm r)).map fun g => { s with vg := g } else none
  | .xload op d m, s =>
    let a := m.ea s.vg
    if a.toNat % 16 = 0 then (s.vg.load128 a).map fun v => { s with vg := s.vg.setXmm d (op.eval (s.vg.xmm d) v) }
    else none
  | .vbinSym op .l128 d a m, s => ((s.vg.load128 ((Mem.sym m).ea s.vg)).map fun v =>
    s.vg.setV .l128 d (op.sse.eval (s.vg.lane a 0) v) 0).map fun g => { s with vg := g }
  | .vbinSym op .l256 d a m, s => ((s.vg.load256 ((Mem.sym m).ea s.vg)).map fun v =>
    s.vg.setV .l256 d (op.sse.eval (s.vg.lane a 0) (v.extractLsb' 0 128))
      (op.sse.eval (s.vg.lane a 1) (v.extractLsb' 128 128))).map fun g => { s with vg := g }
  | .vmovdqaLoad .l128 d m, s =>
    let a := m.ea s.vg
    if a.toNat % 16 = 0 then (s.vg.load128 a).map fun v => { s with vg := s.vg.setV .l128 d v 0 } else none
  | .vmovdqaLoad .l256 d m, s =>
    let a := m.ea s.vg
    if a.toNat % 32 = 0 then (s.vg.load256 a).map fun v =>
      { s with vg := s.vg.setV .l256 d (v.extractLsb' 0 128) (v.extractLsb' 128 128) }
    else none
  | .vmovdqaStore .l128 m r, s =>
    let a := s.vg.ea m
    if a.toNat % 16 = 0 then (s.vg.store128 a (s.vg.xmm r)).map fun g => { s with vg := g } else none
  | .vmovdqaStore .l256 m r, s =>
    let a := s.vg.ea m
    if a.toNat % 32 = 0 then (s.vg.store256 a (s.vg.ymm r)).map fun g => { s with vg := g } else none
  | .pinsrb d m i, s =>
    if i < 16 then (s.vg.load8 (s.vg.ea m)).map fun b =>
      let mask : BitVec 128 := BitVec.shiftLeft 0xFF (8 * i)
      let byte : BitVec 128 := BitVec.shiftLeft (b.setWidth 128) (8 * i)
      { s with vg := s.vg.setXmm d ((s.vg.xmm d &&& ~~~mask) ||| byte) }
    else none
  | .pextrb m r i, s =>
    if i < 16 then (s.vg.store8 (s.vg.ea m) ((s.vg.xmm r).extractLsb' (8 * i) 8)).map fun g => { s with vg := g }
    else none
  | .pextrq d r i, s =>
    if i < 2 then some { s with vg := s.vg.setReg d ((s.vg.xmm r).extractLsb' (64 * i) 64) } else none
  | .imulMem d m, s => (s.vg.load64 (s.vg.ea m)).map fun b =>
    let t := (s.vg.gpr d).toInt * b.toInt
    let r : BitVec 64 := BitVec.ofInt 64 t
    let o := r.toInt != t
    { s with vg := (s.vg.setFlags (some o) (some o) none none).setReg d r }
  | .movPad _ d r, s => (VG.X86_64.exec (.mov d (.reg r)) s.vg).map fun g => { s with vg := g }
  | .mulxD32 hi lo m, s => (VG.X86_64.exec (.mulx hi lo (.mem m)) s.vg).map fun g => { s with vg := g }
  | .align _, s | .jmpAlign _, s => some s

/-- The addresses an instruction accesses: VG's for its own, and for the
others the quadword a push stores or a pop loads, the bytes a `movdqa`,
`vmovdqa`, `pinsrb`, or `pextrb` moves, or the memory operand an `imul`, a
`mulx`, or an SSE or AVX instruction reads, each at its start, as VG's. -/
def addrs : Instr → State → List Addr
  | .vg i, s => VG.X86_64.addrs i s.vg
  | .push _, s => [s.vg.gpr .rsp - 8]
  | .pop _, s => [s.vg.gpr .rsp]
  | .movdqaLoad _ m, s | .movdqaStore m _, s | .imulMem _ m, s | .mulxD32 _ _ m, s
  | .vmovdqaStore _ m _, s | .pinsrb _ m _, s | .pextrb m _ _, s => [s.vg.ea m]
  | .xload _ _ m, s | .vmovdqaLoad _ _ m, s => [m.ea s.vg]
  | .vbinSym _ _ _ _ m, s => [(Mem.sym m).ea s.vg]
  | .aluRsp .., _ | .lea .., _ | .leaSym .., _ | .leaRsp _, _ | .neg _, _ | .dec _, _ | .inc _, _
  | .cmov .., _ | .shrd .., _ | .movPad .., _ | .pextrq .., _ | .align _, _ | .jmpAlign _, _ => []

/-- The CPU features beyond the baseline: VG's for its own and for the
forms of VG's instructions here, SSE4.1 for `pinsrb`, `pextrb`, and
`pextrq`, AVX for `vmovdqa`, and none for the others, which are x86-64 and
SSE2 baseline instructions. -/
def Instr.requires : Instr → List String
  | .vg i => i.requires
  | .mulxD32 .. => ["bmi2"]
  | .xload op d _ => (VG.X86_64.Instr.xop (.bin op d d)).requires
  | .vbinSym op l d a _ => (VG.X86_64.Instr.vop (.vbin op l d a a)).requires
  | .vmovdqaLoad .. | .vmovdqaStore .. => ["avx"]
  | .pinsrb .. | .pextrb .. | .pextrq .. => ["sse4.1"]
  | _ => []

/-- The model. No program here calls or makes a frame of VG's kind, so
calls, returns, and VG's pushes and pops fault: a function's return is the
`ret` `function` appends, to the return address its theorem shows it
keeps. -/
abbrev isa : ISA where
  State := State
  Instr := Instr
  Cond := Cond
  exec := exec
  addrs := addrs
  eval c s := Rind.X86_64.eval c s.vg
  call _ := none
  callAddrs _ := []
  ret _ _ := none
  retAddrs _ := []
  writesSp
    | .push _ | .pop _ | .aluRsp .. | .leaRsp _ => true
    | _ => false
  push _ _ := none
  pop _ _ _ := none
  requires := Instr.requires

/-! ## Machine code -/

/-- LLVM's NOP of `n` bytes, from 1 to 10, as its x86 assembler pads with
for the generic x86-64 CPU (`X86AsmBackend::writeNopData`). -/
def nop : Nat → List Nat
  | 1 => [0x90]
  | 2 => [0x66, 0x90]
  | 3 => [0x0F, 0x1F, 0x00]
  | 4 => [0x0F, 0x1F, 0x40, 0x00]
  | 5 => [0x0F, 0x1F, 0x44, 0x00, 0x00]
  | 6 => [0x66, 0x0F, 0x1F, 0x44, 0x00, 0x00]
  | 7 => [0x0F, 0x1F, 0x80, 0x00, 0x00, 0x00, 0x00]
  | 8 => [0x0F, 0x1F, 0x84, 0x00, 0x00, 0x00, 0x00, 0x00]
  | 9 => [0x66, 0x0F, 0x1F, 0x84, 0x00, 0x00, 0x00, 0x00, 0x00]
  | _ => [0x66, 0x2E, 0x0F, 0x1F, 0x84, 0x00, 0x00, 0x00, 0x00, 0x00]

/-- LLVM's padding of `n` bytes: NOPs of 10 bytes, then one of the rest. -/
def padding (n : Nat) : List Nat :=
  if n = 0 then [] else if n ≤ 10 then nop n else nop 10 ++ padding (n - 10)
termination_by n
decreasing_by omega

/-- The bytes from `o` to the next multiple of `n`. -/
def padLen (n o : Nat) : Nat := (n - o % n) % n

/-- `mulxD32`'s bytes: VEX's three-byte form (`C4`, `R̄X̄B̄` and map `0F38`,
then `W1`, `vvvv` the low half's register inverted, `L0`, `F2`), `F6`,
ModR/M with `mod = 10`, a SIB for an `rsp` or `r12` base, and the 32-bit
displacement. `none` with an index, which aws-lc's bytes have none of. -/
def mulxD32Bytes (hi lo : Reg) (m : MemOp) : Option (List Nat) :=
  if m.index.isSome then none
  else
    let b := Enc.reg m.base
    let sib := if b % 8 == 4 then [0x24] else []
    some ([0xC4, (1 - Enc.reg hi / 8 % 2) <<< 7 ||| 1 <<< 6 ||| (1 - b / 8 % 2) <<< 5 ||| 2,
      0x80 ||| (15 - Enc.reg lo % 16) <<< 3 ||| 3, 0xF6,
      0x80 ||| (Enc.reg hi % 8) <<< 3 ||| (if sib.isEmpty then b % 8 else 4)] ++ sib ++
      Enc.le 4 (m.disp % 2 ^ 32).toNat)

/-- The ModR/M byte of a RIP-relative operand with `reg` field `r` (`mod =
00`, `r/m = 101`, SDM Vol. 2 Table 2-7), then its 32-bit displacement, left 0
for the linker. -/
def ripModRM (r : Nat) : List Nat := [0x05 ||| (r % 8) <<< 3, 0, 0, 0, 0]

/-- `Enc.legacy` with a RIP-relative operand, which sets neither `REX.X` nor
`REX.B`. -/
def ripLegacy (pfx : List Nat) (w : Bool) (op : List Nat) (r : Nat) : List Nat :=
  let bits := (if w then 8 else 0) ||| (r / 8 % 2) <<< 2
  pfx ++ (if bits != 0 then [0x40 ||| bits] else []) ++ op ++ ripModRM r

/-- `Enc.vex` with a RIP-relative operand, whose `X` and `B` are 0, so the
two-byte prefix in map `0F`. -/
def ripVex (pp map l v op r : Nat) : List Nat :=
  let rb := 1 - r / 8 % 2
  let vv := 15 - v % 16
  if map == 1 then [0xC5, rb <<< 7 ||| vv <<< 3 ||| l <<< 2 ||| pp, op] ++ ripModRM r
  else [0xC4, rb <<< 7 ||| 1 <<< 6 ||| 1 <<< 5 ||| map, vv <<< 3 ||| l <<< 2 ||| pp, op] ++ ripModRM r

/-- The condition code of a `Jcc` or `CMOVcc` (SDM Vol. 2, "Jcc", `7x cb`,
`0F 8x cd`; "CMOVcc", `0F 4x`): B 2, AE 3, E 4, NE 5, BE 6, A 7, L C, GE D,
LE E, G F. -/
def Cond.cc : Cond → Nat
  | .vg .b => 2
  | .vg .ae => 3
  | .vg .e => 4
  | .vg .ne => 5
  | .be => 6
  | .a => 7
  | .l => 0xC
  | .ge => 0xD
  | .le => 0xE
  | .g => 0xF

/-- The bytes of an instruction at byte offset `o`: VG's encoding of its own
(`Instr.encode`); `push` `50+rd` and `pop` `58+rd`, with `REX.B` for
`r8`–`r15`; `aluRsp` as VG's `alu` into `rsp`; `lea`, `neg`, `dec`, `inc`,
`cmov`, `shrd`, `movdqa`, `vmovdqa`, `pinsrb`, `pextrb`, `pextrq`, and
`imul` as their docs give, and `xload` and `vbinSym` as VG's encoding of its
instruction with a memory operand, in VG's encoder's forms, a RIP-relative
operand's displacement 0 (`ripModRM`); `movPad` as `n` bytes `67` then VG's
`mov`; `mulxD32`'s; and the padding, `none` unless `n` is a power of two up
to 64 and the jump's reach (`EB cb`, at most 127) covers it. -/
def Instr.encode (o : Nat) : Instr → Option (List Nat)
  | .vg i => i.encode.map List.flatten
  | .push r => some (Enc.plusReg false [] 0x50 (Enc.reg r))
  | .pop r => some (Enc.plusReg false [] 0x58 (Enc.reg r))
  | .aluRsp op v => Enc.alu true op .rsp (.imm v)
  | .inc d => Enc.legacy [] true [0xFF] 0 (Enc.RM.reg (Enc.reg d))
  | .cmov c d r => Enc.legacy [] true [0x0F, 0x40 + c.cc] (Enc.reg d) (Enc.RM.reg (Enc.reg r))
  | .leaSym d _ => some (ripLegacy [] true [0x8D] (Enc.reg d))
  | .xload op d (.op m) => let (pp, map, c) := op.opc; Enc.sse pp map c (Enc.xreg d) (.mem m)
  | .xload op d (.sym _) => let (pp, map, c) := op.opc; some (ripLegacy (Enc.ppBytes pp) false (Enc.mapBytes map ++ [c]) (Enc.xreg d))
  | .vbinSym op l d a _ => let (pp, map, c, _) := op.opc; some (ripVex pp map (Enc.len l) (Enc.xreg a) c (Enc.xreg d))
  | .vmovdqaLoad l d (.op m) => Enc.vex 1 1 false (Enc.len l) 0 0x6F (Enc.xreg d) (.mem m)
  | .vmovdqaLoad l d (.sym _) => some (ripVex 1 1 (Enc.len l) 0 0x6F (Enc.xreg d))
  | .vmovdqaStore l m r => Enc.vex 1 1 false (Enc.len l) 0 0x7F (Enc.xreg r) (.mem m)
  | .pinsrb d m i => (Enc.ib i).bind fun b => Enc.sse 1 3 0x20 (Enc.xreg d) (.mem m) b
  | .pextrb m r i => (Enc.ib i).bind fun b => Enc.sse 1 3 0x14 (Enc.xreg r) (.mem m) b
  | .pextrq d r i => (Enc.ib i).bind fun b => Enc.sse 1 3 0x16 (Enc.xreg r) (.reg (Enc.reg d)) b (w := true)
  | .lea d m => Enc.legacy [] true [0x8D] (Enc.reg d) (Enc.RM.mem m)
  | .leaRsp m => Enc.legacy [] true [0x8D] (Enc.reg .rsp) (Enc.RM.mem m)
  | .neg d => Enc.legacy [] true [0xF7] 3 (Enc.RM.reg (Enc.reg d))
  | .dec d => Enc.legacy [] true [0xFF] 1 (Enc.RM.reg (Enc.reg d))
  | .shrd d r n => if n < 256 then Enc.legacy [] true [0x0F, 0xAC] (Enc.reg r) (Enc.RM.reg (Enc.reg d)) [n] else none
  | .movdqaLoad d m => Enc.sse 1 1 0x6F (Enc.xreg d) (Enc.RM.mem m)
  | .movdqaStore m r => Enc.sse 1 1 0x7F (Enc.xreg r) (Enc.RM.mem m)
  | .imulMem d m => Enc.legacy [] true [0x0F, 0xAF] (Enc.reg d) (Enc.RM.mem m)
  | .movPad n d r => (Enc.legacy [] true [0x89] (Enc.reg r) (Enc.RM.reg (Enc.reg d))).map (List.replicate n 0x67 ++ ·)
  | .mulxD32 hi lo m => mulxD32Bytes hi lo m
  | .align n => if n ∈ [1, 2, 4, 8, 16, 32, 64] then some (padding (padLen n o)) else none
  | .jmpAlign n =>
    if n ∈ [1, 2, 4, 8, 16, 32, 64] then some ([0xEB, padLen n (o + 2)] ++ padding (padLen n (o + 2)))
    else none

/-- A `Jcc` from offset `o` to offset `t`, short (`7x cb`) when the
displacement fits a byte, else near (`0F 8x cd`), as LLVM's assembler
relaxes it. -/
def jcc (c : Cond) (o t : Nat) : List Nat :=
  let d : Int := (t : Int) - (o + 2)
  if -128 ≤ d ∧ d < 128 then [0x70 + c.cc, (d % 256).toNat]
  else [0x0F, 0x80 + c.cc] ++ Enc.le 4 (((t : Int) - (o + 6)) % 2 ^ 32).toNat

/-- A `jmp` from offset `o` to offset `t`, short (`EB cb`) when the
displacement fits a byte, else near (`E9 cd`), as LLVM's assembler relaxes
it. -/
def jmp (o t : Nat) : List Nat :=
  let d : Int := (t : Int) - (o + 2)
  if -128 ≤ d ∧ d < 128 then [0xEB, (d % 256).toNat]
  else [0xE9] ++ Enc.le 4 (((t : Int) - (o + 5)) % 2 ^ 32).toNat

/-- The static a RIP-relative operand of an instruction names, whose
displacement is its bytes' last four. -/
def Instr.sym : Instr → Option SymOp
  | .leaSym _ m | .xload _ _ (.sym m) | .vbinSym _ _ _ _ m | .vmovdqaLoad _ _ (.sym m) => some m
  | _ => none

/-- A relocation in a function's machine code: the byte offset of the 32-bit
displacement the linker fills with the distance from the end of its
instruction to `addend + 4` bytes past the static `sym`, the target an
`R_X86_64_PC32` relocation names (System V ABI, AMD64 supplement, §4.4:
`S + A - P`, `P` the displacement's own address, four bytes before the
instruction's end). -/
structure Reloc where
  off : Nat
  sym : String
  addend : Int
  deriving DecidableEq, Repr

/-- The bytes a jump into `c`, laid out from `o`, skips: those of the
padding it begins with, as the assembler puts a label after its `.align`. -/
def entry : Prog isa → Nat → Nat
  | .block (.align n :: _), o => padLen n o
  | .seq a _, o => entry a o
  | .loop b _, o => entry b o
  | _, _ => 0

/-- The machine code of a program from byte offset `o` on, as rind's build
emits aws-lc's text and rind's own copies of it, and its relocations: each
instruction's bytes, and a relocation for each RIP-relative operand;
a do-while loop as its body then the `Jcc` that branches back to its entry;
`if c then t else e` as a `Jcc` to `t`'s entry, `e`, a `jmp` past `t`, then
`t`; and `if c then (nothing) else e` as a `Jcc` past `e`, then `e`. Each
jump is short where its displacement fits a byte and near otherwise, the
first sizes, short before near and the `Jcc`'s before the `jmp`'s, whose
jumps reach their targets: what LLVM's assembler reaches by relaxing the
jumps that do not reach, from all short. `none` for any other control
flow, which no program here has, and for an instruction that does not
encode. -/
def layout : Prog isa → Nat → Option (List Nat × List Reloc)
  | .block is, o =>
    is.foldlM (init := ([], [])) fun (bs, rs) i => (i.encode (o + bs.length)).map fun b =>
      (bs ++ b, rs ++ (i.sym.map fun m => ⟨o + bs.length + b.length - 4, m.name, m.disp - 4⟩).toList)
  | .seq a b, o => do
    let (ba, ra) ← layout a o
    let (bb, rb) ← layout b (o + ba.length)
    return (ba ++ bb, ra ++ rb)
  | .loop body c, o => do
    let (bb, rb) ← layout body o
    return (bb ++ jcc c (o + bb.length) (o + entry body o), rb)
  | .ite c (.block []) e, o =>
    [2, 6].firstM fun jc => do
      let (be, re) ← layout e (o + jc)
      let j := jcc c o (o + jc + be.length)
      if j.length = jc then return (j ++ be, re) else none
  | .ite c t e, o =>
    [(2, 2), (2, 5), (6, 2), (6, 5)].firstM fun (jc, jm) => do
      let (be, re) ← layout e (o + jc)
      let p := o + jc + be.length
      let (bt, rt) ← layout t (p + jm)
      let j := jcc c o (p + jm + entry t (p + jm))
      let k := jmp p (p + jm + bt.length)
      if j.length = jc ∧ k.length = jm then return (j ++ be ++ k ++ bt, re ++ rt) else none
  | _, _ => none

/-- `rep ret` (`F3 C3`), aws-lc's return. -/
def repRet : List Nat := [0xF3, 0xC3]

/-- The machine code of a function whose body is `c`, from a section start,
and its relocations: the body, then `rep ret`. -/
def function (c : Prog isa) : Option (List Nat × List Reloc) :=
  (layout c 0).map fun (bs, rs) => (bs ++ repRet, rs)

end Rind.X86_64
