module
public import Aeneas
public import Rind.X86_64.Simd
@[expose] public section
open Aeneas Aeneas.Std Result
set_option linter.dupNamespace false

/-!
# rind's AES-NI key expansion and block cipher, modelled by hand

These load through raw pointers, `transmute` a vector to bytes, and zip
iterators, which Aeneas cannot translate, so the translation leaves them opaque and this file models
them over `Rind.X86_64.Simd`'s intrinsics. So does `u128_to_m128i` and the
constants beside it, which `transmute` a `u128`, whose bits a vector holds
unchanged. `admin/prove` fails unless these quotes are still that Rust, so a
change to it is a change to this model:

```rust
const RCON: [i32; 10] = [0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36];

fn aes128_expand(key: &[u8; 16], out: &mut [__m128i; 11]) {
    // SAFETY: `key` is 16 bytes and can be loaded from
    let mut t = unsafe { _mm_loadu_si128(key.as_ptr().cast()) };
    out[0] = t;

    for (rk, rcon) in out[1..].iter_mut().zip(RCON) {
        t = _mm_xor_si128(xor_prefix(t), sub_rot_word(t, rcon));
        *rk = t;
    }
}

fn aes256_expand(key: &[u8; 32], out: &mut [__m128i; 15]) {
    // SAFETY: `key` is 32 bytes and readable
    let (mut a, mut b) = unsafe {
        (
            _mm_loadu_si128(key.as_ptr().cast()),
            _mm_loadu_si128(key[16..].as_ptr().cast()),
        )
    };
    out[0] = a;
    out[1] = b;

    // Round keys alternate: the first of each pair takes RotWord and the
    // round constant, as AES-128's do, and the second only SubWord.
    for (i, rcon) in RCON[..7].iter().enumerate() {
        a = _mm_xor_si128(xor_prefix(a), sub_rot_word(b, *rcon));
        out[2 * i + 2] = a;
        if i == 6 {
            break;
        }
        let sub = _mm_aesenclast_si128(_mm_shuffle_epi32(a, 0b11_11_11_11), zero());
        b = _mm_xor_si128(xor_prefix(b), sub);
        out[2 * i + 3] = b;
    }
}

fn sub_rot_word(t: __m128i, rcon: i32) -> __m128i {
    let rot_word_3 = _mm_setr_epi8(
        13, 14, 15, 12, 13, 14, 15, 12, 13, 14, 15, 12, 13, 14, 15, 12,
    );
    _mm_aesenclast_si128(_mm_shuffle_epi8(t, rot_word_3), _mm_set1_epi32(rcon))
}

fn xor_prefix(t: __m128i) -> __m128i {
    let t = _mm_xor_si128(t, _mm_slli_si128(t, 4));
    _mm_xor_si128(t, _mm_slli_si128(t, 8))
}

fn zero() -> __m128i {
    // SAFETY: every x86_64 CPU has SSE2
    unsafe { _mm_setzero_si128() }
}

fn aes128_block(round_keys: &[__m128i; 11], block: &[u8; 16]) -> [u8; 16] {
    // SAFETY: `block` is 16 bytes and readable
    let block = unsafe { _mm_loadu_si128(block.as_ptr().cast()) };
    let block = _mm_xor_si128(block, round_keys[0]);
    let block = _mm_aesenc_si128(block, round_keys[1]);
    let block = _mm_aesenc_si128(block, round_keys[2]);
    let block = _mm_aesenc_si128(block, round_keys[3]);
    let block = _mm_aesenc_si128(block, round_keys[4]);
    let block = _mm_aesenc_si128(block, round_keys[5]);
    let block = _mm_aesenc_si128(block, round_keys[6]);
    let block = _mm_aesenc_si128(block, round_keys[7]);
    let block = _mm_aesenc_si128(block, round_keys[8]);
    let block = _mm_aesenc_si128(block, round_keys[9]);
    let block = _mm_aesenclast_si128(block, round_keys[10]);
    // SAFETY: both are 16 bytes, and any bits are a valid array
    unsafe { core::mem::transmute(block) }
}

fn aes256_block(round_keys: &[__m128i; 15], block: &[u8; 16]) -> [u8; 16] {
    // SAFETY: `block` is 16 bytes and readable
    let block = unsafe { _mm_loadu_si128(block.as_ptr().cast()) };
    let block = _mm_xor_si128(block, round_keys[0]);
    let block = _mm_aesenc_si128(block, round_keys[1]);
    let block = _mm_aesenc_si128(block, round_keys[2]);
    let block = _mm_aesenc_si128(block, round_keys[3]);
    let block = _mm_aesenc_si128(block, round_keys[4]);
    let block = _mm_aesenc_si128(block, round_keys[5]);
    let block = _mm_aesenc_si128(block, round_keys[6]);
    let block = _mm_aesenc_si128(block, round_keys[7]);
    let block = _mm_aesenc_si128(block, round_keys[8]);
    let block = _mm_aesenc_si128(block, round_keys[9]);
    let block = _mm_aesenc_si128(block, round_keys[10]);
    let block = _mm_aesenc_si128(block, round_keys[11]);
    let block = _mm_aesenc_si128(block, round_keys[12]);
    let block = _mm_aesenc_si128(block, round_keys[13]);
    let block = _mm_aesenclast_si128(block, round_keys[14]);
    // SAFETY: both are 16 bytes, and any bits are a valid array
    unsafe { core::mem::transmute(block) }
}

fn u128_to_m128i(v: u128) -> __m128i {
    // SAFETY: sizeof(u128) == sizeof(__m128i), all bits have same meaning
    unsafe { mem::transmute(v) }
}

const GF128_POLY_HI: __m128i = unsafe { mem::transmute(0xc2000000_00000000u128) };

const GF128_POLY_CARRY_MASK: __m128i =
    unsafe { mem::transmute(0xc2000000_00000001_00000000_00000001u128) };

```

