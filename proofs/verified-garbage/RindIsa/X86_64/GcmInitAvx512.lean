import RindIsa.X86_64

/-!
# BoringSSL's `gcm_init_vpclmulqdq_avx512`

rind's naked function `low::x86_64::aes_gcm_vaes::gcm_init_vpclmulqdq_avx512`,
BoringSSL's key setup for its AVX-512 AES-GCM routines
(`crypto/fipsmodule/aes/asm/aes-gcm-avx512-x86_64.pl`), in rind's model of
x86_64: `gcm_init_vpclmulqdq_avx512(Htable = rdi, H = rsi)`. It loads the
GHASH key from the two words at `rsi`, high first, multiplies it by `x`
(`shift_key_1`), squares it, and writes its powers H^16 down to H^1 to the
table's 256 bytes: H^4 to H^1 to its last 64 bytes, then, four at a time,
each set times H^4 below the one before, each product a schoolbook product
folded twice by `gfpoly` (`x^63 + x^62 + x^57` in its high word), on 128,
256, or 512 bits (`mul`).

`admin/prove lean` checks that `function prog plainRet` is the function's
bytes and relocations as rind's Linux release build emits it, from
BoringSSL's text, which the blocks below follow line for line, and that its
statics begin with `gfpoly`'s and `carry`'s words.
-/

namespace Rind.X86_64.GcmInitAvx512

open VG VG.X86_64

/-- The static of the reduction constant. -/
def gfpolyName : String := "gfpoly"

/-- `gfpoly`: 1, and `x^63 + x^62 + x^57` reflected, in its high word. -/
def gfpoly : List (BitVec 64) := [1, 0xc200000000000000]

/-- The static `shift_key_1` adds by. -/
def carryName : String := "gfpoly_and_internal_carrybit"

/-- `gfpoly_and_internal_carrybit`: `gfpoly`, and the carry from the low word
into the high one. -/
def carry : List (BitVec 64) := [1, 0xc200000000000001]

def vop (o : VOp) : Instr := .vg (.vop o)

def zop (o : ZOp) : Instr := .vg (.zop o)

/-- Point `r8` at the table's last 64 bytes, load the key, swapping its
words, and multiply it by `x`: shift each word left, and add the carry out
of the low word and, if the top bit fell out, `gfpoly`, by masks of the sign
bits `vpsrad` spreads (`vpternlogd` `0x78`, `a ^ (b & c)`). Then broadcast
`gfpoly` to the four lanes of `zmm5`. -/
def head : List Instr :=
  [.lea .r8 { base := .rdi, disp := 192 },
   .vpshufdLoad .xmm3 { base := .rsi } 0x4e,
   vop (.vpshufd .l128 .xmm0 .xmm3 0xd3),
   vop (.vshift .psrad .l128 .xmm0 .xmm0 31),
   vop (.vbin .vpaddq .l128 .xmm3 .xmm3 .xmm3),
   .rip (.vpternlogd .xmm3 .xmm0 0x78) carryName carry,
   .rip (.vbroadcasti32x4 .xmm5) gfpolyName gfpoly]

/-- Square H^1 in `xmm3` into H^2 in `xmm4`: the low and high products, the
low folded into the middle and the middle into the high (`vpternlogd`
`0x96`, a three-way XOR). -/
def square : List Instr :=
  [vop (.vpclmulqdq .l128 .xmm0 .xmm3 .xmm3 0x00),
   vop (.vpclmulqdq .l128 .xmm4 .xmm3 .xmm3 0x11),
   vop (.vpclmulqdq .l128 .xmm1 .xmm5 .xmm0 0x01),
   vop (.vpshufd .l128 .xmm0 .xmm0 0x4e),
   vop (.vbin .vpxor .l128 .xmm1 .xmm1 .xmm0),
   vop (.vpclmulqdq .l128 .xmm0 .xmm5 .xmm1 0x01),
   vop (.vpshufd .l128 .xmm1 .xmm1 0x4e),
   vop (.vpternlogd .l128 .xmm4 .xmm1 .xmm0 0x96)]

