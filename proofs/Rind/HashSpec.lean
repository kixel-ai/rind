module
public import Aeneas
@[expose] public section

/-!
# What rind's hashes and their constructions compute

SHA-1 and SHA-256, transliterated from FIPS 180-4, and HMAC, HKDF, and
PBKDF2, transliterated from RFC 2104, RFC 5869, and RFC 8018 over any hash, in
the shape of HACL*'s `Spec.Agile.HMAC` and `Spec.Agile.HKDF`.
-/

namespace rind.spec

/-- `bytes` in `n`-byte blocks, FIPS 180-4 section 5.2, dropping a shorter
remainder, which a padded message has none of. -/
def blocks (n : Nat) (bytes : List Byte) : List (List Byte) :=
  if 0 < n ∧ n ≤ bytes.length then bytes.take n :: blocks n (bytes.drop n) else []
termination_by bytes.length
decreasing_by simp; omega

/-- FIPS 180-4 section 5.1.1's padding of `message` for SHA-1 and SHA-256: a 1
bit, then the fewest zero bits that leave room for the message's length in bits
as a 64-bit big-endian number to end on a 512-bit boundary, then that length. -/
def pad (message : List Byte) : List Byte :=
  message ++ [0x80] ++ List.replicate ((64 - (message.length + 9) % 64) % 64) 0 ++
    (BitVec.ofNat 64 (8 * message.length)).toBEBytes

/-- The 32-bit word whose big-endian bytes these are. -/
def be32 (b0 b1 b2 b3 : Byte) : BitVec 32 := BitVec.fromBEBytes [b0, b1, b2, b3]

/-- A block's big-endian 32-bit words, FIPS 180-4 section 5.2.1. -/
def words (block : List Byte) : List (BitVec 32) :=
  (List.range (block.length / 4)).map fun i =>
    be32 block[4 * i]! block[4 * i + 1]! block[4 * i + 2]! block[4 * i + 3]!

/-- FIPS 180-4 section 4.1.1 and 4.1.2's `Ch`. -/
def ch (x y z : BitVec 32) : BitVec 32 := (x &&& y) ^^^ (~~~x &&& z)

/-- FIPS 180-4 section 4.1.1 and 4.1.2's `Maj`. -/
def maj (x y z : BitVec 32) : BitVec 32 := (x &&& y) ^^^ (x &&& z) ^^^ (y &&& z)

namespace sha256

/-- FIPS 180-4 section 4.2.2's constants. -/
def K : List (BitVec 32) :=
  [0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
   0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
   0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
   0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
   0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
   0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
   0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
   0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2]

/-- FIPS 180-4 section 5.3.3's initial hash value. -/
def H0 : List (BitVec 32) :=
  [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]

/-- FIPS 180-4 section 4.1.2's functions. -/
def bigSigma0 (x : BitVec 32) : BitVec 32 := x.rotateRight 2 ^^^ x.rotateRight 13 ^^^ x.rotateRight 22
def bigSigma1 (x : BitVec 32) : BitVec 32 := x.rotateRight 6 ^^^ x.rotateRight 11 ^^^ x.rotateRight 25
def smallSigma0 (x : BitVec 32) : BitVec 32 := x.rotateRight 7 ^^^ x.rotateRight 18 ^^^ x >>> 3
def smallSigma1 (x : BitVec 32) : BitVec 32 := x.rotateRight 17 ^^^ x.rotateRight 19 ^^^ x >>> 10

/-- FIPS 180-4 section 6.2.2 step 1: the message schedule from a block's 16
words, each further word from the four 2, 7, 15, and 16 before it. -/
def schedule (M : List (BitVec 32)) : List (BitVec 32) :=
  (List.range 48).foldl (fun W t => W ++ [smallSigma1 W[t + 14]! + W[t + 9]! + smallSigma0 W[t + 1]! + W[t]!]) M

/-- FIPS 180-4 section 6.2.2 steps 2 to 4: hash value `H` after one block. -/
def compress (H : List (BitVec 32)) (block : List Byte) : List (BitVec 32) :=
  let W := schedule (words block)
  let round := fun (s : List (BitVec 32)) t =>
    let T1 := s[7]! + bigSigma1 s[4]! + ch s[4]! s[5]! s[6]! + K[t]! + W[t]!
    let T2 := bigSigma0 s[0]! + maj s[0]! s[1]! s[2]!
    [T1 + T2, s[0]!, s[1]!, s[2]!, s[3]! + T1, s[4]!, s[5]!, s[6]!]
  List.zipWith (· + ·) ((List.range 64).foldl round H) H

/-- FIPS 180-4 section 6.2: SHA-256 of a message under 2^64 bits. -/
def hash (message : List Byte) : List Byte :=
  ((blocks 64 (pad message)).foldl compress H0).flatMap BitVec.toBEBytes

