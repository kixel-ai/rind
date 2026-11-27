import VerifiedGarbage.TCB.X86_64.Encode

/-!
# rind's extension of VG's x86_64 model

**Trusted.** VG's model (`VerifiedGarbage/TCB/X86_64/`) covers the
instructions VG's own code uses, and keeps the stack pointer to VG's nested
frames of under a page. aws-lc's Montgomery routines make their own frame:
they push the callee-saved registers, move `rsp` down past their scratch
space by `lea`, a page at a time with a probing load at each, and restore
`rsp` from a saved copy in one `lea`. They also use `neg`, `dec`, `ja`,
aligned `movdqa` to and from memory, and padding the assembler lays out;
aws-lc's Poly1305 also uses `shrd`. BoringSSL's AES-GCM routines read
`vpshufd`'s source from memory, return with a plain `ret`, and read their
constant tables by RIP-relative addressing (`rip`), which VG's code reaches
only through a register `lea` loads. This model is VG's with those added:
its state is VG's with the lowest address the stack may reach, its
instructions are VG's, run by VG's
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

A static: as for VG's table instructions (`aluTbl`, `vmovdquTbl`), an
immutable object of the words the instruction names, which no writable
memory overlaps, so a read of it gives those words and leaks only its
offset in the static, here 0. `admin/prove lean` checks that the static
rind's build emits begins with those words and that the instruction's
relocation reaches its start.

`admin/prove vg` cosimulates each of these instructions against the CPU
(`Cosim/RindX86_64.lean`), and `admin/prove lean` checks that each program's bytes
and relocations (`layout`) are the ones rind's build emits.
-/

namespace Rind.X86_64

open VG VG.X86_64

/-- VG's machine state with `lo`, the lowest address the function's stack
may reach, which no instruction changes. -/
structure State where
  vg : VG.X86_64.State
  lo : Addr

/-- Branch conditions: VG's, and `ja`. -/
inductive Cond
  | vg (c : VG.X86_64.Cond)
  /-- `ja`: CF = 0 and ZF = 0 -/
  | a
  deriving DecidableEq, Repr

/-- SDM Vol. 2, "Jcc": A, "above (CF=0 and ZF=0)"; VG's for its own. `none`,
and so a fault, if a flag it reads is undefined. -/
def eval : Cond → VG.X86_64.State → Option Bool
  | .vg c, s => VG.X86_64.eval c s
  | .a, s => s.cf.bind fun c => s.zf.map fun z => !c && !z

/-- An AVX instruction whose memory operand is the start of a static,
`[rip + name]`. -/
inductive RipOp
  /-- `op xmm1, xmm2, XMMWORD PTR [rip + name]` or `op ymm1, ymm2, YMMWORD PTR
  [rip + name]`: VG's `vbinLoad op len dst src1` with the static as `src2`. -/
  | vbin (op : VBinOp) (len : VLen) (dst src1 : XReg)
  /-- `vbroadcasti128 ymm, XMMWORD PTR [rip + name]` (`VEX.256.66.0F38.W0 5A /r`) -/
  | vbroadcasti128 (dst : XReg)
  deriving DecidableEq, Repr

inductive Instr
  /-- An instruction of VG's model, with VG's semantics. -/
  | vg (i : VG.X86_64.Instr)
  /-- `push r64` (`50+rd`), `r` not `rsp` -/
  | push (r : Reg)
  /-- `lea r64, m` (`REX.W 8D /r`), `d` not `rsp` -/
  | lea (d : Reg) (m : MemOp)
  /-- `lea rsp, m` (`REX.W 8D /r`): moves the stack pointer -/
  | leaRsp (m : MemOp)
  /-- `neg r64` (`REX.W F7 /3`) -/
  | neg (d : Reg)
  /-- `dec r64` (`REX.W FF /1`) -/
  | dec (d : Reg)
  /-- `shrd r64, r64, imm8` (`REX.W 0F AC /r ib`): `d` shifted right by `n`,
  filled from the low bits of `s` -/
  | shrd (d s : Reg) (n : Nat)
  /-- `movdqa xmm, XMMWORD PTR m` (`66 0F 6F /r`) -/
  | movdqaLoad (d : XReg) (m : MemOp)
  /-- `movdqa XMMWORD PTR m, xmm` (`66 0F 7F /r`) -/
  | movdqaStore (m : MemOp) (s : XReg)
  /-- `vpshufd xmm, XMMWORD PTR m, imm8` (`VEX.128.66.0F.WIG 70 /r ib`) -/
  | vpshufdLoad (d : XReg) (m : MemOp) (order : BitVec 8)
  /-- `op`, its memory operand the start of the static `name`, whose words
  are `words`, by RIP-relative addressing. -/
  | rip (op : RipOp) (name : String) (words : List (BitVec 64))
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

