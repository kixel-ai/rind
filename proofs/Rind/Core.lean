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

/-- `Result::ok`. -/
def core.result.Result.ok {T E : Type _} :
    core.result.Result T E → Result (Option T)
  | .Ok x => Std.Result.ok (some x)
  | .Err _ => Std.Result.ok none

/-- `Result::map`. -/
def core.result.Result.map {T E U F : Type _} (inst : core.ops.function.FnOnce F T U) :
    core.result.Result T E → F → Result (core.result.Result U E)
  | .Ok x, f => do
    let y ← inst.call_once f x
    Std.Result.ok (.Ok y)
  | .Err e, _ => Std.Result.ok (.Err e)

/-- `<[T]>::first`. -/
def core.slice.Slice.first {T : Type _} (s : Slice T) : Result (Option T) :=
  Std.Result.ok s.val.head?

/-- `<[T]>::split_first`. -/
def core.slice.Slice.split_first {T : Type _} (s : Slice T) : Result (Option (T × Slice T)) :=
  match h : s.val with
  | [] => Std.Result.ok none
  | x :: rest => Std.Result.ok (some (x, .from rest (by have := s.property; simp [h] at this; omega)))

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