end sha256

namespace sha1

/-- FIPS 180-4 section 5.3.1's initial hash value. -/
def H0 : List (BitVec 32) := [0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476, 0xc3d2e1f0]

/-- FIPS 180-4 section 4.1.1's function for round `t`. -/
def f (t : Nat) (x y z : BitVec 32) : BitVec 32 :=
  if t < 20 then ch x y z else if t < 40 then x ^^^ y ^^^ z else if t < 60 then maj x y z
  else x ^^^ y ^^^ z

/-- FIPS 180-4 section 4.2.1's constant for round `t`. -/
def K (t : Nat) : BitVec 32 :=
  if t < 20 then 0x5a827999 else if t < 40 then 0x6ed9eba1 else if t < 60 then 0x8f1bbcdc
  else 0xca62c1d6

/-- FIPS 180-4 section 6.1.2 step 1: the message schedule from a block's 16
words, each further word from the four 3, 8, 14, and 16 before it. -/
def schedule (M : List (BitVec 32)) : List (BitVec 32) :=
  (List.range 64).foldl
    (fun W t => W ++ [(W[t + 13]! ^^^ W[t + 8]! ^^^ W[t + 2]! ^^^ W[t]!).rotateLeft 1]) M

/-- FIPS 180-4 section 6.1.2 steps 2 to 4: hash value `H` after one block. -/
def compress (H : List (BitVec 32)) (block : List Byte) : List (BitVec 32) :=
  let W := schedule (words block)
  let round := fun (s : List (BitVec 32)) t =>
    [s[0]!.rotateLeft 5 + f t s[1]! s[2]! s[3]! + s[4]! + K t + W[t]!,
      s[0]!, s[1]!.rotateLeft 30, s[2]!, s[3]!]
  List.zipWith (· + ·) ((List.range 80).foldl round H) H

/-- FIPS 180-4 section 6.1: SHA-1 of a message under 2^64 bits. -/
def hash (message : List Byte) : List Byte :=
  ((blocks 64 (pad message)).foldl compress H0).flatMap BitVec.toBEBytes

end sha1

/-- RFC 2104's HMAC of `text` under `key`, with hash `H` of `B`-byte blocks,
as HACL*'s `Spec.Agile.HMAC.hmac`: a key longer than a block is hashed first,
and the key is zero-padded to a block. -/
def hmac (H : List Byte → List Byte) (B : Nat) (key text : List Byte) : List Byte :=
  let key := if key.length ≤ B then key else H key
  let key := key ++ List.replicate (B - key.length) 0
  H (key.map (· ^^^ 0x5c) ++ H (key.map (· ^^^ 0x36) ++ text))

/-- RFC 5869 section 2.2's HKDF-Extract, the HMAC of the input keying
material under the salt. -/
def hkdfExtract (prf : List Byte → List Byte → List Byte) (salt ikm : List Byte) : List Byte :=
  prf salt ikm

/-- RFC 5869 section 2.3's HKDF-Expand: the first `L` bytes of `T(1) | T(2) |
...`, where `T(i)` is the PRF under `prk` of `T(i - 1) | info | i`, and `T(0)`
is empty. `L` is at most 255 hash outputs. -/
def hkdfExpand (prf : List Byte → List Byte → List Byte) (hashLen : Nat) (prk info : List Byte)
    (L : Nat) : List Byte :=
  let T := (List.range ((L + hashLen - 1) / hashLen)).foldl
    (fun (acc : List Byte × List Byte) i =>
      let t := prf prk (acc.1 ++ info ++ [BitVec.ofNat 8 (i + 1)])
      (t, acc.2 ++ t))
    ([], [])
  T.2.take L

/-- RFC 8018 section 5.2's PBKDF2: the first `dkLen` bytes of `T_1 | T_2 |
...`, where `T_i` is the XOR of `U_1` to `U_c`, `U_1` the PRF under the password
of the salt and `i` as four big-endian bytes, and each further `U_j` the PRF of
`U_(j-1)`. -/
def pbkdf2 (prf : List Byte → List Byte → List Byte) (hLen : Nat) (password salt : List Byte)
    (c dkLen : Nat) : List Byte :=
  let T := fun (i : Nat) =>
    let U1 := prf password (salt ++ (BitVec.ofNat 32 i).toBEBytes)
    ((List.range (c - 1)).foldl
      (fun (acc : List Byte × List Byte) _ =>
        let u := prf password acc.1
        (u, List.zipWith (· ^^^ ·) acc.2 u))
      (U1, U1)).2
  ((List.range ((dkLen + hLen - 1) / hLen)).flatMap fun i => T (i + 1)).take dkLen

end rind.spec
