import Rind.AesModes
open Aeneas Aeneas.Std

/-!
# SP 800-38F's AES key wrap, KW and KWP, on bytes

The wrapping function W and its inverse, as SP 800-38F's algorithms 1 and 2
state them in RFC 3394's index form (section 2.2.1 and 2.2.2): `6n` steps
over the `n` 64-bit semiblocks, step `t = nj + i` ciphering `A | R[i]` and
XORing `t`, big-endian, into the new `A`. KW (algorithms 3 and 4) wraps under
the default ICV1 `A6A6A6A6A6A6A6A6`, and KWP (algorithms 5 and 6, RFC 5649)
under ICV2 `A65959A6` and the plaintext's length, padding it with zeros to a
whole number of semiblocks and ciphering a single padded semiblock with AES
itself. Nothing here is a target's: `Rind.X86_64.AesKw` proves rind's
`key_wrap::AesKek` against it on both targets.
-/

namespace rind.vale

/-- The 8 bytes of the 64-bit big-endian integer `n`. -/
def be64 (n : Nat) : List (BitVec 8) := (be128 n).drop 8

/-- Bytewise XOR. -/
def xorBytes (a b : List (BitVec 8)) : List (BitVec 8) := List.zipWith (· ^^^ ·) a b

/-- The bytes `p` as `p.length / 8` semiblocks of 8 bytes. -/
def semiblocks (p : List (BitVec 8)) : List (List (BitVec 8)) :=
  (List.range (p.length / 8)).map fun i => (p.drop (8 * i)).take 8

/-- W's step `t = k + 1` over `n` semiblocks: `B = CIPH(A | R[i])`, then
`A = MSB64(B) ⊕ [t]64` and `R[i] = LSB64(B)`, with `i = k mod n`. -/
def wStep (alg : Algorithm) (key : List (BitVec 8)) (n : Nat)
    (s : List (BitVec 8) × List (List (BitVec 8))) (k : Nat) :
    List (BitVec 8) × List (List (BitVec 8)) :=
  let b := aesBlock alg key (s.1 ++ s.2[k % n]!)
  (xorBytes (b.take 8) (be64 (k + 1)), s.2.set (k % n) (b.drop 8))

/-- SP 800-38F's wrapping function W of the semiblocks `a | p`: its `6n`
steps for the `n` semiblocks of `p`, returning `A` and the `R[i]` in order. -/
def kwW (alg : Algorithm) (key a p : List (BitVec 8)) : List (BitVec 8) :=
  let n := p.length / 8
  let s := (List.range (6 * n)).foldl (wStep alg key n) (a, semiblocks p)
  s.1 ++ s.2.flatten

/-- W⁻¹'s step `t = k + 1`, the inverse of `wStep`: `B = CIPH⁻¹((A ⊕ [t]64) | R[i])`,
then `A = MSB64(B)` and `R[i] = LSB64(B)`. -/
def uStep (alg : Algorithm) (key : List (BitVec 8)) (n : Nat)
    (s : List (BitVec 8) × List (List (BitVec 8))) (k : Nat) :
    List (BitVec 8) × List (List (BitVec 8)) :=
  let b := aesBlockDecrypt alg key (xorBytes s.1 (be64 (k + 1)) ++ s.2[k % n]!)
  (b.take 8, s.2.set (k % n) (b.drop 8))

/-- SP 800-38F's unwrapping function W⁻¹ of the semiblocks `a | c`: its `6n`
steps from the last, returning `A` and the `R[i]` in order. -/
def kwWInv (alg : Algorithm) (key a c : List (BitVec 8)) : List (BitVec 8) × List (BitVec 8) :=
  let n := c.length / 8
  let s := (List.range (6 * n)).reverse.foldl (uStep alg key n) (a, semiblocks c)
  (s.1, s.2.flatten)

/-- KW's default ICV1. -/
def icv1 : List (BitVec 8) := List.replicate 8 0xa6

/-- KWP's ICV2, which the plaintext's 32-bit length follows. -/
def icv2 : List (BitVec 8) := [0xa6, 0x59, 0x59, 0xa6]

/-- KW-AE, for a plaintext of at least two semiblocks. -/
def kwAE (alg : Algorithm) (key p : List (BitVec 8)) : List (BitVec 8) :=
  kwW alg key icv1 p

/-- KW-AD, for a ciphertext of at least three semiblocks: the plaintext, unless
W⁻¹'s `A` is not ICV1. -/
def kwAD (alg : Algorithm) (key c : List (BitVec 8)) : Option (List (BitVec 8)) :=
  let (a, p) := kwWInv alg key (c.take 8) (c.drop 8)
  if a = icv1 then some p else none

