import Cosim.X86_64
import Std.Data.HashMap

/-!
# `vg-cosim`

`vg-cosim <arch> <groups> <cases> <seed> <features> <native|emulated>`
reads the groups of lines of VG's code that `admin/vg-bytes` wrote, each
its kind, its text and its machine code, and writes to stdout the stream
`admin/vg-cosim-runner.rs` reads: `cases` random cases of each instruction
whose CPU features are all among `features` (comma-separated Rust
`target_feature` names), or with `emulated`, of each that needs one that is
not. It fails if a group is not an instruction of the model, or the model
faults in every state tried.
-/

open Cosim

def main (args : List String) : IO UInt32 := do
  let [arch, groups, n, seed, feats, select] := args
    | IO.eprintln "usage: vg-cosim <x86_64|aarch64> <groups> <cases> <seed> <features> <native|emulated>"
      return 2
  let some n := n.toNat? | IO.eprintln "vg-cosim: cases is not a number"; return 2
  let some seed := seed.toNat? | IO.eprintln "vg-cosim: seed is not a number"; return 2
  let host := (feats.splitOn ",").filter (· != "")
  let emulated := select == "emulated"
  let (archByte, stateLen) := match arch with
    | "x86_64" => ((0 : UInt8), X86_64.stateLen)
    | _ => (1, 0)
  let out ← IO.getStdout
  out.write (header archByte stateLen)
  let mut errors : Array String := #[]
  let mut nBlocks := 0
  let mut nCases := 0
  let mut missing : Std.HashMap String Nat := {}
  let mut rng : UInt64 := seed.toUInt64
  for line in (← IO.FS.lines groups) do
    let [kind, text, hex] := line.splitOn "\t" | errors := errors.push s!"bad line: {line}"; continue
    let some code := parseHex hex | errors := errors.push s!"bad bytes: {line}"; continue
    let lines := text.splitOn "; "
    let gen := match arch with
      | "x86_64" => X86_64.blocks kind lines code n
      | _ => pure (.error s!"vg-cosim: no model for {arch}")
    let (res, rng') := gen.run rng
    rng := rng'
    match res with
    | .error e => errors := errors.push e
    | .ok bs =>
      for (b, req) in bs do
        let lacks := req.filter (!host.contains ·)
        if lacks.isEmpty == emulated then continue
        for f in lacks do
          missing := missing.insert f (missing.getD f 0 + 1)
        out.write b.encode
        nBlocks := nBlocks + 1
        nCases := nCases + b.cases.size
  out.write trailer
  out.flush
  let lacking := ", ".intercalate (missing.toList.map fun (f, k) => s!"{f} ({k})")
  IO.eprintln s!"vg-cosim: {arch} {select}: {nBlocks} instructions, {nCases} cases\
    {if lacking.isEmpty then "" else s!", needing {lacking}"}"
  for e in errors do
    IO.eprintln s!"vg-cosim: {e}"
  return if errors.isEmpty then 0 else 1
