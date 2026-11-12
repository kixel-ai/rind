(*
 * SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0
 *)

(* ========================================================================= *)
(* Montgomery multiplication, aws-lc's aarch64 bn_mul_mont, as rind's build  *)
(* emits it. Work in progress: the width-generic path's loops.              *)
(* ========================================================================= *)

(* rind's naked function low::aarch64::mont::bn_mul_mont is aws-lc's
   bn_mul_mont (crypto/fipsmodule/bn/asm/armv8-mont.pl). It dispatches on the
   width k: a multiple of eight goes to __bn_sqr8x_mont when squaring and to
   __bn_mul4x_mont otherwise, as does any other multiple of four, and every
   other width runs the generic path at offset 0x10. The goal is s2n-bignum's
   bignum_montmul specification for all three. This file so far proves the
   generic path's word-by-word loops as segment lemmas, each an `ensures`
   between two program points with a definitional invariant:

   - GEN_H1_BODY and GEN_LOOP1: the first pass's loop, multiplying x by y's
     first word and adding q0 times m, word by word (gen_h1_inv).
   - GEN_SKIP1: the first pass's tail, ending at the outer loop's head with
     its invariant for one word of y (gen_out_inv).
   - GEN_IN_BODY: one word of the outer loop's inner loop (gen_in_inv).

   Carries the code drops are proven zero from product bounds: a 64x64-bit
   product's high word is at most 2^64 - 2, and when it is, the low word is
   at most 1 (PROD_BOUND), with linear arithmetic over the carry cases. *)

needs "arm/proofs/base.ml";;

(* admin/prove writes the function, as rind's release build emits it, to
   aarch64/bn_mul_mont.o. The definition fails unless its instructions are
   these. *)
let bn_mul_mont_mc =
  define_assert_from_elf "bn_mul_mont_mc" "aarch64/bn_mul_mont.o"
[
  0xf24008bf;       (* arm_TST X5 (rvalue (word 7)) *)
  0x540011e0;       (* arm_BEQ (word 572) *)
  0xf24004bf;       (* arm_TST X5 (rvalue (word 3)) *)
  0x540060a0;       (* arm_BEQ (word 3092) *)
  0xa9bc7bfd;       (* arm_STP X29 X30 SP (Preimmediate_Offset (iword (-- &64))) *)
  0x910003fd;       (* arm_ADD X29 SP (rvalue (word 0)) *)
  0xa90153f3;       (* arm_STP X19 X20 SP (Immediate_Offset (iword (&16))) *)
  0xa9025bf5;       (* arm_STP X21 X22 SP (Immediate_Offset (iword (&32))) *)
  0xa90363f7;       (* arm_STP X23 X24 SP (Immediate_Offset (iword (&48))) *)
  0xf8408449;       (* arm_LDR X9 X2 (Postimmediate_Offset (word 8)) *)
  0xcb256ff6;       (* arm_SUB X22 SP (Shiftedreg (Extendedreg X5 UXTX) LSL 3) *)
  0xa8c12027;       (* arm_LDP X7 X8 X1 (Postimmediate_Offset (iword (&16))) *)
  0xd37df0a5;       (* arm_LSL X5 X5 3 *)
  0xf9400084;       (* arm_LDR X4 X4 (Immediate_Offset (word 0)) *)
  0x927ceed6;       (* arm_AND X22 X22 (rvalue (word 18446744073709551600)) *)
  0xa8c1386d;       (* arm_LDP X13 X14 X3 (Postimmediate_Offset (iword (&16))) *)
  0x9b097ce6;       (* arm_MUL X6 X7 X9 *)
  0xd10040b5;       (* arm_SUB X21 X5 (rvalue (word 16)) *)
  0x9bc97ce7;       (* arm_UMULH X7 X7 X9 *)
  0x9b097d0a;       (* arm_MUL X10 X8 X9 *)
  0x9bc97d0b;       (* arm_UMULH X11 X8 X9 *)
  0x9b047ccf;       (* arm_MUL X15 X6 X4 *)
  0x910002df;       (* arm_ADD SP X22 (rvalue (word 0)) *)
  0x9bcf7dad;       (* arm_UMULH X13 X13 X15 *)
  0x9b0f7dd0;       (* arm_MUL X16 X14 X15 *)
  0xf10004df;       (* arm_CMP X6 (rvalue (word 1)) *)
  0x9bcf7dd1;       (* arm_UMULH X17 X14 X15 *)
  0x9a1f01ad;       (* arm_ADC X13 X13 XZR *)
  0xb4000215;       (* arm_CBZ X21 (word 64) *)
  0xf8408428;       (* arm_LDR X8 X1 (Postimmediate_Offset (word 8)) *)
  0xab070146;       (* arm_ADDS X6 X10 X7 *)
  0xd10022b5;       (* arm_SUB X21 X21 (rvalue (word 8)) *)
  0x9a1f0167;       (* arm_ADC X7 X11 XZR *)
  0xf840846e;       (* arm_LDR X14 X3 (Postimmediate_Offset (word 8)) *)
  0xab0d020c;       (* arm_ADDS X12 X16 X13 *)
  0x9b097d0a;       (* arm_MUL X10 X8 X9 *)
  0x9a1f022d;       (* arm_ADC X13 X17 XZR *)
  0x9bc97d0b;       (* arm_UMULH X11 X8 X9 *)
  0xab06018c;       (* arm_ADDS X12 X12 X6 *)
  0x9b0f7dd0;       (* arm_MUL X16 X14 X15 *)
  0x9a1f01ad;       (* arm_ADC X13 X13 XZR *)
  0x9bcf7dd1;       (* arm_UMULH X17 X14 X15 *)
  0xf80086cc;       (* arm_STR X12 X22 (Postimmediate_Offset (word 8)) *)
  0xb5fffe55;       (* arm_CBNZ X21 (word 2097096) *)
  0xab070146;       (* arm_ADDS X6 X10 X7 *)
  0xcb050021;       (* arm_SUB X1 X1 X5 *)
  0x9a1f0167;       (* arm_ADC X7 X11 XZR *)
  0xab0d020c;       (* arm_ADDS X12 X16 X13 *)
  0xcb050063;       (* arm_SUB X3 X3 X5 *)
  0x9a1f022d;       (* arm_ADC X13 X17 XZR *)
  0xab06018c;       (* arm_ADDS X12 X12 X6 *)
  0xd10020b4;       (* arm_SUB X20 X5 (rvalue (word 8)) *)
  0xba0701ad;       (* arm_ADCS X13 X13 X7 *)
  0x9a1f03f3;       (* arm_ADC X19 XZR XZR *)
  0xa90036cc;       (* arm_STP X12 X13 X22 (Immediate_Offset (iword (&0))) *)
  0xf8408449;       (* arm_LDR X9 X2 (Postimmediate_Offset (word 8)) *)
  0xa8c12027;       (* arm_LDP X7 X8 X1 (Postimmediate_Offset (iword (&16))) *)
  0xf94003f7;       (* arm_LDR X23 SP (Immediate_Offset (word 0)) *)
  0x910023f6;       (* arm_ADD X22 SP (rvalue (word 8)) *)
  0x9b097ce6;       (* arm_MUL X6 X7 X9 *)
  0xd10040b5;       (* arm_SUB X21 X5 (rvalue (word 16)) *)
  0x9bc97ce7;       (* arm_UMULH X7 X7 X9 *)
  0xa8c1386d;       (* arm_LDP X13 X14 X3 (Postimmediate_Offset (iword (&16))) *)
  0x9b097d0a;       (* arm_MUL X10 X8 X9 *)
  0xab1700c6;       (* arm_ADDS X6 X6 X23 *)
  0x9bc97d0b;       (* arm_UMULH X11 X8 X9 *)
  0x9a1f00e7;       (* arm_ADC X7 X7 XZR *)
  0x9b047ccf;       (* arm_MUL X15 X6 X4 *)
  0xd1002294;       (* arm_SUB X20 X20 (rvalue (word 8)) *)
  0x9bcf7dad;       (* arm_UMULH X13 X13 X15 *)
  0x9b0f7dd0;       (* arm_MUL X16 X14 X15 *)
  0xf10004df;       (* arm_CMP X6 (rvalue (word 1)) *)
  0x9bcf7dd1;       (* arm_UMULH X17 X14 X15 *)
  0xb4000275;       (* arm_CBZ X21 (word 76) *)
  0xf8408428;       (* arm_LDR X8 X1 (Postimmediate_Offset (word 8)) *)
  0x9a1f01ad;       (* arm_ADC X13 X13 XZR *)
  0xf84086d7;       (* arm_LDR X23 X22 (Postimmediate_Offset (word 8)) *)
  0xab070146;       (* arm_ADDS X6 X10 X7 *)
  0xd10022b5;       (* arm_SUB X21 X21 (rvalue (word 8)) *)
  0x9a1f0167;       (* arm_ADC X7 X11 XZR *)
  0xab0d020c;       (* arm_ADDS X12 X16 X13 *)
  0xf840846e;       (* arm_LDR X14 X3 (Postimmediate_Offset (word 8)) *)
  0x9a1f022d;       (* arm_ADC X13 X17 XZR *)
  0x9b097d0a;       (* arm_MUL X10 X8 X9 *)
  0xab1700c6;       (* arm_ADDS X6 X6 X23 *)
  0x9bc97d0b;       (* arm_UMULH X11 X8 X9 *)
  0x9a1f00e7;       (* arm_ADC X7 X7 XZR *)
  0x9b0f7dd0;       (* arm_MUL X16 X14 X15 *)
  0xab06018c;       (* arm_ADDS X12 X12 X6 *)
  0x9bcf7dd1;       (* arm_UMULH X17 X14 X15 *)
  0xf81f02cc;       (* arm_STR X12 X22 (Immediate_Offset (word 18446744073709551600)) *)
  0xb5fffdf5;       (* arm_CBNZ X21 (word 2097084) *)
  0xf84086d7;       (* arm_LDR X23 X22 (Postimmediate_Offset (word 8)) *)
  0x9a1f01ad;       (* arm_ADC X13 X13 XZR *)
  0xab070146;       (* arm_ADDS X6 X10 X7 *)
  0xcb050021;       (* arm_SUB X1 X1 X5 *)
  0x9a1f0167;       (* arm_ADC X7 X11 XZR *)
  0xab0d020c;       (* arm_ADDS X12 X16 X13 *)
  0xcb050063;       (* arm_SUB X3 X3 X5 *)
  0xba13022d;       (* arm_ADCS X13 X17 X19 *)
  0x9a1f03f3;       (* arm_ADC X19 XZR XZR *)
  0xab1700c6;       (* arm_ADDS X6 X6 X23 *)
  0x9a1f00e7;       (* arm_ADC X7 X7 XZR *)
  0xab06018c;       (* arm_ADDS X12 X12 X6 *)
  0xba0701ad;       (* arm_ADCS X13 X13 X7 *)
  0x9a1f0273;       (* arm_ADC X19 X19 XZR *)
  0xa93f36cc;       (* arm_STP X12 X13 X22 (Immediate_Offset (iword (-- &16))) *)
  0xb5fff994;       (* arm_CBNZ X20 (word 2096944) *)
  0xf94003f7;       (* arm_LDR X23 SP (Immediate_Offset (word 0)) *)
  0x910023f6;       (* arm_ADD X22 SP (rvalue (word 8)) *)
  0xf840846e;       (* arm_LDR X14 X3 (Postimmediate_Offset (word 8)) *)
  0xf10020b5;       (* arm_SUBS X21 X5 (rvalue (word 8)) *)
  0xaa0003e1;       (* arm_MOV X1 X0 *)
  0xfa0e02e8;       (* arm_SBCS X8 X23 X14 *)
  0xf84086d7;       (* arm_LDR X23 X22 (Postimmediate_Offset (word 8)) *)
  0xd10022b5;       (* arm_SUB X21 X21 (rvalue (word 8)) *)
  0xf840846e;       (* arm_LDR X14 X3 (Postimmediate_Offset (word 8)) *)
  0xf8008428;       (* arm_STR X8 X1 (Postimmediate_Offset (word 8)) *)
  0xb5ffff75;       (* arm_CBNZ X21 (word 2097132) *)
  0xfa0e02e8;       (* arm_SBCS X8 X23 X14 *)
  0xfa1f0273;       (* arm_SBCS X19 X19 XZR *)
  0xf8008428;       (* arm_STR X8 X1 (Postimmediate_Offset (word 8)) *)
  0xf94003f7;       (* arm_LDR X23 SP (Immediate_Offset (word 0)) *)
  0x910023f6;       (* arm_ADD X22 SP (rvalue (word 8)) *)
  0xf8408408;       (* arm_LDR X8 X0 (Postimmediate_Offset (word 8)) *)
  0xd10020a5;       (* arm_SUB X5 X5 (rvalue (word 8)) *)
  0xd503201f;       (* arm_NOP *)
  0xd10020a5;       (* arm_SUB X5 X5 (rvalue (word 8)) *)
  0x9a8832ee;       (* arm_CSEL X14 X23 X8 Condition_CC *)
  0xf84086d7;       (* arm_LDR X23 X22 (Postimmediate_Offset (word 8)) *)
  0xf8408408;       (* arm_LDR X8 X0 (Postimmediate_Offset (word 8)) *)
  0xf81f02df;       (* arm_STR XZR X22 (Immediate_Offset (word 18446744073709551600)) *)
  0xf81f000e;       (* arm_STR X14 X0 (Immediate_Offset (word 18446744073709551600)) *)
  0xb5ffff45;       (* arm_CBNZ X5 (word 2097128) *)
  0x9a8832ee;       (* arm_CSEL X14 X23 X8 Condition_CC *)
  0xf81f82df;       (* arm_STR XZR X22 (Immediate_Offset (word 18446744073709551608)) *)
  0xf81f800e;       (* arm_STR X14 X0 (Immediate_Offset (word 18446744073709551608)) *)
  0xa94153b3;       (* arm_LDP X19 X20 X29 (Immediate_Offset (iword (&16))) *)
  0x910003bf;       (* arm_ADD SP X29 (rvalue (word 0)) *)
  0xa9425bb5;       (* arm_LDP X21 X22 X29 (Immediate_Offset (iword (&32))) *)
  0xd2800020;       (* arm_MOV X0 (rvalue (word 1)) *)
  0xa94363b7;       (* arm_LDP X23 X24 X29 (Immediate_Offset (iword (&48))) *)
  0xf84407fd;       (* arm_LDR X29 SP (Postimmediate_Offset (word 64)) *)
  0xd65f03c0;       (* arm_RET X30 *)
  0xeb02003f;       (* arm_CMP X1 X2 *)
  0x54004ee1;       (* arm_BNE (word 2524) *)
  0xa9b87bfd;       (* arm_STP X29 X30 SP (Preimmediate_Offset (iword (-- &128))) *)
  0x910003fd;       (* arm_ADD X29 SP (rvalue (word 0)) *)
  0xa90153f3;       (* arm_STP X19 X20 SP (Immediate_Offset (iword (&16))) *)
  0xa9025bf5;       (* arm_STP X21 X22 SP (Immediate_Offset (iword (&32))) *)
  0xa90363f7;       (* arm_STP X23 X24 SP (Immediate_Offset (iword (&48))) *)
  0xa9046bf9;       (* arm_STP X25 X26 SP (Immediate_Offset (iword (&64))) *)
  0xa90573fb;       (* arm_STP X27 X28 SP (Immediate_Offset (iword (&80))) *)
  0xa9060fe0;       (* arm_STP X0 X3 SP (Immediate_Offset (iword (&96))) *)
  0xa9401c26;       (* arm_LDP X6 X7 X1 (Immediate_Offset (iword (&0))) *)
  0xa9412428;       (* arm_LDP X8 X9 X1 (Immediate_Offset (iword (&16))) *)
  0xa9422c2a;       (* arm_LDP X10 X11 X1 (Immediate_Offset (iword (&32))) *)
  0xa943342c;       (* arm_LDP X12 X13 X1 (Immediate_Offset (iword (&48))) *)
  0xcb2573e2;       (* arm_SUB X2 SP (Shiftedreg (Extendedreg X5 UXTX) LSL 4) *)
  0xd37df0a5;       (* arm_LSL X5 X5 3 *)
  0xf9400084;       (* arm_LDR X4 X4 (Immediate_Offset (word 0)) *)
  0x9100005f;       (* arm_ADD SP X2 (rvalue (word 0)) *)
  0xd10100bb;       (* arm_SUB X27 X5 (rvalue (word 64)) *)
  0x14000006;       (* arm_B (word 24) *)
  0xd101037b;       (* arm_SUB X27 X27 (rvalue (word 64)) *)
  0xa9007c5f;       (* arm_STP XZR XZR X2 (Immediate_Offset (iword (&0))) *)
  0xa9017c5f;       (* arm_STP XZR XZR X2 (Immediate_Offset (iword (&16))) *)
  0xa9027c5f;       (* arm_STP XZR XZR X2 (Immediate_Offset (iword (&32))) *)
  0xa9037c5f;       (* arm_STP XZR XZR X2 (Immediate_Offset (iword (&48))) *)
  0xa9047c5f;       (* arm_STP XZR XZR X2 (Immediate_Offset (iword (&64))) *)
  0xa9057c5f;       (* arm_STP XZR XZR X2 (Immediate_Offset (iword (&80))) *)
  0xa9067c5f;       (* arm_STP XZR XZR X2 (Immediate_Offset (iword (&96))) *)
  0xa9077c5f;       (* arm_STP XZR XZR X2 (Immediate_Offset (iword (&112))) *)
  0x91020042;       (* arm_ADD X2 X2 (rvalue (word 128)) *)
  0xb5fffedb;       (* arm_CBNZ X27 (word 2097112) *)
  0x8b050023;       (* arm_ADD X3 X1 X5 *)
  0x91010021;       (* arm_ADD X1 X1 (rvalue (word 64)) *)
  0xaa1f03f3;       (* arm_MOV X19 XZR *)
  0xaa1f03f4;       (* arm_MOV X20 XZR *)
  0xaa1f03f5;       (* arm_MOV X21 XZR *)
  0xaa1f03f6;       (* arm_MOV X22 XZR *)
  0xaa1f03f7;       (* arm_MOV X23 XZR *)
  0xaa1f03f8;       (* arm_MOV X24 XZR *)
  0xaa1f03f9;       (* arm_MOV X25 XZR *)
  0xaa1f03fa;       (* arm_MOV X26 XZR *)
  0x910003e2;       (* arm_ADD X2 SP (rvalue (word 0)) *)
  0xf9003ba4;       (* arm_STR X4 X29 (Immediate_Offset (word 112)) *)
  0xd503201f;       (* arm_NOP *)
  0x9b067cee;       (* arm_MUL X14 X7 X6 *)
  0x9b067d0f;       (* arm_MUL X15 X8 X6 *)
  0x9b067d30;       (* arm_MUL X16 X9 X6 *)
  0x9b067d51;       (* arm_MUL X17 X10 X6 *)
  0xab0e0294;       (* arm_ADDS X20 X20 X14 *)
  0x9b067d6e;       (* arm_MUL X14 X11 X6 *)
  0xba0f02b5;       (* arm_ADCS X21 X21 X15 *)
  0x9b067d8f;       (* arm_MUL X15 X12 X6 *)
  0xba1002d6;       (* arm_ADCS X22 X22 X16 *)
  0x9b067db0;       (* arm_MUL X16 X13 X6 *)
  0xba1102f7;       (* arm_ADCS X23 X23 X17 *)
  0x9bc67cf1;       (* arm_UMULH X17 X7 X6 *)
  0xba0e0318;       (* arm_ADCS X24 X24 X14 *)
  0x9bc67d0e;       (* arm_UMULH X14 X8 X6 *)
  0xba0f0339;       (* arm_ADCS X25 X25 X15 *)
  0x9bc67d2f;       (* arm_UMULH X15 X9 X6 *)
  0xba10035a;       (* arm_ADCS X26 X26 X16 *)
  0x9bc67d50;       (* arm_UMULH X16 X10 X6 *)
  0xa8815053;       (* arm_STP X19 X20 X2 (Postimmediate_Offset (iword (&16))) *)
  0x9a1f03f3;       (* arm_ADC X19 XZR XZR *)
  0xab1102b5;       (* arm_ADDS X21 X21 X17 *)
  0x9bc67d71;       (* arm_UMULH X17 X11 X6 *)
  0xba0e02d6;       (* arm_ADCS X22 X22 X14 *)
  0x9bc67d8e;       (* arm_UMULH X14 X12 X6 *)
  0xba0f02f7;       (* arm_ADCS X23 X23 X15 *)
  0x9bc67daf;       (* arm_UMULH X15 X13 X6 *)
  0xba100318;       (* arm_ADCS X24 X24 X16 *)
  0x9b077d10;       (* arm_MUL X16 X8 X7 *)
  0xba110339;       (* arm_ADCS X25 X25 X17 *)
  0x9b077d31;       (* arm_MUL X17 X9 X7 *)
  0xba0e035a;       (* arm_ADCS X26 X26 X14 *)
  0x9b077d4e;       (* arm_MUL X14 X10 X7 *)
  0x9a0f0273;       (* arm_ADC X19 X19 X15 *)
  0x9b077d6f;       (* arm_MUL X15 X11 X7 *)
  0xab1002d6;       (* arm_ADDS X22 X22 X16 *)
  0x9b077d90;       (* arm_MUL X16 X12 X7 *)
  0xba1102f7;       (* arm_ADCS X23 X23 X17 *)
  0x9b077db1;       (* arm_MUL X17 X13 X7 *)
  0xba0e0318;       (* arm_ADCS X24 X24 X14 *)
  0x9bc77d0e;       (* arm_UMULH X14 X8 X7 *)
  0xba0f0339;       (* arm_ADCS X25 X25 X15 *)
  0x9bc77d2f;       (* arm_UMULH X15 X9 X7 *)
  0xba10035a;       (* arm_ADCS X26 X26 X16 *)
  0x9bc77d50;       (* arm_UMULH X16 X10 X7 *)
  0xba110273;       (* arm_ADCS X19 X19 X17 *)
  0x9bc77d71;       (* arm_UMULH X17 X11 X7 *)
  0xa8815855;       (* arm_STP X21 X22 X2 (Postimmediate_Offset (iword (&16))) *)
  0x9a1f03f4;       (* arm_ADC X20 XZR XZR *)
  0xab0e02f7;       (* arm_ADDS X23 X23 X14 *)
  0x9bc77d8e;       (* arm_UMULH X14 X12 X7 *)
  0xba0f0318;       (* arm_ADCS X24 X24 X15 *)
  0x9bc77daf;       (* arm_UMULH X15 X13 X7 *)
  0xba100339;       (* arm_ADCS X25 X25 X16 *)
  0x9b087d30;       (* arm_MUL X16 X9 X8 *)
  0xba11035a;       (* arm_ADCS X26 X26 X17 *)
  0x9b087d51;       (* arm_MUL X17 X10 X8 *)
  0xba0e0273;       (* arm_ADCS X19 X19 X14 *)
  0x9b087d6e;       (* arm_MUL X14 X11 X8 *)
  0x9a0f0294;       (* arm_ADC X20 X20 X15 *)
  0x9b087d8f;       (* arm_MUL X15 X12 X8 *)
  0xab100318;       (* arm_ADDS X24 X24 X16 *)
  0x9b087db0;       (* arm_MUL X16 X13 X8 *)
  0xba110339;       (* arm_ADCS X25 X25 X17 *)
  0x9bc87d31;       (* arm_UMULH X17 X9 X8 *)
  0xba0e035a;       (* arm_ADCS X26 X26 X14 *)
  0x9bc87d4e;       (* arm_UMULH X14 X10 X8 *)
  0xba0f0273;       (* arm_ADCS X19 X19 X15 *)
  0x9bc87d6f;       (* arm_UMULH X15 X11 X8 *)
  0xba100294;       (* arm_ADCS X20 X20 X16 *)
  0x9bc87d90;       (* arm_UMULH X16 X12 X8 *)
  0xa8816057;       (* arm_STP X23 X24 X2 (Postimmediate_Offset (iword (&16))) *)
  0x9a1f03f5;       (* arm_ADC X21 XZR XZR *)
  0xab110339;       (* arm_ADDS X25 X25 X17 *)
  0x9bc87db1;       (* arm_UMULH X17 X13 X8 *)
  0xba0e035a;       (* arm_ADCS X26 X26 X14 *)
  0x9b097d4e;       (* arm_MUL X14 X10 X9 *)
  0xba0f0273;       (* arm_ADCS X19 X19 X15 *)
  0x9b097d6f;       (* arm_MUL X15 X11 X9 *)
  0xba100294;       (* arm_ADCS X20 X20 X16 *)
  0x9b097d90;       (* arm_MUL X16 X12 X9 *)
  0x9a1102b5;       (* arm_ADC X21 X21 X17 *)
  0x9b097db1;       (* arm_MUL X17 X13 X9 *)
  0xab0e035a;       (* arm_ADDS X26 X26 X14 *)
  0x9bc97d4e;       (* arm_UMULH X14 X10 X9 *)
  0xba0f0273;       (* arm_ADCS X19 X19 X15 *)
  0x9bc97d6f;       (* arm_UMULH X15 X11 X9 *)
  0xba100294;       (* arm_ADCS X20 X20 X16 *)
  0x9bc97d90;       (* arm_UMULH X16 X12 X9 *)
  0xba1102b5;       (* arm_ADCS X21 X21 X17 *)
  0x9bc97db1;       (* arm_UMULH X17 X13 X9 *)
  0xa8816859;       (* arm_STP X25 X26 X2 (Postimmediate_Offset (iword (&16))) *)
  0x9a1f03f6;       (* arm_ADC X22 XZR XZR *)
  0xab0e0273;       (* arm_ADDS X19 X19 X14 *)
  0x9b0a7d6e;       (* arm_MUL X14 X11 X10 *)
  0xba0f0294;       (* arm_ADCS X20 X20 X15 *)
  0x9b0a7d8f;       (* arm_MUL X15 X12 X10 *)
  0xba1002b5;       (* arm_ADCS X21 X21 X16 *)
  0x9b0a7db0;       (* arm_MUL X16 X13 X10 *)
  0x9a1102d6;       (* arm_ADC X22 X22 X17 *)
  0x9bca7d71;       (* arm_UMULH X17 X11 X10 *)
  0xab0e0294;       (* arm_ADDS X20 X20 X14 *)
  0x9bca7d8e;       (* arm_UMULH X14 X12 X10 *)
  0xba0f02b5;       (* arm_ADCS X21 X21 X15 *)
  0x9bca7daf;       (* arm_UMULH X15 X13 X10 *)
  0xba1002d6;       (* arm_ADCS X22 X22 X16 *)
  0x9b0b7d90;       (* arm_MUL X16 X12 X11 *)
  0x9a1f03f7;       (* arm_ADC X23 XZR XZR *)
  0xab1102b5;       (* arm_ADDS X21 X21 X17 *)
  0x9b0b7db1;       (* arm_MUL X17 X13 X11 *)
  0xba0e02d6;       (* arm_ADCS X22 X22 X14 *)
  0x9bcb7d8e;       (* arm_UMULH X14 X12 X11 *)
  0x9a0f02f7;       (* arm_ADC X23 X23 X15 *)
  0x9bcb7daf;       (* arm_UMULH X15 X13 X11 *)
  0xab1002d6;       (* arm_ADDS X22 X22 X16 *)
  0x9b0c7db0;       (* arm_MUL X16 X13 X12 *)
  0xba1102f7;       (* arm_ADCS X23 X23 X17 *)
  0x9bcc7db1;       (* arm_UMULH X17 X13 X12 *)
  0x9a1f03f8;       (* arm_ADC X24 XZR XZR *)
  0xab0e02f7;       (* arm_ADDS X23 X23 X14 *)
  0xcb01007b;       (* arm_SUB X27 X3 X1 *)
  0x9a0f0318;       (* arm_ADC X24 X24 X15 *)
  0xab100318;       (* arm_ADDS X24 X24 X16 *)
  0xcb05006e;       (* arm_SUB X14 X3 X5 *)
  0x9a1f03f9;       (* arm_ADC X25 XZR XZR *)
  0x8b110339;       (* arm_ADD X25 X25 X17 *)
  0xb4000cfb;       (* arm_CBZ X27 (word 412) *)
  0xaa0603e4;       (* arm_MOV X4 X6 *)
  0xa9401c46;       (* arm_LDP X6 X7 X2 (Immediate_Offset (iword (&0))) *)
  0xa9412448;       (* arm_LDP X8 X9 X2 (Immediate_Offset (iword (&16))) *)
  0xa9422c4a;       (* arm_LDP X10 X11 X2 (Immediate_Offset (iword (&32))) *)
  0xa943344c;       (* arm_LDP X12 X13 X2 (Immediate_Offset (iword (&48))) *)
  0xab060273;       (* arm_ADDS X19 X19 X6 *)
  0xba070294;       (* arm_ADCS X20 X20 X7 *)
  0xa9401c26;       (* arm_LDP X6 X7 X1 (Immediate_Offset (iword (&0))) *)
  0xba0802b5;       (* arm_ADCS X21 X21 X8 *)
  0xba0902d6;       (* arm_ADCS X22 X22 X9 *)
  0xa9412428;       (* arm_LDP X8 X9 X1 (Immediate_Offset (iword (&16))) *)
  0xba0a02f7;       (* arm_ADCS X23 X23 X10 *)
  0xba0b0318;       (* arm_ADCS X24 X24 X11 *)
  0xa9422c2a;       (* arm_LDP X10 X11 X1 (Immediate_Offset (iword (&32))) *)
  0xba0c0339;       (* arm_ADCS X25 X25 X12 *)
  0xaa0103e0;       (* arm_MOV X0 X1 *)
  0xba0d03fa;       (* arm_ADCS X26 XZR X13 *)
  0xa943342c;       (* arm_LDP X12 X13 X1 (Immediate_Offset (iword (&48))) *)
  0x91010021;       (* arm_ADD X1 X1 (rvalue (word 64)) *)
  0x928007fb;       (* arm_MOVN X27 (word 63) 0 *)
  0x9b047cce;       (* arm_MUL X14 X6 X4 *)
  0x9a1f03fc;       (* arm_ADC X28 XZR XZR *)
  0x9b047cef;       (* arm_MUL X15 X7 X4 *)
  0x9100237b;       (* arm_ADD X27 X27 (rvalue (word 8)) *)
  0x9b047d10;       (* arm_MUL X16 X8 X4 *)
  0x9b047d31;       (* arm_MUL X17 X9 X4 *)
  0xab0e0273;       (* arm_ADDS X19 X19 X14 *)
  0x9b047d4e;       (* arm_MUL X14 X10 X4 *)
  0xba0f0294;       (* arm_ADCS X20 X20 X15 *)
  0x9b047d6f;       (* arm_MUL X15 X11 X4 *)
  0xba1002b5;       (* arm_ADCS X21 X21 X16 *)
  0x9b047d90;       (* arm_MUL X16 X12 X4 *)
  0xba1102d6;       (* arm_ADCS X22 X22 X17 *)
  0x9b047db1;       (* arm_MUL X17 X13 X4 *)
  0xba0e02f7;       (* arm_ADCS X23 X23 X14 *)
  0x9bc47cce;       (* arm_UMULH X14 X6 X4 *)
  0xba0f0318;       (* arm_ADCS X24 X24 X15 *)
  0x9bc47cef;       (* arm_UMULH X15 X7 X4 *)
  0xba100339;       (* arm_ADCS X25 X25 X16 *)
  0x9bc47d10;       (* arm_UMULH X16 X8 X4 *)
  0xba11035a;       (* arm_ADCS X26 X26 X17 *)
  0x9bc47d31;       (* arm_UMULH X17 X9 X4 *)
  0x9a1f039c;       (* arm_ADC X28 X28 XZR *)
  0xf8008453;       (* arm_STR X19 X2 (Postimmediate_Offset (word 8)) *)
  0xab0e0293;       (* arm_ADDS X19 X20 X14 *)
  0x9bc47d4e;       (* arm_UMULH X14 X10 X4 *)
  0xba0f02b4;       (* arm_ADCS X20 X21 X15 *)
  0x9bc47d6f;       (* arm_UMULH X15 X11 X4 *)
  0xba1002d5;       (* arm_ADCS X21 X22 X16 *)
  0x9bc47d90;       (* arm_UMULH X16 X12 X4 *)
  0xba1102f6;       (* arm_ADCS X22 X23 X17 *)
  0x9bc47db1;       (* arm_UMULH X17 X13 X4 *)
  0xf87b6804;       (* arm_LDR X4 X0 (Register_Offset X27) *)
  0xba0e0317;       (* arm_ADCS X23 X24 X14 *)
  0xba0f0338;       (* arm_ADCS X24 X25 X15 *)
  0xba100359;       (* arm_ADCS X25 X26 X16 *)
  0xba11039a;       (* arm_ADCS X26 X28 X17 *)
  0xb5fffb7b;       (* arm_CBNZ X27 (word 2097004) *)
  0xeb03003f;       (* arm_CMP X1 X3 *)
  0x540002e0;       (* arm_BEQ (word 92) *)
  0xa9401c46;       (* arm_LDP X6 X7 X2 (Immediate_Offset (iword (&0))) *)
  0xa9412448;       (* arm_LDP X8 X9 X2 (Immediate_Offset (iword (&16))) *)
  0xa9422c4a;       (* arm_LDP X10 X11 X2 (Immediate_Offset (iword (&32))) *)
  0xa943344c;       (* arm_LDP X12 X13 X2 (Immediate_Offset (iword (&48))) *)
  0xab060273;       (* arm_ADDS X19 X19 X6 *)
  0xf85c0004;       (* arm_LDR X4 X0 (Immediate_Offset (word 18446744073709551552)) *)
  0xba070294;       (* arm_ADCS X20 X20 X7 *)
  0xa9401c26;       (* arm_LDP X6 X7 X1 (Immediate_Offset (iword (&0))) *)
  0xba0802b5;       (* arm_ADCS X21 X21 X8 *)
  0xba0902d6;       (* arm_ADCS X22 X22 X9 *)
  0xa9412428;       (* arm_LDP X8 X9 X1 (Immediate_Offset (iword (&16))) *)
  0xba0a02f7;       (* arm_ADCS X23 X23 X10 *)
  0xba0b0318;       (* arm_ADCS X24 X24 X11 *)
  0xa9422c2a;       (* arm_LDP X10 X11 X1 (Immediate_Offset (iword (&32))) *)
  0xba0c0339;       (* arm_ADCS X25 X25 X12 *)
  0x928007fb;       (* arm_MOVN X27 (word 63) 0 *)
  0xba0d035a;       (* arm_ADCS X26 X26 X13 *)
  0xa943342c;       (* arm_LDP X12 X13 X1 (Immediate_Offset (iword (&48))) *)
  0x91010021;       (* arm_ADD X1 X1 (rvalue (word 64)) *)
  0x17ffffc5;       (* arm_B (word 268435220) *)
  0xd503201f;       (* arm_NOP *)
  0xd503201f;       (* arm_NOP *)
  0xa9401c06;       (* arm_LDP X6 X7 X0 (Immediate_Offset (iword (&0))) *)
  0x91010001;       (* arm_ADD X1 X0 (rvalue (word 64)) *)
  0xa9412408;       (* arm_LDP X8 X9 X0 (Immediate_Offset (iword (&16))) *)
  0xcb01006e;       (* arm_SUB X14 X3 X1 *)
  0xa9422c0a;       (* arm_LDP X10 X11 X0 (Immediate_Offset (iword (&32))) *)
  0xcb0e004f;       (* arm_SUB X15 X2 X14 *)
  0xa943340c;       (* arm_LDP X12 X13 X0 (Immediate_Offset (iword (&48))) *)
  0xb4ffe52e;       (* arm_CBZ X14 (word 2096292) *)
  0xa9005053;       (* arm_STP X19 X20 X2 (Immediate_Offset (iword (&0))) *)
  0xa94051f3;       (* arm_LDP X19 X20 X15 (Immediate_Offset (iword (&0))) *)
  0xa9015855;       (* arm_STP X21 X22 X2 (Immediate_Offset (iword (&16))) *)
  0xa94159f5;       (* arm_LDP X21 X22 X15 (Immediate_Offset (iword (&16))) *)
  0xa9026057;       (* arm_STP X23 X24 X2 (Immediate_Offset (iword (&32))) *)
  0xa94261f7;       (* arm_LDP X23 X24 X15 (Immediate_Offset (iword (&32))) *)
  0xa9036859;       (* arm_STP X25 X26 X2 (Immediate_Offset (iword (&48))) *)
  0xaa0f03e2;       (* arm_MOV X2 X15 *)
  0xa94369f9;       (* arm_LDP X25 X26 X15 (Immediate_Offset (iword (&48))) *)
  0x17ffff1f;       (* arm_B (word 268434556) *)
  0xd503201f;       (* arm_NOP *)
  0xd503201f;       (* arm_NOP *)
  0xa94025c7;       (* arm_LDP X7 X9 X14 (Immediate_Offset (iword (&0))) *)
  0xa940c3ef;       (* arm_LDP X15 X16 SP (Immediate_Offset (iword (&8))) *)
  0xa94135cb;       (* arm_LDP X11 X13 X14 (Immediate_Offset (iword (&16))) *)
  0x910081c1;       (* arm_ADD X1 X14 (rvalue (word 32)) *)
  0xa941bbf1;       (* arm_LDP X17 X14 SP (Immediate_Offset (iword (&24))) *)
  0xa9005053;       (* arm_STP X19 X20 X2 (Immediate_Offset (iword (&0))) *)
  0x9b077cf3;       (* arm_MUL X19 X7 X7 *)
  0xa9015855;       (* arm_STP X21 X22 X2 (Immediate_Offset (iword (&16))) *)
  0x9bc77ce7;       (* arm_UMULH X7 X7 X7 *)
  0xa9026057;       (* arm_STP X23 X24 X2 (Immediate_Offset (iword (&32))) *)
  0x9b097d28;       (* arm_MUL X8 X9 X9 *)
  0xa9036859;       (* arm_STP X25 X26 X2 (Immediate_Offset (iword (&48))) *)
  0x910003e2;       (* arm_ADD X2 SP (rvalue (word 0)) *)
  0x9bc97d29;       (* arm_UMULH X9 X9 X9 *)
  0xab0f04f4;       (* arm_ADDS X20 X7 (Shiftedreg X15 LSL 1) *)
  0x93cffe0f;       (* arm_EXTR X15 X16 X15 63 *)
  0xd10080bb;       (* arm_SUB X27 X5 (rvalue (word 32)) *)
  0xba0f0115;       (* arm_ADCS X21 X8 X15 *)
  0x93d0fe30;       (* arm_EXTR X16 X17 X16 63 *)
  0xd100837b;       (* arm_SUB X27 X27 (rvalue (word 32)) *)
  0xba100136;       (* arm_ADCS X22 X9 X16 *)
  0xa942c04f;       (* arm_LDP X15 X16 X2 (Immediate_Offset (iword (&40))) *)
  0x9b0b7d6a;       (* arm_MUL X10 X11 X11 *)
  0xa8c12427;       (* arm_LDP X7 X9 X1 (Postimmediate_Offset (iword (&16))) *)
  0x9bcb7d6b;       (* arm_UMULH X11 X11 X11 *)
  0x9b0d7dac;       (* arm_MUL X12 X13 X13 *)
  0x9bcd7dad;       (* arm_UMULH X13 X13 X13 *)
  0x93d1fdd1;       (* arm_EXTR X17 X14 X17 63 *)
  0xa9005053;       (* arm_STP X19 X20 X2 (Immediate_Offset (iword (&0))) *)
  0xba110157;       (* arm_ADCS X23 X10 X17 *)
  0x93cefdee;       (* arm_EXTR X14 X15 X14 63 *)
  0xa9015855;       (* arm_STP X21 X22 X2 (Immediate_Offset (iword (&16))) *)
  0xba0e0178;       (* arm_ADCS X24 X11 X14 *)
  0xa943b851;       (* arm_LDP X17 X14 X2 (Immediate_Offset (iword (&56))) *)
  0x93cffe0f;       (* arm_EXTR X15 X16 X15 63 *)
  0xba0f0199;       (* arm_ADCS X25 X12 X15 *)
  0x93d0fe30;       (* arm_EXTR X16 X17 X16 63 *)
  0xba1001ba;       (* arm_ADCS X26 X13 X16 *)
  0xa944c04f;       (* arm_LDP X15 X16 X2 (Immediate_Offset (iword (&72))) *)
  0x9b077ce6;       (* arm_MUL X6 X7 X7 *)
  0xa8c1342b;       (* arm_LDP X11 X13 X1 (Postimmediate_Offset (iword (&16))) *)
  0x9bc77ce7;       (* arm_UMULH X7 X7 X7 *)
  0x9b097d28;       (* arm_MUL X8 X9 X9 *)
  0x9bc97d29;       (* arm_UMULH X9 X9 X9 *)
  0xa9026057;       (* arm_STP X23 X24 X2 (Immediate_Offset (iword (&32))) *)
  0x93d1fdd1;       (* arm_EXTR X17 X14 X17 63 *)
  0xa9036859;       (* arm_STP X25 X26 X2 (Immediate_Offset (iword (&48))) *)
  0x91010042;       (* arm_ADD X2 X2 (rvalue (word 64)) *)
  0xba1100d3;       (* arm_ADCS X19 X6 X17 *)
  0x93cefdee;       (* arm_EXTR X14 X15 X14 63 *)
  0xba0e00f4;       (* arm_ADCS X20 X7 X14 *)
  0xa941b851;       (* arm_LDP X17 X14 X2 (Immediate_Offset (iword (&24))) *)
  0x93cffe0f;       (* arm_EXTR X15 X16 X15 63 *)
  0xb5fffb9b;       (* arm_CBNZ X27 (word 2097008) *)
  0xa94693a1;       (* arm_LDP X1 X4 X29 (Immediate_Offset (iword (&104))) *)
  0xba0f0115;       (* arm_ADCS X21 X8 X15 *)
  0x93d0fe30;       (* arm_EXTR X16 X17 X16 63 *)
  0xba100136;       (* arm_ADCS X22 X9 X16 *)
  0xa942c04f;       (* arm_LDP X15 X16 X2 (Immediate_Offset (iword (&40))) *)
  0x9b0b7d6a;       (* arm_MUL X10 X11 X11 *)
  0x9bcb7d6b;       (* arm_UMULH X11 X11 X11 *)
  0xa9005053;       (* arm_STP X19 X20 X2 (Immediate_Offset (iword (&0))) *)
  0x9b0d7dac;       (* arm_MUL X12 X13 X13 *)
  0x9bcd7dad;       (* arm_UMULH X13 X13 X13 *)
  0xa9015855;       (* arm_STP X21 X22 X2 (Immediate_Offset (iword (&16))) *)
  0x93d1fdd1;       (* arm_EXTR X17 X14 X17 63 *)
  0xba110157;       (* arm_ADCS X23 X10 X17 *)
  0x93cefdee;       (* arm_EXTR X14 X15 X14 63 *)
  0xa94053f3;       (* arm_LDP X19 X20 SP (Immediate_Offset (iword (&0))) *)
  0xba0e0178;       (* arm_ADCS X24 X11 X14 *)
  0x93cffe0f;       (* arm_EXTR X15 X16 X15 63 *)
  0xa9401c26;       (* arm_LDP X6 X7 X1 (Immediate_Offset (iword (&0))) *)
  0xba0f0199;       (* arm_ADCS X25 X12 X15 *)
  0x93d0fff0;       (* arm_EXTR X16 XZR X16 63 *)
  0xa9412428;       (* arm_LDP X8 X9 X1 (Immediate_Offset (iword (&16))) *)
  0x9a1001ba;       (* arm_ADC X26 X13 X16 *)
  0xa9422c2a;       (* arm_LDP X10 X11 X1 (Immediate_Offset (iword (&32))) *)
  0x9b137c9c;       (* arm_MUL X28 X4 X19 *)
  0xa943342c;       (* arm_LDP X12 X13 X1 (Immediate_Offset (iword (&48))) *)
  0x8b050023;       (* arm_ADD X3 X1 X5 *)
  0xa9415bf5;       (* arm_LDP X21 X22 SP (Immediate_Offset (iword (&16))) *)
  0xa9026057;       (* arm_STP X23 X24 X2 (Immediate_Offset (iword (&32))) *)
  0xa94263f7;       (* arm_LDP X23 X24 SP (Immediate_Offset (iword (&32))) *)
  0xa9036859;       (* arm_STP X25 X26 X2 (Immediate_Offset (iword (&48))) *)
  0xa9436bf9;       (* arm_LDP X25 X26 SP (Immediate_Offset (iword (&48))) *)
  0x91010021;       (* arm_ADD X1 X1 (rvalue (word 64)) *)
  0xaa1f03fe;       (* arm_MOV X30 XZR *)
  0x910003e2;       (* arm_ADD X2 SP (rvalue (word 0)) *)
  0xd280011b;       (* arm_MOV X27 (rvalue (word 8)) *)
  0x9b1c7cef;       (* arm_MUL X15 X7 X28 *)
  0xd100077b;       (* arm_SUB X27 X27 (rvalue (word 1)) *)
  0x9b1c7d10;       (* arm_MUL X16 X8 X28 *)
  0xf800845c;       (* arm_STR X28 X2 (Postimmediate_Offset (word 8)) *)
  0x9b1c7d31;       (* arm_MUL X17 X9 X28 *)
  0xf100067f;       (* arm_CMP X19 (rvalue (word 1)) *)
  0x9b1c7d4e;       (* arm_MUL X14 X10 X28 *)
  0xba0f0293;       (* arm_ADCS X19 X20 X15 *)
  0x9b1c7d6f;       (* arm_MUL X15 X11 X28 *)
  0xba1002b4;       (* arm_ADCS X20 X21 X16 *)
  0x9b1c7d90;       (* arm_MUL X16 X12 X28 *)
  0xba1102d5;       (* arm_ADCS X21 X22 X17 *)
  0x9b1c7db1;       (* arm_MUL X17 X13 X28 *)
  0xba0e02f6;       (* arm_ADCS X22 X23 X14 *)
  0x9bdc7cce;       (* arm_UMULH X14 X6 X28 *)
  0xba0f0317;       (* arm_ADCS X23 X24 X15 *)
  0x9bdc7cef;       (* arm_UMULH X15 X7 X28 *)
  0xba100338;       (* arm_ADCS X24 X25 X16 *)
  0x9bdc7d10;       (* arm_UMULH X16 X8 X28 *)
  0xba110359;       (* arm_ADCS X25 X26 X17 *)
  0x9bdc7d31;       (* arm_UMULH X17 X9 X28 *)
  0x9a1f03fa;       (* arm_ADC X26 XZR XZR *)
  0xab0e0273;       (* arm_ADDS X19 X19 X14 *)
  0x9bdc7d4e;       (* arm_UMULH X14 X10 X28 *)
  0xba0f0294;       (* arm_ADCS X20 X20 X15 *)
  0x9bdc7d6f;       (* arm_UMULH X15 X11 X28 *)
  0xba1002b5;       (* arm_ADCS X21 X21 X16 *)
  0x9bdc7d90;       (* arm_UMULH X16 X12 X28 *)
  0xba1102d6;       (* arm_ADCS X22 X22 X17 *)
  0x9bdc7db1;       (* arm_UMULH X17 X13 X28 *)
  0x9b137c9c;       (* arm_MUL X28 X4 X19 *)
  0xba0e02f7;       (* arm_ADCS X23 X23 X14 *)
  0xba0f0318;       (* arm_ADCS X24 X24 X15 *)
  0xba100339;       (* arm_ADCS X25 X25 X16 *)
  0x9a11035a;       (* arm_ADC X26 X26 X17 *)
  0xb5fffbbb;       (* arm_CBNZ X27 (word 2097012) *)
  0xa9403c4e;       (* arm_LDP X14 X15 X2 (Immediate_Offset (iword (&0))) *)
  0xa9414450;       (* arm_LDP X16 X17 X2 (Immediate_Offset (iword (&16))) *)
  0xaa0203e0;       (* arm_MOV X0 X2 *)
  0xcb01007b;       (* arm_SUB X27 X3 X1 *)
  0xab0e0273;       (* arm_ADDS X19 X19 X14 *)
  0xba0f0294;       (* arm_ADCS X20 X20 X15 *)
  0xa9423c4e;       (* arm_LDP X14 X15 X2 (Immediate_Offset (iword (&32))) *)
  0xba1002b5;       (* arm_ADCS X21 X21 X16 *)
  0xba1102d6;       (* arm_ADCS X22 X22 X17 *)
  0xa9434450;       (* arm_LDP X16 X17 X2 (Immediate_Offset (iword (&48))) *)
  0xba0e02f7;       (* arm_ADCS X23 X23 X14 *)
  0xba0f0318;       (* arm_ADCS X24 X24 X15 *)
  0xba100339;       (* arm_ADCS X25 X25 X16 *)
  0xba11035a;       (* arm_ADCS X26 X26 X17 *)
  0xb400163b;       (* arm_CBZ X27 (word 708) *)
  0xf85c0044;       (* arm_LDR X4 X2 (Immediate_Offset (word 18446744073709551552)) *)
  0xa9401c26;       (* arm_LDP X6 X7 X1 (Immediate_Offset (iword (&0))) *)
  0xa9412428;       (* arm_LDP X8 X9 X1 (Immediate_Offset (iword (&16))) *)
  0xa9422c2a;       (* arm_LDP X10 X11 X1 (Immediate_Offset (iword (&32))) *)
  0x928007fb;       (* arm_MOVN X27 (word 63) 0 *)
  0xa943342c;       (* arm_LDP X12 X13 X1 (Immediate_Offset (iword (&48))) *)
  0x91010021;       (* arm_ADD X1 X1 (rvalue (word 64)) *)
  0x9b047cce;       (* arm_MUL X14 X6 X4 *)
  0x9a1f03fc;       (* arm_ADC X28 XZR XZR *)
  0x9b047cef;       (* arm_MUL X15 X7 X4 *)
  0x9100237b;       (* arm_ADD X27 X27 (rvalue (word 8)) *)
  0x9b047d10;       (* arm_MUL X16 X8 X4 *)
  0x9b047d31;       (* arm_MUL X17 X9 X4 *)
  0xab0e0273;       (* arm_ADDS X19 X19 X14 *)
  0x9b047d4e;       (* arm_MUL X14 X10 X4 *)
  0xba0f0294;       (* arm_ADCS X20 X20 X15 *)
  0x9b047d6f;       (* arm_MUL X15 X11 X4 *)
  0xba1002b5;       (* arm_ADCS X21 X21 X16 *)
  0x9b047d90;       (* arm_MUL X16 X12 X4 *)
  0xba1102d6;       (* arm_ADCS X22 X22 X17 *)
  0x9b047db1;       (* arm_MUL X17 X13 X4 *)
  0xba0e02f7;       (* arm_ADCS X23 X23 X14 *)
  0x9bc47cce;       (* arm_UMULH X14 X6 X4 *)
  0xba0f0318;       (* arm_ADCS X24 X24 X15 *)
  0x9bc47cef;       (* arm_UMULH X15 X7 X4 *)
  0xba100339;       (* arm_ADCS X25 X25 X16 *)
  0x9bc47d10;       (* arm_UMULH X16 X8 X4 *)
  0xba11035a;       (* arm_ADCS X26 X26 X17 *)
  0x9bc47d31;       (* arm_UMULH X17 X9 X4 *)
  0x9a1f039c;       (* arm_ADC X28 X28 XZR *)
  0xf8008453;       (* arm_STR X19 X2 (Postimmediate_Offset (word 8)) *)
  0xab0e0293;       (* arm_ADDS X19 X20 X14 *)
  0x9bc47d4e;       (* arm_UMULH X14 X10 X4 *)
  0xba0f02b4;       (* arm_ADCS X20 X21 X15 *)
  0x9bc47d6f;       (* arm_UMULH X15 X11 X4 *)
  0xba1002d5;       (* arm_ADCS X21 X22 X16 *)
  0x9bc47d90;       (* arm_UMULH X16 X12 X4 *)
  0xba1102f6;       (* arm_ADCS X22 X23 X17 *)
  0x9bc47db1;       (* arm_UMULH X17 X13 X4 *)
  0xf87b6804;       (* arm_LDR X4 X0 (Register_Offset X27) *)
  0xba0e0317;       (* arm_ADCS X23 X24 X14 *)
  0xba0f0338;       (* arm_ADCS X24 X25 X15 *)
  0xba100359;       (* arm_ADCS X25 X26 X16 *)
  0xba11039a;       (* arm_ADCS X26 X28 X17 *)
  0xb5fffb7b;       (* arm_CBNZ X27 (word 2097004) *)
  0xa9401c46;       (* arm_LDP X6 X7 X2 (Immediate_Offset (iword (&0))) *)
  0xcb01007b;       (* arm_SUB X27 X3 X1 *)
  0xcb050070;       (* arm_SUB X16 X3 X5 *)
  0xa9412448;       (* arm_LDP X8 X9 X2 (Immediate_Offset (iword (&16))) *)
  0xa9422c4a;       (* arm_LDP X10 X11 X2 (Immediate_Offset (iword (&32))) *)
  0xa943344c;       (* arm_LDP X12 X13 X2 (Immediate_Offset (iword (&48))) *)
  0xb400023b;       (* arm_CBZ X27 (word 68) *)
  0xf85c0004;       (* arm_LDR X4 X0 (Immediate_Offset (word 18446744073709551552)) *)
  0xab060273;       (* arm_ADDS X19 X19 X6 *)
  0xba070294;       (* arm_ADCS X20 X20 X7 *)
  0xa9401c26;       (* arm_LDP X6 X7 X1 (Immediate_Offset (iword (&0))) *)
  0xba0802b5;       (* arm_ADCS X21 X21 X8 *)
  0xba0902d6;       (* arm_ADCS X22 X22 X9 *)
  0xa9412428;       (* arm_LDP X8 X9 X1 (Immediate_Offset (iword (&16))) *)
  0xba0a02f7;       (* arm_ADCS X23 X23 X10 *)
  0xba0b0318;       (* arm_ADCS X24 X24 X11 *)
  0xa9422c2a;       (* arm_LDP X10 X11 X1 (Immediate_Offset (iword (&32))) *)
  0xba0c0339;       (* arm_ADCS X25 X25 X12 *)
  0x928007fb;       (* arm_MOVN X27 (word 63) 0 *)
  0xba0d035a;       (* arm_ADCS X26 X26 X13 *)
  0xa943342c;       (* arm_LDP X12 X13 X1 (Immediate_Offset (iword (&48))) *)
  0x91010021;       (* arm_ADD X1 X1 (rvalue (word 64)) *)
  0x17ffffc4;       (* arm_B (word 268435216) *)
  0xf9403ba4;       (* arm_LDR X4 X29 (Immediate_Offset (word 112)) *)
  0x9101005b;       (* arm_ADD X27 X2 (rvalue (word 64)) *)
  0xf10007df;       (* arm_CMP X30 (rvalue (word 1)) *)
  0xba06026e;       (* arm_ADCS X14 X19 X6 *)
  0xba07028f;       (* arm_ADCS X15 X20 X7 *)
  0xa9405013;       (* arm_LDP X19 X20 X0 (Immediate_Offset (iword (&0))) *)
  0xba0802b5;       (* arm_ADCS X21 X21 X8 *)
  0xa9401e06;       (* arm_LDP X6 X7 X16 (Immediate_Offset (iword (&0))) *)
  0xba0902d6;       (* arm_ADCS X22 X22 X9 *)
  0xa9412608;       (* arm_LDP X8 X9 X16 (Immediate_Offset (iword (&16))) *)
  0xba0a02f7;       (* arm_ADCS X23 X23 X10 *)
  0xba0b0318;       (* arm_ADCS X24 X24 X11 *)
  0xa9422e0a;       (* arm_LDP X10 X11 X16 (Immediate_Offset (iword (&32))) *)
  0xba0c0339;       (* arm_ADCS X25 X25 X12 *)
  0xba0d035a;       (* arm_ADCS X26 X26 X13 *)
  0xa943360c;       (* arm_LDP X12 X13 X16 (Immediate_Offset (iword (&48))) *)
  0x91010201;       (* arm_ADD X1 X16 (rvalue (word 64)) *)
  0x9a1f03fe;       (* arm_ADC X30 XZR XZR *)
  0x9b137c9c;       (* arm_MUL X28 X4 X19 *)
  0xa9003c4e;       (* arm_STP X14 X15 X2 (Immediate_Offset (iword (&0))) *)
  0xa9015855;       (* arm_STP X21 X22 X2 (Immediate_Offset (iword (&16))) *)
  0xa9415815;       (* arm_LDP X21 X22 X0 (Immediate_Offset (iword (&16))) *)
  0xa9026057;       (* arm_STP X23 X24 X2 (Immediate_Offset (iword (&32))) *)
  0xa9426017;       (* arm_LDP X23 X24 X0 (Immediate_Offset (iword (&32))) *)
  0xeb1d037f;       (* arm_CMP X27 X29 *)
  0xa9036859;       (* arm_STP X25 X26 X2 (Immediate_Offset (iword (&48))) *)
  0xaa0003e2;       (* arm_MOV X2 X0 *)
  0xa9436819;       (* arm_LDP X25 X26 X0 (Immediate_Offset (iword (&48))) *)
  0xd280011b;       (* arm_MOV X27 (rvalue (word 8)) *)
  0x54ffed81;       (* arm_BNE (word 2096560) *)
  0xf94033a0;       (* arm_LDR X0 X29 (Immediate_Offset (word 96)) *)
  0x91010042;       (* arm_ADD X2 X2 (rvalue (word 64)) *)
  0xeb06026e;       (* arm_SUBS X14 X19 X6 *)
  0xfa07028f;       (* arm_SBCS X15 X20 X7 *)
  0xd10100bb;       (* arm_SUB X27 X5 (rvalue (word 64)) *)
  0xaa0003e3;       (* arm_MOV X3 X0 *)
  0xfa0802b0;       (* arm_SBCS X16 X21 X8 *)
  0xa9401c26;       (* arm_LDP X6 X7 X1 (Immediate_Offset (iword (&0))) *)
  0xfa0902d1;       (* arm_SBCS X17 X22 X9 *)
  0xa9003c0e;       (* arm_STP X14 X15 X0 (Immediate_Offset (iword (&0))) *)
  0xfa0a02ee;       (* arm_SBCS X14 X23 X10 *)
  0xa9412428;       (* arm_LDP X8 X9 X1 (Immediate_Offset (iword (&16))) *)
  0xfa0b030f;       (* arm_SBCS X15 X24 X11 *)
  0xa9014410;       (* arm_STP X16 X17 X0 (Immediate_Offset (iword (&16))) *)
  0xfa0c0330;       (* arm_SBCS X16 X25 X12 *)
  0xa9422c2a;       (* arm_LDP X10 X11 X1 (Immediate_Offset (iword (&32))) *)
  0xfa0d0351;       (* arm_SBCS X17 X26 X13 *)
  0xa943342c;       (* arm_LDP X12 X13 X1 (Immediate_Offset (iword (&48))) *)
  0x91010021;       (* arm_ADD X1 X1 (rvalue (word 64)) *)
  0xa9405053;       (* arm_LDP X19 X20 X2 (Immediate_Offset (iword (&0))) *)
  0xd101037b;       (* arm_SUB X27 X27 (rvalue (word 64)) *)
  0xa9415855;       (* arm_LDP X21 X22 X2 (Immediate_Offset (iword (&16))) *)
  0xa9426057;       (* arm_LDP X23 X24 X2 (Immediate_Offset (iword (&32))) *)
  0xa9436859;       (* arm_LDP X25 X26 X2 (Immediate_Offset (iword (&48))) *)
  0x91010042;       (* arm_ADD X2 X2 (rvalue (word 64)) *)
  0xa9023c0e;       (* arm_STP X14 X15 X0 (Immediate_Offset (iword (&32))) *)
  0xfa06026e;       (* arm_SBCS X14 X19 X6 *)
  0xa9034410;       (* arm_STP X16 X17 X0 (Immediate_Offset (iword (&48))) *)
  0x91010000;       (* arm_ADD X0 X0 (rvalue (word 64)) *)
  0xfa07028f;       (* arm_SBCS X15 X20 X7 *)
  0xb5fffd1b;       (* arm_CBNZ X27 (word 2097056) *)
  0xfa0802b0;       (* arm_SBCS X16 X21 X8 *)
  0x910003e2;       (* arm_ADD X2 SP (rvalue (word 0)) *)
  0x8b2563e1;       (* arm_ADD X1 SP (Extendedreg X5 UXTX) *)
  0xa9401c66;       (* arm_LDP X6 X7 X3 (Immediate_Offset (iword (&0))) *)
  0xfa0902d1;       (* arm_SBCS X17 X22 X9 *)
  0xa9003c0e;       (* arm_STP X14 X15 X0 (Immediate_Offset (iword (&0))) *)
  0xfa0a02ee;       (* arm_SBCS X14 X23 X10 *)
  0xa9412468;       (* arm_LDP X8 X9 X3 (Immediate_Offset (iword (&16))) *)
  0xfa0b030f;       (* arm_SBCS X15 X24 X11 *)
  0xa9014410;       (* arm_STP X16 X17 X0 (Immediate_Offset (iword (&16))) *)
  0xfa0c0330;       (* arm_SBCS X16 X25 X12 *)
  0xa9405033;       (* arm_LDP X19 X20 X1 (Immediate_Offset (iword (&0))) *)
  0xfa0d0351;       (* arm_SBCS X17 X26 X13 *)
  0xa9415835;       (* arm_LDP X21 X22 X1 (Immediate_Offset (iword (&16))) *)
  0xfa1f03df;       (* arm_SBCS XZR X30 XZR *)
  0xf94007be;       (* arm_LDR X30 X29 (Immediate_Offset (word 8)) *)
  0xa9023c0e;       (* arm_STP X14 X15 X0 (Immediate_Offset (iword (&32))) *)
  0xa9034410;       (* arm_STP X16 X17 X0 (Immediate_Offset (iword (&48))) *)
  0xd10080bb;       (* arm_SUB X27 X5 (rvalue (word 32)) *)
  0xd100837b;       (* arm_SUB X27 X27 (rvalue (word 32)) *)
  0x9a86326e;       (* arm_CSEL X14 X19 X6 Condition_CC *)
  0xa9007c5f;       (* arm_STP XZR XZR X2 (Immediate_Offset (iword (&0))) *)
  0x9a87328f;       (* arm_CSEL X15 X20 X7 Condition_CC *)
  0xa9421c66;       (* arm_LDP X6 X7 X3 (Immediate_Offset (iword (&32))) *)
  0xa9425033;       (* arm_LDP X19 X20 X1 (Immediate_Offset (iword (&32))) *)
  0x9a8832b0;       (* arm_CSEL X16 X21 X8 Condition_CC *)
  0xa9017c5f;       (* arm_STP XZR XZR X2 (Immediate_Offset (iword (&16))) *)
  0x91008042;       (* arm_ADD X2 X2 (rvalue (word 32)) *)
  0x9a8932d1;       (* arm_CSEL X17 X22 X9 Condition_CC *)
  0xa9432468;       (* arm_LDP X8 X9 X3 (Immediate_Offset (iword (&48))) *)
  0xa9435835;       (* arm_LDP X21 X22 X1 (Immediate_Offset (iword (&48))) *)
  0x91008021;       (* arm_ADD X1 X1 (rvalue (word 32)) *)
  0xa9003c6e;       (* arm_STP X14 X15 X3 (Immediate_Offset (iword (&0))) *)
  0xa9014470;       (* arm_STP X16 X17 X3 (Immediate_Offset (iword (&16))) *)
  0x91008063;       (* arm_ADD X3 X3 (rvalue (word 32)) *)
  0xa9007c3f;       (* arm_STP XZR XZR X1 (Immediate_Offset (iword (&0))) *)
  0xa9017c3f;       (* arm_STP XZR XZR X1 (Immediate_Offset (iword (&16))) *)
  0xb5fffddb;       (* arm_CBNZ X27 (word 2097080) *)
  0x9a86326e;       (* arm_CSEL X14 X19 X6 Condition_CC *)
  0xa9007c5f;       (* arm_STP XZR XZR X2 (Immediate_Offset (iword (&0))) *)
  0x9a87328f;       (* arm_CSEL X15 X20 X7 Condition_CC *)
  0xa9017c5f;       (* arm_STP XZR XZR X2 (Immediate_Offset (iword (&16))) *)
  0x9a8832b0;       (* arm_CSEL X16 X21 X8 Condition_CC *)
  0x9a8932d1;       (* arm_CSEL X17 X22 X9 Condition_CC *)
  0xa9003c6e;       (* arm_STP X14 X15 X3 (Immediate_Offset (iword (&0))) *)
  0xa9014470;       (* arm_STP X16 X17 X3 (Immediate_Offset (iword (&16))) *)
  0x14000021;       (* arm_B (word 132) *)
  0x9a1f03fc;       (* arm_ADC X28 XZR XZR *)
  0xf94007be;       (* arm_LDR X30 X29 (Immediate_Offset (word 8)) *)
  0xeb060266;       (* arm_SUBS X6 X19 X6 *)
  0xf94033a1;       (* arm_LDR X1 X29 (Immediate_Offset (word 96)) *)
  0xfa070287;       (* arm_SBCS X7 X20 X7 *)
  0xa9007fff;       (* arm_STP XZR XZR SP (Immediate_Offset (iword (&0))) *)
  0xfa0802a8;       (* arm_SBCS X8 X21 X8 *)
  0xa9017fff;       (* arm_STP XZR XZR SP (Immediate_Offset (iword (&16))) *)
  0xfa0902c9;       (* arm_SBCS X9 X22 X9 *)
  0xa9027fff;       (* arm_STP XZR XZR SP (Immediate_Offset (iword (&32))) *)
  0xfa0a02ea;       (* arm_SBCS X10 X23 X10 *)
  0xa9037fff;       (* arm_STP XZR XZR SP (Immediate_Offset (iword (&48))) *)
  0xfa0b030b;       (* arm_SBCS X11 X24 X11 *)
  0xa9047fff;       (* arm_STP XZR XZR SP (Immediate_Offset (iword (&64))) *)
  0xfa0c032c;       (* arm_SBCS X12 X25 X12 *)
  0xa9057fff;       (* arm_STP XZR XZR SP (Immediate_Offset (iword (&80))) *)
  0xfa0d034d;       (* arm_SBCS X13 X26 X13 *)
  0xa9067fff;       (* arm_STP XZR XZR SP (Immediate_Offset (iword (&96))) *)
  0xfa1f039c;       (* arm_SBCS X28 X28 XZR *)
  0xa9077fff;       (* arm_STP XZR XZR SP (Immediate_Offset (iword (&112))) *)
  0x9a863266;       (* arm_CSEL X6 X19 X6 Condition_CC *)
  0x9a873287;       (* arm_CSEL X7 X20 X7 Condition_CC *)
  0x9a8832a8;       (* arm_CSEL X8 X21 X8 Condition_CC *)
  0x9a8932c9;       (* arm_CSEL X9 X22 X9 Condition_CC *)
  0xa9001c26;       (* arm_STP X6 X7 X1 (Immediate_Offset (iword (&0))) *)
  0x9a8a32ea;       (* arm_CSEL X10 X23 X10 Condition_CC *)
  0x9a8b330b;       (* arm_CSEL X11 X24 X11 Condition_CC *)
  0xa9012428;       (* arm_STP X8 X9 X1 (Immediate_Offset (iword (&16))) *)
  0x9a8c332c;       (* arm_CSEL X12 X25 X12 Condition_CC *)
  0x9a8d334d;       (* arm_CSEL X13 X26 X13 Condition_CC *)
  0xa9022c2a;       (* arm_STP X10 X11 X1 (Immediate_Offset (iword (&32))) *)
  0xa903342c;       (* arm_STP X12 X13 X1 (Immediate_Offset (iword (&48))) *)
  0xa94153b3;       (* arm_LDP X19 X20 X29 (Immediate_Offset (iword (&16))) *)
  0x910003bf;       (* arm_ADD SP X29 (rvalue (word 0)) *)
  0xa9425bb5;       (* arm_LDP X21 X22 X29 (Immediate_Offset (iword (&32))) *)
  0xd2800020;       (* arm_MOV X0 (rvalue (word 1)) *)
  0xa94363b7;       (* arm_LDP X23 X24 X29 (Immediate_Offset (iword (&48))) *)
  0xa9446bb9;       (* arm_LDP X25 X26 X29 (Immediate_Offset (iword (&64))) *)
  0xa94573bb;       (* arm_LDP X27 X28 X29 (Immediate_Offset (iword (&80))) *)
  0xf84807fd;       (* arm_LDR X29 SP (Postimmediate_Offset (word 128)) *)
  0xd65f03c0;       (* arm_RET X30 *)
  0xd503201f;       (* arm_NOP *)
  0xd503201f;       (* arm_NOP *)
  0xd503201f;       (* arm_NOP *)
  0xa9b87bfd;       (* arm_STP X29 X30 SP (Preimmediate_Offset (iword (-- &128))) *)
  0x910003fd;       (* arm_ADD X29 SP (rvalue (word 0)) *)
  0xa90153f3;       (* arm_STP X19 X20 SP (Immediate_Offset (iword (&16))) *)
  0xa9025bf5;       (* arm_STP X21 X22 SP (Immediate_Offset (iword (&32))) *)
  0xa90363f7;       (* arm_STP X23 X24 SP (Immediate_Offset (iword (&48))) *)
  0xa9046bf9;       (* arm_STP X25 X26 SP (Immediate_Offset (iword (&64))) *)
  0xa90573fb;       (* arm_STP X27 X28 SP (Immediate_Offset (iword (&80))) *)
  0xcb256ffa;       (* arm_SUB X26 SP (Shiftedreg (Extendedreg X5 UXTX) LSL 3) *)
  0xd37df0a5;       (* arm_LSL X5 X5 3 *)
  0xf9400084;       (* arm_LDR X4 X4 (Immediate_Offset (word 0)) *)
  0xd100835f;       (* arm_SUB SP X26 (rvalue (word 32)) *)
  0x8b05004a;       (* arm_ADD X10 X2 X5 *)
  0x8b05003b;       (* arm_ADD X27 X1 X5 *)
  0xa9062ba0;       (* arm_STP X0 X10 X29 (Immediate_Offset (iword (&96))) *)
  0xf9400058;       (* arm_LDR X24 X2 (Immediate_Offset (word 0)) *)
  0xa9401c26;       (* arm_LDP X6 X7 X1 (Immediate_Offset (iword (&0))) *)
  0xa9412428;       (* arm_LDP X8 X9 X1 (Immediate_Offset (iword (&16))) *)
  0x91008021;       (* arm_ADD X1 X1 (rvalue (word 32)) *)
  0xaa1f03f3;       (* arm_MOV X19 XZR *)
  0xaa1f03f4;       (* arm_MOV X20 XZR *)
  0xaa1f03f5;       (* arm_MOV X21 XZR *)
  0xaa1f03f6;       (* arm_MOV X22 XZR *)
  0xa9403c6e;       (* arm_LDP X14 X15 X3 (Immediate_Offset (iword (&0))) *)
  0xa9414470;       (* arm_LDP X16 X17 X3 (Immediate_Offset (iword (&16))) *)
  0xb1008063;       (* arm_ADDS X3 X3 (rvalue (word 32)) *)
  0xaa1f03e0;       (* arm_MOV X0 XZR *)
  0xd280001c;       (* arm_MOV X28 (rvalue (word 0)) *)
  0x910003fa;       (* arm_ADD X26 SP (rvalue (word 0)) *)
  0x9b187cca;       (* arm_MUL X10 X6 X24 *)
  0x9a1f0000;       (* arm_ADC X0 X0 XZR *)
  0x9b187ceb;       (* arm_MUL X11 X7 X24 *)
  0x9100239c;       (* arm_ADD X28 X28 (rvalue (word 8)) *)
  0x9b187d0c;       (* arm_MUL X12 X8 X24 *)
  0x9240139c;       (* arm_AND X28 X28 (rvalue (word 31)) *)
  0x9b187d2d;       (* arm_MUL X13 X9 X24 *)
  0xab0a0273;       (* arm_ADDS X19 X19 X10 *)
  0x9bd87cca;       (* arm_UMULH X10 X6 X24 *)
  0xba0b0294;       (* arm_ADCS X20 X20 X11 *)
  0x9b047e79;       (* arm_MUL X25 X19 X4 *)
  0xba0c02b5;       (* arm_ADCS X21 X21 X12 *)
  0x9bd87ceb;       (* arm_UMULH X11 X7 X24 *)
  0xba0d02d6;       (* arm_ADCS X22 X22 X13 *)
  0x9bd87d0c;       (* arm_UMULH X12 X8 X24 *)
  0x9a1f03f7;       (* arm_ADC X23 XZR XZR *)
  0x9bd87d2d;       (* arm_UMULH X13 X9 X24 *)
  0xf87c6858;       (* arm_LDR X24 X2 (Register_Offset X28) *)
  0xab0a0294;       (* arm_ADDS X20 X20 X10 *)
  0xf8008759;       (* arm_STR X25 X26 (Postimmediate_Offset (word 8)) *)
  0xba0b02b5;       (* arm_ADCS X21 X21 X11 *)
  0x9b197deb;       (* arm_MUL X11 X15 X25 *)
  0xba0c02d6;       (* arm_ADCS X22 X22 X12 *)
  0x9b197e0c;       (* arm_MUL X12 X16 X25 *)
  0x9a0d02f7;       (* arm_ADC X23 X23 X13 *)
  0x9b197e2d;       (* arm_MUL X13 X17 X25 *)
  0xf100067f;       (* arm_CMP X19 (rvalue (word 1)) *)
  0x9bd97dca;       (* arm_UMULH X10 X14 X25 *)
  0xba0b0293;       (* arm_ADCS X19 X20 X11 *)
  0x9bd97deb;       (* arm_UMULH X11 X15 X25 *)
  0xba0c02b4;       (* arm_ADCS X20 X21 X12 *)
  0x9bd97e0c;       (* arm_UMULH X12 X16 X25 *)
  0xba0d02d5;       (* arm_ADCS X21 X22 X13 *)
  0x9bd97e2d;       (* arm_UMULH X13 X17 X25 *)
  0xba0002f6;       (* arm_ADCS X22 X23 X0 *)
  0x9a1f03e0;       (* arm_ADC X0 XZR XZR *)
  0xab0a0273;       (* arm_ADDS X19 X19 X10 *)
  0xcb01036a;       (* arm_SUB X10 X27 X1 *)
  0xba0b0294;       (* arm_ADCS X20 X20 X11 *)
  0xba0c02b5;       (* arm_ADCS X21 X21 X12 *)
  0xba0d02d6;       (* arm_ADCS X22 X22 X13 *)
  0xb5fffafc;       (* arm_CBNZ X28 (word 2096988) *)
  0xb40023ca;       (* arm_CBZ X10 (word 1144) *)
  0xa9401c26;       (* arm_LDP X6 X7 X1 (Immediate_Offset (iword (&0))) *)
  0xa9412428;       (* arm_LDP X8 X9 X1 (Immediate_Offset (iword (&16))) *)
  0x91008021;       (* arm_ADD X1 X1 (rvalue (word 32)) *)
  0xf94003f9;       (* arm_LDR X25 SP (Immediate_Offset (word 0)) *)
  0xa9403c6e;       (* arm_LDP X14 X15 X3 (Immediate_Offset (iword (&0))) *)
  0xa9414470;       (* arm_LDP X16 X17 X3 (Immediate_Offset (iword (&16))) *)
  0x91008063;       (* arm_ADD X3 X3 (rvalue (word 32)) *)
  0x9b187cca;       (* arm_MUL X10 X6 X24 *)
  0x9a1f0000;       (* arm_ADC X0 X0 XZR *)
  0x9b187ceb;       (* arm_MUL X11 X7 X24 *)
  0x9100239c;       (* arm_ADD X28 X28 (rvalue (word 8)) *)
  0x9b187d0c;       (* arm_MUL X12 X8 X24 *)
  0x9240139c;       (* arm_AND X28 X28 (rvalue (word 31)) *)
  0x9b187d2d;       (* arm_MUL X13 X9 X24 *)
  0xab0a0273;       (* arm_ADDS X19 X19 X10 *)
  0x9bd87cca;       (* arm_UMULH X10 X6 X24 *)
  0xba0b0294;       (* arm_ADCS X20 X20 X11 *)
  0x9bd87ceb;       (* arm_UMULH X11 X7 X24 *)
  0xba0c02b5;       (* arm_ADCS X21 X21 X12 *)
  0x9bd87d0c;       (* arm_UMULH X12 X8 X24 *)
  0xba0d02d6;       (* arm_ADCS X22 X22 X13 *)
  0x9bd87d2d;       (* arm_UMULH X13 X9 X24 *)
  0x9a1f03f7;       (* arm_ADC X23 XZR XZR *)
  0xf87c6858;       (* arm_LDR X24 X2 (Register_Offset X28) *)
  0xab0a0294;       (* arm_ADDS X20 X20 X10 *)
  0x9b197dca;       (* arm_MUL X10 X14 X25 *)
  0xba0b02b5;       (* arm_ADCS X21 X21 X11 *)
  0x9b197deb;       (* arm_MUL X11 X15 X25 *)
  0xba0c02d6;       (* arm_ADCS X22 X22 X12 *)
  0x9b197e0c;       (* arm_MUL X12 X16 X25 *)
  0x9a0d02f7;       (* arm_ADC X23 X23 X13 *)
  0x9b197e2d;       (* arm_MUL X13 X17 X25 *)
  0xab0a0273;       (* arm_ADDS X19 X19 X10 *)
  0x9bd97dca;       (* arm_UMULH X10 X14 X25 *)
  0xba0b0294;       (* arm_ADCS X20 X20 X11 *)
  0x9bd97deb;       (* arm_UMULH X11 X15 X25 *)
  0xba0c02b5;       (* arm_ADCS X21 X21 X12 *)
  0x9bd97e0c;       (* arm_UMULH X12 X16 X25 *)
  0xba0d02d6;       (* arm_ADCS X22 X22 X13 *)
  0xba0002f7;       (* arm_ADCS X23 X23 X0 *)
  0x9bd97e2d;       (* arm_UMULH X13 X17 X25 *)
  0x9a1f03e0;       (* arm_ADC X0 XZR XZR *)
  0xf87c6bf9;       (* arm_LDR X25 SP (Register_Offset X28) *)
  0xf8008753;       (* arm_STR X19 X26 (Postimmediate_Offset (word 8)) *)
  0xab0a0293;       (* arm_ADDS X19 X20 X10 *)
  0xcb01036a;       (* arm_SUB X10 X27 X1 *)
  0xba0b02b4;       (* arm_ADCS X20 X21 X11 *)
  0xba0c02d5;       (* arm_ADCS X21 X22 X12 *)
  0xba0d02f6;       (* arm_ADCS X22 X23 X13 *)
  0xb5fffadc;       (* arm_CBNZ X28 (word 2096984) *)
  0xcb05036b;       (* arm_SUB X11 X27 X5 *)
  0xb40001ca;       (* arm_CBZ X10 (word 56) *)
  0xa9401c26;       (* arm_LDP X6 X7 X1 (Immediate_Offset (iword (&0))) *)
  0xa9412428;       (* arm_LDP X8 X9 X1 (Immediate_Offset (iword (&16))) *)
  0x91008021;       (* arm_ADD X1 X1 (rvalue (word 32)) *)
  0xa9403c6e;       (* arm_LDP X14 X15 X3 (Immediate_Offset (iword (&0))) *)
  0xa9414470;       (* arm_LDP X16 X17 X3 (Immediate_Offset (iword (&16))) *)
  0x91008063;       (* arm_ADD X3 X3 (rvalue (word 32)) *)
  0x17ffffcd;       (* arm_B (word 268435252) *)
  0xd503201f;       (* arm_NOP *)
  0xd503201f;       (* arm_NOP *)
  0xd503201f;       (* arm_NOP *)
  0xd503201f;       (* arm_NOP *)
  0xd503201f;       (* arm_NOP *)
  0xd503201f;       (* arm_NOP *)
  0xf8420c58;       (* arm_LDR X24 X2 (Preimmediate_Offset (word 32)) *)
  0x9a1f001e;       (* arm_ADC X30 X0 XZR *)
  0xa9401d66;       (* arm_LDP X6 X7 X11 (Immediate_Offset (iword (&0))) *)
  0xcb050063;       (* arm_SUB X3 X3 X5 *)
  0xa9412568;       (* arm_LDP X8 X9 X11 (Immediate_Offset (iword (&16))) *)
  0x91008161;       (* arm_ADD X1 X11 (rvalue (word 32)) *)
  0xa9005353;       (* arm_STP X19 X20 X26 (Immediate_Offset (iword (&0))) *)
  0xa94253f3;       (* arm_LDP X19 X20 SP (Immediate_Offset (iword (&32))) *)
  0xa9015b55;       (* arm_STP X21 X22 X26 (Immediate_Offset (iword (&16))) *)
  0xa9435bf5;       (* arm_LDP X21 X22 SP (Immediate_Offset (iword (&48))) *)
  0xa9403c6e;       (* arm_LDP X14 X15 X3 (Immediate_Offset (iword (&0))) *)
  0x910003fa;       (* arm_ADD X26 SP (rvalue (word 0)) *)
  0xa9414470;       (* arm_LDP X16 X17 X3 (Immediate_Offset (iword (&16))) *)
  0xb1008063;       (* arm_ADDS X3 X3 (rvalue (word 32)) *)
  0xaa1f03e0;       (* arm_MOV X0 XZR *)
  0xd503201f;       (* arm_NOP *)
  0x9b187cca;       (* arm_MUL X10 X6 X24 *)
  0x9a1f0000;       (* arm_ADC X0 X0 XZR *)
  0x9b187ceb;       (* arm_MUL X11 X7 X24 *)
  0x9100239c;       (* arm_ADD X28 X28 (rvalue (word 8)) *)
  0x9b187d0c;       (* arm_MUL X12 X8 X24 *)
  0x9240139c;       (* arm_AND X28 X28 (rvalue (word 31)) *)
  0x9b187d2d;       (* arm_MUL X13 X9 X24 *)
  0xab0a0273;       (* arm_ADDS X19 X19 X10 *)
  0x9bd87cca;       (* arm_UMULH X10 X6 X24 *)
  0xba0b0294;       (* arm_ADCS X20 X20 X11 *)
  0x9b047e79;       (* arm_MUL X25 X19 X4 *)
  0xba0c02b5;       (* arm_ADCS X21 X21 X12 *)
  0x9bd87ceb;       (* arm_UMULH X11 X7 X24 *)
  0xba0d02d6;       (* arm_ADCS X22 X22 X13 *)
  0x9bd87d0c;       (* arm_UMULH X12 X8 X24 *)
  0x9a1f03f7;       (* arm_ADC X23 XZR XZR *)
  0x9bd87d2d;       (* arm_UMULH X13 X9 X24 *)
  0xf87c6858;       (* arm_LDR X24 X2 (Register_Offset X28) *)
  0xab0a0294;       (* arm_ADDS X20 X20 X10 *)
  0xf8008759;       (* arm_STR X25 X26 (Postimmediate_Offset (word 8)) *)
  0xba0b02b5;       (* arm_ADCS X21 X21 X11 *)
  0x9b197deb;       (* arm_MUL X11 X15 X25 *)
  0xba0c02d6;       (* arm_ADCS X22 X22 X12 *)
  0x9b197e0c;       (* arm_MUL X12 X16 X25 *)
  0x9a0d02f7;       (* arm_ADC X23 X23 X13 *)
  0x9b197e2d;       (* arm_MUL X13 X17 X25 *)
  0xf100067f;       (* arm_CMP X19 (rvalue (word 1)) *)
  0x9bd97dca;       (* arm_UMULH X10 X14 X25 *)
  0xba0b0293;       (* arm_ADCS X19 X20 X11 *)
  0x9bd97deb;       (* arm_UMULH X11 X15 X25 *)
  0xba0c02b4;       (* arm_ADCS X20 X21 X12 *)
  0x9bd97e0c;       (* arm_UMULH X12 X16 X25 *)
  0xba0d02d5;       (* arm_ADCS X21 X22 X13 *)
  0x9bd97e2d;       (* arm_UMULH X13 X17 X25 *)
  0xba0002f6;       (* arm_ADCS X22 X23 X0 *)
  0x9a1f03e0;       (* arm_ADC X0 XZR XZR *)
  0xab0a0273;       (* arm_ADDS X19 X19 X10 *)
  0xba0b0294;       (* arm_ADCS X20 X20 X11 *)
  0xba0c02b5;       (* arm_ADCS X21 X21 X12 *)
  0xba0d02d6;       (* arm_ADCS X22 X22 X13 *)
  0xb5fffb1c;       (* arm_CBNZ X28 (word 2096992) *)
  0x9a1f0000;       (* arm_ADC X0 X0 XZR *)
  0xa9422f4a;       (* arm_LDP X10 X11 X26 (Immediate_Offset (iword (&32))) *)
  0xa943374c;       (* arm_LDP X12 X13 X26 (Immediate_Offset (iword (&48))) *)
  0xa9401c26;       (* arm_LDP X6 X7 X1 (Immediate_Offset (iword (&0))) *)
  0xa9412428;       (* arm_LDP X8 X9 X1 (Immediate_Offset (iword (&16))) *)
  0x91008021;       (* arm_ADD X1 X1 (rvalue (word 32)) *)
  0xab0a0273;       (* arm_ADDS X19 X19 X10 *)
  0xba0b0294;       (* arm_ADCS X20 X20 X11 *)
  0xba0c02b5;       (* arm_ADCS X21 X21 X12 *)
  0xba0d02d6;       (* arm_ADCS X22 X22 X13 *)
  0xf94003f9;       (* arm_LDR X25 SP (Immediate_Offset (word 0)) *)
  0xa9403c6e;       (* arm_LDP X14 X15 X3 (Immediate_Offset (iword (&0))) *)
  0xa9414470;       (* arm_LDP X16 X17 X3 (Immediate_Offset (iword (&16))) *)
  0x91008063;       (* arm_ADD X3 X3 (rvalue (word 32)) *)
  0xd503201f;       (* arm_NOP *)
  0x9b187cca;       (* arm_MUL X10 X6 X24 *)
  0x9a1f0000;       (* arm_ADC X0 X0 XZR *)
  0x9b187ceb;       (* arm_MUL X11 X7 X24 *)
  0x9100239c;       (* arm_ADD X28 X28 (rvalue (word 8)) *)
  0x9b187d0c;       (* arm_MUL X12 X8 X24 *)
  0x9240139c;       (* arm_AND X28 X28 (rvalue (word 31)) *)
  0x9b187d2d;       (* arm_MUL X13 X9 X24 *)
  0xab0a0273;       (* arm_ADDS X19 X19 X10 *)
  0x9bd87cca;       (* arm_UMULH X10 X6 X24 *)
  0xba0b0294;       (* arm_ADCS X20 X20 X11 *)
  0x9bd87ceb;       (* arm_UMULH X11 X7 X24 *)
  0xba0c02b5;       (* arm_ADCS X21 X21 X12 *)
  0x9bd87d0c;       (* arm_UMULH X12 X8 X24 *)
  0xba0d02d6;       (* arm_ADCS X22 X22 X13 *)
  0x9bd87d2d;       (* arm_UMULH X13 X9 X24 *)
  0x9a1f03f7;       (* arm_ADC X23 XZR XZR *)
  0xf87c6858;       (* arm_LDR X24 X2 (Register_Offset X28) *)
  0xab0a0294;       (* arm_ADDS X20 X20 X10 *)
  0x9b197dca;       (* arm_MUL X10 X14 X25 *)
  0xba0b02b5;       (* arm_ADCS X21 X21 X11 *)
  0x9b197deb;       (* arm_MUL X11 X15 X25 *)
  0xba0c02d6;       (* arm_ADCS X22 X22 X12 *)
  0x9b197e0c;       (* arm_MUL X12 X16 X25 *)
  0x9a0d02f7;       (* arm_ADC X23 X23 X13 *)
  0x9b197e2d;       (* arm_MUL X13 X17 X25 *)
  0xab0a0273;       (* arm_ADDS X19 X19 X10 *)
  0x9bd97dca;       (* arm_UMULH X10 X14 X25 *)
  0xba0b0294;       (* arm_ADCS X20 X20 X11 *)
  0x9bd97deb;       (* arm_UMULH X11 X15 X25 *)
  0xba0c02b5;       (* arm_ADCS X21 X21 X12 *)
  0x9bd97e0c;       (* arm_UMULH X12 X16 X25 *)
  0xba0d02d6;       (* arm_ADCS X22 X22 X13 *)
  0x9bd97e2d;       (* arm_UMULH X13 X17 X25 *)
  0xba0002f7;       (* arm_ADCS X23 X23 X0 *)
  0xf87c6bf9;       (* arm_LDR X25 SP (Register_Offset X28) *)
  0x9a1f03e0;       (* arm_ADC X0 XZR XZR *)
  0xf8008753;       (* arm_STR X19 X26 (Postimmediate_Offset (word 8)) *)
  0xab0a0293;       (* arm_ADDS X19 X20 X10 *)
  0xcb01036a;       (* arm_SUB X10 X27 X1 *)
  0xba0b02b4;       (* arm_ADCS X20 X21 X11 *)
  0xba0c02d5;       (* arm_ADCS X21 X22 X12 *)
  0xba0d02f6;       (* arm_ADCS X22 X23 X13 *)
  0xb5fffadc;       (* arm_CBNZ X28 (word 2096984) *)
  0xcb05006b;       (* arm_SUB X11 X3 X5 *)
  0x9a1f0000;       (* arm_ADC X0 X0 XZR *)
  0xb40001ea;       (* arm_CBZ X10 (word 60) *)
  0xa9422f4a;       (* arm_LDP X10 X11 X26 (Immediate_Offset (iword (&32))) *)
  0xa943374c;       (* arm_LDP X12 X13 X26 (Immediate_Offset (iword (&48))) *)
  0xa9401c26;       (* arm_LDP X6 X7 X1 (Immediate_Offset (iword (&0))) *)
  0xa9412428;       (* arm_LDP X8 X9 X1 (Immediate_Offset (iword (&16))) *)
  0x91008021;       (* arm_ADD X1 X1 (rvalue (word 32)) *)
  0xab0a0273;       (* arm_ADDS X19 X19 X10 *)
  0xba0b0294;       (* arm_ADCS X20 X20 X11 *)
  0xba0c02b5;       (* arm_ADCS X21 X21 X12 *)
  0xba0d02d6;       (* arm_ADCS X22 X22 X13 *)
  0xa9403c6e;       (* arm_LDP X14 X15 X3 (Immediate_Offset (iword (&0))) *)
  0xa9414470;       (* arm_LDP X16 X17 X3 (Immediate_Offset (iword (&16))) *)
  0x91008063;       (* arm_ADD X3 X3 (rvalue (word 32)) *)
  0x17ffffc6;       (* arm_B (word 268435224) *)
  0xd503201f;       (* arm_NOP *)
  0xa94637ac;       (* arm_LDP X12 X13 X29 (Immediate_Offset (iword (&96))) *)
  0xab1e0273;       (* arm_ADDS X19 X19 X30 *)
  0x91008042;       (* arm_ADD X2 X2 (rvalue (word 32)) *)
  0xba1f0294;       (* arm_ADCS X20 X20 XZR *)
  0xcb050021;       (* arm_SUB X1 X1 X5 *)
  0xba1f02b5;       (* arm_ADCS X21 X21 XZR *)
  0xa9005353;       (* arm_STP X19 X20 X26 (Immediate_Offset (iword (&0))) *)
  0xba1f02d6;       (* arm_ADCS X22 X22 XZR *)
  0xa94253f3;       (* arm_LDP X19 X20 SP (Immediate_Offset (iword (&32))) *)
  0x9a1f001e;       (* arm_ADC X30 X0 XZR *)
  0xa9015b55;       (* arm_STP X21 X22 X26 (Immediate_Offset (iword (&16))) *)
  0xeb0d005f;       (* arm_CMP X2 X13 *)
  0xa9435bf5;       (* arm_LDP X21 X22 SP (Immediate_Offset (iword (&48))) *)
  0xa9403d6e;       (* arm_LDP X14 X15 X11 (Immediate_Offset (iword (&0))) *)
  0xa9414570;       (* arm_LDP X16 X17 X11 (Immediate_Offset (iword (&16))) *)
  0x91008163;       (* arm_ADD X3 X11 (rvalue (word 32)) *)
  0x54000100;       (* arm_BEQ (word 32) *)
  0xf9400058;       (* arm_LDR X24 X2 (Immediate_Offset (word 0)) *)
  0xa9401c26;       (* arm_LDP X6 X7 X1 (Immediate_Offset (iword (&0))) *)
  0xa9412428;       (* arm_LDP X8 X9 X1 (Immediate_Offset (iword (&16))) *)
  0xb1008021;       (* arm_ADDS X1 X1 (rvalue (word 32)) *)
  0xaa1f03e0;       (* arm_MOV X0 XZR *)
  0x910003fa;       (* arm_ADD X26 SP (rvalue (word 0)) *)
  0x17ffff75;       (* arm_B (word 268434900) *)
  0xaa0c03e0;       (* arm_MOV X0 X12 *)
  0xaa0c03fb;       (* arm_MOV X27 X12 *)
  0xeb0e026a;       (* arm_SUBS X10 X19 X14 *)
  0x910103fa;       (* arm_ADD X26 SP (rvalue (word 64)) *)
  0xfa0f028b;       (* arm_SBCS X11 X20 X15 *)
  0xd10080bc;       (* arm_SUB X28 X5 (rvalue (word 32)) *)
  0xfa1002ac;       (* arm_SBCS X12 X21 X16 *)
  0xa9403c6e;       (* arm_LDP X14 X15 X3 (Immediate_Offset (iword (&0))) *)
  0xd100839c;       (* arm_SUB X28 X28 (rvalue (word 32)) *)
  0xa9405353;       (* arm_LDP X19 X20 X26 (Immediate_Offset (iword (&0))) *)
  0xfa1102cd;       (* arm_SBCS X13 X22 X17 *)
  0xa9414470;       (* arm_LDP X16 X17 X3 (Immediate_Offset (iword (&16))) *)
  0x91008063;       (* arm_ADD X3 X3 (rvalue (word 32)) *)
  0xa9415b55;       (* arm_LDP X21 X22 X26 (Immediate_Offset (iword (&16))) *)
  0x9100835a;       (* arm_ADD X26 X26 (rvalue (word 32)) *)
  0xa9002c0a;       (* arm_STP X10 X11 X0 (Immediate_Offset (iword (&0))) *)
  0xfa0e026a;       (* arm_SBCS X10 X19 X14 *)
  0xa901340c;       (* arm_STP X12 X13 X0 (Immediate_Offset (iword (&16))) *)
  0x91008000;       (* arm_ADD X0 X0 (rvalue (word 32)) *)
  0xfa0f028b;       (* arm_SBCS X11 X20 X15 *)
  0xb5fffe5c;       (* arm_CBNZ X28 (word 2097096) *)
  0xfa1002ac;       (* arm_SBCS X12 X21 X16 *)
  0x910003fa;       (* arm_ADD X26 SP (rvalue (word 0)) *)
  0x910083e1;       (* arm_ADD X1 SP (rvalue (word 32)) *)
  0xa9401f66;       (* arm_LDP X6 X7 X27 (Immediate_Offset (iword (&0))) *)
  0xfa1102cd;       (* arm_SBCS X13 X22 X17 *)
  0xa9002c0a;       (* arm_STP X10 X11 X0 (Immediate_Offset (iword (&0))) *)
  0xa9412768;       (* arm_LDP X8 X9 X27 (Immediate_Offset (iword (&16))) *)
  0xa901340c;       (* arm_STP X12 X13 X0 (Immediate_Offset (iword (&16))) *)
  0xa9405033;       (* arm_LDP X19 X20 X1 (Immediate_Offset (iword (&0))) *)
  0xa9415835;       (* arm_LDP X21 X22 X1 (Immediate_Offset (iword (&16))) *)
  0xfa1f03df;       (* arm_SBCS XZR X30 XZR *)
  0xf94007be;       (* arm_LDR X30 X29 (Immediate_Offset (word 8)) *)
  0xd10080bc;       (* arm_SUB X28 X5 (rvalue (word 32)) *)
  0xd100839c;       (* arm_SUB X28 X28 (rvalue (word 32)) *)
  0x9a86326a;       (* arm_CSEL X10 X19 X6 Condition_CC *)
  0xa9007f5f;       (* arm_STP XZR XZR X26 (Immediate_Offset (iword (&0))) *)
  0x9a87328b;       (* arm_CSEL X11 X20 X7 Condition_CC *)
  0xa9421f66;       (* arm_LDP X6 X7 X27 (Immediate_Offset (iword (&32))) *)
  0xa9425033;       (* arm_LDP X19 X20 X1 (Immediate_Offset (iword (&32))) *)
  0x9a8832ac;       (* arm_CSEL X12 X21 X8 Condition_CC *)
  0xa9017f5f;       (* arm_STP XZR XZR X26 (Immediate_Offset (iword (&16))) *)
  0x9100835a;       (* arm_ADD X26 X26 (rvalue (word 32)) *)
  0x9a8932cd;       (* arm_CSEL X13 X22 X9 Condition_CC *)
  0xa9432768;       (* arm_LDP X8 X9 X27 (Immediate_Offset (iword (&48))) *)
  0xa9435835;       (* arm_LDP X21 X22 X1 (Immediate_Offset (iword (&48))) *)
  0x91008021;       (* arm_ADD X1 X1 (rvalue (word 32)) *)
  0xa9002f6a;       (* arm_STP X10 X11 X27 (Immediate_Offset (iword (&0))) *)
  0xa901376c;       (* arm_STP X12 X13 X27 (Immediate_Offset (iword (&16))) *)
  0x9100837b;       (* arm_ADD X27 X27 (rvalue (word 32)) *)
  0xb5fffe1c;       (* arm_CBNZ X28 (word 2097088) *)
  0x9a86326a;       (* arm_CSEL X10 X19 X6 Condition_CC *)
  0xa9007f5f;       (* arm_STP XZR XZR X26 (Immediate_Offset (iword (&0))) *)
  0x9a87328b;       (* arm_CSEL X11 X20 X7 Condition_CC *)
  0xa9017f5f;       (* arm_STP XZR XZR X26 (Immediate_Offset (iword (&16))) *)
  0x9a8832ac;       (* arm_CSEL X12 X21 X8 Condition_CC *)
  0xa901ff5f;       (* arm_STP XZR XZR X26 (Immediate_Offset (iword (&24))) *)
  0x9a8932cd;       (* arm_CSEL X13 X22 X9 Condition_CC *)
  0xa9027f5f;       (* arm_STP XZR XZR X26 (Immediate_Offset (iword (&32))) *)
  0xa9002f6a;       (* arm_STP X10 X11 X27 (Immediate_Offset (iword (&0))) *)
  0xa901376c;       (* arm_STP X12 X13 X27 (Immediate_Offset (iword (&16))) *)
  0x14000015;       (* arm_B (word 84) *)
  0xd503201f;       (* arm_NOP *)
  0xd503201f;       (* arm_NOP *)
  0x9a1f0000;       (* arm_ADC X0 X0 XZR *)
  0xf94033a1;       (* arm_LDR X1 X29 (Immediate_Offset (word 96)) *)
  0xeb0e0266;       (* arm_SUBS X6 X19 X14 *)
  0xf94007be;       (* arm_LDR X30 X29 (Immediate_Offset (word 8)) *)
  0xfa0f0287;       (* arm_SBCS X7 X20 X15 *)
  0xa9007fff;       (* arm_STP XZR XZR SP (Immediate_Offset (iword (&0))) *)
  0xfa1002a8;       (* arm_SBCS X8 X21 X16 *)
  0xa9017fff;       (* arm_STP XZR XZR SP (Immediate_Offset (iword (&16))) *)
  0xfa1102c9;       (* arm_SBCS X9 X22 X17 *)
  0xa9027fff;       (* arm_STP XZR XZR SP (Immediate_Offset (iword (&32))) *)
  0xfa1f001f;       (* arm_SBCS XZR X0 XZR *)
  0xa9037fff;       (* arm_STP XZR XZR SP (Immediate_Offset (iword (&48))) *)
  0x9a863266;       (* arm_CSEL X6 X19 X6 Condition_CC *)
  0x9a873287;       (* arm_CSEL X7 X20 X7 Condition_CC *)
  0x9a8832a8;       (* arm_CSEL X8 X21 X8 Condition_CC *)
  0x9a8932c9;       (* arm_CSEL X9 X22 X9 Condition_CC *)
  0xa9001c26;       (* arm_STP X6 X7 X1 (Immediate_Offset (iword (&0))) *)
  0xa9012428;       (* arm_STP X8 X9 X1 (Immediate_Offset (iword (&16))) *)
  0xa94153b3;       (* arm_LDP X19 X20 X29 (Immediate_Offset (iword (&16))) *)
  0x910003bf;       (* arm_ADD SP X29 (rvalue (word 0)) *)
  0xa9425bb5;       (* arm_LDP X21 X22 X29 (Immediate_Offset (iword (&32))) *)
  0xd2800020;       (* arm_MOV X0 (rvalue (word 1)) *)
  0xa94363b7;       (* arm_LDP X23 X24 X29 (Immediate_Offset (iword (&48))) *)
  0xa9446bb9;       (* arm_LDP X25 X26 X29 (Immediate_Offset (iword (&64))) *)
  0xa94573bb;       (* arm_LDP X27 X28 X29 (Immediate_Offset (iword (&80))) *)
  0xf84807fd;       (* arm_LDR X29 SP (Postimmediate_Offset (word 128)) *)
  0xd65f03c0        (* arm_RET X30 *)
];;

let BN_MUL_MONT_EXEC = ARM_MK_EXEC_RULE bn_mul_mont_mc;;

let LENGTH_BN = REWRITE_CONV[bn_mul_mont_mc] `LENGTH bn_mul_mont_mc` |> CONV_RULE(RAND_CONV LENGTH_CONV);;

let BN_DIGIT_READ = prove
 (`!base k s v i. bignum_from_memory(base,k) s = v /\ i < k
    ==> read (memory :> bytes64(word_add base (word(8*i)))) s = word(bigdigit v i)`,
  REPEAT STRIP_TAC THEN FIRST_X_ASSUM(SUBST1_TAC o SYM) THEN
  ASM_REWRITE_TAC[BIGDIGIT_BIGNUM_FROM_MEMORY; WORD_VAL]);;

let ALIGN16_AND = prove
 (`!tp:int64 d. aligned 16 tp /\ d < 16
   ==> word_and (word_add tp (word d)) (word 18446744073709551600) = tp`,
  REWRITE_TAC[aligned] THEN REPEAT STRIP_TAC THEN
  REWRITE_TAC[WORD_BLAST `word_and (x:int64) (word 18446744073709551600) =
                          word_sub x (word_and x (word 15))`] THEN
  SUBGOAL_THEN `word_and (word_add tp (word d)) (word 15):int64 = word d`
   SUBST1_TAC THENL [ALL_TAC; CONV_TAC WORD_RULE] THEN
  REWRITE_TAC[GSYM VAL_EQ] THEN
  SUBGOAL_THEN `word 15:int64 = word(2 EXP 4 - 1)` SUBST1_TAC THENL
   [CONV_TAC NUM_REDUCE_CONV; ALL_TAC] THEN
  REWRITE_TAC[VAL_WORD_AND_MASK_WORD] THEN
  REWRITE_TAC[VAL_WORD_ADD; VAL_WORD; DIMINDEX_64] THEN
  ASM_SIMP_TAC[MOD_LT; ARITH_RULE `d < 16 ==> d < 2 EXP 64`] THEN
  REWRITE_TAC[ARITH_RULE `2 EXP 64 = 2 EXP 4 * 2 EXP 60`; MOD_MULT_MOD] THEN
  FIRST_X_ASSUM(CHOOSE_THEN SUBST1_TAC o REWRITE_RULE[divides]) THEN
  CONV_TAC NUM_REDUCE_CONV THEN
  ONCE_REWRITE_TAC[MULT_SYM] THEN ASM_SIMP_TAC[MOD_MULT_ADD; MOD_LT]);;

let NUM_ARITH_ASM_TAC : tactic =
  fun (asl,w) ->
    let ok th =
      let c = concl th in
      let rec good t =
        if is_conj t then good(lhand t) && good(rand t) else
        (is_eq t && type_of(lhs t) = `:num`) ||
        (is_comb t && is_comb(rator t) &&
         (let f = rator(rator t) in
          f = `(<):num->num->bool` || f = `(<=):num->num->bool`)) ||
        (is_neg t && good(rand t)) in
      good c in
    let ths = filter ok (map snd asl) in
    (MAP_EVERY MP_TAC ths THEN ARITH_TAC) (asl,w);;

let BN_DIGIT_READ_BYTES = prove
 (`!base k s v i. read (memory :> bytes(base,8 * k)) s = v /\ i < k
    ==> read (memory :> bytes64(word_add base (word(8*i)))) s = word(bigdigit v i)`,
  REWRITE_TAC[GSYM BIGNUM_FROM_MEMORY_BYTES] THEN MESON_TAC[BN_DIGIT_READ]);;

(* From read(memory :> bytes(base,8 * k)) s = v (or the bignum_from_memory
   form), adds read(memory :> bytes64(base + 8*i)) s = word(bigdigit v i). *)

let READ_DIGIT_TAC (base:term) (i:term) : tactic =
  fun (asl,w) ->
    let pat1 = vsubst [base,`base:int64`] `read (memory :> bytes(base,8 * kk)) ss`
    and pat2 = vsubst [base,`base:int64`] `bignum_from_memory(base,kk) ss` in
    let lcs = frees base in
    let th = snd(find (fun (_,th) ->
      let c = concl th in is_eq c &&
      (can (term_match lcs pat1) (lhs c) || can (term_match lcs pat2) (lhs c)))
      asl) in
    let th = if can (term_match lcs pat2) (lhs(concl th)) then th
             else REWRITE_RULE[GSYM BIGNUM_FROM_MEMORY_BYTES] th in
    let l = lhs(concl th) in
    let kt = rand(rand(rator l)) and st = rand l and v = rhs(concl th) in
    let tm = vsubst [base,`base:int64`; st,`s:armstate`; v,`v:num`; i,`i:num`]
      `read (memory :> bytes64(word_add base (word(8*i)))) s = word(bigdigit v i)` in
    (SUBGOAL_THEN tm MP_TAC THENL
      [MATCH_MP_TAC BN_DIGIT_READ THEN EXISTS_TAC kt THEN
       CONJ_TAC THENL [ACCEPT_TAC th; NUM_ARITH_ASM_TAC];
       CONV_TAC(ONCE_DEPTH_CONV NUM_REDUCE_CONV) THEN
       REWRITE_TAC[WORD_ADD_0] THEN DISCH_TAC]) (asl,w);;

let MONT_Q_CONG = prove
 (`!n w:int64 t:int64.
     (n * val w + 1 == 0) (mod (2 EXP 64))
     ==> (bigdigit n 0 * val(word(val t * val w):int64) + val t == 0)
         (mod (2 EXP 64))`,
  REPEAT STRIP_TAC THEN
  REWRITE_TAC[bigdigit; MULT_CLAUSES; EXP; DIV_1; VAL_WORD; DIMINDEX_64] THEN
  REWRITE_TAC[CONG] THEN CONV_TAC MOD_DOWN_CONV THEN REWRITE_TAC[GSYM CONG] THEN
  UNDISCH_TAC `(n * val(w:int64) + 1 == 0) (mod (2 EXP 64))` THEN
  SPEC_TAC(`2 EXP 64`,`e:num`) THEN CONV_TAC NUMBER_RULE);;

let LOWWORD_CARRY = prove
 (`!n0 q t:int64 lo:int64.
     (n0 * q + val t == 0) (mod (2 EXP 64)) /\ word(n0 * q) = lo
     ==> val lo + val t = 2 EXP 64 * bitval(1 <= val t)`,
  REPEAT GEN_TAC THEN DISCH_THEN(CONJUNCTS_THEN2 MP_TAC (SUBST1_TAC o SYM)) THEN
  REWRITE_TAC[VAL_WORD; DIMINDEX_64; CONG; MOD_0] THEN
  ONCE_REWRITE_TAC[GSYM MOD_ADD_MOD] THEN REWRITE_TAC[MOD_MOD_REFL] THEN
  SIMP_TAC[MOD_LT; VAL_BOUND_64] THEN
  MP_TAC(ISPEC `t:int64` VAL_BOUND_64) THEN
  MP_TAC(SPECL [`n0 * q:num`; `2 EXP 64`] MOD_LT_EQ) THEN
  ABBREV_TAC `l = (n0 * q) MOD 2 EXP 64` THEN ABBREV_TAC `u = val(t:int64)` THEN
  REWRITE_TAC[EXP_EQ_0; ARITH_EQ] THEN REPEAT STRIP_TAC THEN
  MP_TAC(SPECL [`l + u:num`; `2 EXP 64`] DIVISION) THEN
  ASM_REWRITE_TAC[EXP_EQ_0; ARITH_EQ; ADD_CLAUSES] THEN
  SUBGOAL_THEN `(l + u) DIV 2 EXP 64 < 2` MP_TAC THENL
   [REWRITE_TAC[RDIV_LT_EQ; EXP_EQ_0; ARITH_EQ] THEN ASM_ARITH_TAC;
    SPEC_TAC(`(l + u) DIV 2 EXP 64`,`c:num`)] THEN
  REWRITE_TAC[ARITH_RULE `c < 2 <=> c = 0 \/ c = 1`] THEN
  REWRITE_TAC[bitval] THEN COND_CASES_TAC THEN
  REPEAT STRIP_TAC THEN ASM_ARITH_TAC);;

let WORD_SHL3 = prove
 (`!k. word_shl (word k:int64) 3 = word(8 * k)`,
  REWRITE_TAC[GSYM VAL_EQ; VAL_WORD_SHL; VAL_WORD; DIMINDEX_64] THEN
  CONV_TAC MOD_DOWN_CONV THEN REWRITE_TAC[MULT_SYM] THEN CONV_TAC NUM_REDUCE_CONV);;

let CMP_ONE_CARRY = prove
 (`!c s:int64 x:int64.
     --(&2 pow 64) * &(bitval c) + &(val s):real = &(val x) - &1
     ==> (c <=> val x = 0)`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[REAL_ARITH `--(e:real) * c + s = x - &1 <=> x + e * c = s + &1`] THEN
  REWRITE_TAC[REAL_OF_NUM_POW; REAL_OF_NUM_MUL; REAL_OF_NUM_ADD; REAL_OF_NUM_EQ] THEN
  MP_TAC(ISPEC `s:int64` VAL_BOUND_64) THEN
  BOOL_CASES_TAC `c:bool` THEN REWRITE_TAC[BITVAL_CLAUSES] THEN ARITH_TAC);;

let VAL_WORD_BIGDIGIT = prove
 (`!n i. val(word(bigdigit n i):int64) = bigdigit n i`,
  SIMP_TAC[VAL_WORD_EQ; DIMINDEX_64; BIGDIGIT_BOUND]);;

let MONT_LOWWORD = prove
 (`!n w:int64 t:int64 q:int64 lo:int64.
     (n * val w + 1 == 0) (mod (2 EXP 64)) /\
     word(val t * val w) = q /\ word(bigdigit n 0 * val q) = lo
     ==> val lo + val t = 2 EXP 64 * bitval(1 <= val t)`,
  REPEAT STRIP_TAC THEN MATCH_MP_TAC LOWWORD_CARRY THEN
  EXISTS_TAC `bigdigit n 0` THEN EXISTS_TAC `val(q:int64)` THEN
  ASM_REWRITE_TAC[] THEN
  UNDISCH_THEN `word(val(t:int64) * val(w:int64)):int64 = q` (SUBST1_TAC o SYM) THEN
  ASM_SIMP_TAC[MONT_Q_CONG]);;

let LOWWORD_TAC t q lo : tactic =
  MP_TAC(SPECL [`n:num`; `w:int64`; t; q; lo] MONT_LOWWORD) THEN
  ANTS_TAC THENL
   [RULE_ASSUM_TAC(REWRITE_RULE[VAL_WORD_BIGDIGIT]) THEN ASM_REWRITE_TAC[];
    DISCH_TAC];;

let REAL_VAL_BOUND = prove
 (`!x:int64. &0 <= &(val x):real /\ &(val x):real <= &18446744073709551615`,
  GEN_TAC THEN REWRITE_TAC[REAL_POS; REAL_OF_NUM_LE] THEN
  MP_TAC(ISPEC `x:int64` VAL_BOUND_64) THEN ARITH_TAC);;

let REAL_BITVAL_BOUND = prove
 (`!c. &0 <= &(bitval c):real /\ &(bitval c):real <= &1`,
  GEN_TAC THEN BOOL_CASES_TAC `c:bool` THEN REWRITE_TAC[BITVAL_CLAUSES] THEN
  REAL_ARITH_TAC);;

let real_atoms_of tm =
  let vs = find_terms (fun t -> match t with
     Comb(Const("real_of_num",_),Comb(Const("val",_),x)) -> type_of x = `:int64`
   | _ -> false) tm
  and bs = find_terms (fun t -> match t with
     Comb(Const("real_of_num",_),Comb(Const("bitval",_),_)) -> true
   | _ -> false) tm in
  setify vs, setify bs;;

(* Linear arithmetic over the real equations and inequalities in the
   assumptions, with word and bit bounds for every atom. *)

let PROD_BOUND = prove
 (`!h:int64 l:int64 x y.
     2 EXP 64 * val h + val l = x * y /\ x < 2 EXP 64 /\ y < 2 EXP 64
     ==> &2 pow 64 * &(val h) + &(val l):real <=
         &340282366920938463426481119284349108225`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[REAL_OF_NUM_CLAUSES] THEN
  ASM_REWRITE_TAC[] THEN
  TRANS_TAC LE_TRANS `(2 EXP 64 - 1) * (2 EXP 64 - 1)` THEN CONJ_TAC THENL
   [MATCH_MP_TAC LE_MULT2 THEN ASM_ARITH_TAC; CONV_TAC NUM_REDUCE_CONV]);;

(* Adds the real bound of every assumption 2^64 * hi + lo = x * y. *)

let BOUND_LT_TAC : tactic =
  REWRITE_TAC[BIGDIGIT_BOUND; VAL_BOUND_64];;

let PROD_BOUND_RULE th =
  let th1 = MATCH_MP (REWRITE_RULE[IMP_CONJ] PROD_BOUND) th in
  let a1 = fst(dest_imp(concl th1)) in
  let th2 = MP th1 (prove(a1,BOUND_LT_TAC)) in
  let a2 = fst(dest_imp(concl th2)) in
  MP th2 (prove(a2,BOUND_LT_TAC));;

let ADDS_WORD = prove
 (`!c s:int64 x:int64 y.
     &2 pow 64 * &(bitval c) + &(val s):real = &(val x) + &y ==> s = word_add x (word y)`,
  REPEAT GEN_TAC THEN REWRITE_TAC[REAL_OF_NUM_CLAUSES] THEN DISCH_TAC THEN
  REWRITE_TAC[GSYM VAL_EQ; VAL_WORD_ADD; VAL_WORD; DIMINDEX_64] THEN
  CONV_TAC MOD_DOWN_CONV THEN FIRST_X_ASSUM(SUBST1_TAC o SYM) THEN
  ONCE_REWRITE_TAC[ADD_SYM] THEN REWRITE_TAC[MOD_MULT_ADD] THEN
  SIMP_TAC[MOD_LT; VAL_BOUND_64]);;

let REAL_PROD_BOUND = prove
 (`!h:int64 l:int64 x:int64 y:int64.
     &2 pow 64 * &(val h) + &(val l):real = &(val x) * &(val y)
     ==> &2 pow 64 * &(val h) + &(val l):real <=
         &340282366920938463426481119284349108225`,
  REPEAT GEN_TAC THEN DISCH_THEN SUBST1_TAC THEN
  REWRITE_TAC[REAL_OF_NUM_CLAUSES] THEN
  TRANS_TAC LE_TRANS `(2 EXP 64 - 1) * (2 EXP 64 - 1)` THEN CONJ_TAC THENL
   [MATCH_MP_TAC LE_MULT2 THEN REWRITE_TAC[ARITH_RULE `x <= 2 EXP 64 - 1 <=> x < 2 EXP 64`] THEN
    REWRITE_TAC[VAL_BOUND_64]; CONV_TAC NUM_REDUCE_CONV]);;

let ADD_PROD_BOUNDS_TAC : tactic =
  ASSUM_LIST(fun ths ->
    MAP_EVERY (fun th ->
      try ASSUME_TAC(PROD_BOUND_RULE th) with Failure _ ->
      try ASSUME_TAC(MATCH_MP REAL_PROD_BOUND th) with Failure _ -> ALL_TAC) ths);;

let REAL_LINEAR_SPLIT_TAC (cs:term list) : tactic =
  fun (asl,w) ->
    let isreal t =
      (is_eq t && type_of(lhs t) = `:real`) ||
      (is_comb t && is_comb(rator t) &&
       (let f = rator(rator t) in
        f = `(<=):real->real->bool` || f = `(<):real->real->bool`)) in
    let ths = filter (isreal o concl) (map snd asl) in
    let tm = list_mk_conj(w :: map concl ths) in
    let vs,_ = real_atoms_of tm in
    let vths = map (fun t -> SPEC (rand(rand t)) REAL_VAL_BOUND) vs in
    (MAP_EVERY MP_TAC (ths @ vths) THEN
     MAP_EVERY BOOL_CASES_TAC cs THEN REWRITE_TAC[BITVAL_CLAUSES] THEN
     CONV_TAC REAL_ARITH) (asl,w);;

let CARRY_ZERO_TAC (c:term) (cs:term list) : tactic =
  SUBGOAL_THEN (mk_neg c) ASSUME_TAC THENL
   [DISCH_TAC THEN RULE_ASSUM_TAC(REWRITE_RULE[ASSUME c; BITVAL_CLAUSES]) THEN
    REWRITE_TAC[] THEN REAL_LINEAR_SPLIT_TAC cs;
    RULE_ASSUM_TAC(REWRITE_RULE[ASSUME (mk_neg c); BITVAL_CLAUSES])];;

let LOWDIGITS_TOP = prove
 (`!x p. x < 2 EXP (64 * (p + 1)) ==> x = 2 EXP (64 * p) * bigdigit x p + lowdigits x p`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[GSYM LOWDIGITS_CLAUSES] THEN
  ASM_SIMP_TAC[LOWDIGITS_SELF]);;

let BYTES_STEP = prove
 (`!tp p s. read (memory :> bytes(tp,8 * (p + 1))) s =
            read (memory :> bytes(tp,8 * p)) s +
            2 EXP (64 * p) * val(read (memory :> bytes64(word_add tp (word(8 * p)))) s)`,
  REWRITE_TAC[GSYM BIGNUM_FROM_MEMORY_BYTES; BIGNUM_FROM_MEMORY_STEP]);;

let gen_h1_inv = new_definition `gen_h1_inv (k:num) (z:int64) (x:int64) (y:int64)
    (m:int64) (w:int64) (a:num) (b:num) (n:num) (tp:int64) (q0:int64) (j:num) s <=>
   read X0 s = z /\ read X2 s = word_add y (word 8) /\ read X4 s = w /\
   read X5 s = word(8 * k) /\ read SP s = tp /\
   read X1 s = word_add x (word(8 * j)) /\ read X3 s = word_add m (word(8 * j)) /\
   read X9 s = word(bigdigit b 0) /\ read X15 s = q0 /\
   read X21 s = word(8 * (k - j)) /\ read X22 s = word_add tp (word(8 * (j - 2))) /\
   bignum_from_memory(x,k) s = a /\ bignum_from_memory(y,k) s = b /\
   bignum_from_memory(m,k) s = n /\
   2 EXP 64 * val(read X11 s) + val(read X10 s) = bigdigit a (j - 1) * bigdigit b 0 /\
   2 EXP 64 * val(read X17 s) + val(read X16 s) = bigdigit n (j - 1) * val q0 /\
   2 EXP 64 * bignum_from_memory(tp,j - 2) s +
   2 EXP (64 * (j - 1)) * (val(read X7 s) + val(read X13 s)) =
   lowdigits a (j - 1) * bigdigit b 0 + lowdigits n (j - 1) * val q0`;;

let VAL_8K_EQ0 = prove
 (`!k j. k < 2 EXP 58 ==> (val(word(8 * (k - j)):int64) = 0 <=> k <= j)`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[VAL_WORD; DIMINDEX_64] THEN
  SUBGOAL_THEN `8 * (k - j) < 2 EXP 64` (fun th -> SIMP_TAC[th; MOD_LT]) THEN
  ASM_ARITH_TAC);;

let GEN_H1_BODY = prove
 (`!k z x y m a b n w tp q0 j pc.
   2 <= j /\ j < k /\ k < 2 EXP 58 /\
   ALL (nonoverlapping (tp,8 * k))
       [(word pc,LENGTH bn_mul_mont_mc); (x,8 * k); (y,8 * k); (m,8 * k)]
   ==> ensures arm
     (\s. aligned_bytes_loaded s (word pc) bn_mul_mont_mc /\
          read PC s = word(pc + 0x74) /\ gen_h1_inv k z x y m w a b n tp q0 j s)
     (\s. aligned_bytes_loaded s (word pc) bn_mul_mont_mc /\
          read PC s = word(pc + 0xac) /\ gen_h1_inv k z x y m w a b n tp q0 (j + 1) s)
     (MAYCHANGE [PC; X0; X1; X2; X3; X4; X5; X6; X7; X8; X9; X10; X11;
                 X12; X13; X14; X15; X16; X17; X19; X20; X21; X22; X23; SP] ,,
      MAYCHANGE SOME_FLAGS ,, MAYCHANGE [events] ,,
      MAYCHANGE [memory :> bytes(z,8 * k); memory :> bytes(tp,8 * k)])`,
  REPEAT GEN_TAC THEN REWRITE_TAC[ALL; NONOVERLAPPING_CLAUSES; LENGTH_BN; SOME_FLAGS] THEN STRIP_TAC THEN
  REWRITE_TAC[gen_h1_inv] THEN
  SUBGOAL_THEN `?p. j = p + 2` (CHOOSE_THEN SUBST_ALL_TAC) THENL
   [EXISTS_TAC `j - 2` THEN ASM_ARITH_TAC; ALL_TAC] THEN
  REWRITE_TAC[ARITH_RULE `(p + 2) - 2 = p /\ (p + 2) - 1 = p + 1 /\ ((p + 2) + 1) - 2 = p + 1 /\ ((p + 2) + 1) - 1 = p + 2`] THEN
  GHOST_INTRO_TAC `h7:int64` `read X7` THEN GHOST_INTRO_TAC `h13:int64` `read X13` THEN
  GHOST_INTRO_TAC `h11:int64` `read X11` THEN GHOST_INTRO_TAC `l10:int64` `read X10` THEN
  GHOST_INTRO_TAC `h17:int64` `read X17` THEN GHOST_INTRO_TAC `l16:int64` `read X16` THEN
  GHOST_INTRO_TAC `nlo:num` `bignum_from_memory(tp,p)` THEN
  REWRITE_TAC[BIGNUM_FROM_MEMORY_BYTES] THEN ENSURES_INIT_TAC "s0" THEN
  READ_DIGIT_TAC `x:int64` `p + 2` THEN READ_DIGIT_TAC `m:int64` `p + 2` THEN
  ARM_ACCSTEPS_TAC BN_MUL_MONT_EXEC [2;4;6;7;8;10;11;12] (1--14) THEN
  ENSURES_FINAL_STATE_TAC THEN ASM_REWRITE_TAC[] THEN
  ADD_PROD_BOUNDS_TAC THEN
  CARRY_ZERO_TAC `carry_s4:bool` [] THEN
  CARRY_ZERO_TAC `carry_s8:bool` [] THEN
  CARRY_ZERO_TAC `carry_s12:bool` [`carry_s6:bool`; `carry_s10:bool`] THEN
  SUBGOAL_THEN `&(val(sum_s10:int64)) + &2 pow 64 * (&(val(sum_s4:int64)) + &(val(sum_s12:int64))):real =
   &(val(h7:int64)) + &(val(h13:int64)) + &(val(l10:int64)) + &(val(l16:int64)) +
   &2 pow 64 * (&(val(h11:int64)) + &(val(h17:int64)))` ASSUME_TAC THENL
  [REAL_LINEAR_SPLIT_TAC []; ALL_TAC] THEN
  RULE_ASSUM_TAC(REWRITE_RULE[VAL_WORD_BIGDIGIT]) THEN REPEAT CONJ_TAC THENL
   [CONV_TAC WORD_RULE;
    CONV_TAC WORD_RULE;
    ASM_SIMP_TAC[WORD_SUB2; ARITH_RULE `p + 2 < k ==> 8 <= 8 * (k - (p + 2))`] THEN
    AP_TERM_TAC THEN ASM_ARITH_TAC;
    CONV_TAC WORD_RULE;
    REWRITE_TAC[GSYM REAL_OF_NUM_CLAUSES] THEN REAL_LINEAR_SPLIT_TAC [];
    REWRITE_TAC[GSYM REAL_OF_NUM_CLAUSES] THEN REAL_LINEAR_SPLIT_TAC [];
    ALL_TAC] THEN
  REWRITE_TAC[GSYM BIGNUM_FROM_MEMORY_BYTES; BIGNUM_FROM_MEMORY_STEP] THEN
  REWRITE_TAC[BIGNUM_FROM_MEMORY_BYTES] THEN ASM_REWRITE_TAC[] THEN
  SUBGOAL_THEN `!x. lowdigits x (p + 2) = 2 EXP (64 * (p + 1)) * bigdigit x (p + 1) + lowdigits x (p + 1)`
    (fun th -> REWRITE_TAC[th]) THENL
   [REWRITE_TAC[ARITH_RULE `p + 2 = SUC(p + 1)`] THEN
    GEN_TAC THEN REWRITE_TAC[ADD1; LOWDIGITS_CLAUSES] THEN ARITH_TAC; ALL_TAC] THEN
  FIRST_X_ASSUM(MP_TAC o check (fun th -> is_eq(concl th) && type_of(lhs(concl th)) = `:real` &&
     free_in `sum_s10:int64` (concl th) && free_in `h7:int64` (concl th))) THEN
  FIRST_X_ASSUM(MP_TAC o check (fun th -> free_in `nlo:num` (concl th) && free_in `h7:int64` (concl th))) THEN
  FIRST_X_ASSUM(MP_TAC o check (fun th -> free_in `l16:int64` (concl th) && is_eq(concl th) && type_of(lhs(concl th)) = `:num`)) THEN
  FIRST_X_ASSUM(MP_TAC o check (fun th -> free_in `l10:int64` (concl th) && is_eq(concl th) && type_of(lhs(concl th)) = `:num`)) THEN
  REWRITE_TAC[ARITH_RULE `64 * (p + 2) = 64 * p + 128 /\ 64 * (p + 1) = 64 * p + 64`; EXP_ADD] THEN
  SPEC_TAC(`2 EXP (64 * p)`,`e:num`) THEN GEN_TAC THEN
  REWRITE_TAC[GSYM REAL_OF_NUM_CLAUSES] THEN CONV_TAC REAL_RING);;

let gen_out_inv = new_definition `gen_out_inv (k:num) (z:int64) (x:int64) (y:int64)
    (m:int64) (w:int64) (a:num) (b:num) (n:num) (tp:int64) (i:num) s <=>
   read X0 s = z /\ read X1 s = x /\ read X2 s = word_add y (word(8 * i)) /\
   read X3 s = m /\ read X4 s = w /\ read X5 s = word(8 * k) /\
   read SP s = tp /\ read X20 s = word(8 * (k - i)) /\
   bignum_from_memory(x,k) s = a /\ bignum_from_memory(y,k) s = b /\
   bignum_from_memory(m,k) s = n /\
   ?q. q < 2 EXP (64 * i) /\
       2 EXP (64 * i) * (2 EXP (64 * k) * val(read X19 s) + bignum_from_memory(tp,k) s) =
       lowdigits b i * a + q * n`;;

let GEN_SKIP1 = prove
 (`!k z x y m a b n w tp q0 pc.
   2 <= k /\ k < 2 EXP 58 /\ a < 2 EXP (64 * k) /\ n < 2 EXP (64 * k) /\
   ALL (nonoverlapping (tp,8 * k))
       [(word pc,LENGTH bn_mul_mont_mc); (x,8 * k); (y,8 * k); (m,8 * k)]
   ==> ensures arm
     (\s. aligned_bytes_loaded s (word pc) bn_mul_mont_mc /\
          read PC s = word(pc + 0xb0) /\ gen_h1_inv k z x y m w a b n tp q0 k s)
     (\s. aligned_bytes_loaded s (word pc) bn_mul_mont_mc /\
          read PC s = word(pc + 0xdc) /\ gen_out_inv k z x y m w a b n tp 1 s)
     (MAYCHANGE [PC; X0; X1; X2; X3; X4; X5; X6; X7; X8; X9; X10; X11;
                 X12; X13; X14; X15; X16; X17; X19; X20; X21; X22; X23; SP] ,,
      MAYCHANGE SOME_FLAGS ,, MAYCHANGE [events] ,,
      MAYCHANGE [memory :> bytes(z,8 * k); memory :> bytes(tp,8 * k)])`,
  REPEAT GEN_TAC THEN REWRITE_TAC[ALL; NONOVERLAPPING_CLAUSES; LENGTH_BN; SOME_FLAGS] THEN STRIP_TAC THEN
  REWRITE_TAC[gen_h1_inv; gen_out_inv] THEN
  SUBGOAL_THEN `?p. k = p + 2` (CHOOSE_THEN SUBST_ALL_TAC) THENL
   [EXISTS_TAC `k - 2` THEN ASM_ARITH_TAC; ALL_TAC] THEN
  REWRITE_TAC[ARITH_RULE `(p + 2) - 2 = p /\ (p + 2) - 1 = p + 1`] THEN
  GHOST_INTRO_TAC `h7:int64` `read X7` THEN GHOST_INTRO_TAC `h13:int64` `read X13` THEN
  GHOST_INTRO_TAC `h11:int64` `read X11` THEN GHOST_INTRO_TAC `l10:int64` `read X10` THEN
  GHOST_INTRO_TAC `h17:int64` `read X17` THEN GHOST_INTRO_TAC `l16:int64` `read X16` THEN
  GHOST_INTRO_TAC `nlo:num` `bignum_from_memory(tp,p)` THEN
  REWRITE_TAC[BIGNUM_FROM_MEMORY_BYTES] THEN ENSURES_INIT_TAC "s0" THEN
  ARM_ACCSTEPS_TAC BN_MUL_MONT_EXEC [1;3;4;6;7;9] (1--11) THEN
  ENSURES_FINAL_STATE_TAC THEN ASM_REWRITE_TAC[] THEN
  ADD_PROD_BOUNDS_TAC THEN
  CARRY_ZERO_TAC `carry_s3:bool` [] THEN CARRY_ZERO_TAC `carry_s6:bool` [] THEN
  REPEAT CONJ_TAC THENL
   [CONV_TAC WORD_RULE; CONV_TAC NUM_REDUCE_CONV THEN REFL_TAC; CONV_TAC WORD_RULE;
    CONV_TAC WORD_RULE; ALL_TAC] THEN
  EXISTS_TAC `val(q0:int64)` THEN REWRITE_TAC[VAL_BOUND_64; MULT_CLAUSES; LOWDIGITS_1] THEN
  REWRITE_TAC[ARITH_RULE `p + 2 = (p + 1) + 1`; BYTES_STEP] THEN
  REWRITE_TAC[ARITH_RULE `8 * (p + 1) = 8 * p + 8`] THEN ASM_REWRITE_TAC[ADD_CLAUSES; VAL_WORD_BITVAL] THEN
  MP_TAC(SPECL [`a:num`; `p + 1`] LOWDIGITS_TOP) THEN MP_TAC(SPECL [`n:num`; `p + 1`] LOWDIGITS_TOP) THEN
  ASM_REWRITE_TAC[ARITH_RULE `(p + 1) + 1 = p + 2`] THEN
  DISCH_THEN(fun th -> ONCE_REWRITE_TAC[th]) THEN DISCH_THEN(fun th -> ONCE_REWRITE_TAC[th]) THEN
  SUBGOAL_THEN `&(val(sum_s7:int64)) + &2 pow 64 * (&(val(sum_s9:int64)) + &2 pow 64 * &(bitval carry_s9)):real =
   &(val(h7:int64)) + &(val(h13:int64)) + &(val(l10:int64)) + &(val(l16:int64)) +
   &2 pow 64 * (&(val(h11:int64)) + &(val(h17:int64)))` MP_TAC THENL
  [REAL_LINEAR_SPLIT_TAC []; ALL_TAC] THEN
  FIRST_X_ASSUM(MP_TAC o check (fun th -> free_in `nlo:num` (concl th) && free_in `h7:int64` (concl th))) THEN
  FIRST_X_ASSUM(MP_TAC o check (fun th -> free_in `l16:int64` (concl th) && is_eq(concl th) && type_of(lhs(concl th)) = `:num`)) THEN
  FIRST_X_ASSUM(MP_TAC o check (fun th -> free_in `l10:int64` (concl th) && is_eq(concl th) && type_of(lhs(concl th)) = `:num`)) THEN
  REWRITE_TAC[ARITH_RULE `64 * (p + 2) = 64 * p + 128 /\ 64 * (p + 1) = 64 * p + 64`; EXP_ADD] THEN
  SPEC_TAC(`2 EXP (64 * p)`,`e:num`) THEN GEN_TAC THEN
  REWRITE_TAC[GSYM REAL_OF_NUM_CLAUSES] THEN CONV_TAC REAL_RING);;

let BR_TAC exec inv : tactic =
  REWRITE_TAC[inv; BIGNUM_FROM_MEMORY_BYTES] THEN ENSURES_INIT_TAC "s0" THEN
  ARM_STEPS_TAC exec [1] THEN ENSURES_FINAL_STATE_TAC THEN
  ASM_SIMP_TAC[VAL_8K_EQ0; SUB_REFL] THEN
  TRY(COND_CASES_TAC THEN ASM_REWRITE_TAC[] THEN ASM_ARITH_TAC);;

let GEN_LOOP1 = prove
 (`!k z x y m a b n w tp q0 pc.
   2 <= k /\ k < 2 EXP 58 /\
   ALL (nonoverlapping (tp,8 * k))
       [(word pc,LENGTH bn_mul_mont_mc); (x,8 * k); (y,8 * k); (m,8 * k)]
   ==> ensures arm
     (\s. aligned_bytes_loaded s (word pc) bn_mul_mont_mc /\
          read PC s = word(pc + 0x70) /\ gen_h1_inv k z x y m w a b n tp q0 2 s)
     (\s. aligned_bytes_loaded s (word pc) bn_mul_mont_mc /\
          read PC s = word(pc + 0xb0) /\ gen_h1_inv k z x y m w a b n tp q0 k s)
     (MAYCHANGE [PC; X0; X1; X2; X3; X4; X5; X6; X7; X8; X9; X10; X11;
                 X12; X13; X14; X15; X16; X17; X19; X20; X21; X22; X23; SP] ,,
      MAYCHANGE SOME_FLAGS ,, MAYCHANGE [events] ,,
      MAYCHANGE [memory :> bytes(z,8 * k); memory :> bytes(tp,8 * k)])`,
  REPEAT GEN_TAC THEN STRIP_TAC THEN ASM_CASES_TAC `k = 2` THENL
   [FIRST_X_ASSUM SUBST_ALL_TAC THEN
    REWRITE_TAC[gen_h1_inv; BIGNUM_FROM_MEMORY_BYTES] THEN CONV_TAC NUM_REDUCE_CONV THEN
    ENSURES_INIT_TAC "s0" THEN
    ARM_STEPS_TAC BN_MUL_MONT_EXEC [1] THEN ENSURES_FINAL_STATE_TAC THEN
    ASM_REWRITE_TAC[] THEN
    REWRITE_TAC[WORD_ADD_0] THEN REWRITE_TAC[SOME_FLAGS] THEN MONOTONE_MAYCHANGE_TAC;
    ALL_TAC] THEN
  REWRITE_TAC[SOME_FLAGS] THEN ENSURES_WHILE_AUP_TAC `2` `k:num` `pc + 0x74` `pc + 0xac`
   `\j s. gen_h1_inv k z x y m w a b n tp q0 j s` THEN REPEAT CONJ_TAC THENL
   [ASM_ARITH_TAC;
    BR_TAC BN_MUL_MONT_EXEC gen_h1_inv;
    X_GEN_TAC `j:num` THEN STRIP_TAC THEN
    MP_TAC(SPECL [`k:num`; `z:int64`; `x:int64`; `y:int64`; `m:int64`; `a:num`; `b:num`; `n:num`;
                  `w:int64`; `tp:int64`; `q0:int64`; `j:num`; `pc:num`] GEN_H1_BODY) THEN
    ASM_REWRITE_TAC[SOME_FLAGS];
    X_GEN_TAC `j:num` THEN STRIP_TAC THEN BR_TAC BN_MUL_MONT_EXEC gen_h1_inv;
    BR_TAC BN_MUL_MONT_EXEC gen_h1_inv]);;

let gen_in_inv = new_definition `gen_in_inv (k:num) (z:int64) (x:int64) (y:int64)
    (m:int64) (w:int64) (a:num) (b:num) (n:num) (tp:int64) (i:num) (t:num)
    (c19:int64) (qi:int64) (j:num) s <=>
   read X0 s = z /\ read X2 s = word_add y (word(8 * (i + 1))) /\ read X4 s = w /\
   read X5 s = word(8 * k) /\ read SP s = tp /\ read X20 s = word(8 * (k - (i + 1))) /\
   read X19 s = c19 /\ read X9 s = word(bigdigit b i) /\ read X15 s = qi /\
   read X1 s = word_add x (word(8 * j)) /\ read X3 s = word_add m (word(8 * j)) /\
   read X21 s = word(8 * (k - j)) /\ read X22 s = word_add tp (word(8 * (j - 1))) /\
   bignum_from_memory(x,k) s = a /\ bignum_from_memory(y,k) s = b /\
   bignum_from_memory(m,k) s = n /\
   bignum_from_memory(word_add tp (word(8 * (j - 1))),k - (j - 1)) s = highdigits t (j - 1) /\
   2 EXP 64 * val(read X11 s) + val(read X10 s) = bigdigit a (j - 1) * bigdigit b i /\
   2 EXP 64 * val(read X17 s) + val(read X16 s) = bigdigit n (j - 1) * val qi /\
   val(read X13 s) + bitval(read CF s) < 2 EXP 64 /\
   2 EXP 64 * bignum_from_memory(tp,j - 2) s +
   2 EXP (64 * (j - 1)) * (val(read X7 s) + val(read X13 s) + bitval(read CF s)) =
   lowdigits t (j - 1) + lowdigits a (j - 1) * bigdigit b i + lowdigits n (j - 1) * val qi`;;

let GEN_IN_BODY = prove
 (`!k z x y m a b n w tp i t c19 qi j pc.
   2 <= j /\ j < k /\ k < 2 EXP 58 /\
   ALL (nonoverlapping (tp,8 * k))
       [(word pc,LENGTH bn_mul_mont_mc); (x,8 * k); (y,8 * k); (m,8 * k)]
   ==> ensures arm
     (\s. aligned_bytes_loaded s (word pc) bn_mul_mont_mc /\
          read PC s = word(pc + 0x128) /\ gen_in_inv k z x y m w a b n tp i t c19 qi j s)
     (\s. aligned_bytes_loaded s (word pc) bn_mul_mont_mc /\
          read PC s = word(pc + 0x16c) /\ gen_in_inv k z x y m w a b n tp i t c19 qi (j + 1) s)
     (MAYCHANGE [PC; X0; X1; X2; X3; X4; X5; X6; X7; X8; X9; X10; X11;
                 X12; X13; X14; X15; X16; X17; X19; X20; X21; X22; X23; SP] ,,
      MAYCHANGE SOME_FLAGS ,, MAYCHANGE [events] ,,
      MAYCHANGE [memory :> bytes(z,8 * k); memory :> bytes(tp,8 * k)])`,
  REPEAT GEN_TAC THEN REWRITE_TAC[ALL; NONOVERLAPPING_CLAUSES; LENGTH_BN; SOME_FLAGS] THEN STRIP_TAC THEN
  REWRITE_TAC[gen_in_inv] THEN
  SUBGOAL_THEN `?p. j = p + 2` (CHOOSE_THEN SUBST_ALL_TAC) THENL
   [EXISTS_TAC `j - 2` THEN ASM_ARITH_TAC; ALL_TAC] THEN
  REWRITE_TAC[ARITH_RULE `(p + 2) - 2 = p /\ (p + 2) - 1 = p + 1 /\ ((p + 2) + 1) - 2 = p + 1 /\ ((p + 2) + 1) - 1 = p + 2`] THEN
  MP_TAC(ISPECL [`tp:int64`; `k - (p + 1)`; `t:num`; `p + 1`; `p + 1`] BIGNUM_FROM_MEMORY_OFFSET_EQ_HIGHDIGITS) THEN
  DISCH_THEN(fun th -> ONCE_REWRITE_TAC[th]) THEN
  ASM_REWRITE_TAC[ARITH_RULE `k - (p + 1) = 0 <=> ~(p + 2 <= k)`; ARITH_RULE `k - (p + 1) - 1 = k - (p + 2)`;
                  ARITH_RULE `(p + 1) + 1 = p + 2`] THEN
  ASM_SIMP_TAC[ARITH_RULE `p + 2 < k ==> p + 2 <= k`] THEN
  GHOST_INTRO_TAC `h7:int64` `read X7` THEN GHOST_INTRO_TAC `h13:int64` `read X13` THEN
  GHOST_INTRO_TAC `cf:bool` `read CF` THEN
  GHOST_INTRO_TAC `h11:int64` `read X11` THEN GHOST_INTRO_TAC `l10:int64` `read X10` THEN
  GHOST_INTRO_TAC `h17:int64` `read X17` THEN GHOST_INTRO_TAC `l16:int64` `read X16` THEN
  GHOST_INTRO_TAC `nlo:num` `bignum_from_memory(tp,p)` THEN
  REWRITE_TAC[BIGNUM_FROM_MEMORY_BYTES] THEN ENSURES_INIT_TAC "s0" THEN
  READ_DIGIT_TAC `x:int64` `p + 2` THEN READ_DIGIT_TAC `m:int64` `p + 2` THEN
  ARM_ACCSTEPS_TAC BN_MUL_MONT_EXEC [2;4;6;7;9;10;11;13;14;15] (1--16) THEN
  SUBGOAL_THEN `read X22 s16 = word_add (word_add tp (word (8 * p))) (word 16)` MP_TAC THENL
  [ASM_REWRITE_TAC[] THEN CONV_TAC WORD_RULE; ALL_TAC] THEN
  FIRST_X_ASSUM(K ALL_TAC o check (fun th -> try rator(lhs(concl th)) = `read X22` with _ -> false)) THEN
  DISCH_TAC THEN
  ARM_STEPS_TAC BN_MUL_MONT_EXEC [17] THEN
  ENSURES_FINAL_STATE_TAC THEN ASM_REWRITE_TAC[] THEN
  ADD_PROD_BOUNDS_TAC THEN
  CARRY_ZERO_TAC `carry_s6:bool` [] THEN
  CARRY_ZERO_TAC `carry_s9:bool` [] THEN
  CARRY_ZERO_TAC `carry_s13:bool` [`carry_s4:bool`; `carry_s11:bool`] THEN
  SUBGOAL_THEN `val(sum_s9:int64) + bitval carry_s15 < 18446744073709551616` ASSUME_TAC THENL
  [REWRITE_TAC[GSYM REAL_OF_NUM_CLAUSES; GSYM REAL_OF_NUM_LT] THEN
   REAL_LINEAR_SPLIT_TAC [`carry_s7:bool`; `carry_s15:bool`]; ALL_TAC] THEN
  SUBGOAL_THEN `~carry_s2` (fun th -> RULE_ASSUM_TAC(REWRITE_RULE[th; BITVAL_CLAUSES])) THENL
   [ASM_REWRITE_TAC[]; ALL_TAC] THEN
  RULE_ASSUM_TAC(REWRITE_RULE[VAL_WORD_BIGDIGIT]) THEN
  SUBGOAL_THEN `&(val(sum_s15:int64)) + &2 pow 64 * (&(val(sum_s13:int64)) + &(val(sum_s9:int64)) + &(bitval carry_s15)):real =
   &(val(h7:int64)) + &(val(h13:int64)) + &(bitval cf) + &(bigdigit t (p + 1)) + &(val(l10:int64)) + &(val(l16:int64)) +
   &2 pow 64 * (&(val(h11:int64)) + &(val(h17:int64)))` ASSUME_TAC THENL
  [REAL_LINEAR_SPLIT_TAC []; ALL_TAC] THEN
  ASM_REWRITE_TAC[] THEN REPEAT CONJ_TAC THENL
   [CONV_TAC WORD_RULE;
    CONV_TAC WORD_RULE;
    ASM_SIMP_TAC[WORD_SUB2; ARITH_RULE `p + 2 < k ==> 8 <= 8 * (k - (p + 2))`] THEN
    AP_TERM_TAC THEN ASM_ARITH_TAC;
    CONV_TAC WORD_RULE;
    REWRITE_TAC[GSYM REAL_OF_NUM_CLAUSES] THEN REAL_LINEAR_SPLIT_TAC [];
    REWRITE_TAC[GSYM REAL_OF_NUM_CLAUSES] THEN REAL_LINEAR_SPLIT_TAC [];
    ALL_TAC] THEN
  REWRITE_TAC[GSYM BIGNUM_FROM_MEMORY_BYTES; BIGNUM_FROM_MEMORY_STEP] THEN
  REWRITE_TAC[BIGNUM_FROM_MEMORY_BYTES] THEN ASM_REWRITE_TAC[] THEN
  SUBGOAL_THEN `!x. lowdigits x (p + 2) = 2 EXP (64 * (p + 1)) * bigdigit x (p + 1) + lowdigits x (p + 1)`
    (fun th -> REWRITE_TAC[th]) THENL
   [REWRITE_TAC[ARITH_RULE `p + 2 = SUC(p + 1)`] THEN
    GEN_TAC THEN REWRITE_TAC[ADD1; LOWDIGITS_CLAUSES] THEN ARITH_TAC; ALL_TAC] THEN
  FIRST_X_ASSUM(MP_TAC o check (fun th -> is_eq(concl th) && type_of(lhs(concl th)) = `:real` &&
     free_in `sum_s15:int64` (concl th) && free_in `h7:int64` (concl th))) THEN
  FIRST_X_ASSUM(MP_TAC o check (fun th -> free_in `nlo:num` (concl th) && free_in `h7:int64` (concl th))) THEN
  FIRST_X_ASSUM(MP_TAC o check (fun th -> free_in `l16:int64` (concl th) && is_eq(concl th) && type_of(lhs(concl th)) = `:num`)) THEN
  FIRST_X_ASSUM(MP_TAC o check (fun th -> free_in `l10:int64` (concl th) && is_eq(concl th) && type_of(lhs(concl th)) = `:num`)) THEN
  REWRITE_TAC[ARITH_RULE `64 * (p + 2) = 64 * p + 128 /\ 64 * (p + 1) = 64 * p + 64`; EXP_ADD] THEN
  SPEC_TAC(`2 EXP (64 * p)`,`e:num`) THEN GEN_TAC THEN
  REWRITE_TAC[GSYM REAL_OF_NUM_CLAUSES] THEN CONV_TAC REAL_RING);;
