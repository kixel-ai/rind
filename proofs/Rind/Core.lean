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
-/

/-- `Option::and_then`. -/
def core.option.Option.and_then {T U F : Type _}
    (inst : core.ops.function.FnOnce F T (Option U)) : Option T → F → Result (Option U)
  | none, _ => ok none
  | some x, f => inst.call_once f x

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

/-- `bool::then_some`. -/
def core.bool.Bool.then_some {T : Type _} (b : Bool) (t : T) : Result (Option T) :=
  Std.Result.ok (if b then some t else none)

/-- `<&[T] as PartialEq<[U; N]>>::eq`: the slice compared with the whole
array, as slices. -/
def Shared0Slice.Insts.CoreCmpPartialEqArray.eq {T U : Type _} {N : Std.Usize}
    (inst : core.cmp.PartialEq T U) (s : Slice T) (a : Array U N) : Result Bool :=
  core.slice.cmp.PartialEqSlice.eq inst s a.to_slice

/-- The elements of `l` mapped by `f` in order, which each call may update. -/
def core.array.Array.map.go {T F U : Type _} (inst : core.ops.function.FnMut F T U) :
    List T → F → Result (List U)
  | [], _ => Std.Result.ok []
  | x :: xs, f => do
    let (y, f) ← inst.call_mut f x
    let ys ← core.array.Array.map.go inst xs f
    Std.Result.ok (y :: ys)

/-- `<[T; N]>::map`: `f` applied to each element in order. -/
def core.array.Array.map {T F U : Type _} {N : Std.Usize}
    (inst : core.ops.function.FnMut F T U) (a : Array T N) (f : F) : Result (Array U N) := do
  let l ← core.array.Array.map.go inst a.val f
  if h : l.length = N.val then Std.Result.ok (Array.from l h) else Std.Result.fail .panic

/-- `i8::unsigned_abs`. -/
def core.num.I8.unsigned_abs (x : Std.I8) : Result Std.U8 :=
  Std.Result.ok ⟨BitVec.ofNat 8 x.val.natAbs⟩

/-- `<[T]>::as_chunks::<N>`: the slice's leading `N`-element chunks, and what
is left. It panics for `N` of zero. -/
def core.slice.Slice.as_chunks {T : Type _} (N : Std.Usize) (s : Slice T) :
    Result ((Slice (Array T N)) × (Slice T)) :=
  if N.val = 0 then Std.Result.fail .panic
  else
    let k := s.length / N.val
    have hk : k * N.val ≤ s.length := Nat.div_mul_le_self _ _
    Std.Result.ok
      (Slice.from (List.ofFn fun i : Fin k =>
          Array.from ((s.val.drop (i.val * N.val)).take N.val) (by
            have : (i.val + 1) * N.val ≤ k * N.val := Nat.mul_le_mul_right _ i.isLt
            simp only [List.length_take, List.length_drop, Slice.length] at hk ⊢
            rw [Nat.add_mul, Nat.one_mul] at this
            omega))
        (by have := s.property; simp only [List.length_ofFn]
            exact le_trans (Nat.div_le_self _ _) this),
       Slice.from (s.val.drop (k * N.val)) (by have := s.property; simp; omega))

/-- `<[T]>::last`. -/
def core.slice.Slice.last {T : Type _} (s : Slice T) : Result (Option T) :=
  Std.Result.ok s.val.getLast?

/-- `<&u64 as Shr<usize>>::shr`, which overflows for a shift of 64 or more,
as `u64`'s own does. -/
def Shared0U64.Insts.CoreOpsBitShrUsizeU64.shr (x : Std.U64) (y : Std.Usize) : Result Std.U64 :=
  x >>> y

/-- `<&u8 as BitAnd<u8>>::bitand`. -/
def Shared0U8.Insts.CoreOpsBitBitAndU8U8.bitand (x y : Std.U8) : Result Std.U8 :=
  Std.Result.ok (x &&& y)

/-- `getrandom`'s error. -/
opaque getrandom.error.Error : Type

/-- `getrandom::fill`, the system random source. -/
opaque getrandom.fill :
  Slice Std.U8 → Result ((core.result.Result Unit getrandom.error.Error) × (Slice Std.U8))

/-- `core::array::from_fn`. -/
opaque core.array.from_fn {T F : Type _} (N : Std.Usize)
    (_ : core.ops.function.FnMut F Std.Usize T) : F → Result (Array T N)