/-- The first 16 bytes of a static of `words`, little-endian, its first word
lowest; `none` if it has fewer. -/
def static128 (ws : List (BitVec 64)) : Option (BitVec 128) :=
  if 2 ≤ ws.length then some (ws.getD 1 0 ++ ws.getD 0 0) else none

/-- Its first 32 bytes. -/
def static256 (ws : List (BitVec 64)) : Option (BitVec 256) :=
  if 4 ≤ ws.length then some (ws.getD 3 0 ++ ws.getD 2 0 ++ ws.getD 1 0 ++ ws.getD 0 0) else none

/-- Semantics:
* VG's instructions: VG's `exec`, on VG's part of the state.
* "PUSH" (`50+rd`, 64-bit operand and stack address size): `RSP := RSP − 8;
  Memory[SS:RSP] := SRC`; no flags are affected. The stack grows to the new
  `rsp` (`moveSp`), then the store, which faults outside `wr`.
* "LEA" (`REX.W 8D /r`): `DEST := EffectiveAddress(SRC)`, modulo 2⁶⁴; no
  flags are affected and no memory is accessed. Into `rsp`, through
  `moveSp`.
* "NEG": `IF DEST = 0 THEN CF := 0; ELSE CF := 1; FI; DEST := [– (DEST)]`;
  "The OF, SF, ZF, AF, and PF flags are set according to the result": those
  of the subtraction `0 - DEST`.
* "DEC": `DEST := DEST – 1`; "The CF flag is not affected. The OF, SF, ZF,
  AF, and PF flags are set according to the result": those of the
  subtraction `DEST - 1`.
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
* "PSHUFD" (VEX.128 encoded version): `DEST[127:0]` as PSHUFD's of `SRC`
  (`shufDwords`), `DEST[MAXVL-1:128] := 0` (`setV .l128`); `SRC` the 16
  bytes at the address, little-endian, with no alignment required.
