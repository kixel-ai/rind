import Rind.GcmSpec
import Rind.AesSbox

/-!
# s2n-bignum's AES-GCM spec

s2n-bignum's SP 800-38D and FIPS 197 specs, `common/gcm.ml`,
`common/fips197.ml`, the S-box and `MixColumns` tables of `common/aes.ml`,
`common/ghash_nist_defs.ml`'s `nist_dot` and `nist_ghash`, and
`common/ghash.ml`'s `ghash_reduce`, and the vocabulary its aarch64 AES-GCM
kernels' theorems state, `arm/proofs/utils/aes_gcm_spec.ml`'s, at rind's
fork's base, `3f01260f` (`thirdparty/s2n-bignum`, which changes none of them),
transliterated: HOL Light's `word_xor` is `^^^`, `word_add` is `+`,
`word_join` is `++`, grouped as the HOL Light is, `word_subword w (pos, len)`
into a `len`-bit word is `w.extractLsb' pos len`, `word_zx` is `setWidth`,
`word_ushr` is `>>>`, `word_rol` is `rotateLeft`, `bit i w` is `w.getLsbD i`,
`val` is `toNat`, `word n` is `BitVec.ofNat`, `ODD` is `% 2 = 1`, `EL n l` is
`l[n]!`, and `word_of_bits`, `word_reversefields`, `word_pmul`, and
`list_of_seq` are defined here as HOL Light's `Library/words.ml` and
`lists.ml` define them.

SP 800-38D reads a block's first byte as its most significant, Vale's
`quad32` its least, so a block in one is the other's with its bytes reversed:
Vale's `reverse_bytes_quad32`, which is s2n-bignum's `word_reversefields 8`
(`reversefields_eight`). Through it, the two specs are one function:

- `aes128Cipher_eq` and `aes256Cipher_eq`: FIPS 197's cipher is Vale's
  `eval_cipher` for any round keys, and `aes128KeyExpansion_eq` and
  `aes256KeyExpansion_eq`: its key schedule is Vale's `key_to_round_keys_LE`;
- `nistDot_eq` and `nistGhash_eq`: GHASH's product is Vale's `gf128_mul_LE`,
  and its fold from any accumulator Vale's Horner rule;
- `gctr_eq`, and `cipherBlock_eq` and `nistCipherBlock_eq` for the kernels'
  blocks: GCTR from any counter block is Vale's `gctr_encrypt_LE`'s blocks
  from it, so from the counter block of an IV of any length;
- `gcmAe_eq` and `gcmAd_eq`: AES-GCM with a 96-bit IV and whole-block AAD and
  message, all `gcm_ae` and `gcm_ad` take, is `gcm_encrypt_LE` and
  `gcm_decrypt_LE`, for any cipher that is Vale's AES under a key, and
  `gcmAe_aes128`, `gcmAd_aes128`, `gcmAe_aes256`, and `gcmAd_aes256` for
  FIPS 197's AES-128 and AES-256 under s2n-bignum's own key schedules.
-/

namespace rind.spec.s2n.gcm

open Polynomial
open rind.vale (Quad32 byte reverseBytesQuad32 toPoly)


/-! ## HOL Light's words and lists -/

/-- `word_of_bits s`: the word whose bit `i` is set exactly when `i` is in `s`. -/
def wordOfBits (n : Nat) (s : Nat → Bool) : BitVec n :=
  BitVec.ofNat n (∑ i ∈ Finset.range n, if s i then 2 ^ i else 0)

/-- `word_reversefields b w`: `w`'s `b`-bit fields in the other order. -/
def reversefields {n : Nat} (b : Nat) (w : BitVec n) : BitVec n :=
  wordOfBits n fun i =>
    decide (i < n) && w.getLsbD (if i < b * (n / b) then b * (n / b - 1 - i / b) + i % b else i)

/-- `word_pmul x y`: the carry-less product, its bit `k` the parity of the
set bits `i` of `x` whose partner `k - i` in `y` is set too. -/
def wordPmul {m n : Nat} (p : Nat) (x : BitVec m) (y : BitVec n) : BitVec p :=
  wordOfBits p fun k => ((Finset.range (k + 1)).filter fun i => x.getLsbD i ∧ y.getLsbD (k - i)).card % 2 = 1

/-- `list_of_seq s n`: `s 0` to `s (n - 1)`. -/
def listOfSeq {α : Type} (s : Nat → α) : Nat → List α
  | 0 => []
  | n + 1 => listOfSeq s n ++ [s n]

/-! ## AES, `common/aes.ml` and `common/fips197.ml` -/

/-- `word_join_list_16_8`: 16 bytes, the first most significant. -/
def joinList16_8 (l : List (BitVec 8)) : BitVec 128 :=
  l[0]! ++ (l[1]! ++ (l[2]! ++ (l[3]! ++ (l[4]! ++ (l[5]! ++ (l[6]! ++ (l[7]! ++ (l[8]! ++ (l[9]! ++
    (l[10]! ++ (l[11]! ++ (l[12]! ++ (l[13]! ++ (l[14]! ++ l[15]!))))))))))))))

/-- `word_join_list_16_128`: 16 blocks, the first most significant. -/
def joinList16_128 (l : List (BitVec 128)) : BitVec 2048 :=
  l[0]! ++ (l[1]! ++ (l[2]! ++ (l[3]! ++ (l[4]! ++ (l[5]! ++ (l[6]! ++ (l[7]! ++ (l[8]! ++ (l[9]! ++
    (l[10]! ++ (l[11]! ++ (l[12]! ++ (l[13]! ++ (l[14]! ++ l[15]!))))))))))))))

/-- `GF2`: FIPS 197's S-box, its value at `b` byte `b` of `joined_GF2`. -/
def gf2 : List (BitVec 128) :=
  [0x16bb54b00f2d99416842e6bf0d89a18c, 0xdf2855cee9871e9b948ed9691198f8e1,
   0x9e1dc186b95735610ef6034866b53e70, 0x8a8bbd4b1f74dde8c6b4a61c2e2578ba,
   0x08ae7a65eaf4566ca94ed58d6d37c8e7, 0x79e4959162acd3c25c2406490a3a32e0,
   0xdb0b5ede14b8ee4688902a22dc4f8160, 0x73195d643d7ea7c41744975fec130ccd,
   0xd2f3ff1021dab6bcf5389d928f40a351, 0xa89f3c507f02f94585334d43fbaaefd0,
   0xcf584c4a39becb6a5bb1fc20ed00d153, 0x842fe329b3d63b52a05a6e1b1a2c8309,
   0x75b227ebe28012079a059618c323c704, 0x1531d871f1e5a534ccf73f362693fdb7,
   0xc072a49cafa2d4adf04759fa7dc982ca, 0x76abd7fe2b670130c56f6bf27b777c63]

/-- `joined_GF2`. -/
def joinedGF2 : BitVec 2048 := joinList16_128 gf2

/-- `FFmul_02`: the products by 2 in FIPS 197's field. -/
def ffmul02Table : List (BitVec 128) :=
  [0xE5E7E1E3EDEFE9EBF5F7F1F3FDFFF9FB, 0xC5C7C1C3CDCFC9CBD5D7D1D3DDDFD9DB,
   0xA5A7A1A3ADAFA9ABB5B7B1B3BDBFB9BB, 0x858781838D8F898B959791939D9F999B,
   0x656761636D6F696B757771737D7F797B, 0x454741434D4F494B555751535D5F595B,
   0x252721232D2F292B353731333D3F393B, 0x050701030D0F090B151711131D1F191B,
   0xFEFCFAF8F6F4F2F0EEECEAE8E6E4E2E0, 0xDEDCDAD8D6D4D2D0CECCCAC8C6C4C2C0,
   0xBEBCBAB8B6B4B2B0AEACAAA8A6A4A2A0, 0x9E9C9A98969492908E8C8A8886848280,
   0x7E7C7A78767472706E6C6A6866646260, 0x5E5C5A58565452504E4C4A4846444240,
   0x3E3C3A38363432302E2C2A2826242220, 0x1E1C1A18161412100E0C0A0806040200]

/-- `joined_FFmul_02`. -/
def joinedFFmul02 : BitVec 2048 := joinList16_128 ffmul02Table

/-- `FFmul_03`: the products by 3 in FIPS 197's field. -/
def ffmul03Table : List (BitVec 128) :=
  [0x1A191C1F16151013020104070E0D080B, 0x2A292C2F26252023323134373E3D383B,
   0x7A797C7F76757073626164676E6D686B, 0x4A494C4F46454043525154575E5D585B,
   0xDAD9DCDFD6D5D0D3C2C1C4C7CECDC8CB, 0xEAE9ECEFE6E5E0E3F2F1F4F7FEFDF8FB,
   0xBAB9BCBFB6B5B0B3A2A1A4A7AEADA8AB, 0x8A898C8F86858083929194979E9D989B,
   0x818287848D8E8B88999A9F9C95969390, 0xB1B2B7B4BDBEBBB8A9AAAFACA5A6A3A0,
   0xE1E2E7E4EDEEEBE8F9FAFFFCF5F6F3F0, 0xD1D2D7D4DDDEDBD8C9CACFCCC5C6C3C0,
   0x414247444D4E4B48595A5F5C55565350, 0x717277747D7E7B78696A6F6C65666360,
   0x212227242D2E2B28393A3F3C35363330, 0x111217141D1E1B18090A0F0C05060300]

/-- `joined_FFmul_03`. -/
def joinedFFmul03 : BitVec 2048 := joinList16_128 ffmul03Table

/-- `aes_sub_byte`: byte `pos` of the table. -/
def aesSubByte (gf : BitVec 2048) (pos : BitVec 8) : BitVec 8 := gf.extractLsb' (pos.toNat * 8) 8

/-- `aes_sub_bytes_select`: the table at byte `i` of `op`. -/
def aesSubBytesSelect (gf : BitVec 2048) (op : BitVec 128) (i : Nat) : BitVec 8 :=
  aesSubByte gf (op.extractLsb' (i * 8) 8)

/-- `aes_sub_bytes`: the table at each byte, in place. -/
def aesSubBytes (gf : BitVec 2048) (op : BitVec 128) : BitVec 128 :=
  joinList16_8
    [aesSubBytesSelect gf op 15, aesSubBytesSelect gf op 14, aesSubBytesSelect gf op 13,
     aesSubBytesSelect gf op 12, aesSubBytesSelect gf op 11, aesSubBytesSelect gf op 10,
     aesSubBytesSelect gf op 9, aesSubBytesSelect gf op 8, aesSubBytesSelect gf op 7,
     aesSubBytesSelect gf op 6, aesSubBytesSelect gf op 5, aesSubBytesSelect gf op 4,
     aesSubBytesSelect gf op 3, aesSubBytesSelect gf op 2, aesSubBytesSelect gf op 1,
     aesSubBytesSelect gf op 0]

/-- `FFmul`: byte `b` of the table. -/
def ffmul (tb : BitVec 2048) (b : BitVec 8) : BitVec 8 := tb.extractLsb' (b.toNat * 8) 8

/-- `FFmul02`. -/
def ffmul02 : BitVec 8 → BitVec 8 := ffmul joinedFFmul02

/-- `FFmul03`. -/
def ffmul03 : BitVec 8 → BitVec 8 := ffmul joinedFFmul03

/-- `aes_mix_word`: one byte of `MixColumns`, from the bytes at bits `a` to `d`. -/
def aesMixWord (op : BitVec 128) (a b c d : Nat) : BitVec 8 :=
  ffmul02 (op.extractLsb' a 8) ^^^ (ffmul03 (op.extractLsb' b 8) ^^^ (op.extractLsb' c 8 ^^^ op.extractLsb' d 8))