/-- KWP's padded plaintext: `p` and the zeros that fill its last semiblock. -/
def kwpPad (p : List (BitVec 8)) : List (BitVec 8) :=
  p ++ List.replicate ((8 - p.length % 8) % 8) 0

/-- KWP-AE, for a plaintext of 1 to `2^32 - 1` bytes: one AES block of
`ICV2 | [len]32 | PAD` for a single padded semiblock, else W of it. -/
def kwpAE (alg : Algorithm) (key p : List (BitVec 8)) : List (BitVec 8) :=
  let a := icv2 ++ be32 p.length
  if p.length ≤ 8 then aesBlock alg key (a ++ kwpPad p) else kwW alg key a (kwpPad p)

/-- KWP-AD, for a ciphertext of at least two semiblocks: its `n` semiblocks of
padded plaintext, from one AES block for `n = 1` and W⁻¹ otherwise, are
returned without their padding if `A` is ICV2 and a length `m` with
`8(n - 1) < m ≤ 8n`, and the padding is zeros. -/
def kwpAD (alg : Algorithm) (key c : List (BitVec 8)) : Option (List (BitVec 8)) :=
  let n := c.length / 8 - 1
  let (a, p) :=
    if n = 1 then
      let s := aesBlockDecrypt alg key c
      (s.take 8, s.drop 8)
    else kwWInv alg key (c.take 8) (c.drop 8)
  let m := ofBe (a.drop 4)
  if a.take 4 = icv2 ∧ 8 * (n - 1) < m ∧ m ≤ 8 * n ∧ ∀ b ∈ p.drop m, b = 0 then some (p.take m)
  else none

-- RFC 3394's section 4.1 and 4.6, and RFC 5649's section 6.
private def hex (s : String) : List (BitVec 8) :=
  let d (c : Char) : Nat := if c.isDigit then c.toNat - '0'.toNat else c.toNat - 'a'.toNat + 10
  let rec go : List Char → List (BitVec 8)
    | a :: b :: rest => BitVec.ofNat 8 (16 * d a + d b) :: go rest
    | _ => []
  go s.toList

#guard kwAE .AES_128 (hex "000102030405060708090a0b0c0d0e0f") (hex "00112233445566778899aabbccddeeff") ==
  hex "1fa68b0a8112b447aef34bd8fb5a7b829d3e862371d2cfe5"
#guard kwAD .AES_128 (hex "000102030405060708090a0b0c0d0e0f")
  (hex "1fa68b0a8112b447aef34bd8fb5a7b829d3e862371d2cfe5") == some (hex "00112233445566778899aabbccddeeff")
#guard kwAD .AES_128 (hex "000102030405060708090a0b0c0d0e0f")
  (hex "1fa68b0a8112b447aef34bd8fb5a7b829d3e862371d2cfe4") == none
#guard kwAE .AES_256 (hex "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f")
  (hex "00112233445566778899aabbccddeeff000102030405060708090a0b0c0d0e0f") ==
  hex "28c9f404c4b810f4cbccb35cfb87f8263f5786e2d80ed326cbc7f0e71a99f43bfb988b9b7a02dd21"
#guard kwpAE .AES_192 (hex "5840df6e29b02af1ab493b705bf16ea1ae8338f4dcc176a8")
  (hex "c37b7e6492584340bed12207808941155068f738") ==
  hex "138bdeaa9b8fa7fc61f97742e72248ee5ae6ae5360d1ae6a5f54f373fa543b6a"
#guard kwpAD .AES_192 (hex "5840df6e29b02af1ab493b705bf16ea1ae8338f4dcc176a8")
  (hex "138bdeaa9b8fa7fc61f97742e72248ee5ae6ae5360d1ae6a5f54f373fa543b6a") ==
  some (hex "c37b7e6492584340bed12207808941155068f738")
#guard kwpAE .AES_192 (hex "5840df6e29b02af1ab493b705bf16ea1ae8338f4dcc176a8") (hex "466f7250617369") ==
  hex "afbeb0f07dfbf5419200f2ccb50bb24f"
#guard kwpAD .AES_192 (hex "5840df6e29b02af1ab493b705bf16ea1ae8338f4dcc176a8")
  (hex "afbeb0f07dfbf5419200f2ccb50bb24f") == some (hex "466f7250617369")
#guard kwpAD .AES_192 (hex "5840df6e29b02af1ab493b705bf16ea1ae8338f4dcc176a8")
  (hex "afbeb0f07dfbf5419200f2ccb50bb24e") == none

end rind.vale