/-- `_ghash_mul` of the two lanes of `ymm3` by those of `ymm4` into `ymm4`:
the low, middle, and high schoolbook products, the low folded into the
middle and the middle into the high, by `gfpoly` in `ymm5`, with `ymm0` to
`ymm2` as scratch. -/
def mul256 : List Instr :=
  [vop (.vpclmulqdq .l256 .xmm0 .xmm3 .xmm4 0x00),
   vop (.vpclmulqdq .l256 .xmm1 .xmm3 .xmm4 0x01),
   vop (.vpclmulqdq .l256 .xmm2 .xmm3 .xmm4 0x10),
   .vpxordY .xmm1 .xmm1 .xmm2,
   vop (.vpclmulqdq .l256 .xmm2 .xmm5 .xmm0 0x01),
   vop (.vpshufd .l256 .xmm0 .xmm0 0x4e),
   vop (.vpternlogd .l256 .xmm1 .xmm0 .xmm2 0x96),
   vop (.vpclmulqdq .l256 .xmm4 .xmm3 .xmm4 0x11),
   vop (.vpclmulqdq .l256 .xmm0 .xmm5 .xmm1 0x01),
   vop (.vpshufd .l256 .xmm1 .xmm1 0x4e),
   vop (.vpternlogd .l256 .xmm4 .xmm1 .xmm0 0x96)]

/-- `[H^2, H^1]` in `ymm3` and `[H^2, H^2]` in `ymm4`, then `[H^4, H^3]` in
`ymm4`; `[H^4, H^3, H^2, H^1]` in `zmm3` and H^4 in the four lanes of `zmm4`;
the first stored to the table's last 64 bytes; and the count of the sets
left in `eax`. -/
def powers : List Instr :=
  [vop (.vinserti128 .xmm3 .xmm4 .xmm3 1),
   vop (.vinserti128 .xmm4 .xmm4 .xmm4 1)] ++
  mul256 ++
  [.vg (.e5op (.vinserti64x4 (.lo .xmm3) (.lo .xmm4) (.lo .xmm3) 1)),
   .vshufi64x2 .xmm4 .xmm4 .xmm4 0,
   .vmovdqu8Store { base := .r8 } .xmm3,
   .vg (.mov32 .rax (.imm 3))]

/-- One set of four powers: `zmm3`'s lanes times H^4 in `zmm4`, as `mul256`
on 512 bits, stored 64 bytes below the set before. -/
def body : List Instr :=
  [.vg (.alu .sub .r8 (.imm 64)),
   zop (.vpclmulqdq .xmm0 .xmm3 .xmm4 0x00),
   zop (.vpclmulqdq .xmm1 .xmm3 .xmm4 0x01),
   zop (.vpclmulqdq .xmm2 .xmm3 .xmm4 0x10),
   zop (.zbin .vpxord .xmm1 .xmm1 .xmm2),
   zop (.vpclmulqdq .xmm2 .xmm5 .xmm0 0x01),
   zop (.vpshufd .xmm0 .xmm0 0x4e),
   zop (.vpternlogd .xmm1 .xmm0 .xmm2 0x96),
   zop (.vpclmulqdq .xmm3 .xmm3 .xmm4 0x11),
   zop (.vpclmulqdq .xmm0 .xmm5 .xmm1 0x01),
   zop (.vpshufd .xmm1 .xmm1 0x4e),
   zop (.vpternlogd .xmm3 .xmm1 .xmm0 0x96),
   .vmovdqu8Store { base := .r8 } .xmm3,
   .dec32 .rax]

/-- The function, but for its `ret`: three sets in the loop, then
`vzeroupper`. -/
def prog : Prog isa :=
  .seq (.block (head ++ square ++ powers)) (.seq (.loop (.block body) (.vg .ne)) (.block [vop .vzeroupper]))

end Rind.X86_64.GcmInitAvx512
