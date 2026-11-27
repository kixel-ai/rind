import Rind.X86_64.Asm

/-!
# Carry chains as linear arithmetic

A block of `mulx`, `adcx`, `adox`, `adc`, and `add` run symbolically leaves
each register a term of sums with carries and halves of products. `acct`
proves an equation between weighted sums of such terms: it names each sum
with a carry, `adcS x y c` and its carry `adcC x y c`, and each product's
halves, `mulLo x y` and `mulHi x y`, innermost first, each with the equation
that defines it (`adc_fact`, `mul_fact`), and leaves `linarith` a goal linear
in the names and the products of the block's inputs.
-/

namespace rind.x86_64.acct

open Lean Meta Elab Tactic
open rind.x86_64.asm

/-- `x + y + c`, as `adc`, `adcx`, and `adox` leave it. -/
def adcS (x y : BitVec 64) (c : Bool) : BitVec 64 := x + y + (BitVec.ofBool c).setWidth 64

/-- The carry out of `x + y + c`. -/
def adcC (x y : BitVec 64) (c : Bool) : Bool := decide (2 ^ 64 ≤ x.toNat + y.toNat + c.toNat)

/-- The carry out of `x + y`, as `add` leaves it. -/
def addC (x y : BitVec 64) : Bool := decide (2 ^ 64 ≤ x.toNat + y.toNat)

theorem fold_adcS (x y : BitVec 64) (c : Bool) : x + y + (BitVec.ofBool c).setWidth 64 = adcS x y c := rfl

theorem fold_adcC (x y : BitVec 64) (c : Bool) :
    decide (2 ^ 64 ≤ x.toNat + y.toNat + c.toNat) = adcC x y c := rfl

theorem fold_adcC' (x y : BitVec 64) (c : Bool) :
    decide (18446744073709551616 ≤ x.toNat + y.toNat + c.toNat) = adcC x y c := rfl

theorem fold_addC (x y : BitVec 64) : decide (2 ^ 64 ≤ x.toNat + y.toNat) = addC x y := rfl

theorem fold_addC' (x y : BitVec 64) : decide (18446744073709551616 ≤ x.toNat + y.toNat) = addC x y := rfl

theorem fold_mulLo (x y : BitVec 64) : BitVec.ofNat 64 (x.toNat * y.toNat) = mulLo x y := rfl

theorem fold_mulHi (x y : BitVec 64) : BitVec.ofNat 64 (x.toNat * y.toNat / 2 ^ 64) = mulHi x y := rfl

theorem fold_mulHi' (x y : BitVec 64) :
    BitVec.ofNat 64 (x.toNat * y.toNat / 18446744073709551616) = mulHi x y := rfl

theorem adc_fact (x y : BitVec 64) (c : Bool) :
    (adcS x y c).toNat + 2 ^ 64 * (adcC x y c).toNat = x.toNat + y.toNat + c.toNat := by
  have := x.isLt; have := y.isLt; have := Bool.toNat_le c
  simp only [adcS, adcC, BitVec.toNat_add, ofBool_toNat]
  by_cases h : 2 ^ 64 ≤ x.toNat + y.toNat + c.toNat
  · simp only [h, decide_true, Bool.toNat_true]; omega
  · simp only [h, decide_false, Bool.toNat_false]; omega

theorem add_fact (x y : BitVec 64) : (x + y).toNat + 2 ^ 64 * (addC x y).toNat = x.toNat + y.toNat := by
  have := x.isLt; have := y.isLt
  simp only [addC, BitVec.toNat_add]
  by_cases h : 2 ^ 64 ≤ x.toNat + y.toNat
  · simp only [h, decide_true, Bool.toNat_true]; omega
  · simp only [h, decide_false, Bool.toNat_false]; omega

theorem mul_fact (x y : BitVec 64) : (mulHi x y).toNat * 2 ^ 64 + (mulLo x y).toNat = x.toNat * y.toNat :=
  mul_toNat x y

theorem adcS_int (x y : BitVec 64) (c : Bool) :
    ((adcS x y c).toNat : ℤ) = x.toNat + y.toNat + c.toNat - 2 ^ 64 * (adcC x y c).toNat := by
  have := adc_fact x y c; omega

theorem add_int (x y : BitVec 64) : ((x + y).toNat : ℤ) = x.toNat + y.toNat - 2 ^ 64 * (addC x y).toNat := by
  have := add_fact x y; omega

theorem mulLo_int (x y : BitVec 64) : ((mulLo x y).toNat : ℤ) = x.toNat * y.toNat - 2 ^ 64 * (mulHi x y).toNat := by
  have := mul_fact x y; zify at this; linarith

