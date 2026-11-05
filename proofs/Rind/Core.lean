module
public import Aeneas
@[expose] public section
open Aeneas Aeneas.Std Result

/-!
# What the translation calls outside rind and Aeneas's library

Models of the `core` items rind's translation calls that Aeneas's library
lacks, each following the Rust standard library, and opaque declarations for
the random source, whose draw the functional spec leaves out, and for
`core::array::from_fn`, which only AES's header protection calls.
`Rind.X86_64.Simd` models the x86_64 intrinsics.
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

/-- `<[T]>::first_chunk::<N>`: the first `N` elements, if there are that many. -/
def core.slice.Slice.first_chunk {T : Type _} (N : Std.Usize) (s : Slice T) :
    Result (Option (Array T N)) :=
  if h : N.val ≤ s.length then
    Std.Result.ok (some (Array.from (s.val.take N.val) (by simp [Slice.length] at h; simp [h])))
  else Std.Result.ok none

/-- `<[[T; N]]>::as_flattened_mut`: the arrays' elements in order, which write
back to them `N` at a time. Rust's length never overflows for an element with
a size, so the failure is unreachable. -/
def core.slice.SliceArray.as_flattened_mut {T : Type _} {N : Std.Usize} (s : Slice (Array T N)) :
    Result ((Slice T) × (Slice T → Slice (Array T N))) :=
  let flat := s.val.flatMap (·.val)
  if h : flat.length ≤ Usize.max then
    Std.Result.ok (Slice.from flat h, fun t =>
      Slice.from (s.val.mapIdx fun i a =>
        a.from_slice (Slice.from ((t.val.drop (i * N.val)).take N.val)
          (by have := t.property; simp only [List.length_take, List.length_drop]; omega)))
        (by simp))
  else Std.Result.fail .panic

/-- `<[T; N]>::map`: `f` called on each element in order. -/
def core.array.Array.map {T F U : Type _} {N : Std.Usize} (inst : core.ops.function.FnMut F T U)
    (a : Array T N) (f : F) : Result (Array U N) := do
  let (l, _) ← a.val.foldlM (fun (acc, f) x => do
    let (y, f) ← inst.call_mut f x
    ok (acc ++ [y], f)) ([], f)
  if h : l.length = N.val then ok (Array.from l h) else fail .panic

/-- `usize::div_ceil`, which panics on a zero divisor. -/
def core.num.Usize.div_ceil (a b : Std.Usize) : Result Std.Usize :=
  if h : b.val = 0 then fail .panic
  else ok (UScalar.ofNatCore ((a.val + b.val - 1) / b.val) (by
    have ha := a.hBounds
    apply Nat.div_lt_of_lt_mul
    obtain ⟨c, hc⟩ : ∃ c, b.val = c + 1 := ⟨b.val - 1, by omega⟩
    generalize (2 : Nat) ^ UScalarTy.Usize.numBits = N at ha ⊢
    rw [hc, show a.val + (c + 1) - 1 = a.val + c by omega]
    nlinarith [Nat.mul_le_mul_left c (show 1 ≤ N by omega)]))

/-- `getrandom`'s error. -/
opaque getrandom.error.Error : Type

/-- `getrandom::fill`, the system random source. -/
opaque getrandom.fill :
  Slice Std.U8 → Result ((core.result.Result Unit getrandom.error.Error) × (Slice Std.U8))

/-- `core::array::from_fn`. -/
opaque core.array.from_fn {T F : Type _} (N : Std.Usize)
    (_ : core.ops.function.FnMut F Std.Usize T) : F → Result (Array T N)