/-- `aes_subword`: the S-box on each byte. -/
def aesSubword (op : BitVec 32) : BitVec 32 :=
  aesSubByte joinedGF2 (op.extractLsb' 24 8) ++ (aesSubByte joinedGF2 (op.extractLsb' 16 8) ++
    (aesSubByte joinedGF2 (op.extractLsb' 8 8) ++ aesSubByte joinedGF2 (op.extractLsb' 0 8)))

/-- `fips197_sub_bytes`. -/
def fips197SubBytes (s : BitVec 128) : BitVec 128 := aesSubBytes joinedGF2 s

/-- `fips197_shift_rows`. -/
def fips197ShiftRows (op : BitVec 128) : BitVec 128 :=
  joinList16_8
    [op.extractLsb' 120 8, op.extractLsb' 80 8, op.extractLsb' 40 8, op.extractLsb' 0 8,
     op.extractLsb' 88 8, op.extractLsb' 48 8, op.extractLsb' 8 8, op.extractLsb' 96 8,
     op.extractLsb' 56 8, op.extractLsb' 16 8, op.extractLsb' 104 8, op.extractLsb' 64 8,
     op.extractLsb' 24 8, op.extractLsb' 112 8, op.extractLsb' 72 8, op.extractLsb' 32 8]

/-- `fips197_mix_columns`. -/
def fips197MixColumns (op : BitVec 128) : BitVec 128 :=
  let d00 := aesMixWord op 120 112 104 96
  let d10 := aesMixWord op 112 104 96 120
  let d20 := aesMixWord op 104 96 120 112
  let d30 := aesMixWord op 96 120 112 104
  let d01 := aesMixWord op 88 80 72 64
  let d11 := aesMixWord op 80 72 64 88
  let d21 := aesMixWord op 72 64 88 80
  let d31 := aesMixWord op 64 88 80 72
  let d02 := aesMixWord op 56 48 40 32
  let d12 := aesMixWord op 48 40 32 56
  let d22 := aesMixWord op 40 32 56 48
  let d32 := aesMixWord op 32 56 48 40
  let d03 := aesMixWord op 24 16 8 0
  let d13 := aesMixWord op 16 8 0 24
  let d23 := aesMixWord op 8 0 24 16
  let d33 := aesMixWord op 0 24 16 8
  joinList16_8 [d00, d10, d20, d30, d01, d11, d21, d31, d02, d12, d22, d32, d03, d13, d23, d33]

/-- `fips197_round`. -/
def fips197Round (state roundKey : BitVec 128) : BitVec 128 :=
  fips197MixColumns (fips197ShiftRows (fips197SubBytes state)) ^^^ roundKey

/-- `fips197_final_round`. -/
def fips197FinalRound (state roundKey : BitVec 128) : BitVec 128 :=
  fips197ShiftRows (fips197SubBytes state) ^^^ roundKey

/-- `aes128_cipher`. -/
def aes128Cipher (plaintext : BitVec 128) (ks : List (BitVec 128)) : BitVec 128 :=
  let s0 := plaintext ^^^ ks[0]!
  let s1 := fips197Round s0 ks[1]!
  let s2 := fips197Round s1 ks[2]!
  let s3 := fips197Round s2 ks[3]!
  let s4 := fips197Round s3 ks[4]!
  let s5 := fips197Round s4 ks[5]!
  let s6 := fips197Round s5 ks[6]!
  let s7 := fips197Round s6 ks[7]!
  let s8 := fips197Round s7 ks[8]!
  let s9 := fips197Round s8 ks[9]!
  fips197FinalRound s9 ks[10]!

/-- `aes256_cipher`. -/
def aes256Cipher (plaintext : BitVec 128) (ks : List (BitVec 128)) : BitVec 128 :=
  let s0 := plaintext ^^^ ks[0]!
  let s1 := fips197Round s0 ks[1]!
  let s2 := fips197Round s1 ks[2]!
  let s3 := fips197Round s2 ks[3]!
  let s4 := fips197Round s3 ks[4]!
  let s5 := fips197Round s4 ks[5]!
  let s6 := fips197Round s5 ks[6]!
  let s7 := fips197Round s6 ks[7]!
  let s8 := fips197Round s7 ks[8]!
  let s9 := fips197Round s8 ks[9]!
  let s10 := fips197Round s9 ks[10]!
  let s11 := fips197Round s10 ks[11]!
  let s12 := fips197Round s11 ks[12]!
  let s13 := fips197Round s12 ks[13]!
  fips197FinalRound s13 ks[14]!

/-! ## AES's key schedule, `common/fips197.ml` -/

/-- Four words, as the key schedule's steps pass them. -/
abbrev Words4 := BitVec 32 × BitVec 32 × BitVec 32 × BitVec 32

/-- `aes_kexp_core`: `back` XOR `SubWord(RotWord(prev))` XOR `rcon`. -/
def aesKexpCore (rcon prev back : BitVec 32) : BitVec 32 :=
  back ^^^ (aesSubword (prev.rotateLeft 8) ^^^ rcon)

/-- `aes_kexp_sub`: `back` XOR `SubWord(prev)`. -/
def aesKexpSub (prev back : BitVec 32) : BitVec 32 := back ^^^ aesSubword prev

/-- `aes_rcon`: FIPS 197's round constants. -/
def aesRcon : List (BitVec 32) :=
  [0x01000000, 0x02000000, 0x04000000, 0x08000000, 0x10000000,
   0x20000000, 0x40000000, 0x80000000, 0x1b000000, 0x36000000]

/-- `aes128_kexp_round`. -/
def aes128KexpRound (i : Nat) : Words4 → Words4
  | (w0, w1, w2, w3) =>
    let w4 := aesKexpCore aesRcon[i]! w3 w0
    let w5 := w1 ^^^ w4
    let w6 := w2 ^^^ w5
    let w7 := w3 ^^^ w6
    (w4, w5, w6, w7)

/-- `aes256_kexp_round`. -/
def aes256KexpRound (i : Nat) : Words4 × Words4 → Words4 × Words4
  | ((w0, w1, w2, w3), (w4, w5, w6, w7)) =>
    let w8 := aesKexpCore aesRcon[i]! w7 w0
    let w9 := w1 ^^^ w8
    let w10 := w2 ^^^ w9
    let w11 := w3 ^^^ w10
    let w12 := aesKexpSub w11 w4
    let w13 := w5 ^^^ w12
    let w14 := w6 ^^^ w13
    let w15 := w7 ^^^ w14
    ((w8, w9, w10, w11), (w12, w13, w14, w15))

/-- `aes256_kexp_last`. -/
def aes256KexpLast (i : Nat) : Words4 × Words4 → Words4
  | ((w0, w1, w2, w3), (_, _, _, w7)) =>
    let w8 := aesKexpCore aesRcon[i]! w7 w0
    let w9 := w1 ^^^ w8
    let w10 := w2 ^^^ w9
    let w11 := w3 ^^^ w10
    (w8, w9, w10, w11)

/-- `word_join4_32_128`: four words, the first most significant. -/
def wordJoin4 : Words4 → BitVec 128
  | (w0, w1, w2, w3) => w0 ++ (w1 ++ (w2 ++ w3))

/-- `word_split128_4x32`: a block's four words, the most significant first. -/
def wordSplit4 (k : BitVec 128) : Words4 :=
  (k.extractLsb' 96 32, k.extractLsb' 64 32, k.extractLsb' 32 32, k.extractLsb' 0 32)

/-- `aes128_key_expansion`: the 11 round keys. -/
def aes128KeyExpansion (key : BitVec 128) : List (BitVec 128) :=
  let k0 := wordSplit4 key
  let k1 := aes128KexpRound 0 k0
  let k2 := aes128KexpRound 1 k1
  let k3 := aes128KexpRound 2 k2
  let k4 := aes128KexpRound 3 k3
  let k5 := aes128KexpRound 4 k4
  let k6 := aes128KexpRound 5 k5
  let k7 := aes128KexpRound 6 k6
  let k8 := aes128KexpRound 7 k7
  let k9 := aes128KexpRound 8 k8
  let k10 := aes128KexpRound 9 k9
  [k0, k1, k2, k3, k4, k5, k6, k7, k8, k9, k10].map wordJoin4

/-- `aes256_key_expansion`: the 15 round keys of the key whose first 128 bits
are `keyHi`. -/
def aes256KeyExpansion (keyHi keyLo : BitVec 128) : List (BitVec 128) :=
  let h0 := wordSplit4 keyHi
  let l0 := wordSplit4 keyLo
  let r1 := aes256KexpRound 0 (h0, l0)
  let r2 := aes256KexpRound 1 r1
  let r3 := aes256KexpRound 2 r2
  let r4 := aes256KexpRound 3 r3
  let r5 := aes256KexpRound 4 r4
  let r6 := aes256KexpRound 5 r5
  let r7 := aes256KexpLast 6 r6
  [keyHi, keyLo, wordJoin4 r1.1, wordJoin4 r1.2, wordJoin4 r2.1, wordJoin4 r2.2,
   wordJoin4 r3.1, wordJoin4 r3.2, wordJoin4 r4.1, wordJoin4 r4.2,
   wordJoin4 r5.1, wordJoin4 r5.2, wordJoin4 r6.1, wordJoin4 r6.2, wordJoin4 r7]

/-! ## GHASH, `common/ghash.ml` and `common/ghash_nist_defs.ml` -/

/-- `bit_reflect128`: bit `i` to bit `127 - i`. -/
def bitReflect128 (a : BitVec 128) : BitVec 128 := reversefields 1 a