/-- Proves an equation between weighted sums of a block's terms: each sum and each product's low half, in
`ℤ`, is its inputs less `2^64` times its carry or high half, which leaves an identity of polynomials. -/
macro "acct" : tactic => `(tactic| set_option exponentiation.threshold 4096 in (
  zify
  push_cast
  simp only [adcS_int, add_int, mulLo_int, BitVec.toNat_zero, BitVec.ofNat_eq_ofNat, Nat.cast_zero]
  ring))

theorem bool_le (c : Bool) : c.toNat ≤ 1 := Bool.toNat_le c

/-- The first subterm of `e`, innermost first, that `p` picks. -/
partial def innermost (p : Expr → Option Expr) (e : Expr) : Option Expr :=
  let inner := match e with
    | .app f a => (innermost p f).orElse fun _ => innermost p a
    | .lam _ t b _ | .forallE _ t b _ => (innermost p t).orElse fun _ => innermost p b
    | .letE _ t v b _ => ((innermost p t).orElse fun _ => innermost p v).orElse fun _ => innermost p b
    | .mdata _ b | .proj _ _ b => innermost p b
    | _ => none
  inner.orElse fun _ => p e

/-- The fact that defines a term `acct` names, if `e` is one. -/
def factOf (e : Expr) : Option Expr :=
  match_expr e with
  | adcS x y c => some (mkApp3 (.const ``adc_fact []) x y c)
  | adcC x y c => some (mkApp3 (.const ``adc_fact []) x y c)
  | addC x y => some (mkApp2 (.const ``add_fact []) x y)
  | mulLo x y => some (mkApp2 (.const ``mul_fact []) x y)
  | mulHi x y => some (mkApp2 (.const ``mul_fact []) x y)
  | _ => none

/-- Names the innermost term of the goal `acct` names, and the others its fact
defines, the fact a hypothesis of the goal; `false` once none is left. -/
def step : TacticM Bool := withMainContext do
  let g ← instantiateMVars (← getMainTarget)
  let some e := innermost (fun e => (factOf e).map fun _ => e) g | return false
  let some pf := factOf e | return false
  let ty ← inferType pf
  let terms : List Expr ← match_expr e with
    | adcS x y c => pure [mkApp3 (.const ``adcS []) x y c, mkApp3 (.const ``adcC []) x y c]
    | adcC x y c => pure [mkApp3 (.const ``adcS []) x y c, mkApp3 (.const ``adcC []) x y c]
    | addC x y => do
      let sum ← mkAppM ``HAdd.hAdd #[x, y]
      pure [mkApp2 (.const ``addC []) x y, sum]
    | mulLo x y => pure [mkApp2 (.const ``mulLo []) x y, mkApp2 (.const ``mulHi []) x y]
    | mulHi x y => pure [mkApp2 (.const ``mulLo []) x y, mkApp2 (.const ``mulHi []) x y]
    | _ => pure []
  let mvarId ← (← getMainGoal).assert (← mkFreshUserName `acct) ty pf
  let args ← terms.toArray.mapM fun t => do
    return ({ expr := t, xName? := some (← mkFreshUserName `v) } : GeneralizeArg)
  let (_, mvarId) ← mvarId.generalize args
  replaceMainGoal [mvarId]
  return true

/-- Names every term of the goal `acct` names, innermost first, each with its
fact, then introduces the facts. -/
elab "acct_name" : tactic => do
  let mut n := 0
  while ← step do
    n := n + 1
    if n > 10000 then throwError "acct_name: too many terms"
  evalTactic (← `(tactic| intros))

/-- Folds the block's sums, carries, and products into `acct`'s names. -/
macro "acct_fold" : tactic => `(tactic|
  simp only [fold_adcS, fold_adcC, fold_adcC', fold_addC, fold_addC', fold_mulLo, fold_mulHi, fold_mulHi'] at *)

end rind.x86_64.acct

namespace rind.x86_64.acct

open rind.x86_64.asm

example (a b c d : BitVec 64) (f : Bool) :
    (adcS (mulLo a b) c f).toNat + 2 ^ 64 * ((adcS (mulHi a b) d (adcC (mulLo a b) c f)).toNat +
      2 ^ 64 * (adcC (mulHi a b) d (adcC (mulLo a b) c f)).toNat) =
      a.toNat * b.toNat + c.toNat + f.toNat + 2 ^ 64 * d.toNat := by
  acct_name
  linarith

end rind.x86_64.acct