The model departs from the Rust in four ways, and adds no axiom:

- `_mm_loadu_si128` of a byte array is the vector of its bytes, the first
  lowest, and `_mm_storeu_si128` writes the vector's bytes the same way.
- `zero()` is `_mm_setzero_si128()`, which is its body.
- A loop is a recursion over its round constants, building the round keys it
  writes in order; AES-256's `i == 6` is its last constant. The loops write
  every round key, so the result does not depend on `out`'s.
- The unrolled rounds are a recursion over the round keys after the first.
-/

namespace rind.x86_64

open rind.vale

/-- `_mm_loadu_si128` of a byte array: its bytes, the first lowest. -/
def low.x86_64.aes.load (bytes : List U8) : core.core_arch.x86.__m128i :=
  leBytesToQuad32 (bytes.map (·.bv))

/-- `RCON`. -/
def low.x86_64.aes.RCON : List Std.I32 :=
  [0x01#i32, 0x02#i32, 0x04#i32, 0x08#i32, 0x10#i32, 0x20#i32, 0x40#i32, 0x80#i32, 0x1b#i32, 0x36#i32]

/-- `sub_rot_word`. -/
def low.x86_64.aes.sub_rot_word (t : core.core_arch.x86.__m128i) (rcon : Std.I32) :
    Result core.core_arch.x86.__m128i := do
  let rot_word_3 ← core.core_arch.x86.sse2._mm_setr_epi8 13#i8 14#i8 15#i8 12#i8 13#i8 14#i8
    15#i8 12#i8 13#i8 14#i8 15#i8 12#i8 13#i8 14#i8 15#i8 12#i8
  let s ← core.core_arch.x86.ssse3._mm_shuffle_epi8 t rot_word_3
  let r ← core.core_arch.x86.sse2._mm_set1_epi32 rcon
  core.core_arch.x86.aes._mm_aesenclast_si128 s r

/-- `xor_prefix`. -/
def low.x86_64.aes.xor_prefix (t : core.core_arch.x86.__m128i) :
    Result core.core_arch.x86.__m128i := do
  let s ← core.core_arch.x86.sse2._mm_slli_si128 4#i32 t
  let t ← core.core_arch.x86.sse2._mm_xor_si128 t s
  let s ← core.core_arch.x86.sse2._mm_slli_si128 8#i32 t
  core.core_arch.x86.sse2._mm_xor_si128 t s

/-- `aes128_expand`'s loop: the round keys after `t`, one per constant. -/
def low.x86_64.aes.aes128_expand_loop (t : core.core_arch.x86.__m128i) :
    List Std.I32 → Result (List core.core_arch.x86.__m128i)
  | [] => ok []
  | rcon :: rest => do
    let p ← low.x86_64.aes.xor_prefix t
    let s ← low.x86_64.aes.sub_rot_word t rcon
    let t ← core.core_arch.x86.sse2._mm_xor_si128 p s
    let ts ← low.x86_64.aes.aes128_expand_loop t rest
    ok (t :: ts)

/-- `aes128_expand`. -/
def low.x86_64.aes.aes128_expand (key : Std.Array Std.U8 16#usize)
    (_out : Std.Array core.core_arch.x86.__m128i 11#usize) :
    Result (Std.Array core.core_arch.x86.__m128i 11#usize) := do
  let t := low.x86_64.aes.load key.val
  let ts ← low.x86_64.aes.aes128_expand_loop t low.x86_64.aes.RCON
  if h : (t :: ts).length = 11 then ok (Std.Array.from (t :: ts) h) else fail .panic

/-- `aes256_expand`'s loop: the round keys after `a` and `b`, two per constant
but one for the last. -/
def low.x86_64.aes.aes256_expand_loop (a b : core.core_arch.x86.__m128i) :
    List Std.I32 → Result (List core.core_arch.x86.__m128i)
  | [] => ok []
  | rcon :: rest => do
    let p ← low.x86_64.aes.xor_prefix a
    let s ← low.x86_64.aes.sub_rot_word b rcon
    let a ← core.core_arch.x86.sse2._mm_xor_si128 p s
    if rest = [] then ok [a] else
    let w ← core.core_arch.x86.sse2._mm_shuffle_epi32 255#i32 a
    let z ← core.core_arch.x86.sse2._mm_setzero_si128
    let sub ← core.core_arch.x86.aes._mm_aesenclast_si128 w z
    let p ← low.x86_64.aes.xor_prefix b
    let b ← core.core_arch.x86.sse2._mm_xor_si128 p sub
    let ts ← low.x86_64.aes.aes256_expand_loop a b rest
    ok (a :: b :: ts)

/-- `aes256_expand`. -/
def low.x86_64.aes.aes256_expand (key : Std.Array Std.U8 32#usize)
    (_out : Std.Array core.core_arch.x86.__m128i 15#usize) :
    Result (Std.Array core.core_arch.x86.__m128i 15#usize) := do
  let a := low.x86_64.aes.load (key.val.take 16)
  let b := low.x86_64.aes.load (key.val.drop 16)
  let ts ← low.x86_64.aes.aes256_expand_loop a b (low.x86_64.aes.RCON.take 7)
  if h : (a :: b :: ts).length = 15 then ok (Std.Array.from (a :: b :: ts) h) else fail .panic

/-- A vector as a byte array, as `transmute` reads it: its bytes, the lowest first. -/
def low.x86_64.aes.store (v : core.core_arch.x86.__m128i) : Std.Array Std.U8 16#usize :=
  Std.Array.from ((leQuad32ToBytes v).map fun b => ⟨b⟩) (by simp [leQuad32ToBytes])

/-- The AES rounds after the first round key's XOR: `AESENC` with each round
key but the last, then `AESENCLAST`. -/
def low.x86_64.aes.rounds (block : core.core_arch.x86.__m128i) :
    List core.core_arch.x86.__m128i → Result core.core_arch.x86.__m128i
  | [] => ok block
  | [k] => core.core_arch.x86.aes._mm_aesenclast_si128 block k
  | k :: rest => do
    let block ← core.core_arch.x86.aes._mm_aesenc_si128 block k
    low.x86_64.aes.rounds block rest

/-- `aes128_block`, whose calls are unrolled over the round keys in order. -/
def low.x86_64.aes.aes128_block (round_keys : Std.Array core.core_arch.x86.__m128i 11#usize)
    (block : Std.Array Std.U8 16#usize) : Result (Std.Array Std.U8 16#usize) := do
  let block := low.x86_64.aes.load block.val
  let block ← core.core_arch.x86.sse2._mm_xor_si128 block round_keys.val[0]!
  let block ← low.x86_64.aes.rounds block (round_keys.val.drop 1)
  ok (low.x86_64.aes.store block)

/-- `aes256_block`, whose calls are unrolled over the round keys in order. -/
def low.x86_64.aes.aes256_block (round_keys : Std.Array core.core_arch.x86.__m128i 15#usize)
    (block : Std.Array Std.U8 16#usize) : Result (Std.Array Std.U8 16#usize) := do
  let block := low.x86_64.aes.load block.val
  let block ← core.core_arch.x86.sse2._mm_xor_si128 block round_keys.val[0]!
  let block ← low.x86_64.aes.rounds block (round_keys.val.drop 1)
  ok (low.x86_64.aes.store block)

/-- `u128_to_m128i`. -/
def low.x86_64.ghash.u128_to_m128i (v : Std.U128) : Result core.core_arch.x86.__m128i :=
  ok v.bv

/-- `GF128_POLY_HI`. -/
def low.x86_64.ghash.GF128_POLY_HI : Result core.core_arch.x86.__m128i :=
  ok 0xc2000000_00000000#128

/-- `GF128_POLY_CARRY_MASK`. -/
def low.x86_64.ghash.GF128_POLY_CARRY_MASK : Result core.core_arch.x86.__m128i :=
  ok 0xc2000000_00000001_00000000_00000001#128

end rind.x86_64