/-- `ghash_reduce1`: the bits from 128 up folded down by `x^128 = x^7 + x^2 + x + 1`. -/
def ghashReduce1 {n : Nat} (x : BitVec n) : BitVec n :=
  (x.extractLsb' 0 128).setWidth n ^^^ wordPmul n (x >>> 128) (BitVec.ofNat n 0x87)

/-- `ghash_reduce`: a 256-bit product reduced modulo `x^128 + x^7 + x^2 + x + 1`. -/
def ghashReduce (x : BitVec 256) : BitVec 128 := (ghashReduce1 (ghashReduce1 x)).setWidth 128

/-- `nist_dot`: SP 800-38D's product in GF(2^128), its bits reflected. -/
def nistDot (a b : BitVec 128) : BitVec 128 :=
  bitReflect128 (ghashReduce (wordPmul 256 (bitReflect128 a) (bitReflect128 b)))

/-- `nist_ghash`: SP 800-38D's GHASH from the accumulator `acc`. -/
def nistGhash (h : BitVec 128) : BitVec 128 → List (BitVec 128) → BitVec 128
  | acc, [] => acc
  | acc, x :: xs => nistGhash h (nistDot (acc ^^^ x) h) xs

/-! ## GCM, `common/gcm.ml` -/

/-- `inc32`: the low 32 bits plus one, wrapping. -/
def inc32 (cb : BitVec 128) : BitVec 128 :=
  let top96 : BitVec 96 := cb.extractLsb' 32 96
  let bot32 : BitVec 32 := cb.extractLsb' 0 32
  top96 ++ (bot32 + 1)

/-- A block cipher as s2n-bignum's specs take it: a block and the round keys. -/
abbrev Cipher := BitVec 128 → List (BitVec 128) → BitVec 128

/-- `gctr`: SP 800-38D's GCTR on whole blocks. -/
def gctr (enc : Cipher) (ks : List (BitVec 128)) : BitVec 128 → List (BitVec 128) → List (BitVec 128)
  | _, [] => []
  | icb, x :: rest => (x ^^^ enc icb ks) :: gctr enc ks (inc32 icb) rest

/-- `gcm_ae`: SP 800-38D's GCM-AE for a 96-bit IV and whole blocks. -/
def gcmAe (enc : Cipher) (ks : List (BitVec 128)) (iv : BitVec 96) (P A : List (BitVec 128)) :
    List (BitVec 128) × BitVec 128 :=
  let H := enc 0 ks
  let J0 : BitVec 128 := iv ++ (1 : BitVec 32)
  let C := gctr enc ks (inc32 J0) P
  let lenBlock : BitVec 128 := BitVec.ofNat 64 (128 * A.length) ++ BitVec.ofNat 64 (128 * C.length)
  let S := nistGhash H 0 (A ++ (C ++ [lenBlock]))
  let tag := S ^^^ enc J0 ks
  (C, tag)

/-- `gcm_ad`: SP 800-38D's GCM-AD for a 96-bit IV and whole blocks. -/
def gcmAd (enc : Cipher) (ks : List (BitVec 128)) (iv : BitVec 96) (C A : List (BitVec 128))
    (tag : BitVec 128) : Option (List (BitVec 128)) :=
  let H := enc 0 ks
  let J0 : BitVec 128 := iv ++ (1 : BitVec 32)
  let P := gctr enc ks (inc32 J0) C
  let lenBlock : BitVec 128 := BitVec.ofNat 64 (128 * A.length) ++ BitVec.ofNat 64 (128 * C.length)
  let S := nistGhash H 0 (A ++ (C ++ [lenBlock]))
  let tag' := S ^^^ enc J0 ks
  if tag' = tag then some P else none

/-! ## The aarch64 kernels' blocks, `arm/proofs/utils/aes_gcm_spec.ml` -/

/-- `ctr_block`: a 96-bit nonce and a 32-bit counter. -/
def ctrBlock (nonce : BitVec 96) (ctr : Nat) : BitVec 128 := nonce ++ BitVec.ofNat 32 ctr

/-- `aes_ctr_block`: data block `i`'s keystream, from counter `c`, its bytes
in a load's order. -/
def aesCtrBlock (enc : Cipher) (c : Nat) (nonce : BitVec 96) (rk : List (BitVec 128)) (i : Nat) :
    BitVec 128 :=
  reversefields 8 (enc (ctrBlock nonce (i + c)) rk)

/-- `cipher_block`: output block `i`, the keystream XOR input block `i`. -/
def cipherBlock (enc : Cipher) (c : Nat) (nonce : BitVec 96) (rk : List (BitVec 128))
    (inblock : Nat → BitVec 128) (i : Nat) : BitVec 128 :=
  aesCtrBlock enc c nonce rk i ^^^ inblock i

/-- `nist_cipher_block`: output block `i` in SP 800-38D's byte order. -/
def nistCipherBlock (enc : Cipher) (c : Nat) (nonce : BitVec 96) (rk : List (BitVec 128))
    (inblock : Nat → BitVec 128) (i : Nat) : BitVec 128 :=
  reversefields 8 (cipherBlock enc c nonce rk inblock i)

/-- `nist_input_block`: input block `i` in SP 800-38D's byte order. -/
def nistInputBlock (inblock : Nat → BitVec 128) (i : Nat) : BitVec 128 := reversefields 8 (inblock i)


/-! ## Words and bytes -/

theorem getLsbD_wordOfBits (n : Nat) (s : Nat → Bool) (k : Nat) :
    (wordOfBits n s).getLsbD k = (decide (k < n) && s k) := by
  rw [wordOfBits, BitVec.getLsbD_ofNat, vale.testBit_sum]
  cases decide (k < n) <;> rfl

/-- `word_reversefields 8` on a block is Vale's `reverse_bytes_quad32`. -/
theorem reversefields_eight (q : Quad32) : reversefields 8 q = reverseBytesQuad32 q := by
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  rw [reversefields, getLsbD_wordOfBits, vale.getLsbD_reverseBytesQuad32 _ hk]
  simp only [hk, decide_true, Bool.true_and, ite_true]

theorem getLsbD_bitReflect128 (a : BitVec 128) (k : Nat) :
    (bitReflect128 a).getLsbD k = (decide (k < 128) && a.getLsbD (127 - k)) := by
  rw [bitReflect128, reversefields, getLsbD_wordOfBits]
  by_cases hk : k < 128
  · simp only [hk, decide_true, Bool.true_and, ite_true]
    congr 1; omega
  · simp [hk]

theorem extractLsb'_append_lo {m n : Nat} (x : BitVec m) (y : BitVec n) {s k : Nat} (h : s + k ≤ n) :
    (x ++ y).extractLsb' s k = y.extractLsb' s k := by
  apply BitVec.eq_of_getLsbD_eq; intro j hj
  simp [BitVec.getLsbD_append, hj, show s + j < n by omega]

theorem extractLsb'_append_hi {m n : Nat} (x : BitVec m) (y : BitVec n) {s k : Nat} (h : n ≤ s) :
    (x ++ y).extractLsb' s k = x.extractLsb' (s - n) k := by
  apply BitVec.eq_of_getLsbD_eq; intro j hj
  simp [BitVec.getLsbD_append, hj, show ¬ s + j < n by omega, show s + j - n = s - n + j by omega]

theorem extractLsb'_self {n s : Nat} (x : BitVec n) (h : s = 0) : x.extractLsb' s n = x := by
  subst h; apply BitVec.eq_of_getLsbD_eq; intro j hj; simp [hj]

theorem extractLsb'_extractLsb' {m : Nat} (x : BitVec m) {a n b k : Nat} (h : b + k ≤ n) :
    (x.extractLsb' a n).extractLsb' b k = x.extractLsb' (a + b) k := by
  apply BitVec.eq_of_getLsbD_eq; intro j hj
  simp [hj, show b + j < n by omega, Nat.add_assoc]

theorem byte_joinList16_8 (l : List (BitVec 8)) {i : Nat} (hi : i < 16) :
    byte (joinList16_8 l) i = l[15 - i]! := by
  unfold joinList16_8 byte
  interval_cases i <;> simp (disch := omega) only [extractLsb'_append_lo, extractLsb'_append_hi, extractLsb'_self]

/-- A byte of a block, its bytes reversed, at its bit position. -/
theorem extractLsb'_rev (s : Quad32) (p : Nat) (hp : p % 8 = 0) (hp' : p < 128) :
    (reverseBytesQuad32 s).extractLsb' p 8 = byte s (15 - p / 8) := by
  rw [← vale.byte_reverseBytes _ (by omega), byte]; congr 1; omega

theorem rev_zero : reverseBytesQuad32 0 = 0 := by decide

theorem getElem!_map_rev (rk : List Quad32) (i : Nat) :
    (rk.map reverseBytesQuad32)[i]! = reverseBytesQuad32 rk[i]! := by
  by_cases h : i < rk.length
  · simp [h]
  · simp only [List.getElem!_eq_getElem?_getD, List.getElem?_map, List.getElem?_eq_none (show rk.length ≤ i by omega)]
    exact rev_zero.symm

/-! ## AES -/

/-- Every byte's value in `joined_GF2` is FIPS 197's S-box's. -/
def gf2Agrees : Bool :=
  (List.range 256).all fun i => aesSubByte joinedGF2 (BitVec.ofNat 8 i) == vale.sboxTree (BitVec.ofNat 8 i)

theorem gf2Agrees_true : gf2Agrees = true := by decide +kernel

/-- s2n-bignum's S-box table is Vale's S-box. -/
theorem aesSubByte_eq (b : BitVec 8) : aesSubByte joinedGF2 b = vale.sbox b := by
  rw [vale.sbox_eq_tree]
  have := List.all_eq_true.1 gf2Agrees_true b.toNat (List.mem_range.2 b.isLt)
  simpa using this

/-- Every byte's products by 2 and 3 in `joined_FFmul_02` and `joined_FFmul_03`
are FIPS 197's `xtime` and `xtime` XOR the byte. -/
def ffmulAgrees : Bool :=
  (List.range 256).all fun i =>
    ffmul02 (BitVec.ofNat 8 i) == vale.xtime (BitVec.ofNat 8 i) &&
      ffmul03 (BitVec.ofNat 8 i) == (vale.xtime (BitVec.ofNat 8 i) ^^^ BitVec.ofNat 8 i)

theorem ffmulAgrees_true : ffmulAgrees = true := by decide +kernel

theorem ffmul02_eq (b : BitVec 8) : ffmul02 b = vale.xtime b := by
  have := List.all_eq_true.1 ffmulAgrees_true b.toNat (List.mem_range.2 b.isLt)
  simp at this; exact this.1

theorem ffmul03_eq (b : BitVec 8) : ffmul03 b = vale.xtime b ^^^ b := by
  have := List.all_eq_true.1 ffmulAgrees_true b.toNat (List.mem_range.2 b.isLt)
  simp at this; exact this.2

theorem byte_aesSubBytes (gf : BitVec 2048) (op : BitVec 128) {i : Nat} (hi : i < 16) :
    byte (aesSubBytes gf op) i = aesSubByte gf (byte op i) := by
  rw [aesSubBytes, byte_joinList16_8 _ hi]
  interval_cases i <;> rfl

theorem subBytes_rev (s : Quad32) :
    fips197SubBytes (reverseBytesQuad32 s) = reverseBytesQuad32 (vale.subBytes s) := by
  apply vale.eq_of_byte_eq; intro i hi
  rw [fips197SubBytes, byte_aesSubBytes _ _ hi, aesSubByte_eq, vale.byte_reverseBytes _ hi,
    vale.byte_reverseBytes _ hi, vale.byte_subBytes _ (by omega)]

theorem shiftRows_rev (s : Quad32) :
    fips197ShiftRows (reverseBytesQuad32 s) = reverseBytesQuad32 (vale.shiftRows s) := by
  apply vale.eq_of_byte_eq; intro i hi
  rw [fips197ShiftRows, byte_joinList16_8 _ hi, vale.byte_reverseBytes _ hi, vale.byte_shiftRows _ (by omega)]
  interval_cases i <;> simp [extractLsb'_rev]

theorem mixColumns_rev (s : Quad32) :
    fips197MixColumns (reverseBytesQuad32 s) = reverseBytesQuad32 (vale.mixColumns s) := by
  apply vale.eq_of_byte_eq; intro i hi
  simp only [fips197MixColumns]
  rw [byte_joinList16_8 _ hi, vale.byte_reverseBytes _ hi, vale.mixColumns_eq, vale.fips197MixColumns,
    vale.byte_ofBytes _ (by omega)]
  interval_cases i <;> simp [aesMixWord, extractLsb'_rev, ffmul02_eq, ffmul03_eq, BitVec.xor_assoc]

theorem round_rev (s k : Quad32) :
    fips197Round (reverseBytesQuad32 s) (reverseBytesQuad32 k) = reverseBytesQuad32 (vale.evalRound s k) := by
  rw [fips197Round, vale.evalRound, subBytes_rev, shiftRows_rev, mixColumns_rev, vale.reverseBytes_xor]

theorem finalRound_rev (s k : Quad32) :
    fips197FinalRound (reverseBytesQuad32 s) (reverseBytesQuad32 k) =
      reverseBytesQuad32 (vale.shiftRows (vale.subBytes s) ^^^ k) := by
  rw [fips197FinalRound, subBytes_rev, shiftRows_rev, vale.reverseBytes_xor]

/-- FIPS 197's AES-128 is Vale's, for any round keys. -/
theorem aes128Cipher_eq (x : BitVec 128) (rk : List Quad32) :
    aes128Cipher x (rk.map reverseBytesQuad32) =
      reverseBytesQuad32 (vale.evalCipher .AES_128 (reverseBytesQuad32 x) rk) := by
  conv_lhs => rw [← vale.reverseBytesQuad32_involutive x]
  simp only [aes128Cipher, vale.evalCipher, vale.nr, vale.evalRounds, getElem!_map_rev,
    ← vale.reverseBytes_xor, round_rev, finalRound_rev]

/-- FIPS 197's AES-256 is Vale's, for any round keys. -/
theorem aes256Cipher_eq (x : BitVec 128) (rk : List Quad32) :
    aes256Cipher x (rk.map reverseBytesQuad32) =
      reverseBytesQuad32 (vale.evalCipher .AES_256 (reverseBytesQuad32 x) rk) := by
  conv_lhs => rw [← vale.reverseBytesQuad32_involutive x]
  simp only [aes256Cipher, vale.evalCipher, vale.nr, vale.evalRounds, getElem!_map_rev,
    ← vale.reverseBytes_xor, round_rev, finalRound_rev]

/-! ## GHASH -/

theorem natCast_zmod2 (c : Nat) : (c : ZMod 2) = if c % 2 = 1 then 1 else 0 := by
  rw [← ZMod.natCast_mod]
  rcases Nat.mod_two_eq_zero_or_one c with h | h <;> simp [h]

/-- `word_pmul`'s bit `k` is the product's coefficient `k`. -/
theorem coeff_toPoly_wordPmul {m n : Nat} (p : Nat) (x : BitVec m) (y : BitVec n) (k : Nat) :
    (toPoly (wordPmul p x y)).coeff k = if k < p then (toPoly x * toPoly y).coeff k else 0 := by
  rw [vale.coeff_toPoly, wordPmul, getLsbD_wordOfBits, Polynomial.coeff_mul,
    Finset.Nat.sum_antidiagonal_eq_sum_range_succ_mk]
  simp only [vale.coeff_toPoly, ite_mul, one_mul, zero_mul]
  have hs : (∑ i ∈ Finset.range (k + 1),
      if x.getLsbD i = true then (if y.getLsbD (k - i) = true then (1 : ZMod 2) else 0) else 0) =
      (((Finset.range (k + 1)).filter fun i => x.getLsbD i = true ∧ y.getLsbD (k - i) = true).card : ZMod 2) := by
    rw [Finset.natCast_card_filter]
    apply Finset.sum_congr rfl; intro i _
    by_cases hx : x.getLsbD i = true <;> by_cases hy : y.getLsbD (k - i) = true <;> simp [hx, hy]
  rw [hs, natCast_zmod2]
  by_cases hk : k < p <;> simp [hk]

theorem natDegree_toPoly_le {n : Nat} (x : BitVec n) : (toPoly x).natDegree ≤ n - 1 :=
  Polynomial.natDegree_le_iff_coeff_eq_zero.2 fun j hj => by
    rw [vale.coeff_toPoly, BitVec.getLsbD_of_ge x j (by
      have : n - 1 < j := by exact_mod_cast hj
      omega)]
    rfl

/-- `word_pmul` into a word wide enough for the product is the product. -/
theorem toPoly_wordPmul {m n : Nat} (p : Nat) (x : BitVec m) (y : BitVec n)
    (h : (toPoly x * toPoly y).natDegree < p) : toPoly (wordPmul p x y) = toPoly x * toPoly y := by
  ext k
  rw [coeff_toPoly_wordPmul]
  split
  · rfl
  · rw [Polynomial.coeff_eq_zero_of_natDegree_lt (by omega)]

theorem toPoly_bitReflect128 (a : BitVec 128) : toPoly (bitReflect128 a) = vale.reverse (toPoly a) 127 := by
  ext j
  rw [vale.coeff_toPoly, getLsbD_bitReflect128, vale.coeff_reverse, vale.coeff_toPoly]
  by_cases hj : j < 128
  · simp [hj, show j ≤ 127 by omega]
  · simp [hj, show ¬ j ≤ 127 by omega]

theorem toPoly_c87 : toPoly (BitVec.ofNat 256 0x87) = vale.gf128ModulusLowTerms := by
  ext m
  rw [vale.coeff_toPoly, vale.coeff_low, BitVec.getLsbD_ofNat]
  by_cases hm : m < 8
  · interval_cases m <;> simp <;> decide
  · have : (0x87 : Nat).testBit m = false :=
      Nat.testBit_lt_two_pow (lt_of_lt_of_le (by norm_num) (Nat.pow_le_pow_right (by omega) (show 8 ≤ m by omega)))
    simp [this, show ¬ (m = 0 ∨ m = 1 ∨ m = 2 ∨ m = 7) by omega]

theorem natDegree_low : vale.gf128ModulusLowTerms.natDegree ≤ 7 :=
  Polynomial.natDegree_le_iff_coeff_eq_zero.2 fun j hj => by
    have : 7 < j := by exact_mod_cast hj
    rw [vale.coeff_low]
    simp [show ¬ (j = 0 ∨ j = 1 ∨ j = 2 ∨ j = 7) by omega]

/-- The low 128 bits of a 256-bit word, zero-extended. -/
abbrev low128 (x : BitVec 256) : BitVec 256 := (x.extractLsb' 0 128).setWidth 256

theorem natDegree_low128 (x : BitVec 256) : (toPoly (low128 x)).natDegree ≤ 127 :=
  Polynomial.natDegree_le_iff_coeff_eq_zero.2 fun j hj => by
    have : 127 < j := by exact_mod_cast hj
    rw [vale.coeff_toPoly]; simp [BitVec.getLsbD_setWidth, BitVec.getLsbD_extractLsb', show ¬ j < 128 by omega]

theorem toPoly_split (x : BitVec 256) : toPoly x = toPoly (low128 x) + X ^ 128 * toPoly (x >>> 128) := by
  ext j
  rw [Polynomial.coeff_add, vale.coeff_toPoly, vale.coeff_toPoly, Polynomial.coeff_X_pow_mul', vale.coeff_toPoly]
  by_cases hj : j < 128
  · simp [hj, show ¬ 128 ≤ j by omega, show j < 256 by omega]
  · simp [BitVec.getLsbD_setWidth, show 128 ≤ j by omega, show 128 + (j - 128) = j by omega]

theorem natDegree_ushr (x : BitVec 256) {d : Nat} (hx : (toPoly x).natDegree ≤ 128 + d) :
    (toPoly (x >>> 128)).natDegree ≤ d :=
  Polynomial.natDegree_le_iff_coeff_eq_zero.2 fun j hj => by
    have : d < j := by exact_mod_cast hj
    have h := Polynomial.coeff_eq_zero_of_natDegree_lt (show (toPoly x).natDegree < 128 + j by omega)
    rw [vale.coeff_toPoly] at h ⊢
    simp only [BitVec.getLsbD_ushiftRight]
    by_cases hb : x.getLsbD (128 + j) = true
    · simp [hb] at h
    · simp [hb]

theorem toPoly_ghashReduce1 (x : BitVec 256) :
    toPoly (ghashReduce1 x) = toPoly (low128 x) + toPoly (x >>> 128) * vale.gf128ModulusLowTerms := by
  have hd := natDegree_ushr x (d := 127) (by have := natDegree_toPoly_le x; omega)
  rw [ghashReduce1, vale.toPoly_xor, toPoly_wordPmul, toPoly_c87]
  rw [toPoly_c87]
  have := Polynomial.natDegree_mul_le (p := toPoly (x >>> 128)) (q := vale.gf128ModulusLowTerms)
  have := natDegree_low
  omega

theorem modulus_eq : vale.gf128Modulus = X ^ 128 + vale.gf128ModulusLowTerms := by
  unfold vale.gf128Modulus; rfl

theorem dvd_ghashReduce1 (x : BitVec 256) : vale.gf128Modulus ∣ toPoly x - toPoly (ghashReduce1 x) :=
  ⟨toPoly (x >>> 128), by
    rw [modulus_eq]
    linear_combination toPoly_split x - toPoly_ghashReduce1 x -
      (toPoly (x >>> 128) * vale.gf128ModulusLowTerms) * vale.two_eq_zero_P⟩

theorem natDegree_ghashReduce1 (x : BitVec 256) {d : Nat} (hd : (toPoly (x >>> 128)).natDegree ≤ d) :
    (toPoly (ghashReduce1 x)).natDegree ≤ max 127 (d + 7) := by
  rw [toPoly_ghashReduce1]
  have h1 := natDegree_low128 x
  have h2 := Polynomial.natDegree_mul_le (p := toPoly (x >>> 128)) (q := vale.gf128ModulusLowTerms)
  have h3 := natDegree_low
  have := Polynomial.natDegree_add_le (toPoly (low128 x)) (toPoly (x >>> 128) * vale.gf128ModulusLowTerms)
  omega

theorem toPoly_setWidth128 (z : BitVec 256) (hz : (toPoly z).natDegree ≤ 127) :
    toPoly (z.setWidth 128) = toPoly z := by
  ext j
  rw [vale.coeff_toPoly, vale.coeff_toPoly, BitVec.getLsbD_setWidth]
  by_cases hj : j < 128
  · simp [hj]
  · have h := Polynomial.coeff_eq_zero_of_natDegree_lt (show (toPoly z).natDegree < j by omega)
    rw [vale.coeff_toPoly] at h
    by_cases hb : z.getLsbD j = true
    · simp [hb] at h
    · simp [hj, hb]

/-- `ghash_reduce` is the remainder modulo GCM's polynomial. -/
theorem toPoly_ghashReduce (x : BitVec 256) : toPoly (ghashReduce x) = toPoly x %ₘ vale.gf128Modulus := by
  have hy := natDegree_ghashReduce1 x (d := 127) (natDegree_ushr x (by have := natDegree_toPoly_le x; omega))
  have hz := natDegree_ghashReduce1 (ghashReduce1 x) (d := 6) (natDegree_ushr _ (by omega))
  rw [ghashReduce, toPoly_setWidth128 _ (by omega)]
  apply vale.eq_of_dvd (by unfold vale.Small; omega) (vale.small_mod _)
  have hm : vale.gf128Modulus ∣ toPoly x - toPoly x %ₘ vale.gf128Modulus :=
    ⟨toPoly x /ₘ vale.gf128Modulus, by
      have := Polynomial.modByMonic_add_div (toPoly x) vale.gf128Modulus
      linear_combination -this⟩
  have := dvd_sub (dvd_sub hm (dvd_ghashReduce1 x)) (dvd_ghashReduce1 (ghashReduce1 x))
  convert this using 1; ring

/-- `nist_dot` is Vale's `gf128_mul_rev` on the blocks' polynomials. -/
theorem toPoly_nistDot (a b : BitVec 128) : toPoly (nistDot a b) = vale.gf128MulRev (toPoly a) (toPoly b) := by
  rw [nistDot, toPoly_bitReflect128, toPoly_ghashReduce, toPoly_wordPmul, toPoly_bitReflect128,
    toPoly_bitReflect128]
  · rfl
  · have := Polynomial.natDegree_mul_le (p := toPoly (bitReflect128 a)) (q := toPoly (bitReflect128 b))
    have := natDegree_toPoly_le (bitReflect128 a)
    have := natDegree_toPoly_le (bitReflect128 b)
    omega

/-- `nist_dot` is Vale's `gf128_mul_LE`, its blocks' bytes reversed. -/
theorem nistDot_eq (a b : BitVec 128) :
    nistDot a b = reverseBytesQuad32 (vale.gf128MulLE (reverseBytesQuad32 a) (reverseBytesQuad32 b)) := by
  apply vale.toPoly_inj
  rw [toPoly_nistDot]
  show _ = vale.polyLE _
  rw [vale.polyLE_mulLE]
  simp only [vale.polyLE, vale.reverseBytesQuad32_involutive]

/-- `nist_ghash` from any accumulator is Vale's Horner rule, its blocks' bytes reversed. -/
theorem nistGhash_eq (h : BitVec 128) : ∀ (acc : BitVec 128) (xs : List (BitVec 128)),
    nistGhash h acc xs = reverseBytesQuad32 ((xs.map reverseBytesQuad32).foldl
      (fun y x => vale.gf128MulLE (y ^^^ x) (reverseBytesQuad32 h)) (reverseBytesQuad32 acc))
  | acc, [] => by simp [nistGhash, vale.reverseBytesQuad32_involutive]
  | acc, x :: xs => by
    rw [nistGhash, nistGhash_eq h _ xs, nistDot_eq, vale.reverseBytesQuad32_involutive, vale.reverseBytes_xor,
      List.map_cons, List.foldl_cons]

/-- `nist_ghash` from zero is Vale's `ghash_LE`, its blocks' bytes reversed. -/
theorem nistGhash_zero (h : BitVec 128) (xs : List (BitVec 128)) :
    nistGhash h 0 xs = reverseBytesQuad32 (vale.ghashLE (reverseBytesQuad32 h) (xs.map reverseBytesQuad32)) := by
  rw [nistGhash_eq, rev_zero]; rfl

/-! ## GCTR -/

/-- A cipher that is Vale's AES under the key words `key`, through the byte
reversal: what s2n-bignum's GCM takes as `enc` and `ks`. -/
def IsValeAes (enc : Cipher) (ks : List (BitVec 128)) (alg : vale.Algorithm) (key : List (BitVec 32)) : Prop :=
  ∀ x, enc x ks = reverseBytesQuad32 (vale.aesEncrypt alg key (reverseBytesQuad32 x))

theorem inc32_eq (cb : BitVec 128) : inc32 cb = vale.inc32 cb 1 := rfl

/-- GCTR from counter block `inc32 icb i` is Vale's blocks from `icb`, from
block `i`, their bytes reversed. -/
theorem gctr_eq {enc : Cipher} {ks : List (BitVec 128)} {alg : vale.Algorithm} {key : List (BitVec 32)}
    (he : IsValeAes enc ks alg key) (icb : Quad32) : ∀ (xs : List (BitVec 128)) (i : Nat),
    gctr enc ks (vale.inc32 icb i) xs =
      (vale.gctrEncryptRecursive icb alg key (xs.map reverseBytesQuad32) i).map reverseBytesQuad32
  | [], _ => rfl
  | x :: xs, i => by
    rw [gctr, inc32_eq, vale.inc32_inc32, gctr_eq he icb xs (i + 1), he]
    simp only [List.map_cons, vale.gctrEncryptRecursive, vale.gctrEncryptBlock, vale.reverseBytes_xor,
      vale.reverseBytesQuad32_involutive]

/-! ## The kernels' blocks -/

theorem listOfSeq_eq {α : Type} (s : Nat → α) : ∀ n, listOfSeq s n = (List.range n).map s
  | 0 => rfl
  | n + 1 => by rw [listOfSeq, listOfSeq_eq s n, List.range_succ, List.map_append, List.map_singleton]

/-- Counter `i + c` is Vale's `inc32` of counter `c` by `i`. -/
theorem ctrBlock_add (nonce : BitVec 96) (c i : Nat) : ctrBlock nonce (i + c) = vale.inc32 (ctrBlock nonce c) i := by
  rw [ctrBlock, ctrBlock, vale.inc32, extractLsb'_append_hi _ _ (le_refl 32), extractLsb'_append_lo _ _ (le_refl _),
    extractLsb'_self _ rfl, extractLsb'_self _ rfl, BitVec.ofNat_add, BitVec.add_comm]

/-- `aes_ctr_block` is Vale's keystream block `i` from the counter block. -/
theorem aesCtrBlock_eq {enc : Cipher} {rk : List (BitVec 128)} {alg : vale.Algorithm} {key : List (BitVec 32)}
    (he : IsValeAes enc rk alg key) (c : Nat) (nonce : BitVec 96) (i : Nat) :
    aesCtrBlock enc c nonce rk i = vale.aesEncrypt alg key (reverseBytesQuad32 (vale.inc32 (ctrBlock nonce c) i)) := by
  rw [aesCtrBlock, reversefields_eight, he, vale.reverseBytesQuad32_involutive, ctrBlock_add]

/-- `cipher_block` is Vale's GCTR block `i` from the counter block. -/
theorem cipherBlock_eq {enc : Cipher} {rk : List (BitVec 128)} {alg : vale.Algorithm} {key : List (BitVec 32)}
    (he : IsValeAes enc rk alg key) (c : Nat) (nonce : BitVec 96) (inblock : Nat → BitVec 128) (i : Nat) :
    cipherBlock enc c nonce rk inblock i = vale.gctrEncryptBlock (ctrBlock nonce c) (inblock i) alg key i := by
  rw [cipherBlock, aesCtrBlock_eq he, vale.gctrEncryptBlock, BitVec.xor_comm]

/-- `nist_cipher_block` is Vale's GCTR block `i` from the counter block, its bytes reversed. -/
theorem nistCipherBlock_eq {enc : Cipher} {rk : List (BitVec 128)} {alg : vale.Algorithm} {key : List (BitVec 32)}
    (he : IsValeAes enc rk alg key) (c : Nat) (nonce : BitVec 96) (inblock : Nat → BitVec 128) (i : Nat) :
    nistCipherBlock enc c nonce rk inblock i =
      reverseBytesQuad32 (vale.gctrEncryptBlock (ctrBlock nonce c) (inblock i) alg key i) := by
  rw [nistCipherBlock, reversefields_eight, cipherBlock_eq he]

/-! ## GCM -/

/-- 16 bytes as SP 800-38D reads a block, the first most significant. -/
def beBlock (b : List (BitVec 8)) : BitVec 128 := reverseBytesQuad32 (vale.leBytesToQuad32 b)

/-- Bytes as SP 800-38D's blocks, 16 a block. -/
def beBlocks (b : List (BitVec 8)) : List (BitVec 128) := (vale.leBytesToSeqQuad32 b).map reverseBytesQuad32

/-- A 96-bit IV's 12 bytes as SP 800-38D reads them, the first most significant. -/
def ivWord (iv : List (BitVec 8)) : BitVec 96 := (beBlock (iv ++ List.replicate 4 0)).extractLsb' 32 96

theorem leQuad32ToBytes_leBytesToQuad32 (l : List (BitVec 8)) (hl : l.length = 16) :
    vale.leQuad32ToBytes (vale.leBytesToQuad32 l) = l := by
  apply List.ext_getElem (by simp [vale.leQuad32ToBytes, hl])
  intro i h1 h2
  have hi : i < 16 := by simpa [vale.leQuad32ToBytes] using h1
  have := vale.leQuad32ToBytes_getElem! (vale.leBytesToQuad32 l) hi
  rw [vale.byte_leBytesToQuad32 _ hi] at this
  simpa [List.getElem!_eq_getElem?_getD, h1, h2] using this

theorem beBlock_inj {a b : List (BitVec 8)} (ha : a.length = 16) (hb : b.length = 16) :
    beBlock a = beBlock b ↔ a = b := by
  refine ⟨fun h => ?_, fun h => h ▸ rfl⟩
  have h' := congrArg (fun q => vale.leQuad32ToBytes (reverseBytesQuad32 q)) h
  simp only [beBlock, vale.reverseBytesQuad32_involutive] at h'
  rwa [leQuad32ToBytes_leBytesToQuad32 _ ha, leQuad32ToBytes_leBytesToQuad32 _ hb] at h'

theorem leBytesToSeqQuad32_leSeqQuad32ToBytes : ∀ qs : List Quad32,
    vale.leBytesToSeqQuad32 (vale.leSeqQuad32ToBytes qs) = qs
  | [] => by simp [vale.leBytesToSeqQuad32, vale.leSeqQuad32ToBytes, vale.seqToSeqFourLE, vale.seqNat8ToSeqNat32LE]
  | q :: qs => by
    have hl : (vale.leQuad32ToBytes q).length = 16 := by simp [vale.leQuad32ToBytes]
    have ih := leBytesToSeqQuad32_leSeqQuad32ToBytes qs
    rw [vale.leBytesToSeqQuad32_eq] at ih ⊢
    rw [vale.leSeqQuad32ToBytes, List.flatMap_cons, ← vale.leSeqQuad32ToBytes,
      vale.chunksOf_cons (by omega) (by simp [hl]), List.take_left' hl, List.drop_left' hl, List.map_cons, ih,
      vale.leBytesToQuad32_leQuad32ToBytes]

theorem padTo128Bits_of_mod (b : List (BitVec 8)) (h : b.length % 16 = 0) : vale.padTo128Bits b = b := by
  simp [vale.padTo128Bits, h]

theorem length_beBlocks (b : List (BitVec 8)) : (beBlocks b).length = b.length / 16 := by
  rw [beBlocks, List.length_map, vale.leBytesToSeqQuad32_eq, List.length_map, vale.chunksOf_length]

theorem map_rev_beBlocks (b : List (BitVec 8)) : (beBlocks b).map reverseBytesQuad32 = vale.leBytesToSeqQuad32 b := by
  simp [beBlocks, Function.comp_def, vale.reverseBytesQuad32_involutive]

theorem lengths_block (a c : Nat) :
    vale.insertNat64 (vale.insertNat64 (vale.mkfour 0 0 0 0) a 1) c 0 = BitVec.ofNat 64 a ++ BitVec.ofNat 64 c := by
  simp only [vale.insertNat64, Nat.one_ne_zero, ↓reduceIte]
  rw [extractLsb'_append_hi _ _ (le_refl 64), extractLsb'_self _ rfl]

theorem mkfour_zero : vale.mkfour 0 0 0 0 = 0 := rfl

/-- The hash key: the cipher of the zero block. -/
theorem hashKey_eq {enc : Cipher} {ks : List (BitVec 128)} {alg : vale.Algorithm} {kw : List (BitVec 32)}
    (he : IsValeAes enc ks alg kw) :
    enc 0 ks = reverseBytesQuad32 (vale.aesEncrypt alg kw (vale.mkfour 0 0 0 0)) := by
  rw [he, rev_zero, mkfour_zero]

/-- `J0` for a 96-bit IV is Vale's `compute_iv_BE`'s. -/
theorem j0_eq (hLE : Quad32) (iv : List (BitVec 8)) (hiv : iv.length = 12) :
    ivWord iv ++ (1 : BitVec 32) = vale.computeIvBE hLE iv := by
  rw [vale.computeIvBE_96 _ _ hiv]; rfl

/-- GCTR from `inc32 j0` on whole blocks is Vale's `gctr_encrypt_LE` from `inc32 j0 1`. -/
theorem gctr_bytes {enc : Cipher} {ks : List (BitVec 128)} {alg : vale.Algorithm} {kw : List (BitVec 32)}
    (he : IsValeAes enc ks alg kw) (j0 : Quad32) (m : List (BitVec 8)) (hm : m.length % 16 = 0) :
    gctr enc ks (inc32 j0) (beBlocks m) = beBlocks (vale.gctrEncrypt (vale.inc32 j0 1) m alg kw) := by
  have h0 : inc32 j0 = vale.inc32 (vale.inc32 j0 1) 0 := by rw [vale.inc32_zero, inc32_eq]
  rw [h0, gctr_eq he, map_rev_beBlocks, vale.gctrEncrypt, ite_eq_left hm, beBlocks,
    leBytesToSeqQuad32_leSeqQuad32ToBytes]

/-- The tag: GHASH of the AAD, the ciphertext, and the lengths, XOR the
counter block's keystream, is Vale's, GCTR from `j0` on `gcm_hash`. -/
theorem tag_eq {enc : Cipher} {ks : List (BitVec 128)} {alg : vale.Algorithm} {kw : List (BitVec 32)}
    (he : IsValeAes enc ks alg kw) (j0 : Quad32) (auth c : List (BitVec 8)) (ha : auth.length % 16 = 0)
    (hc : c.length % 16 = 0) :
    let hLE := vale.aesEncrypt alg kw (vale.mkfour 0 0 0 0)
    nistGhash (enc 0 ks) 0 (beBlocks auth ++ (beBlocks c ++
        [BitVec.ofNat 64 (128 * (beBlocks auth).length) ++ BitVec.ofNat 64 (128 * (beBlocks c).length)])) ^^^
      enc j0 ks = beBlock (vale.gctrEncrypt j0 (vale.leQuad32ToBytes (vale.gcmHash hLE auth c)) alg kw) := by
  intro hLE
  rw [hashKey_eq he, nistGhash_zero, vale.reverseBytesQuad32_involutive, he, ← vale.reverseBytes_xor,
    vale.gctr_block, beBlock, vale.leBytesToQuad32_leQuad32ToBytes, length_beBlocks, length_beBlocks,
    show 128 * (auth.length / 16) = 8 * auth.length by omega, show 128 * (c.length / 16) = 8 * c.length by omega,
    vale.gcmHash, padTo128Bits_of_mod _ ha, padTo128Bits_of_mod _ hc, lengths_block]
  simp only [List.map_append, map_rev_beBlocks, List.map_cons, List.map_nil]
  rfl

/-- `gcm_ae` with a 96-bit IV and whole-block AAD and message is Vale's
`gcm_encrypt_LE`, for any cipher that is Vale's AES under the key. -/
theorem gcmAe_eq {enc : Cipher} {ks : List (BitVec 128)} {alg : vale.Algorithm} {key : List (BitVec 8)}
    (he : IsValeAes enc ks alg (vale.seqNat8ToSeqNat32LE key)) (iv plain auth : List (BitVec 8))
    (hiv : iv.length = 12) (hp : plain.length % 16 = 0) (ha : auth.length % 16 = 0) :
    gcmAe enc ks (ivWord iv) (beBlocks plain) (beBlocks auth) =
      (beBlocks (vale.gcmEncrypt alg key iv plain auth).1, beBlock (vale.gcmEncrypt alg key iv plain auth).2) := by
  have hc := vale.length_gctrEncrypt
    (vale.inc32 (vale.computeIvBE (vale.aesEncrypt alg (vale.seqNat8ToSeqNat32LE key) (vale.mkfour 0 0 0 0)) iv) 1)
    plain alg (vale.seqNat8ToSeqNat32LE key)
  simp only [gcmAe, vale.gcmEncrypt]
  rw [j0_eq _ _ hiv, hashKey_eq he] at *
  rw [gctr_bytes he _ _ hp, ← hashKey_eq he, tag_eq he _ _ _ ha (by rw [hc]; exact hp)]

/-- `gcm_ad` with a 96-bit IV and whole-block AAD and ciphertext is Vale's
`gcm_decrypt_LE`: the plaintext when Vale accepts the tag, and nothing when it
refuses it, for any cipher that is Vale's AES under the key. -/
theorem gcmAd_eq {enc : Cipher} {ks : List (BitVec 128)} {alg : vale.Algorithm} {key : List (BitVec 8)}
    (he : IsValeAes enc ks alg (vale.seqNat8ToSeqNat32LE key)) (iv cipher auth tag : List (BitVec 8))
    (hiv : iv.length = 12) (hc : cipher.length % 16 = 0) (ha : auth.length % 16 = 0) (ht : tag.length = 16) :
    gcmAd enc ks (ivWord iv) (beBlocks cipher) (beBlocks auth) (beBlock tag) =
      if (vale.gcmDecrypt alg key iv cipher auth tag).2 then
        some (beBlocks (vale.gcmDecrypt alg key iv cipher auth tag).1)
      else none := by
  simp only [gcmAd, vale.gcmDecrypt]
  rw [j0_eq (vale.aesEncrypt alg (vale.seqNat8ToSeqNat32LE key) (vale.mkfour 0 0 0 0)) _ hiv,
    gctr_bytes he _ _ hc, tag_eq he _ _ _ ha hc]
  have hl : ∀ j0 z, (vale.gctrEncrypt j0 (vale.leQuad32ToBytes z) alg (vale.seqNat8ToSeqNat32LE key)).length = 16 :=
    fun _ _ => by rw [vale.length_gctrEncrypt]; simp [vale.leQuad32ToBytes]
  simp only [beBlock_inj (hl _ _) ht, beq_iff_eq]

/-! ## The key schedules -/

/-- A word's bytes in the other order: Vale's words hold the key's first byte
least significant, s2n-bignum's most. -/
def bswap (w : BitVec 32) : BitVec 32 :=
  w.extractLsb' 0 8 ++ (w.extractLsb' 8 8 ++ (w.extractLsb' 16 8 ++ w.extractLsb' 24 8))

theorem wbyte_bswap (w : BitVec 32) {b : Nat} (hb : b < 4) : vale.wbyte (bswap w) b = vale.wbyte w (3 - b) := by
  unfold bswap vale.wbyte
  interval_cases b <;> simp (disch := omega) only [extractLsb'_append_lo, extractLsb'_append_hi, extractLsb'_self]

theorem bswap_xor (a b : BitVec 32) : bswap (a ^^^ b) = bswap a ^^^ bswap b := by
  apply vale.eq_of_wbyte_eq; intro i hi
  rw [vale.wbyte_xor, wbyte_bswap _ hi, wbyte_bswap _ hi, wbyte_bswap _ hi, vale.wbyte_xor]

theorem wbyte_rotateLeft (w : BitVec 32) {b : Nat} (hb : b < 4) :
    vale.wbyte (w.rotateLeft 8) b = vale.wbyte w ((b + 3) % 4) := by
  apply BitVec.eq_of_getLsbD_eq; intro j hj
  simp only [vale.wbyte, BitVec.getLsbD_extractLsb', hj, decide_true, Bool.true_and, BitVec.getLsbD_rotateLeft]
  interval_cases b <;> interval_cases j <;> simp

/-- `aes_subword` is Vale's `sub_word`. -/
theorem aesSubword_eq (w : BitVec 32) : aesSubword w = vale.subWord w := by
  apply vale.eq_of_wbyte_eq; intro b hb
  rw [vale.wbyte_subWord _ hb]
  unfold aesSubword vale.wbyte
  simp only [aesSubByte_eq]
  interval_cases b <;> simp (disch := omega) only [extractLsb'_append_lo, extractLsb'_append_hi, extractLsb'_self]

theorem subWord_bswap (w : BitVec 32) : vale.subWord (bswap w) = bswap (vale.subWord w) := by
  apply vale.eq_of_wbyte_eq; intro b hb
  rw [vale.wbyte_subWord _ hb, wbyte_bswap _ hb, wbyte_bswap _ hb, vale.wbyte_subWord _ (by omega)]

theorem rotateLeft_bswap (w : BitVec 32) : (bswap w).rotateLeft 8 = bswap (vale.rotWord w) := by
  apply vale.eq_of_wbyte_eq; intro b hb
  rw [wbyte_rotateLeft _ hb, wbyte_bswap _ (by omega), wbyte_bswap _ hb, vale.wbyte_rotWord _ (by omega)]
  congr 1; omega

theorem aesRcon_bswap {r : Nat} (hr : r < 10) : aesRcon[r]! = bswap (vale.aesRcon r) := by
  interval_cases r <;> rfl

theorem aesKexpCore_bswap {r : Nat} (hr : r < 10) (p b : BitVec 32) :
    aesKexpCore aesRcon[r]! (bswap p) (bswap b) =
      bswap (b ^^^ (vale.subWord (vale.rotWord p) ^^^ vale.aesRcon r)) := by
  rw [aesKexpCore, aesRcon_bswap hr, rotateLeft_bswap, aesSubword_eq, subWord_bswap, bswap_xor, bswap_xor]

theorem aesKexpSub_bswap (p b : BitVec 32) : aesKexpSub (bswap p) (bswap b) = bswap (b ^^^ vale.subWord p) := by
  rw [aesKexpSub, aesSubword_eq, subWord_bswap, bswap_xor]

theorem rev_mkfour (a b c d : BitVec 32) :
    reverseBytesQuad32 (vale.mkfour a b c d) = wordJoin4 (bswap a, bswap b, bswap c, bswap d) := by
  apply vale.eq_of_byte_eq; intro i hi
  rw [vale.byte_reverseBytes _ hi]
  unfold wordJoin4 bswap byte vale.mkfour
  interval_cases i <;> simp (disch := omega) only [extractLsb'_append_lo, extractLsb'_append_hi, extractLsb'_self]

theorem wordSplit4_wordJoin4 (a b c d : BitVec 32) : wordSplit4 (wordJoin4 (a, b, c, d)) = (a, b, c, d) := by
  unfold wordSplit4 wordJoin4
  simp (disch := omega) only [extractLsb'_append_lo, extractLsb'_append_hi, extractLsb'_self]

theorem leBytesToQuad32_words (kb : List (BitVec 8)) (hk : kb.length = 16) :
    let kw := vale.seqNat8ToSeqNat32LE kb
    vale.leBytesToQuad32 kb = vale.mkfour kw[0]! kw[1]! kw[2]! kw[3]! := by
  intro kw
  have h := vale.leBytesToSeqQuad32_eq kb
  have hl : kw.length = 4 := by simp [kw, vale.seqNat8ToSeqNat32LE, hk]
  have h4 : (vale.seqNat8ToSeqNat32LE kb).length / 4 = 1 := by rw [show vale.seqNat8ToSeqNat32LE kb = kw from rfl, hl]
  rw [vale.chunksOf_16 kb hk, List.map_singleton, vale.leBytesToSeqQuad32, vale.seqToSeqFourLE, h4] at h
  simpa using h.symm

theorem wordSplit4_beBlock (kb : List (BitVec 8)) (hk : kb.length = 16) :
    let kw := vale.seqNat8ToSeqNat32LE kb
    wordSplit4 (beBlock kb) = (bswap kw[0]!, bswap kw[1]!, bswap kw[2]!, bswap kw[3]!) := by
  intro kw
  rw [beBlock, leBytesToQuad32_words kb hk, rev_mkfour, wordSplit4_wordJoin4]

/-- Word `i` of Vale's key schedule, `expand_key_def`'s recurrence. -/
def scheduleWord (alg : vale.Algorithm) (key : List (BitVec 32)) (i : Nat) : BitVec 32 :=
  if _h : i < vale.nk alg then key[i]!
  else
    let prev := scheduleWord alg key (i - 1)
    let temp :=
      if i % vale.nk alg = 0 then vale.subWord (vale.rotWord prev) ^^^ vale.aesRcon (i / vale.nk alg - 1)
      else if vale.nk alg > 6 ∧ i % vale.nk alg = 4 then vale.subWord prev
      else prev
    scheduleWord alg key (i - vale.nk alg) ^^^ temp
termination_by i
decreasing_by
  all_goals have : 0 < vale.nk alg := by cases alg <;> decide
  all_goals omega

theorem getElem!_concat_lt {l : List (BitVec 32)} (x : BitVec 32) {i : Nat} (h : i < l.length) :
    (l ++ [x])[i]! = l[i]! := by
  simp [List.getElem?_append_left h]

theorem getElem!_concat_eq {l : List (BitVec 32)} (x : BitVec 32) {i : Nat} (h : l.length = i) :
    (l ++ [x])[i]! = x := by
  subst h; simp

/-- Vale's `expand_key_def` is `scheduleWord`'s words. -/
theorem expandKey_spec (alg : vale.Algorithm) (key : List (BitVec 32)) : ∀ n,
    (vale.expandKey alg key n).length = n ∧ ∀ i < n, (vale.expandKey alg key n)[i]! = scheduleWord alg key i
  | 0 => ⟨rfl, fun _ h => absurd h (Nat.not_lt_zero _)⟩
  | n + 1 => by
    obtain ⟨hl, hw⟩ := expandKey_spec alg key n
    have hnk : 0 < vale.nk alg := by cases alg <;> decide
    simp only [vale.expandKey]
    split
    · next hn =>
      refine ⟨by simp [hl], fun i hi => ?_⟩
      by_cases hin : i < n
      · rw [getElem!_concat_lt _ (by omega), hw i hin]
      · obtain rfl : i = n := by omega
        rw [getElem!_concat_eq _ hl, scheduleWord, dite_eq_left hn]
    · next hn =>
      refine ⟨by simp [hl], fun i hi => ?_⟩
      by_cases hin : i < n
      · rw [getElem!_concat_lt _ (by omega), hw i hin]
      · obtain rfl : i = n := by omega
        rw [getElem!_concat_eq _ hl, hw _ (by omega), hw _ (by omega)]
        conv_rhs => rw [scheduleWord, dite_eq_right hn]

theorem scheduleWord_lt (alg : vale.Algorithm) (key : List (BitVec 32)) {i : Nat} (h : i < vale.nk alg) :
    scheduleWord alg key i = key[i]! := by
  rw [scheduleWord, dite_eq_left h]

theorem keyScheduleToRoundKeys_eq (w : List (BitVec 32)) : ∀ n, vale.keyScheduleToRoundKeys n w =
    (List.range n).map fun r => vale.mkfour w[4 * r]! w[4 * r + 1]! w[4 * r + 2]! w[4 * r + 3]!
  | 0 => rfl
  | n + 1 => by
    rw [vale.keyScheduleToRoundKeys, keyScheduleToRoundKeys_eq w n, List.range_succ, List.map_append,
      List.map_singleton]

/-- The words of s2n-bignum's AES-128 key schedule after `r` steps. -/
def kexp128 (key : BitVec 128) : Nat → Words4
  | 0 => wordSplit4 key
  | r + 1 => aes128KexpRound r (kexp128 key r)

section aes128
variable (kw : List (BitVec 32)) (r : Nat)

local notation "sw" => scheduleWord vale.Algorithm.AES_128 kw

theorem sw128_4 : sw (4 * r + 4) = sw (4 * r) ^^^ (vale.subWord (vale.rotWord (sw (4 * r + 3))) ^^^ vale.aesRcon r) := by
  rw [scheduleWord]
  simp only [vale.nk, show ¬ 4 * r + 4 < 4 by omega, ↓reduceDIte, show (4 * r + 4) % 4 = 0 by omega, ↓reduceIte,
    show (4 * r + 4) / 4 - 1 = r by omega, show 4 * r + 4 - 1 = 4 * r + 3 by omega,
    show 4 * r + 4 - 4 = 4 * r by omega]

theorem sw128_xor (j : Nat) (hj1 : 1 ≤ j) (hj : j < 4) :
    sw (4 * r + 4 + j) = sw (4 * r + j) ^^^ sw (4 * r + 3 + j) := by
  rw [scheduleWord]
  simp only [vale.nk, show ¬ 4 * r + 4 + j < 4 by omega, ↓reduceDIte, show ¬ (4 * r + 4 + j) % 4 = 0 by omega,
    ↓reduceIte, show ¬ (4 > 6 ∧ (4 * r + 4 + j) % 4 = 4) by omega, show 4 * r + 4 + j - 1 = 4 * r + 3 + j by omega,
    show 4 * r + 4 + j - 4 = 4 * r + j by omega]

end aes128

theorem kexp128_eq (kb : List (BitVec 8)) (hk : kb.length = 16) : ∀ r, r ≤ 10 →
    kexp128 (beBlock kb) r =
      (bswap (scheduleWord .AES_128 (vale.seqNat8ToSeqNat32LE kb) (4 * r)),
       bswap (scheduleWord .AES_128 (vale.seqNat8ToSeqNat32LE kb) (4 * r + 1)),
       bswap (scheduleWord .AES_128 (vale.seqNat8ToSeqNat32LE kb) (4 * r + 2)),
       bswap (scheduleWord .AES_128 (vale.seqNat8ToSeqNat32LE kb) (4 * r + 3)))
  | 0, _ => by
    rw [kexp128, wordSplit4_beBlock kb hk]
    simp only [Nat.mul_zero, Nat.zero_add, scheduleWord_lt _ _ (show 0 < vale.nk .AES_128 by decide),
      scheduleWord_lt _ _ (show 1 < vale.nk .AES_128 by decide), scheduleWord_lt _ _ (show 2 < vale.nk .AES_128 by decide),
      scheduleWord_lt _ _ (show 3 < vale.nk .AES_128 by decide)]
  | r + 1, hr => by
    rw [kexp128, kexp128_eq kb hk r (by omega), aes128KexpRound]
    simp only [show 4 * (r + 1) = 4 * r + 4 by ring]
    rw [aesKexpCore_bswap (by omega), sw128_xor _ r 1 (by omega) (by omega), sw128_xor _ r 2 (by omega) (by omega),
      sw128_xor _ r 3 (by omega) (by omega), sw128_4]
    simp only [bswap_xor, show 4 * r + 3 + 1 = 4 * r + 4 by omega, show 4 * r + 3 + 2 = 4 * r + 4 + 1 by omega,
      show 4 * r + 3 + 3 = 4 * r + 4 + 2 by omega, sw128_xor _ r 1 (by omega) (by omega),
      sw128_xor _ r 2 (by omega) (by omega), sw128_4]

/-- s2n-bignum's AES-128 key schedule is Vale's, its words' and blocks' bytes reversed. -/
theorem aes128KeyExpansion_eq (kb : List (BitVec 8)) (hk : kb.length = 16) :
    aes128KeyExpansion (beBlock kb) =
      (vale.keyToRoundKeys .AES_128 (vale.seqNat8ToSeqNat32LE kb)).map reverseBytesQuad32 := by
  have hl : aes128KeyExpansion (beBlock kb) = (List.range 11).map fun r => wordJoin4 (kexp128 (beBlock kb) r) := rfl
  obtain ⟨_, hw⟩ := expandKey_spec .AES_128 (vale.seqNat8ToSeqNat32LE kb) 44
  simp only [hl, vale.keyToRoundKeys, vale.nr, vale.nb, Nat.reduceAdd, Nat.reduceMul, keyScheduleToRoundKeys_eq,
    List.map_map]
  apply List.map_congr_left; intro r hr
  have hr := List.mem_range.1 hr
  rw [Function.comp_apply, hw _ (by omega), hw _ (by omega), hw _ (by omega), hw _ (by omega),
    kexp128_eq kb hk r (by omega), rev_mkfour]

theorem wordJoin4_wordSplit4 (k : BitVec 128) : wordJoin4 (wordSplit4 k) = k := by
  apply vale.eq_of_byte_eq; intro i hi
  unfold wordJoin4 wordSplit4 byte
  interval_cases i <;>
    simp (disch := omega) only [extractLsb'_append_lo, extractLsb'_append_hi, extractLsb'_extractLsb']

theorem seqNat8ToSeqNat32LE_append : ∀ (a b : List (BitVec 8)), a.length % 4 = 0 →
    vale.seqNat8ToSeqNat32LE (a ++ b) = vale.seqNat8ToSeqNat32LE a ++ vale.seqNat8ToSeqNat32LE b
  | [], _, _ => rfl
  | [_], _, h | [_, _], _, h | [_, _, _], _, h => by simp at h
  | x0 :: x1 :: x2 :: x3 :: rest, b, h => by
    rw [List.cons_append, List.cons_append, List.cons_append, List.cons_append, vale.seqNat8ToSeqNat32LE_cons4,
      vale.seqNat8ToSeqNat32LE_cons4, seqNat8ToSeqNat32LE_append rest b (by simp at h; omega), List.cons_append]

theorem getElem!_append_lt {l₁ l₂ : List (BitVec 32)} {i : Nat} (h : i < l₁.length) :
    (l₁ ++ l₂)[i]! = l₁[i]! := by
  simp [List.getElem?_append_left h]

theorem getElem!_append_ge {l₁ l₂ : List (BitVec 32)} {i : Nat} (h : l₁.length ≤ i) :
    (l₁ ++ l₂)[i]! = l₂[i - l₁.length]! := by
  simp [List.getElem!_eq_getElem?_getD, List.getElem?_append_right h]

/-- The words of s2n-bignum's AES-256 key schedule after `t` steps. -/
def kexp256 (keyHi keyLo : BitVec 128) : Nat → Words4 × Words4
  | 0 => (wordSplit4 keyHi, wordSplit4 keyLo)
  | t + 1 => aes256KexpRound t (kexp256 keyHi keyLo t)

/-- Two of s2n-bignum's AES-256 round keys as words: Vale's words `8 t` through `8 t + 7`, bytes reversed. -/
def words8 (sw : Nat → BitVec 32) (t : Nat) : Words4 × Words4 :=
  ((bswap (sw (8 * t)), bswap (sw (8 * t + 1)), bswap (sw (8 * t + 2)), bswap (sw (8 * t + 3))),
   (bswap (sw (8 * t + 4)), bswap (sw (8 * t + 5)), bswap (sw (8 * t + 6)), bswap (sw (8 * t + 7))))

section aes256
variable (kw : List (BitVec 32)) (t : Nat)

local notation "sw" => scheduleWord vale.Algorithm.AES_256 kw

theorem sw256_8 : sw (8 * t + 8) = sw (8 * t) ^^^ (vale.subWord (vale.rotWord (sw (8 * t + 7))) ^^^ vale.aesRcon t) := by
  rw [scheduleWord]
  simp only [vale.nk, show ¬ 8 * t + 8 < 8 by omega, ↓reduceDIte, show (8 * t + 8) % 8 = 0 by omega, ↓reduceIte,
    show (8 * t + 8) / 8 - 1 = t by omega, show 8 * t + 8 - 1 = 8 * t + 7 by omega,
    show 8 * t + 8 - 8 = 8 * t by omega]

theorem sw256_12 : sw (8 * t + 8 + 4) = sw (8 * t + 4) ^^^ vale.subWord (sw (8 * t + 7 + 4)) := by
  rw [scheduleWord]
  simp only [vale.nk, show ¬ 8 * t + 8 + 4 < 8 by omega, ↓reduceDIte,
    ↓reduceIte, show 8 > 6 ∧ (8 * t + 8 + 4) % 8 = 4 by omega, show 8 * t + 8 + 4 - 1 = 8 * t + 7 + 4 by omega,
    show 8 * t + 8 + 4 - 8 = 8 * t + 4 by omega, show ¬ (4 : Nat) = 0 by omega, and_self]

theorem sw256_xor (j : Nat) (hj1 : 1 ≤ j) (hj : j < 8) (hj4 : j ≠ 4) :
    sw (8 * t + 8 + j) = sw (8 * t + j) ^^^ sw (8 * t + 7 + j) := by
  rw [scheduleWord]
  simp only [vale.nk, show ¬ 8 * t + 8 + j < 8 by omega, ↓reduceDIte, show ¬ (8 * t + 8 + j) % 8 = 0 by omega,
    ↓reduceIte, show ¬ (8 > 6 ∧ (8 * t + 8 + j) % 8 = 4) by omega, show 8 * t + 8 + j - 1 = 8 * t + 7 + j by omega,
    show 8 * t + 8 + j - 8 = 8 * t + j by omega]

/-- The words of a step of s2n-bignum's AES-256 key schedule, from Vale's eight before them. -/
theorem kexp256_step (ht : t < 7) : aes256KexpRound t (words8 sw t) = words8 sw (t + 1) := by
  simp only [words8, show 8 * (t + 1) = 8 * t + 8 by ring]
  rw [aes256KexpRound]
  simp only [aesKexpCore_bswap (show t < 10 by omega), ← bswap_xor, aesKexpSub_bswap]
  rw [sw256_xor kw t 7 (by omega) (by omega) (by omega), sw256_xor kw t 6 (by omega) (by omega) (by omega),
    sw256_xor kw t 5 (by omega) (by omega) (by omega), sw256_12, sw256_xor kw t 3 (by omega) (by omega) (by omega),
    sw256_xor kw t 2 (by omega) (by omega) (by omega), sw256_xor kw t 1 (by omega) (by omega) (by omega), sw256_8]

end aes256

theorem kexp256_eq (hi lo : List (BitVec 8)) (hhi : hi.length = 16) (hlo : lo.length = 16) : ∀ t, t ≤ 7 →
    kexp256 (beBlock hi) (beBlock lo) t = words8 (scheduleWord .AES_256 (vale.seqNat8ToSeqNat32LE (hi ++ lo))) t
  | 0, _ => by
    have hw : vale.seqNat8ToSeqNat32LE (hi ++ lo) = vale.seqNat8ToSeqNat32LE hi ++ vale.seqNat8ToSeqNat32LE lo :=
      seqNat8ToSeqNat32LE_append hi lo (by omega)
    have hl : (vale.seqNat8ToSeqNat32LE hi).length = 4 := by simp [vale.seqNat8ToSeqNat32LE, hhi]
    have hs : ∀ i, i < 8 → scheduleWord .AES_256 (vale.seqNat8ToSeqNat32LE (hi ++ lo)) i =
        (vale.seqNat8ToSeqNat32LE (hi ++ lo))[i]! := fun i h =>
      scheduleWord_lt _ _ (by simp only [vale.nk]; omega)
    rw [kexp256, words8, wordSplit4_beBlock hi hhi, wordSplit4_beBlock lo hlo]
    simp only [Nat.mul_zero, Nat.zero_add]
    rw [hs 0 (by omega), hs 1 (by omega), hs 2 (by omega), hs 3 (by omega), hs 4 (by omega), hs 5 (by omega),
      hs 6 (by omega), hs 7 (by omega)]
    simp only [hw,
      getElem!_append_lt (show 0 < (vale.seqNat8ToSeqNat32LE hi).length by omega),
      getElem!_append_lt (show 1 < (vale.seqNat8ToSeqNat32LE hi).length by omega),
      getElem!_append_lt (show 2 < (vale.seqNat8ToSeqNat32LE hi).length by omega),
      getElem!_append_lt (show 3 < (vale.seqNat8ToSeqNat32LE hi).length by omega),
      getElem!_append_ge (show (vale.seqNat8ToSeqNat32LE hi).length ≤ 4 by omega),
      getElem!_append_ge (show (vale.seqNat8ToSeqNat32LE hi).length ≤ 5 by omega),
      getElem!_append_ge (show (vale.seqNat8ToSeqNat32LE hi).length ≤ 6 by omega),
      getElem!_append_ge (show (vale.seqNat8ToSeqNat32LE hi).length ≤ 7 by omega), hl]
  | t + 1, ht => by
    rw [kexp256, kexp256_eq hi lo hhi hlo t (by omega), kexp256_step _ t (by omega)]

theorem aes256KexpLast_eq (i : Nat) (x : Words4 × Words4) : aes256KexpLast i x = (aes256KexpRound i x).1 := by
  obtain ⟨⟨_, _, _, _⟩, ⟨_, _, _, _⟩⟩ := x; rfl

theorem aes256KeyExpansion_kexp (kh kl : BitVec 128) : aes256KeyExpansion kh kl =
    [wordJoin4 (kexp256 kh kl 0).1, wordJoin4 (kexp256 kh kl 0).2, wordJoin4 (kexp256 kh kl 1).1,
     wordJoin4 (kexp256 kh kl 1).2, wordJoin4 (kexp256 kh kl 2).1, wordJoin4 (kexp256 kh kl 2).2,
     wordJoin4 (kexp256 kh kl 3).1, wordJoin4 (kexp256 kh kl 3).2, wordJoin4 (kexp256 kh kl 4).1,
     wordJoin4 (kexp256 kh kl 4).2, wordJoin4 (kexp256 kh kl 5).1, wordJoin4 (kexp256 kh kl 5).2,
     wordJoin4 (kexp256 kh kl 6).1, wordJoin4 (kexp256 kh kl 6).2, wordJoin4 (kexp256 kh kl 7).1] := by
  simp only [aes256KeyExpansion, aes256KexpLast_eq, kexp256, wordJoin4_wordSplit4]

/-- s2n-bignum's AES-256 key schedule is Vale's, its words' and blocks' bytes reversed: the key's first 16
bytes are `keyHi` and its last 16 `keyLo`. -/
theorem aes256KeyExpansion_eq (hi lo : List (BitVec 8)) (hhi : hi.length = 16) (hlo : lo.length = 16) :
    aes256KeyExpansion (beBlock hi) (beBlock lo) =
      (vale.keyToRoundKeys .AES_256 (vale.seqNat8ToSeqNat32LE (hi ++ lo))).map reverseBytesQuad32 := by
  obtain ⟨_, hw⟩ := expandKey_spec .AES_256 (vale.seqNat8ToSeqNat32LE (hi ++ lo)) 60
  have hk := kexp256_eq hi lo hhi hlo
  rw [aes256KeyExpansion_kexp, hk 0 (by omega), hk 1 (by omega), hk 2 (by omega), hk 3 (by omega),
    hk 4 (by omega), hk 5 (by omega), hk 6 (by omega), hk 7 (by omega)]
  simp only [vale.keyToRoundKeys, vale.nr, vale.nb, Nat.reduceAdd, Nat.reduceMul, keyScheduleToRoundKeys_eq,
    show List.range 15 = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14] from rfl, List.map_cons, List.map_nil,
    words8, rev_mkfour]
  simp (disch := omega) only [hw]

/-- s2n-bignum's AES-128, under the schedule it expands from a key, is Vale's. -/
theorem isValeAes_aes128 (key : List (BitVec 8)) (hk : key.length = 16) :
    IsValeAes aes128Cipher (aes128KeyExpansion (beBlock key)) .AES_128 (vale.seqNat8ToSeqNat32LE key) := by
  intro x
  rw [aes128KeyExpansion_eq key hk, aes128Cipher_eq, vale.aesEncrypt]

/-- s2n-bignum's AES-256, under the schedule it expands from a key's two halves, is Vale's. -/
theorem isValeAes_aes256 (key : List (BitVec 8)) (hk : key.length = 32) :
    IsValeAes aes256Cipher (aes256KeyExpansion (beBlock (key.take 16)) (beBlock (key.drop 16))) .AES_256
      (vale.seqNat8ToSeqNat32LE key) := by
  intro x
  rw [aes256KeyExpansion_eq _ _ (by simp [hk]) (by simp [hk]), List.take_append_drop, aes256Cipher_eq,
    vale.aesEncrypt]

/-- s2n-bignum's AES-128-GCM encryption is Vale's. -/
theorem gcmAe_aes128 (key iv plain auth : List (BitVec 8)) (hk : key.length = 16) (hiv : iv.length = 12)
    (hp : plain.length % 16 = 0) (ha : auth.length % 16 = 0) :
    gcmAe aes128Cipher (aes128KeyExpansion (beBlock key)) (ivWord iv) (beBlocks plain) (beBlocks auth) =
      (beBlocks (vale.gcmEncrypt .AES_128 key iv plain auth).1,
        beBlock (vale.gcmEncrypt .AES_128 key iv plain auth).2) :=
  gcmAe_eq (isValeAes_aes128 key hk) iv plain auth hiv hp ha

/-- s2n-bignum's AES-128-GCM decryption is Vale's. -/
theorem gcmAd_aes128 (key iv cipher auth tag : List (BitVec 8)) (hk : key.length = 16) (hiv : iv.length = 12)
    (hc : cipher.length % 16 = 0) (ha : auth.length % 16 = 0) (ht : tag.length = 16) :
    gcmAd aes128Cipher (aes128KeyExpansion (beBlock key)) (ivWord iv) (beBlocks cipher) (beBlocks auth)
        (beBlock tag) =
      if (vale.gcmDecrypt .AES_128 key iv cipher auth tag).2 then
        some (beBlocks (vale.gcmDecrypt .AES_128 key iv cipher auth tag).1)
      else none :=
  gcmAd_eq (isValeAes_aes128 key hk) iv cipher auth tag hiv hc ha ht

/-- s2n-bignum's AES-256-GCM encryption is Vale's. -/
theorem gcmAe_aes256 (key iv plain auth : List (BitVec 8)) (hk : key.length = 32) (hiv : iv.length = 12)
    (hp : plain.length % 16 = 0) (ha : auth.length % 16 = 0) :
    gcmAe aes256Cipher (aes256KeyExpansion (beBlock (key.take 16)) (beBlock (key.drop 16))) (ivWord iv)
        (beBlocks plain) (beBlocks auth) =
      (beBlocks (vale.gcmEncrypt .AES_256 key iv plain auth).1,
        beBlock (vale.gcmEncrypt .AES_256 key iv plain auth).2) :=
  gcmAe_eq (isValeAes_aes256 key hk) iv plain auth hiv hp ha

/-- s2n-bignum's AES-256-GCM decryption is Vale's. -/
theorem gcmAd_aes256 (key iv cipher auth tag : List (BitVec 8)) (hk : key.length = 32) (hiv : iv.length = 12)
    (hc : cipher.length % 16 = 0) (ha : auth.length % 16 = 0) (ht : tag.length = 16) :
    gcmAd aes256Cipher (aes256KeyExpansion (beBlock (key.take 16)) (beBlock (key.drop 16))) (ivWord iv)
        (beBlocks cipher) (beBlocks auth) (beBlock tag) =
      if (vale.gcmDecrypt .AES_256 key iv cipher auth tag).2 then
        some (beBlocks (vale.gcmDecrypt .AES_256 key iv cipher auth tag).1)
      else none :=
  gcmAd_eq (isValeAes_aes256 key hk) iv cipher auth tag hiv hc ha ht

end rind.spec.s2n.gcm