* `rip`: VG's `vbinLoad` and `vbroadcasti128`, their memory operand the
  first 16 or 32 bytes of the static (`static128`, `static256`); it faults
  if the static has fewer. In 64-bit mode ModR/M `mod = 00`, `r/m = 101`
  addresses `RIP + disp32` (SDM Vol. 2 §2.2.1.6, "RIP-Relative Addressing":
  "adding displacement to the 64-bit RIP of the next instruction"), and the
  linker writes `disp32` as `S + A - P` (System V AMD64 psABI §4.4,
  `R_X86_64_PC32`), which with the addend `A = -4` the layout gives, `P` the
  displacement's address and the instruction ending with it, is the
  static's address `S`.
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
  | .lea d m, s => if d = .rsp then none else some { s with vg := s.vg.setReg d (s.vg.ea m) }
  | .leaRsp m, s => moveSp s (s.vg.ea m)
  | .neg d, s =>
    let a := s.vg.gpr d
    let r := 0 - a
    some { s with vg := (arithFlags s.vg r (a ≠ 0) (subOverflow 0 a r)).setReg d r }
  | .dec d, s =>
    let a := s.vg.gpr d
    let r := a - 1
    some { s with vg := ({ arithFlags s.vg r false (subOverflow a 1 r) with cf := s.vg.cf }).setReg d r }
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
  | .vpshufdLoad d m o, s =>
    (s.vg.load128 (s.vg.ea m)).map fun v => { s with vg := s.vg.setV .l128 d (shufDwords v o) 0 }
  | .rip (.vbin op .l128 d a) _ ws, s =>
    (static128 ws).map fun v => { s with vg := s.vg.setV .l128 d (op.sse.eval (s.vg.lane a 0) v) 0 }
  | .rip (.vbin op .l256 d a) _ ws, s =>
    (static256 ws).map fun v =>
      let g := s.vg.setV .l256 d (op.sse.eval (s.vg.lane a 0) (v.extractLsb' 0 128))
        (op.sse.eval (s.vg.lane a 1) (v.extractLsb' 128 128))
      { s with vg := g }
  | .rip (.vbroadcasti128 d) _ ws, s => (static128 ws).map fun v => { s with vg := s.vg.setV .l256 d v v }
  | .align _, s | .jmpAlign _, s => some s

/-- The addresses an instruction accesses: VG's for its own, and for the
others the quadword a push stores, the 16 bytes a `movdqa` or `vpshufd`
moves, and a static's offset, 0, as VG's table instructions leak: the
static's address does not depend on the data. -/
def addrs : Instr → State → List Addr
  | .vg i, s => VG.X86_64.addrs i s.vg
  | .push _, s => [s.vg.gpr .rsp - 8]
  | .movdqaLoad _ m, s | .movdqaStore m _, s | .vpshufdLoad _ m _, s => [s.vg.ea m]
  | .rip .., _ => [0]
  | .lea .., _ | .leaRsp _, _ | .neg _, _ | .dec _, _ | .shrd .., _ | .align _, _ | .jmpAlign _, _ => []

/-- The CPU features beyond the baseline: VG's for its own and for the
forms of VG's instructions `rip` reads a static by, AVX for `vpshufd`, and
none for the others, which are x86-64 and SSE2 baseline instructions. -/
def Instr.requires : Instr → List String
  | .vg i => i.requires
  | .vpshufdLoad .. => ["avx"]
  | .rip (.vbin op len d a) .. => (VG.X86_64.Instr.vbinLoad op len d a { base := .rax }).requires
  | .rip (.vbroadcasti128 d) .. => (VG.X86_64.Instr.vbroadcasti128 d { base := .rax }).requires
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
    | .push _ | .leaRsp _ => true
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

/-- A VEX instruction (VG's `Enc.vex`, `W = 0`) whose `r/m` operand is
RIP-relative: ModR/M `mod = 00`, `r/m = 101`, then a zero `disp32` for the
linker to fill, as the last four bytes. -/
def vexRip (pp map l v op r : Nat) : List Nat :=
  let rb := 1 - r / 8 % 2
  let vv := 15 - v % 16
  let tail := [op, (r % 8) <<< 3 ||| 5, 0, 0, 0, 0]
  if map == 1 then [0xC5, rb <<< 7 ||| vv <<< 3 ||| l <<< 2 ||| pp] ++ tail
  else [0xC4, rb <<< 7 ||| 1 <<< 6 ||| 1 <<< 5 ||| map, vv <<< 3 ||| l <<< 2 ||| pp] ++ tail

/-- The bytes of an instruction at byte offset `o`: VG's encoding of its own
(`Instr.encode`); `push` `50+rd`, with `REX.B` for `r8`–`r15`; `lea`,
`neg`, `dec`, `shrd`, `movdqa`, and `vpshufd` as their docs give, in VG's
encoder's forms; `rip`'s as the register forms' VG encodes (`VBinOp.opc`,
"VBROADCAST" `VEX.256.66.0F38.W0 5A /r`) with a RIP-relative operand; and
the padding, `none` unless `n` is a power of two up to 64 and the jump's
reach (`EB cb`, at most 127) covers it. -/
def Instr.encode (o : Nat) : Instr → Option (List Nat)
  | .vg i => i.encode.map List.flatten
  | .push r => some (Enc.plusReg false [] 0x50 (Enc.reg r))
  | .lea d m => Enc.legacy [] true [0x8D] (Enc.reg d) (Enc.RM.mem m)
  | .leaRsp m => Enc.legacy [] true [0x8D] (Enc.reg .rsp) (Enc.RM.mem m)
  | .neg d => Enc.legacy [] true [0xF7] 3 (Enc.RM.reg (Enc.reg d))
  | .dec d => Enc.legacy [] true [0xFF] 1 (Enc.RM.reg (Enc.reg d))
  | .shrd d r n => if n < 256 then Enc.legacy [] true [0x0F, 0xAC] (Enc.reg r) (Enc.RM.reg (Enc.reg d)) [n] else none
  | .movdqaLoad d m => Enc.sse 1 1 0x6F (Enc.xreg d) (Enc.RM.mem m)
  | .movdqaStore m r => Enc.sse 1 1 0x7F (Enc.xreg r) (Enc.RM.mem m)
  | .vpshufdLoad d m n => Enc.vex 1 1 false 0 0 0x70 (Enc.xreg d) (Enc.RM.mem m) [n.toNat]
  | .rip (.vbin op l d a) .. =>
    let (pp, map, c, _) := op.opc
    some (vexRip pp map (Enc.len l) (Enc.xreg a) c (Enc.xreg d))
  | .rip (.vbroadcasti128 d) .. => some (vexRip 1 2 1 0 0x5A (Enc.xreg d))
  | .align n => if n ∈ [1, 2, 4, 8, 16, 32, 64] then some (padding (padLen n o)) else none
  | .jmpAlign n =>
    if n ∈ [1, 2, 4, 8, 16, 32, 64] then some ([0xEB, padLen n (o + 2)] ++ padding (padLen n (o + 2)))
    else none

/-- The condition code of a `Jcc` (SDM Vol. 2, "Jcc", `7x cb`, `0F 8x cd`):
B 2, AE 3, E 4, NE 5, A 7. -/
def Cond.cc : Cond → Nat
  | .vg .b => 2
  | .vg .ae => 3
  | .vg .e => 4
  | .vg .ne => 5
  | .a => 7

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

/-- The bytes a jump into `c`, laid out from `o`, skips: those of the
padding it begins with, as the assembler puts a label after its `.align`. -/
def entry : Prog isa → Nat → Nat
  | .block (.align n :: _), o => padLen n o
  | .seq a _, o => entry a o
  | .loop b _, o => entry b o
  | _, _ => 0

/-- A relocation the linker resolves in a program's machine code: the byte
offset of the field it fills, its ELF type, the symbol it names, and its
addend. -/
structure Reloc where
  off : Nat
  type : String
  sym : String
  addend : Int
  deriving DecidableEq, Repr

/-- The relocations of an instruction laid out at `o` as `bs`: `rip`'s
`disp32`, its last four bytes, `R_X86_64_PC32` against the static with the
addend `-4`, which makes the address it gives the static's start. -/
def Instr.relocs (o : Nat) (bs : List Nat) : Instr → List Reloc
  | .rip _ name _ => [⟨o + bs.length - 4, "R_X86_64_PC32", name, -4⟩]
  | _ => []

/-- The machine code of a program from byte offset `o` on, and its
relocations, as rind's build emits aws-lc's and BoringSSL's text and rind's
own copies of aws-lc's: each instruction's bytes; a do-while loop as its
body then the `Jcc` that branches back to its entry; `if c then t else e` as
a `Jcc` to `t`'s entry, `e`, a `jmp` past `t`, then `t`; and
`if c then (nothing) else e` as a `Jcc` past `e`, then `e`. Each jump is
short where its displacement fits a byte and near otherwise, the first
sizes, short before near and the `Jcc`'s before the `jmp`'s, whose jumps
reach their targets: what LLVM's assembler reaches by relaxing the jumps
that do not reach, from all short. `none` for any other control flow, which
no program here has, and for an instruction that does not encode. -/
def layout : Prog isa → Nat → Option (List Nat × List Reloc)
  | .block is, o =>
    is.foldlM (init := ([], [])) fun (bs, rs) i =>
      (i.encode (o + bs.length)).map fun b => (bs ++ b, rs ++ i.relocs (o + bs.length) b)
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

/-- `ret` (`C3`), BoringSSL's. -/
def plainRet : List Nat := [0xC3]

/-- The machine code of a function whose body is `c`, from a section start,
and its relocations: the body, then its return, `ret`'s bytes. -/
def function (c : Prog isa) (ret : List Nat) : Option (List Nat × List Reloc) :=
  (layout c 0).map fun (bs, rs) => (bs ++ ret, rs)

/-- The statics `rip` instructions in `c` read: each its name and words. -/
def statics : Prog isa → List (String × List (BitVec 64))
  | .block is => is.filterMap fun
    | .rip _ name ws => some (name, ws)
    | _ => none
  | .seq a b => statics a ++ statics b
  | .loop b _ => statics b
  | .ite _ t e => statics t ++ statics e
  | _ => []

end Rind.X86_64
