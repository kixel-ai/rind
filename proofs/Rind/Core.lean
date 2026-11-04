module
public import Aeneas
@[expose] public section
open Aeneas Aeneas.Std Result

/-!
# What the translation calls outside rind and Aeneas's library

Models of the `core` items rind's translation calls that Aeneas's library
lacks, each following the Rust standard library, and opaque declarations for
the random source, whose draw the functional spec leaves out.
-/

/-- `Option::and_then`. -/
def core.option.Option.and_then {T U F : Type _}
    (inst : core.ops.function.FnOnce F T (Option U)) : Option T → F → Result (Option U)
  | none, _ => ok none
  | some x, f => inst.call_once f x

/-- `<[[T; N]]>::as_flattened_mut`: the arrays' elements as one slice, and
writing a slice of that length back splits it into the arrays again. -/
def core.slice.SliceArray.as_flattened_mut {T : Type _} {N : Std.Usize}
    (s : Slice (Std.Array T N)) : Result (Slice T × (Slice T → Slice (Std.Array T N))) :=
  let flat := (s.val.map (·.val)).flatten
  if h : flat.length ≤ Usize.max then
    ok (Slice.from flat h, fun t => Slice.from (s.val.mapIdx fun i a =>
      if ht : ((t.val.drop (i * N.val)).take N.val).length = N.val then Std.Array.from _ ht else a)
      (by simp))
  else fail .integerOverflow

/-- `Result::ok`. -/
def core.result.Result.ok {T E : Type _} :
    core.result.Result T E → Result (Option T)
  | .Ok x => Std.Result.ok (some x)
  | .Err _ => Std.Result.ok none

/-- `Option`'s `?`: continue with the value, or break with `None`. -/
def core.option.Option.Insts.CoreOpsTry_traitTry.branch {T : Type _} :
    Option T → Result (core.ops.control_flow.ControlFlow (Option Never) T)
  | some x => ok (.Continue x)
  | none => ok (.Break none)

/-- `Option`'s `?` returning a `None` residual. -/
def core.option.Option.Insts.CoreOpsTry_traitFromResidualOptionNever.from_residual
    (T : Type _) (_ : Option Never) : Result (Option T) :=
  ok none

/-- `getrandom`'s error. -/
opaque getrandom.error.Error : Type

/-- `getrandom::fill`, the system random source. -/
opaque getrandom.fill :
  Slice Std.U8 → Result ((core.result.Result Unit getrandom.error.Error) × (Slice Std.U8))
