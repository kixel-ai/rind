(*
 * SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0
 *)

(* ========================================================================= *)
(* SHA-256 block compression with AVX2 and BMI2, as rind's build emits it.   *)
(* ========================================================================= *)

(* rind's naked function low::x86_64::sha256::sha256_block_data_order_avx2 is
   OpenSSL's sha256_block_data_order_avx2 (crypto/sha/asm/sha256-x86_64.pl,
   the AVX2 path), which reads its round constants and byte-shuffle masks
   from the K256 table beside it. Its result is s2n-bignum's FIPS 180-4
   spec, sha256_hash_blocks, from s2n-bignum pull request #415, which
   proofs/hol-light/s2n-bignum/ holds until it merges.

   The routine hashes blocks two at a time: it computes both blocks' message
   schedules at once, block A's in the low 128-bit lane of each register and
   block B's in the high one, running block A's 64 rounds alongside and
   storing every schedule word plus its round constant to the stack, from
   which it then runs block B's rounds. An odd last block runs block A's part
   only, with a block from the stack as a dummy B. The proof steps every
   instruction symbolically, both inner loops unrolled since their trip
   counts are fixed, and folds each round and each schedule word into the
   spec as it completes, naming each state word after the round that made
   it, so the terms stay small. *)

needs "x86/proofs/base.ml";;
needs "x86/proofs/utils/sha256_spec.ml";;

(* admin/prove writes the function's object, as rind's release build emits
   it, to x86_64/sha256_block_data_order_avx2.o: its instructions as .text,
   with relocations, and the K256 table as .rodata. The definition fails
   unless the instructions and relocations are these, and sha256_avx2_k256 is
   the table's bytes, which SHA256_AVX2_K256 checks against FIPS 180-4's
   constants. *)
let sha256_avx2_mc,sha256_avx2_data =
  define_assert_relocs_from_elf
    ~map_symbol_name:(fun _ -> "sha256_avx2_k256")
    "sha256_avx2_mc" "x86_64/sha256_block_data_order_avx2.o"
(fun b ADDR -> [b[
  0x48; 0x89; 0xe0;        (* MOV (% rax) (% rsp) *)
  0x53;                    (* PUSH (% rbx) *)
  0x55;                    (* PUSH (% rbp) *)
  0x41; 0x54;              (* PUSH (% r12) *)
  0x41; 0x55;              (* PUSH (% r13) *)
  0x41; 0x56;              (* PUSH (% r14) *)
  0x41; 0x57;              (* PUSH (% r15) *)
  0x48; 0x81; 0xec; 0x20; 0x02; 0x00; 0x00;
                           (* SUB (% rsp) (Imm32 (word 544)) *)
  0x48; 0xc1; 0xe2; 0x04;  (* SHL (% rdx) (Imm8 (word 4)) *)
  0x48; 0x81; 0xe4; 0x00; 0xfc; 0xff; 0xff;
                           (* AND (% rsp) (Imm32 (word 4294966272)) *)
  0x48; 0x8d; 0x14; 0x96;  (* LEA (% rdx) (%%% (rsi,2,rdx)) *)
  0x48; 0x81; 0xc4; 0xc0; 0x01; 0x00; 0x00;
                           (* ADD (% rsp) (Imm32 (word 448)) *)
  0x48; 0x89; 0x7c; 0x24; 0x40;
                           (* MOV (Memop Quadword (%% (rsp,64))) (% rdi) *)
  0x48; 0x89; 0x74; 0x24; 0x48;
                           (* MOV (Memop Quadword (%% (rsp,72))) (% rsi) *)
  0x48; 0x89; 0x54; 0x24; 0x50;
                           (* MOV (Memop Quadword (%% (rsp,80))) (% rdx) *)
  0x48; 0x89; 0x44; 0x24; 0x58;
                           (* MOV (Memop Quadword (%% (rsp,88))) (% rax) *)
  0xc5; 0xf8; 0x77;        (* VZEROUPPER *)
  0x48; 0x83; 0xee; 0xc0;  (* SUB (% rsi) (Imm8 (word 192)) *)
  0x8b; 0x07;              (* MOV (% eax) (Memop Doubleword (%% (rdi,0))) *)
  0x49; 0x89; 0xf4;        (* MOV (% r12) (% rsi) *)
  0x8b; 0x5f; 0x04;        (* MOV (% ebx) (Memop Doubleword (%% (rdi,4))) *)
  0x48; 0x39; 0xd6;        (* CMP (% rsi) (% rdx) *)
  0x8b; 0x4f; 0x08;        (* MOV (% ecx) (Memop Doubleword (%% (rdi,8))) *)
  0x4c; 0x0f; 0x44; 0xe4;  (* CMOVE (% r12) (% rsp) *)
  0x8b; 0x57; 0x0c;        (* MOV (% edx) (Memop Doubleword (%% (rdi,12))) *)
  0x44; 0x8b; 0x47; 0x10;  (* MOV (% r8d) (Memop Doubleword (%% (rdi,16))) *)
  0x44; 0x8b; 0x4f; 0x14;  (* MOV (% r9d) (Memop Doubleword (%% (rdi,20))) *)
  0x44; 0x8b; 0x57; 0x18;  (* MOV (% r10d) (Memop Doubleword (%% (rdi,24))) *)
  0x44; 0x8b; 0x5f; 0x1c;  (* MOV (% r11d) (Memop Doubleword (%% (rdi,28))) *)
  0xc5; 0x7d; 0x6f; 0x05]; ADDR ("sha256_avx2_k256",(540)); b[
                           (* VMOVDQA (%_% ymm8)
(Memop Word256
(Riprel (word_sx (iword (&sha256_avx2_k256 - (&pc + -- &430)))))) *)
  0xc5; 0x7d; 0x6f; 0x0d]; ADDR ("sha256_avx2_k256",(572)); b[
                           (* VMOVDQA (%_% ymm9)
(Memop Word256
(Riprel (word_sx (iword (&sha256_avx2_k256 - (&pc + -- &454)))))) *)
  0xeb; 0x04;              (* JMP (Imm8 (word 4)) *)
  0x0f; 0x1f; 0x40; 0x00;  (* NOP_N (Memop Doubleword (%% (rax,0))) *)
  0xc5; 0xfd; 0x6f; 0x3d]; ADDR ("sha256_avx2_k256",(508)); b[
                           (* VMOVDQA (%_% ymm7)
(Memop Word256
(Riprel (word_sx (iword (&sha256_avx2_k256 - (&pc + -- &376)))))) *)
  0xc5; 0xfa; 0x6f; 0x46; 0xc0;
                           (* VMOVDQU (%_% xmm0) (Memop Word128 (%% (rsi,18446744073709551552))) *)
  0xc5; 0xfa; 0x6f; 0x4e; 0xd0;
                           (* VMOVDQU (%_% xmm1) (Memop Word128 (%% (rsi,18446744073709551568))) *)
  0xc5; 0xfa; 0x6f; 0x56; 0xe0;
                           (* VMOVDQU (%_% xmm2) (Memop Word128 (%% (rsi,18446744073709551584))) *)
  0xc5; 0xfa; 0x6f; 0x5e; 0xf0;
                           (* VMOVDQU (%_% xmm3) (Memop Word128 (%% (rsi,18446744073709551600))) *)
  0xc4; 0xc3; 0x7d; 0x38; 0x04; 0x24; 0x01;
                           (* VINSERTI128 (%_% ymm0) (%_% ymm0) (Memop Word128 (%% (r12,0)))
(Imm8 (word 1)) *)
  0xc4; 0xc3; 0x75; 0x38; 0x4c; 0x24; 0x10; 0x01;
                           (* VINSERTI128 (%_% ymm1) (%_% ymm1) (Memop Word128 (%% (r12,16)))
(Imm8 (word 1)) *)
  0xc4; 0xe2; 0x7d; 0x00; 0xc7;
                           (* VPSHUFB (%_% ymm0) (%_% ymm0) (%_% ymm7) *)
  0xc4; 0xc3; 0x6d; 0x38; 0x54; 0x24; 0x20; 0x01;
                           (* VINSERTI128 (%_% ymm2) (%_% ymm2) (Memop Word128 (%% (r12,32)))
(Imm8 (word 1)) *)
  0xc4; 0xe2; 0x75; 0x00; 0xcf;
                           (* VPSHUFB (%_% ymm1) (%_% ymm1) (%_% ymm7) *)
  0xc4; 0xc3; 0x65; 0x38; 0x5c; 0x24; 0x30; 0x01;
                           (* VINSERTI128 (%_% ymm3) (%_% ymm3) (Memop Word128 (%% (r12,48)))
(Imm8 (word 1)) *)
  0x48; 0x8d; 0x2d]; ADDR ("sha256_avx2_k256",(-4)); b[
                           (* LEA (% rbp) (Riprel (word_sx (iword (&sha256_avx2_k256 - (&pc + &204))))) *)
  0xc4; 0xe2; 0x6d; 0x00; 0xd7;
                           (* VPSHUFB (%_% ymm2) (%_% ymm2) (%_% ymm7) *)
  0xc5; 0xfd; 0xfe; 0x65; 0x00;
                           (* VPADDD (%_% ymm4) (%_% ymm0) (Memop Word256 (%% (rbp,0))) *)
  0xc4; 0xe2; 0x65; 0x00; 0xdf;
                           (* VPSHUFB (%_% ymm3) (%_% ymm3) (%_% ymm7) *)
  0xc5; 0xf5; 0xfe; 0x6d; 0x20;
                           (* VPADDD (%_% ymm5) (%_% ymm1) (Memop Word256 (%% (rbp,32))) *)
  0xc5; 0xed; 0xfe; 0x75; 0x40;
                           (* VPADDD (%_% ymm6) (%_% ymm2) (Memop Word256 (%% (rbp,64))) *)
  0xc5; 0xe5; 0xfe; 0x7d; 0x60;
                           (* VPADDD (%_% ymm7) (%_% ymm3) (Memop Word256 (%% (rbp,96))) *)
  0xc5; 0xfd; 0x7f; 0x24; 0x24;
                           (* VMOVDQA (Memop Word256 (%% (rsp,0))) (%_% ymm4) *)
  0x45; 0x31; 0xf6;        (* XOR (% r14d) (% r14d) *)
  0xc5; 0xfd; 0x7f; 0x6c; 0x24; 0x20;
                           (* VMOVDQA (Memop Word256 (%% (rsp,32))) (%_% ymm5) *)
  0x48; 0x8b; 0x7c; 0x24; 0x58;
                           (* MOV (% rdi) (Memop Quadword (%% (rsp,88))) *)
  0x48; 0x8d; 0x64; 0x24; 0xc0;
                           (* LEA (% rsp) (%% (rsp,18446744073709551552)) *)
  0x48; 0x89; 0x7c; 0x24; 0xf8;
                           (* MOV (Memop Quadword (%% (rsp,18446744073709551608))) (% rdi) *)
  0x89; 0xdf;              (* MOV (% edi) (% ebx) *)
  0xc5; 0xfd; 0x7f; 0x34; 0x24;
                           (* VMOVDQA (Memop Word256 (%% (rsp,0))) (%_% ymm6) *)
  0x31; 0xcf;              (* XOR (% edi) (% ecx) *)
  0xc5; 0xfd; 0x7f; 0x7c; 0x24; 0x20;
                           (* VMOVDQA (Memop Word256 (%% (rsp,32))) (%_% ymm7) *)
  0x45; 0x89; 0xcc;        (* MOV (% r12d) (% r9d) *)
  0x48; 0x83; 0xed; 0x80;  (* SUB (% rbp) (Imm8 (word 128)) *)
  0xeb; 0x01;              (* JMP (Imm8 (word 1)) *)
  0x90;                    (* NOP *)
  0x48; 0x8d; 0x64; 0x24; 0xc0;
                           (* LEA (% rsp) (%% (rsp,18446744073709551552)) *)
  0xff; 0x74; 0x24; 0x38;  (* PUSH (Memop Quadword (%% (rsp,56))) *)
  0x48; 0x8d; 0x64; 0x24; 0x08;
                           (* LEA (% rsp) (%% (rsp,8)) *)
  0xc4; 0xe3; 0x75; 0x0f; 0xe0; 0x04;
                           (* VPALIGNR (%_% ymm4) (%_% ymm1) (%_% ymm0) (Imm8 (word 4)) *)
  0x44; 0x03; 0x9c; 0x24; 0x80; 0x00; 0x00; 0x00;
                           (* ADD (% r11d) (Memop Doubleword (%% (rsp,128))) *)
  0x45; 0x21; 0xc4;        (* AND (% r12d) (% r8d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe8; 0x19;
                           (* RORX (% r13d) (% r8d) (Imm8 (word 25)) *)
  0xc4; 0xe3; 0x65; 0x0f; 0xfa; 0x04;
                           (* VPALIGNR (%_% ymm7) (%_% ymm3) (%_% ymm2) (Imm8 (word 4)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf8; 0x0b;
                           (* RORX (% r15d) (% r8d) (Imm8 (word 11)) *)
  0x42; 0x8d; 0x04; 0x30;  (* LEA (% eax) (%%% (rax,0,r14)) *)
  0x47; 0x8d; 0x1c; 0x23;  (* LEA (% r11d) (%%% (r11,0,r12)) *)
  0xc5; 0xcd; 0x72; 0xd4; 0x07;
                           (* VPSRLD (%_% ymm6) (%_% ymm4) (Imm8 (word 7)) *)
  0xc4; 0x42; 0x38; 0xf2; 0xe2;
                           (* ANDN (% r12d) (% r8d) (% r10d) *)
  0x45; 0x31; 0xfd;        (* XOR (% r13d) (% r15d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf0; 0x06;
                           (* RORX (% r14d) (% r8d) (Imm8 (word 6)) *)
  0xc5; 0xfd; 0xfe; 0xc7;  (* VPADDD (%_% ymm0) (%_% ymm0) (%_% ymm7) *)
  0x47; 0x8d; 0x1c; 0x23;  (* LEA (% r11d) (%%% (r11,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x41; 0x89; 0xc7;        (* MOV (% r15d) (% eax) *)
  0xc5; 0xc5; 0x72; 0xd4; 0x03;
                           (* VPSRLD (%_% ymm7) (%_% ymm4) (Imm8 (word 3)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe0; 0x16;
                           (* RORX (% r12d) (% eax) (Imm8 (word 22)) *)
  0x47; 0x8d; 0x1c; 0x2b;  (* LEA (% r11d) (%%% (r11,0,r13)) *)
  0x41; 0x31; 0xdf;        (* XOR (% r15d) (% ebx) *)
  0xc5; 0xd5; 0x72; 0xf4; 0x0e;
                           (* VPSLLD (%_% ymm5) (%_% ymm4) (Imm8 (word 14)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf0; 0x0d;
                           (* RORX (% r14d) (% eax) (Imm8 (word 13)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe8; 0x02;
                           (* RORX (% r13d) (% eax) (Imm8 (word 2)) *)
  0x42; 0x8d; 0x14; 0x1a;  (* LEA (% edx) (%%% (rdx,0,r11)) *)
  0xc5; 0xc5; 0xef; 0xe6;  (* VPXOR (%_% ymm4) (%_% ymm7) (%_% ymm6) *)
  0x44; 0x21; 0xff;        (* AND (% edi) (% r15d) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x31; 0xdf;              (* XOR (% edi) (% ebx) *)
  0xc5; 0xfd; 0x70; 0xfb; 0xfa;
                           (* VPSHUFD (%_% ymm7) (%_% ymm3) (Imm8 (word 250)) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x45; 0x8d; 0x1c; 0x3b;  (* LEA (% r11d) (%%% (r11,0,rdi)) *)
  0x45; 0x89; 0xc4;        (* MOV (% r12d) (% r8d) *)
  0xc5; 0xcd; 0x72; 0xd6; 0x0b;
                           (* VPSRLD (%_% ymm6) (%_% ymm6) (Imm8 (word 11)) *)
  0x44; 0x03; 0x94; 0x24; 0x84; 0x00; 0x00; 0x00;
                           (* ADD (% r10d) (Memop Doubleword (%% (rsp,132))) *)
  0x41; 0x21; 0xd4;        (* AND (% r12d) (% edx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xea; 0x19;
                           (* RORX (% r13d) (% edx) (Imm8 (word 25)) *)
  0xc5; 0xdd; 0xef; 0xe5;  (* VPXOR (%_% ymm4) (%_% ymm4) (%_% ymm5) *)
  0xc4; 0xe3; 0x7b; 0xf0; 0xfa; 0x0b;
                           (* RORX (% edi) (% edx) (Imm8 (word 11)) *)
  0x47; 0x8d; 0x1c; 0x33;  (* LEA (% r11d) (%%% (r11,0,r14)) *)
  0x47; 0x8d; 0x14; 0x22;  (* LEA (% r10d) (%%% (r10,0,r12)) *)
  0xc5; 0xd5; 0x72; 0xf5; 0x0b;
                           (* VPSLLD (%_% ymm5) (%_% ymm5) (Imm8 (word 11)) *)
  0xc4; 0x42; 0x68; 0xf2; 0xe1;
                           (* ANDN (% r12d) (% edx) (% r9d) *)
  0x41; 0x31; 0xfd;        (* XOR (% r13d) (% edi) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf2; 0x06;
                           (* RORX (% r14d) (% edx) (Imm8 (word 6)) *)
  0xc5; 0xdd; 0xef; 0xe6;  (* VPXOR (%_% ymm4) (%_% ymm4) (%_% ymm6) *)
  0x47; 0x8d; 0x14; 0x22;  (* LEA (% r10d) (%%% (r10,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x44; 0x89; 0xdf;        (* MOV (% edi) (% r11d) *)
  0xc5; 0xcd; 0x72; 0xd7; 0x0a;
                           (* VPSRLD (%_% ymm6) (%_% ymm7) (Imm8 (word 10)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe3; 0x16;
                           (* RORX (% r12d) (% r11d) (Imm8 (word 22)) *)
  0x47; 0x8d; 0x14; 0x2a;  (* LEA (% r10d) (%%% (r10,0,r13)) *)
  0x31; 0xc7;              (* XOR (% edi) (% eax) *)
  0xc5; 0xdd; 0xef; 0xe5;  (* VPXOR (%_% ymm4) (%_% ymm4) (%_% ymm5) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf3; 0x0d;
                           (* RORX (% r14d) (% r11d) (Imm8 (word 13)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xeb; 0x02;
                           (* RORX (% r13d) (% r11d) (Imm8 (word 2)) *)
  0x42; 0x8d; 0x0c; 0x11;  (* LEA (% ecx) (%%% (rcx,0,r10)) *)
  0xc5; 0xc5; 0x73; 0xd7; 0x11;
                           (* VPSRLQ (%_% ymm7) (%_% ymm7) (Imm8 (word 17)) *)
  0x41; 0x21; 0xff;        (* AND (% r15d) (% edi) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x41; 0x31; 0xc7;        (* XOR (% r15d) (% eax) *)
  0xc5; 0xfd; 0xfe; 0xc4;  (* VPADDD (%_% ymm0) (%_% ymm0) (%_% ymm4) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x47; 0x8d; 0x14; 0x3a;  (* LEA (% r10d) (%%% (r10,0,r15)) *)
  0x41; 0x89; 0xd4;        (* MOV (% r12d) (% edx) *)
  0xc5; 0xcd; 0xef; 0xf7;  (* VPXOR (%_% ymm6) (%_% ymm6) (%_% ymm7) *)
  0x44; 0x03; 0x8c; 0x24; 0x88; 0x00; 0x00; 0x00;
                           (* ADD (% r9d) (Memop Doubleword (%% (rsp,136))) *)
  0x41; 0x21; 0xcc;        (* AND (% r12d) (% ecx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe9; 0x19;
                           (* RORX (% r13d) (% ecx) (Imm8 (word 25)) *)
  0xc5; 0xc5; 0x73; 0xd7; 0x02;
                           (* VPSRLQ (%_% ymm7) (%_% ymm7) (Imm8 (word 2)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf9; 0x0b;
                           (* RORX (% r15d) (% ecx) (Imm8 (word 11)) *)
  0x47; 0x8d; 0x14; 0x32;  (* LEA (% r10d) (%%% (r10,0,r14)) *)
  0x47; 0x8d; 0x0c; 0x21;  (* LEA (% r9d) (%%% (r9,0,r12)) *)
  0xc5; 0xcd; 0xef; 0xf7;  (* VPXOR (%_% ymm6) (%_% ymm6) (%_% ymm7) *)
  0xc4; 0x42; 0x70; 0xf2; 0xe0;
                           (* ANDN (% r12d) (% ecx) (% r8d) *)
  0x45; 0x31; 0xfd;        (* XOR (% r13d) (% r15d) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf1; 0x06;
                           (* RORX (% r14d) (% ecx) (Imm8 (word 6)) *)
  0xc4; 0xc2; 0x4d; 0x00; 0xf0;
                           (* VPSHUFB (%_% ymm6) (%_% ymm6) (%_% ymm8) *)
  0x47; 0x8d; 0x0c; 0x21;  (* LEA (% r9d) (%%% (r9,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x45; 0x89; 0xd7;        (* MOV (% r15d) (% r10d) *)
  0xc5; 0xfd; 0xfe; 0xc6;  (* VPADDD (%_% ymm0) (%_% ymm0) (%_% ymm6) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe2; 0x16;
                           (* RORX (% r12d) (% r10d) (Imm8 (word 22)) *)
  0x47; 0x8d; 0x0c; 0x29;  (* LEA (% r9d) (%%% (r9,0,r13)) *)
  0x45; 0x31; 0xdf;        (* XOR (% r15d) (% r11d) *)
  0xc5; 0xfd; 0x70; 0xf8; 0x50;
                           (* VPSHUFD (%_% ymm7) (%_% ymm0) (Imm8 (word 80)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf2; 0x0d;
                           (* RORX (% r14d) (% r10d) (Imm8 (word 13)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xea; 0x02;
                           (* RORX (% r13d) (% r10d) (Imm8 (word 2)) *)
  0x42; 0x8d; 0x1c; 0x0b;  (* LEA (% ebx) (%%% (rbx,0,r9)) *)
  0xc5; 0xcd; 0x72; 0xd7; 0x0a;
                           (* VPSRLD (%_% ymm6) (%_% ymm7) (Imm8 (word 10)) *)
  0x44; 0x21; 0xff;        (* AND (% edi) (% r15d) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x44; 0x31; 0xdf;        (* XOR (% edi) (% r11d) *)
  0xc5; 0xc5; 0x73; 0xd7; 0x11;
                           (* VPSRLQ (%_% ymm7) (%_% ymm7) (Imm8 (word 17)) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x45; 0x8d; 0x0c; 0x39;  (* LEA (% r9d) (%%% (r9,0,rdi)) *)
  0x41; 0x89; 0xcc;        (* MOV (% r12d) (% ecx) *)
  0xc5; 0xcd; 0xef; 0xf7;  (* VPXOR (%_% ymm6) (%_% ymm6) (%_% ymm7) *)
  0x44; 0x03; 0x84; 0x24; 0x8c; 0x00; 0x00; 0x00;
                           (* ADD (% r8d) (Memop Doubleword (%% (rsp,140))) *)
  0x41; 0x21; 0xdc;        (* AND (% r12d) (% ebx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xeb; 0x19;
                           (* RORX (% r13d) (% ebx) (Imm8 (word 25)) *)
  0xc5; 0xc5; 0x73; 0xd7; 0x02;
                           (* VPSRLQ (%_% ymm7) (%_% ymm7) (Imm8 (word 2)) *)
  0xc4; 0xe3; 0x7b; 0xf0; 0xfb; 0x0b;
                           (* RORX (% edi) (% ebx) (Imm8 (word 11)) *)
  0x47; 0x8d; 0x0c; 0x31;  (* LEA (% r9d) (%%% (r9,0,r14)) *)
  0x47; 0x8d; 0x04; 0x20;  (* LEA (% r8d) (%%% (r8,0,r12)) *)
  0xc5; 0xcd; 0xef; 0xf7;  (* VPXOR (%_% ymm6) (%_% ymm6) (%_% ymm7) *)
  0xc4; 0x62; 0x60; 0xf2; 0xe2;
                           (* ANDN (% r12d) (% ebx) (% edx) *)
  0x41; 0x31; 0xfd;        (* XOR (% r13d) (% edi) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf3; 0x06;
                           (* RORX (% r14d) (% ebx) (Imm8 (word 6)) *)
  0xc4; 0xc2; 0x4d; 0x00; 0xf1;
                           (* VPSHUFB (%_% ymm6) (%_% ymm6) (%_% ymm9) *)
  0x47; 0x8d; 0x04; 0x20;  (* LEA (% r8d) (%%% (r8,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x44; 0x89; 0xcf;        (* MOV (% edi) (% r9d) *)
  0xc5; 0xfd; 0xfe; 0xc6;  (* VPADDD (%_% ymm0) (%_% ymm0) (%_% ymm6) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe1; 0x16;
                           (* RORX (% r12d) (% r9d) (Imm8 (word 22)) *)
  0x47; 0x8d; 0x04; 0x28;  (* LEA (% r8d) (%%% (r8,0,r13)) *)
  0x44; 0x31; 0xd7;        (* XOR (% edi) (% r10d) *)
  0xc5; 0xfd; 0xfe; 0x75; 0x00;
                           (* VPADDD (%_% ymm6) (%_% ymm0) (Memop Word256 (%% (rbp,0))) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf1; 0x0d;
                           (* RORX (% r14d) (% r9d) (Imm8 (word 13)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe9; 0x02;
                           (* RORX (% r13d) (% r9d) (Imm8 (word 2)) *)
  0x42; 0x8d; 0x04; 0x00;  (* LEA (% eax) (%%% (rax,0,r8)) *)
  0x41; 0x21; 0xff;        (* AND (% r15d) (% edi) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x45; 0x31; 0xd7;        (* XOR (% r15d) (% r10d) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x47; 0x8d; 0x04; 0x38;  (* LEA (% r8d) (%%% (r8,0,r15)) *)
  0x41; 0x89; 0xdc;        (* MOV (% r12d) (% ebx) *)
  0xc5; 0xfd; 0x7f; 0x34; 0x24;
                           (* VMOVDQA (Memop Word256 (%% (rsp,0))) (%_% ymm6) *)
  0xc4; 0xe3; 0x6d; 0x0f; 0xe1; 0x04;
                           (* VPALIGNR (%_% ymm4) (%_% ymm2) (%_% ymm1) (Imm8 (word 4)) *)
  0x03; 0x94; 0x24; 0xa0; 0x00; 0x00; 0x00;
                           (* ADD (% edx) (Memop Doubleword (%% (rsp,160))) *)
  0x41; 0x21; 0xc4;        (* AND (% r12d) (% eax) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe8; 0x19;
                           (* RORX (% r13d) (% eax) (Imm8 (word 25)) *)
  0xc4; 0xe3; 0x7d; 0x0f; 0xfb; 0x04;
                           (* VPALIGNR (%_% ymm7) (%_% ymm0) (%_% ymm3) (Imm8 (word 4)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf8; 0x0b;
                           (* RORX (% r15d) (% eax) (Imm8 (word 11)) *)
  0x47; 0x8d; 0x04; 0x30;  (* LEA (% r8d) (%%% (r8,0,r14)) *)
  0x42; 0x8d; 0x14; 0x22;  (* LEA (% edx) (%%% (rdx,0,r12)) *)
  0xc5; 0xcd; 0x72; 0xd4; 0x07;
                           (* VPSRLD (%_% ymm6) (%_% ymm4) (Imm8 (word 7)) *)
  0xc4; 0x62; 0x78; 0xf2; 0xe1;
                           (* ANDN (% r12d) (% eax) (% ecx) *)
  0x45; 0x31; 0xfd;        (* XOR (% r13d) (% r15d) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf0; 0x06;
                           (* RORX (% r14d) (% eax) (Imm8 (word 6)) *)
  0xc5; 0xf5; 0xfe; 0xcf;  (* VPADDD (%_% ymm1) (%_% ymm1) (%_% ymm7) *)
  0x42; 0x8d; 0x14; 0x22;  (* LEA (% edx) (%%% (rdx,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x45; 0x89; 0xc7;        (* MOV (% r15d) (% r8d) *)
  0xc5; 0xc5; 0x72; 0xd4; 0x03;
                           (* VPSRLD (%_% ymm7) (%_% ymm4) (Imm8 (word 3)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe0; 0x16;
                           (* RORX (% r12d) (% r8d) (Imm8 (word 22)) *)
  0x42; 0x8d; 0x14; 0x2a;  (* LEA (% edx) (%%% (rdx,0,r13)) *)
  0x45; 0x31; 0xcf;        (* XOR (% r15d) (% r9d) *)
  0xc5; 0xd5; 0x72; 0xf4; 0x0e;
                           (* VPSLLD (%_% ymm5) (%_% ymm4) (Imm8 (word 14)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf0; 0x0d;
                           (* RORX (% r14d) (% r8d) (Imm8 (word 13)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe8; 0x02;
                           (* RORX (% r13d) (% r8d) (Imm8 (word 2)) *)
  0x45; 0x8d; 0x1c; 0x13;  (* LEA (% r11d) (%%% (r11,0,rdx)) *)
  0xc5; 0xc5; 0xef; 0xe6;  (* VPXOR (%_% ymm4) (%_% ymm7) (%_% ymm6) *)
  0x44; 0x21; 0xff;        (* AND (% edi) (% r15d) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x44; 0x31; 0xcf;        (* XOR (% edi) (% r9d) *)
  0xc5; 0xfd; 0x70; 0xf8; 0xfa;
                           (* VPSHUFD (%_% ymm7) (%_% ymm0) (Imm8 (word 250)) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x8d; 0x14; 0x3a;        (* LEA (% edx) (%%% (rdx,0,rdi)) *)
  0x41; 0x89; 0xc4;        (* MOV (% r12d) (% eax) *)
  0xc5; 0xcd; 0x72; 0xd6; 0x0b;
                           (* VPSRLD (%_% ymm6) (%_% ymm6) (Imm8 (word 11)) *)
  0x03; 0x8c; 0x24; 0xa4; 0x00; 0x00; 0x00;
                           (* ADD (% ecx) (Memop Doubleword (%% (rsp,164))) *)
  0x45; 0x21; 0xdc;        (* AND (% r12d) (% r11d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xeb; 0x19;
                           (* RORX (% r13d) (% r11d) (Imm8 (word 25)) *)
  0xc5; 0xdd; 0xef; 0xe5;  (* VPXOR (%_% ymm4) (%_% ymm4) (%_% ymm5) *)
  0xc4; 0xc3; 0x7b; 0xf0; 0xfb; 0x0b;
                           (* RORX (% edi) (% r11d) (Imm8 (word 11)) *)
  0x42; 0x8d; 0x14; 0x32;  (* LEA (% edx) (%%% (rdx,0,r14)) *)
  0x42; 0x8d; 0x0c; 0x21;  (* LEA (% ecx) (%%% (rcx,0,r12)) *)
  0xc5; 0xd5; 0x72; 0xf5; 0x0b;
                           (* VPSLLD (%_% ymm5) (%_% ymm5) (Imm8 (word 11)) *)
  0xc4; 0x62; 0x20; 0xf2; 0xe3;
                           (* ANDN (% r12d) (% r11d) (% ebx) *)
  0x41; 0x31; 0xfd;        (* XOR (% r13d) (% edi) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf3; 0x06;
                           (* RORX (% r14d) (% r11d) (Imm8 (word 6)) *)
  0xc5; 0xdd; 0xef; 0xe6;  (* VPXOR (%_% ymm4) (%_% ymm4) (%_% ymm6) *)
  0x42; 0x8d; 0x0c; 0x21;  (* LEA (% ecx) (%%% (rcx,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x89; 0xd7;              (* MOV (% edi) (% edx) *)
  0xc5; 0xcd; 0x72; 0xd7; 0x0a;
                           (* VPSRLD (%_% ymm6) (%_% ymm7) (Imm8 (word 10)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe2; 0x16;
                           (* RORX (% r12d) (% edx) (Imm8 (word 22)) *)
  0x42; 0x8d; 0x0c; 0x29;  (* LEA (% ecx) (%%% (rcx,0,r13)) *)
  0x44; 0x31; 0xc7;        (* XOR (% edi) (% r8d) *)
  0xc5; 0xdd; 0xef; 0xe5;  (* VPXOR (%_% ymm4) (%_% ymm4) (%_% ymm5) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf2; 0x0d;
                           (* RORX (% r14d) (% edx) (Imm8 (word 13)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xea; 0x02;
                           (* RORX (% r13d) (% edx) (Imm8 (word 2)) *)
  0x45; 0x8d; 0x14; 0x0a;  (* LEA (% r10d) (%%% (r10,0,rcx)) *)
  0xc5; 0xc5; 0x73; 0xd7; 0x11;
                           (* VPSRLQ (%_% ymm7) (%_% ymm7) (Imm8 (word 17)) *)
  0x41; 0x21; 0xff;        (* AND (% r15d) (% edi) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x45; 0x31; 0xc7;        (* XOR (% r15d) (% r8d) *)
  0xc5; 0xf5; 0xfe; 0xcc;  (* VPADDD (%_% ymm1) (%_% ymm1) (%_% ymm4) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x42; 0x8d; 0x0c; 0x39;  (* LEA (% ecx) (%%% (rcx,0,r15)) *)
  0x45; 0x89; 0xdc;        (* MOV (% r12d) (% r11d) *)
  0xc5; 0xcd; 0xef; 0xf7;  (* VPXOR (%_% ymm6) (%_% ymm6) (%_% ymm7) *)
  0x03; 0x9c; 0x24; 0xa8; 0x00; 0x00; 0x00;
                           (* ADD (% ebx) (Memop Doubleword (%% (rsp,168))) *)
  0x45; 0x21; 0xd4;        (* AND (% r12d) (% r10d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xea; 0x19;
                           (* RORX (% r13d) (% r10d) (Imm8 (word 25)) *)
  0xc5; 0xc5; 0x73; 0xd7; 0x02;
                           (* VPSRLQ (%_% ymm7) (%_% ymm7) (Imm8 (word 2)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xfa; 0x0b;
                           (* RORX (% r15d) (% r10d) (Imm8 (word 11)) *)
  0x42; 0x8d; 0x0c; 0x31;  (* LEA (% ecx) (%%% (rcx,0,r14)) *)
  0x42; 0x8d; 0x1c; 0x23;  (* LEA (% ebx) (%%% (rbx,0,r12)) *)
  0xc5; 0xcd; 0xef; 0xf7;  (* VPXOR (%_% ymm6) (%_% ymm6) (%_% ymm7) *)
  0xc4; 0x62; 0x28; 0xf2; 0xe0;
                           (* ANDN (% r12d) (% r10d) (% eax) *)
  0x45; 0x31; 0xfd;        (* XOR (% r13d) (% r15d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf2; 0x06;
                           (* RORX (% r14d) (% r10d) (Imm8 (word 6)) *)
  0xc4; 0xc2; 0x4d; 0x00; 0xf0;
                           (* VPSHUFB (%_% ymm6) (%_% ymm6) (%_% ymm8) *)
  0x42; 0x8d; 0x1c; 0x23;  (* LEA (% ebx) (%%% (rbx,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x41; 0x89; 0xcf;        (* MOV (% r15d) (% ecx) *)
  0xc5; 0xf5; 0xfe; 0xce;  (* VPADDD (%_% ymm1) (%_% ymm1) (%_% ymm6) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe1; 0x16;
                           (* RORX (% r12d) (% ecx) (Imm8 (word 22)) *)
  0x42; 0x8d; 0x1c; 0x2b;  (* LEA (% ebx) (%%% (rbx,0,r13)) *)
  0x41; 0x31; 0xd7;        (* XOR (% r15d) (% edx) *)
  0xc5; 0xfd; 0x70; 0xf9; 0x50;
                           (* VPSHUFD (%_% ymm7) (%_% ymm1) (Imm8 (word 80)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf1; 0x0d;
                           (* RORX (% r14d) (% ecx) (Imm8 (word 13)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe9; 0x02;
                           (* RORX (% r13d) (% ecx) (Imm8 (word 2)) *)
  0x45; 0x8d; 0x0c; 0x19;  (* LEA (% r9d) (%%% (r9,0,rbx)) *)
  0xc5; 0xcd; 0x72; 0xd7; 0x0a;
                           (* VPSRLD (%_% ymm6) (%_% ymm7) (Imm8 (word 10)) *)
  0x44; 0x21; 0xff;        (* AND (% edi) (% r15d) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x31; 0xd7;              (* XOR (% edi) (% edx) *)
  0xc5; 0xc5; 0x73; 0xd7; 0x11;
                           (* VPSRLQ (%_% ymm7) (%_% ymm7) (Imm8 (word 17)) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x8d; 0x1c; 0x3b;        (* LEA (% ebx) (%%% (rbx,0,rdi)) *)
  0x45; 0x89; 0xd4;        (* MOV (% r12d) (% r10d) *)
  0xc5; 0xcd; 0xef; 0xf7;  (* VPXOR (%_% ymm6) (%_% ymm6) (%_% ymm7) *)
  0x03; 0x84; 0x24; 0xac; 0x00; 0x00; 0x00;
                           (* ADD (% eax) (Memop Doubleword (%% (rsp,172))) *)
  0x45; 0x21; 0xcc;        (* AND (% r12d) (% r9d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe9; 0x19;
                           (* RORX (% r13d) (% r9d) (Imm8 (word 25)) *)
  0xc5; 0xc5; 0x73; 0xd7; 0x02;
                           (* VPSRLQ (%_% ymm7) (%_% ymm7) (Imm8 (word 2)) *)
  0xc4; 0xc3; 0x7b; 0xf0; 0xf9; 0x0b;
                           (* RORX (% edi) (% r9d) (Imm8 (word 11)) *)
  0x42; 0x8d; 0x1c; 0x33;  (* LEA (% ebx) (%%% (rbx,0,r14)) *)
  0x42; 0x8d; 0x04; 0x20;  (* LEA (% eax) (%%% (rax,0,r12)) *)
  0xc5; 0xcd; 0xef; 0xf7;  (* VPXOR (%_% ymm6) (%_% ymm6) (%_% ymm7) *)
  0xc4; 0x42; 0x30; 0xf2; 0xe3;
                           (* ANDN (% r12d) (% r9d) (% r11d) *)
  0x41; 0x31; 0xfd;        (* XOR (% r13d) (% edi) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf1; 0x06;
                           (* RORX (% r14d) (% r9d) (Imm8 (word 6)) *)
  0xc4; 0xc2; 0x4d; 0x00; 0xf1;
                           (* VPSHUFB (%_% ymm6) (%_% ymm6) (%_% ymm9) *)
  0x42; 0x8d; 0x04; 0x20;  (* LEA (% eax) (%%% (rax,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x89; 0xdf;              (* MOV (% edi) (% ebx) *)
  0xc5; 0xf5; 0xfe; 0xce;  (* VPADDD (%_% ymm1) (%_% ymm1) (%_% ymm6) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe3; 0x16;
                           (* RORX (% r12d) (% ebx) (Imm8 (word 22)) *)
  0x42; 0x8d; 0x04; 0x28;  (* LEA (% eax) (%%% (rax,0,r13)) *)
  0x31; 0xcf;              (* XOR (% edi) (% ecx) *)
  0xc5; 0xf5; 0xfe; 0x75; 0x20;
                           (* VPADDD (%_% ymm6) (%_% ymm1) (Memop Word256 (%% (rbp,32))) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf3; 0x0d;
                           (* RORX (% r14d) (% ebx) (Imm8 (word 13)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xeb; 0x02;
                           (* RORX (% r13d) (% ebx) (Imm8 (word 2)) *)
  0x45; 0x8d; 0x04; 0x00;  (* LEA (% r8d) (%%% (r8,0,rax)) *)
  0x41; 0x21; 0xff;        (* AND (% r15d) (% edi) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x41; 0x31; 0xcf;        (* XOR (% r15d) (% ecx) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x42; 0x8d; 0x04; 0x38;  (* LEA (% eax) (%%% (rax,0,r15)) *)
  0x45; 0x89; 0xcc;        (* MOV (% r12d) (% r9d) *)
  0xc5; 0xfd; 0x7f; 0x74; 0x24; 0x20;
                           (* VMOVDQA (Memop Word256 (%% (rsp,32))) (%_% ymm6) *)
  0x48; 0x8d; 0x64; 0x24; 0xc0;
                           (* LEA (% rsp) (%% (rsp,18446744073709551552)) *)
  0xff; 0x74; 0x24; 0x38;  (* PUSH (Memop Quadword (%% (rsp,56))) *)
  0x48; 0x8d; 0x64; 0x24; 0x08;
                           (* LEA (% rsp) (%% (rsp,8)) *)
  0xc4; 0xe3; 0x65; 0x0f; 0xe2; 0x04;
                           (* VPALIGNR (%_% ymm4) (%_% ymm3) (%_% ymm2) (Imm8 (word 4)) *)
  0x44; 0x03; 0x9c; 0x24; 0x80; 0x00; 0x00; 0x00;
                           (* ADD (% r11d) (Memop Doubleword (%% (rsp,128))) *)
  0x45; 0x21; 0xc4;        (* AND (% r12d) (% r8d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe8; 0x19;
                           (* RORX (% r13d) (% r8d) (Imm8 (word 25)) *)
  0xc4; 0xe3; 0x75; 0x0f; 0xf8; 0x04;
                           (* VPALIGNR (%_% ymm7) (%_% ymm1) (%_% ymm0) (Imm8 (word 4)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf8; 0x0b;
                           (* RORX (% r15d) (% r8d) (Imm8 (word 11)) *)
  0x42; 0x8d; 0x04; 0x30;  (* LEA (% eax) (%%% (rax,0,r14)) *)
  0x47; 0x8d; 0x1c; 0x23;  (* LEA (% r11d) (%%% (r11,0,r12)) *)
  0xc5; 0xcd; 0x72; 0xd4; 0x07;
                           (* VPSRLD (%_% ymm6) (%_% ymm4) (Imm8 (word 7)) *)
  0xc4; 0x42; 0x38; 0xf2; 0xe2;
                           (* ANDN (% r12d) (% r8d) (% r10d) *)
  0x45; 0x31; 0xfd;        (* XOR (% r13d) (% r15d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf0; 0x06;
                           (* RORX (% r14d) (% r8d) (Imm8 (word 6)) *)
  0xc5; 0xed; 0xfe; 0xd7;  (* VPADDD (%_% ymm2) (%_% ymm2) (%_% ymm7) *)
  0x47; 0x8d; 0x1c; 0x23;  (* LEA (% r11d) (%%% (r11,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x41; 0x89; 0xc7;        (* MOV (% r15d) (% eax) *)
  0xc5; 0xc5; 0x72; 0xd4; 0x03;
                           (* VPSRLD (%_% ymm7) (%_% ymm4) (Imm8 (word 3)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe0; 0x16;
                           (* RORX (% r12d) (% eax) (Imm8 (word 22)) *)
  0x47; 0x8d; 0x1c; 0x2b;  (* LEA (% r11d) (%%% (r11,0,r13)) *)
  0x41; 0x31; 0xdf;        (* XOR (% r15d) (% ebx) *)
  0xc5; 0xd5; 0x72; 0xf4; 0x0e;
                           (* VPSLLD (%_% ymm5) (%_% ymm4) (Imm8 (word 14)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf0; 0x0d;
                           (* RORX (% r14d) (% eax) (Imm8 (word 13)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe8; 0x02;
                           (* RORX (% r13d) (% eax) (Imm8 (word 2)) *)
  0x42; 0x8d; 0x14; 0x1a;  (* LEA (% edx) (%%% (rdx,0,r11)) *)
  0xc5; 0xc5; 0xef; 0xe6;  (* VPXOR (%_% ymm4) (%_% ymm7) (%_% ymm6) *)
  0x44; 0x21; 0xff;        (* AND (% edi) (% r15d) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x31; 0xdf;              (* XOR (% edi) (% ebx) *)
  0xc5; 0xfd; 0x70; 0xf9; 0xfa;
                           (* VPSHUFD (%_% ymm7) (%_% ymm1) (Imm8 (word 250)) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x45; 0x8d; 0x1c; 0x3b;  (* LEA (% r11d) (%%% (r11,0,rdi)) *)
  0x45; 0x89; 0xc4;        (* MOV (% r12d) (% r8d) *)
  0xc5; 0xcd; 0x72; 0xd6; 0x0b;
                           (* VPSRLD (%_% ymm6) (%_% ymm6) (Imm8 (word 11)) *)
  0x44; 0x03; 0x94; 0x24; 0x84; 0x00; 0x00; 0x00;
                           (* ADD (% r10d) (Memop Doubleword (%% (rsp,132))) *)
  0x41; 0x21; 0xd4;        (* AND (% r12d) (% edx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xea; 0x19;
                           (* RORX (% r13d) (% edx) (Imm8 (word 25)) *)
  0xc5; 0xdd; 0xef; 0xe5;  (* VPXOR (%_% ymm4) (%_% ymm4) (%_% ymm5) *)
  0xc4; 0xe3; 0x7b; 0xf0; 0xfa; 0x0b;
                           (* RORX (% edi) (% edx) (Imm8 (word 11)) *)
  0x47; 0x8d; 0x1c; 0x33;  (* LEA (% r11d) (%%% (r11,0,r14)) *)
  0x47; 0x8d; 0x14; 0x22;  (* LEA (% r10d) (%%% (r10,0,r12)) *)
  0xc5; 0xd5; 0x72; 0xf5; 0x0b;
                           (* VPSLLD (%_% ymm5) (%_% ymm5) (Imm8 (word 11)) *)
  0xc4; 0x42; 0x68; 0xf2; 0xe1;
                           (* ANDN (% r12d) (% edx) (% r9d) *)
  0x41; 0x31; 0xfd;        (* XOR (% r13d) (% edi) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf2; 0x06;
                           (* RORX (% r14d) (% edx) (Imm8 (word 6)) *)
  0xc5; 0xdd; 0xef; 0xe6;  (* VPXOR (%_% ymm4) (%_% ymm4) (%_% ymm6) *)
  0x47; 0x8d; 0x14; 0x22;  (* LEA (% r10d) (%%% (r10,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x44; 0x89; 0xdf;        (* MOV (% edi) (% r11d) *)
  0xc5; 0xcd; 0x72; 0xd7; 0x0a;
                           (* VPSRLD (%_% ymm6) (%_% ymm7) (Imm8 (word 10)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe3; 0x16;
                           (* RORX (% r12d) (% r11d) (Imm8 (word 22)) *)
  0x47; 0x8d; 0x14; 0x2a;  (* LEA (% r10d) (%%% (r10,0,r13)) *)
  0x31; 0xc7;              (* XOR (% edi) (% eax) *)
  0xc5; 0xdd; 0xef; 0xe5;  (* VPXOR (%_% ymm4) (%_% ymm4) (%_% ymm5) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf3; 0x0d;
                           (* RORX (% r14d) (% r11d) (Imm8 (word 13)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xeb; 0x02;
                           (* RORX (% r13d) (% r11d) (Imm8 (word 2)) *)
  0x42; 0x8d; 0x0c; 0x11;  (* LEA (% ecx) (%%% (rcx,0,r10)) *)
  0xc5; 0xc5; 0x73; 0xd7; 0x11;
                           (* VPSRLQ (%_% ymm7) (%_% ymm7) (Imm8 (word 17)) *)
  0x41; 0x21; 0xff;        (* AND (% r15d) (% edi) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x41; 0x31; 0xc7;        (* XOR (% r15d) (% eax) *)
  0xc5; 0xed; 0xfe; 0xd4;  (* VPADDD (%_% ymm2) (%_% ymm2) (%_% ymm4) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x47; 0x8d; 0x14; 0x3a;  (* LEA (% r10d) (%%% (r10,0,r15)) *)
  0x41; 0x89; 0xd4;        (* MOV (% r12d) (% edx) *)
  0xc5; 0xcd; 0xef; 0xf7;  (* VPXOR (%_% ymm6) (%_% ymm6) (%_% ymm7) *)
  0x44; 0x03; 0x8c; 0x24; 0x88; 0x00; 0x00; 0x00;
                           (* ADD (% r9d) (Memop Doubleword (%% (rsp,136))) *)
  0x41; 0x21; 0xcc;        (* AND (% r12d) (% ecx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe9; 0x19;
                           (* RORX (% r13d) (% ecx) (Imm8 (word 25)) *)
  0xc5; 0xc5; 0x73; 0xd7; 0x02;
                           (* VPSRLQ (%_% ymm7) (%_% ymm7) (Imm8 (word 2)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf9; 0x0b;
                           (* RORX (% r15d) (% ecx) (Imm8 (word 11)) *)
  0x47; 0x8d; 0x14; 0x32;  (* LEA (% r10d) (%%% (r10,0,r14)) *)
  0x47; 0x8d; 0x0c; 0x21;  (* LEA (% r9d) (%%% (r9,0,r12)) *)
  0xc5; 0xcd; 0xef; 0xf7;  (* VPXOR (%_% ymm6) (%_% ymm6) (%_% ymm7) *)
  0xc4; 0x42; 0x70; 0xf2; 0xe0;
                           (* ANDN (% r12d) (% ecx) (% r8d) *)
  0x45; 0x31; 0xfd;        (* XOR (% r13d) (% r15d) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf1; 0x06;
                           (* RORX (% r14d) (% ecx) (Imm8 (word 6)) *)
  0xc4; 0xc2; 0x4d; 0x00; 0xf0;
                           (* VPSHUFB (%_% ymm6) (%_% ymm6) (%_% ymm8) *)
  0x47; 0x8d; 0x0c; 0x21;  (* LEA (% r9d) (%%% (r9,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x45; 0x89; 0xd7;        (* MOV (% r15d) (% r10d) *)
  0xc5; 0xed; 0xfe; 0xd6;  (* VPADDD (%_% ymm2) (%_% ymm2) (%_% ymm6) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe2; 0x16;
                           (* RORX (% r12d) (% r10d) (Imm8 (word 22)) *)
  0x47; 0x8d; 0x0c; 0x29;  (* LEA (% r9d) (%%% (r9,0,r13)) *)
  0x45; 0x31; 0xdf;        (* XOR (% r15d) (% r11d) *)
  0xc5; 0xfd; 0x70; 0xfa; 0x50;
                           (* VPSHUFD (%_% ymm7) (%_% ymm2) (Imm8 (word 80)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf2; 0x0d;
                           (* RORX (% r14d) (% r10d) (Imm8 (word 13)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xea; 0x02;
                           (* RORX (% r13d) (% r10d) (Imm8 (word 2)) *)
  0x42; 0x8d; 0x1c; 0x0b;  (* LEA (% ebx) (%%% (rbx,0,r9)) *)
  0xc5; 0xcd; 0x72; 0xd7; 0x0a;
                           (* VPSRLD (%_% ymm6) (%_% ymm7) (Imm8 (word 10)) *)
  0x44; 0x21; 0xff;        (* AND (% edi) (% r15d) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x44; 0x31; 0xdf;        (* XOR (% edi) (% r11d) *)
  0xc5; 0xc5; 0x73; 0xd7; 0x11;
                           (* VPSRLQ (%_% ymm7) (%_% ymm7) (Imm8 (word 17)) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x45; 0x8d; 0x0c; 0x39;  (* LEA (% r9d) (%%% (r9,0,rdi)) *)
  0x41; 0x89; 0xcc;        (* MOV (% r12d) (% ecx) *)
  0xc5; 0xcd; 0xef; 0xf7;  (* VPXOR (%_% ymm6) (%_% ymm6) (%_% ymm7) *)
  0x44; 0x03; 0x84; 0x24; 0x8c; 0x00; 0x00; 0x00;
                           (* ADD (% r8d) (Memop Doubleword (%% (rsp,140))) *)
  0x41; 0x21; 0xdc;        (* AND (% r12d) (% ebx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xeb; 0x19;
                           (* RORX (% r13d) (% ebx) (Imm8 (word 25)) *)
  0xc5; 0xc5; 0x73; 0xd7; 0x02;
                           (* VPSRLQ (%_% ymm7) (%_% ymm7) (Imm8 (word 2)) *)
  0xc4; 0xe3; 0x7b; 0xf0; 0xfb; 0x0b;
                           (* RORX (% edi) (% ebx) (Imm8 (word 11)) *)
  0x47; 0x8d; 0x0c; 0x31;  (* LEA (% r9d) (%%% (r9,0,r14)) *)
  0x47; 0x8d; 0x04; 0x20;  (* LEA (% r8d) (%%% (r8,0,r12)) *)
  0xc5; 0xcd; 0xef; 0xf7;  (* VPXOR (%_% ymm6) (%_% ymm6) (%_% ymm7) *)
  0xc4; 0x62; 0x60; 0xf2; 0xe2;
                           (* ANDN (% r12d) (% ebx) (% edx) *)
  0x41; 0x31; 0xfd;        (* XOR (% r13d) (% edi) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf3; 0x06;
                           (* RORX (% r14d) (% ebx) (Imm8 (word 6)) *)
  0xc4; 0xc2; 0x4d; 0x00; 0xf1;
                           (* VPSHUFB (%_% ymm6) (%_% ymm6) (%_% ymm9) *)
  0x47; 0x8d; 0x04; 0x20;  (* LEA (% r8d) (%%% (r8,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x44; 0x89; 0xcf;        (* MOV (% edi) (% r9d) *)
  0xc5; 0xed; 0xfe; 0xd6;  (* VPADDD (%_% ymm2) (%_% ymm2) (%_% ymm6) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe1; 0x16;
                           (* RORX (% r12d) (% r9d) (Imm8 (word 22)) *)
  0x47; 0x8d; 0x04; 0x28;  (* LEA (% r8d) (%%% (r8,0,r13)) *)
  0x44; 0x31; 0xd7;        (* XOR (% edi) (% r10d) *)
  0xc5; 0xed; 0xfe; 0x75; 0x40;
                           (* VPADDD (%_% ymm6) (%_% ymm2) (Memop Word256 (%% (rbp,64))) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf1; 0x0d;
                           (* RORX (% r14d) (% r9d) (Imm8 (word 13)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe9; 0x02;
                           (* RORX (% r13d) (% r9d) (Imm8 (word 2)) *)
  0x42; 0x8d; 0x04; 0x00;  (* LEA (% eax) (%%% (rax,0,r8)) *)
  0x41; 0x21; 0xff;        (* AND (% r15d) (% edi) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x45; 0x31; 0xd7;        (* XOR (% r15d) (% r10d) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x47; 0x8d; 0x04; 0x38;  (* LEA (% r8d) (%%% (r8,0,r15)) *)
  0x41; 0x89; 0xdc;        (* MOV (% r12d) (% ebx) *)
  0xc5; 0xfd; 0x7f; 0x34; 0x24;
                           (* VMOVDQA (Memop Word256 (%% (rsp,0))) (%_% ymm6) *)
  0xc4; 0xe3; 0x7d; 0x0f; 0xe3; 0x04;
                           (* VPALIGNR (%_% ymm4) (%_% ymm0) (%_% ymm3) (Imm8 (word 4)) *)
  0x03; 0x94; 0x24; 0xa0; 0x00; 0x00; 0x00;
                           (* ADD (% edx) (Memop Doubleword (%% (rsp,160))) *)
  0x41; 0x21; 0xc4;        (* AND (% r12d) (% eax) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe8; 0x19;
                           (* RORX (% r13d) (% eax) (Imm8 (word 25)) *)
  0xc4; 0xe3; 0x6d; 0x0f; 0xf9; 0x04;
                           (* VPALIGNR (%_% ymm7) (%_% ymm2) (%_% ymm1) (Imm8 (word 4)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf8; 0x0b;
                           (* RORX (% r15d) (% eax) (Imm8 (word 11)) *)
  0x47; 0x8d; 0x04; 0x30;  (* LEA (% r8d) (%%% (r8,0,r14)) *)
  0x42; 0x8d; 0x14; 0x22;  (* LEA (% edx) (%%% (rdx,0,r12)) *)
  0xc5; 0xcd; 0x72; 0xd4; 0x07;
                           (* VPSRLD (%_% ymm6) (%_% ymm4) (Imm8 (word 7)) *)
  0xc4; 0x62; 0x78; 0xf2; 0xe1;
                           (* ANDN (% r12d) (% eax) (% ecx) *)
  0x45; 0x31; 0xfd;        (* XOR (% r13d) (% r15d) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf0; 0x06;
                           (* RORX (% r14d) (% eax) (Imm8 (word 6)) *)
  0xc5; 0xe5; 0xfe; 0xdf;  (* VPADDD (%_% ymm3) (%_% ymm3) (%_% ymm7) *)
  0x42; 0x8d; 0x14; 0x22;  (* LEA (% edx) (%%% (rdx,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x45; 0x89; 0xc7;        (* MOV (% r15d) (% r8d) *)
  0xc5; 0xc5; 0x72; 0xd4; 0x03;
                           (* VPSRLD (%_% ymm7) (%_% ymm4) (Imm8 (word 3)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe0; 0x16;
                           (* RORX (% r12d) (% r8d) (Imm8 (word 22)) *)
  0x42; 0x8d; 0x14; 0x2a;  (* LEA (% edx) (%%% (rdx,0,r13)) *)
  0x45; 0x31; 0xcf;        (* XOR (% r15d) (% r9d) *)
  0xc5; 0xd5; 0x72; 0xf4; 0x0e;
                           (* VPSLLD (%_% ymm5) (%_% ymm4) (Imm8 (word 14)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf0; 0x0d;
                           (* RORX (% r14d) (% r8d) (Imm8 (word 13)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe8; 0x02;
                           (* RORX (% r13d) (% r8d) (Imm8 (word 2)) *)
  0x45; 0x8d; 0x1c; 0x13;  (* LEA (% r11d) (%%% (r11,0,rdx)) *)
  0xc5; 0xc5; 0xef; 0xe6;  (* VPXOR (%_% ymm4) (%_% ymm7) (%_% ymm6) *)
  0x44; 0x21; 0xff;        (* AND (% edi) (% r15d) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x44; 0x31; 0xcf;        (* XOR (% edi) (% r9d) *)
  0xc5; 0xfd; 0x70; 0xfa; 0xfa;
                           (* VPSHUFD (%_% ymm7) (%_% ymm2) (Imm8 (word 250)) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x8d; 0x14; 0x3a;        (* LEA (% edx) (%%% (rdx,0,rdi)) *)
  0x41; 0x89; 0xc4;        (* MOV (% r12d) (% eax) *)
  0xc5; 0xcd; 0x72; 0xd6; 0x0b;
                           (* VPSRLD (%_% ymm6) (%_% ymm6) (Imm8 (word 11)) *)
  0x03; 0x8c; 0x24; 0xa4; 0x00; 0x00; 0x00;
                           (* ADD (% ecx) (Memop Doubleword (%% (rsp,164))) *)
  0x45; 0x21; 0xdc;        (* AND (% r12d) (% r11d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xeb; 0x19;
                           (* RORX (% r13d) (% r11d) (Imm8 (word 25)) *)
  0xc5; 0xdd; 0xef; 0xe5;  (* VPXOR (%_% ymm4) (%_% ymm4) (%_% ymm5) *)
  0xc4; 0xc3; 0x7b; 0xf0; 0xfb; 0x0b;
                           (* RORX (% edi) (% r11d) (Imm8 (word 11)) *)
  0x42; 0x8d; 0x14; 0x32;  (* LEA (% edx) (%%% (rdx,0,r14)) *)
  0x42; 0x8d; 0x0c; 0x21;  (* LEA (% ecx) (%%% (rcx,0,r12)) *)
  0xc5; 0xd5; 0x72; 0xf5; 0x0b;
                           (* VPSLLD (%_% ymm5) (%_% ymm5) (Imm8 (word 11)) *)
  0xc4; 0x62; 0x20; 0xf2; 0xe3;
                           (* ANDN (% r12d) (% r11d) (% ebx) *)
  0x41; 0x31; 0xfd;        (* XOR (% r13d) (% edi) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf3; 0x06;
                           (* RORX (% r14d) (% r11d) (Imm8 (word 6)) *)
  0xc5; 0xdd; 0xef; 0xe6;  (* VPXOR (%_% ymm4) (%_% ymm4) (%_% ymm6) *)
  0x42; 0x8d; 0x0c; 0x21;  (* LEA (% ecx) (%%% (rcx,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x89; 0xd7;              (* MOV (% edi) (% edx) *)
  0xc5; 0xcd; 0x72; 0xd7; 0x0a;
                           (* VPSRLD (%_% ymm6) (%_% ymm7) (Imm8 (word 10)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe2; 0x16;
                           (* RORX (% r12d) (% edx) (Imm8 (word 22)) *)
  0x42; 0x8d; 0x0c; 0x29;  (* LEA (% ecx) (%%% (rcx,0,r13)) *)
  0x44; 0x31; 0xc7;        (* XOR (% edi) (% r8d) *)
  0xc5; 0xdd; 0xef; 0xe5;  (* VPXOR (%_% ymm4) (%_% ymm4) (%_% ymm5) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf2; 0x0d;
                           (* RORX (% r14d) (% edx) (Imm8 (word 13)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xea; 0x02;
                           (* RORX (% r13d) (% edx) (Imm8 (word 2)) *)
  0x45; 0x8d; 0x14; 0x0a;  (* LEA (% r10d) (%%% (r10,0,rcx)) *)
  0xc5; 0xc5; 0x73; 0xd7; 0x11;
                           (* VPSRLQ (%_% ymm7) (%_% ymm7) (Imm8 (word 17)) *)
  0x41; 0x21; 0xff;        (* AND (% r15d) (% edi) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x45; 0x31; 0xc7;        (* XOR (% r15d) (% r8d) *)
  0xc5; 0xe5; 0xfe; 0xdc;  (* VPADDD (%_% ymm3) (%_% ymm3) (%_% ymm4) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x42; 0x8d; 0x0c; 0x39;  (* LEA (% ecx) (%%% (rcx,0,r15)) *)
  0x45; 0x89; 0xdc;        (* MOV (% r12d) (% r11d) *)
  0xc5; 0xcd; 0xef; 0xf7;  (* VPXOR (%_% ymm6) (%_% ymm6) (%_% ymm7) *)
  0x03; 0x9c; 0x24; 0xa8; 0x00; 0x00; 0x00;
                           (* ADD (% ebx) (Memop Doubleword (%% (rsp,168))) *)
  0x45; 0x21; 0xd4;        (* AND (% r12d) (% r10d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xea; 0x19;
                           (* RORX (% r13d) (% r10d) (Imm8 (word 25)) *)
  0xc5; 0xc5; 0x73; 0xd7; 0x02;
                           (* VPSRLQ (%_% ymm7) (%_% ymm7) (Imm8 (word 2)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xfa; 0x0b;
                           (* RORX (% r15d) (% r10d) (Imm8 (word 11)) *)
  0x42; 0x8d; 0x0c; 0x31;  (* LEA (% ecx) (%%% (rcx,0,r14)) *)
  0x42; 0x8d; 0x1c; 0x23;  (* LEA (% ebx) (%%% (rbx,0,r12)) *)
  0xc5; 0xcd; 0xef; 0xf7;  (* VPXOR (%_% ymm6) (%_% ymm6) (%_% ymm7) *)
  0xc4; 0x62; 0x28; 0xf2; 0xe0;
                           (* ANDN (% r12d) (% r10d) (% eax) *)
  0x45; 0x31; 0xfd;        (* XOR (% r13d) (% r15d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf2; 0x06;
                           (* RORX (% r14d) (% r10d) (Imm8 (word 6)) *)
  0xc4; 0xc2; 0x4d; 0x00; 0xf0;
                           (* VPSHUFB (%_% ymm6) (%_% ymm6) (%_% ymm8) *)
  0x42; 0x8d; 0x1c; 0x23;  (* LEA (% ebx) (%%% (rbx,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x41; 0x89; 0xcf;        (* MOV (% r15d) (% ecx) *)
  0xc5; 0xe5; 0xfe; 0xde;  (* VPADDD (%_% ymm3) (%_% ymm3) (%_% ymm6) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe1; 0x16;
                           (* RORX (% r12d) (% ecx) (Imm8 (word 22)) *)
  0x42; 0x8d; 0x1c; 0x2b;  (* LEA (% ebx) (%%% (rbx,0,r13)) *)
  0x41; 0x31; 0xd7;        (* XOR (% r15d) (% edx) *)
  0xc5; 0xfd; 0x70; 0xfb; 0x50;
                           (* VPSHUFD (%_% ymm7) (%_% ymm3) (Imm8 (word 80)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf1; 0x0d;
                           (* RORX (% r14d) (% ecx) (Imm8 (word 13)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe9; 0x02;
                           (* RORX (% r13d) (% ecx) (Imm8 (word 2)) *)
  0x45; 0x8d; 0x0c; 0x19;  (* LEA (% r9d) (%%% (r9,0,rbx)) *)
  0xc5; 0xcd; 0x72; 0xd7; 0x0a;
                           (* VPSRLD (%_% ymm6) (%_% ymm7) (Imm8 (word 10)) *)
  0x44; 0x21; 0xff;        (* AND (% edi) (% r15d) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x31; 0xd7;              (* XOR (% edi) (% edx) *)
  0xc5; 0xc5; 0x73; 0xd7; 0x11;
                           (* VPSRLQ (%_% ymm7) (%_% ymm7) (Imm8 (word 17)) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x8d; 0x1c; 0x3b;        (* LEA (% ebx) (%%% (rbx,0,rdi)) *)
  0x45; 0x89; 0xd4;        (* MOV (% r12d) (% r10d) *)
  0xc5; 0xcd; 0xef; 0xf7;  (* VPXOR (%_% ymm6) (%_% ymm6) (%_% ymm7) *)
  0x03; 0x84; 0x24; 0xac; 0x00; 0x00; 0x00;
                           (* ADD (% eax) (Memop Doubleword (%% (rsp,172))) *)
  0x45; 0x21; 0xcc;        (* AND (% r12d) (% r9d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe9; 0x19;
                           (* RORX (% r13d) (% r9d) (Imm8 (word 25)) *)
  0xc5; 0xc5; 0x73; 0xd7; 0x02;
                           (* VPSRLQ (%_% ymm7) (%_% ymm7) (Imm8 (word 2)) *)
  0xc4; 0xc3; 0x7b; 0xf0; 0xf9; 0x0b;
                           (* RORX (% edi) (% r9d) (Imm8 (word 11)) *)
  0x42; 0x8d; 0x1c; 0x33;  (* LEA (% ebx) (%%% (rbx,0,r14)) *)
  0x42; 0x8d; 0x04; 0x20;  (* LEA (% eax) (%%% (rax,0,r12)) *)
  0xc5; 0xcd; 0xef; 0xf7;  (* VPXOR (%_% ymm6) (%_% ymm6) (%_% ymm7) *)
  0xc4; 0x42; 0x30; 0xf2; 0xe3;
                           (* ANDN (% r12d) (% r9d) (% r11d) *)
  0x41; 0x31; 0xfd;        (* XOR (% r13d) (% edi) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf1; 0x06;
                           (* RORX (% r14d) (% r9d) (Imm8 (word 6)) *)
  0xc4; 0xc2; 0x4d; 0x00; 0xf1;
                           (* VPSHUFB (%_% ymm6) (%_% ymm6) (%_% ymm9) *)
  0x42; 0x8d; 0x04; 0x20;  (* LEA (% eax) (%%% (rax,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x89; 0xdf;              (* MOV (% edi) (% ebx) *)
  0xc5; 0xe5; 0xfe; 0xde;  (* VPADDD (%_% ymm3) (%_% ymm3) (%_% ymm6) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe3; 0x16;
                           (* RORX (% r12d) (% ebx) (Imm8 (word 22)) *)
  0x42; 0x8d; 0x04; 0x28;  (* LEA (% eax) (%%% (rax,0,r13)) *)
  0x31; 0xcf;              (* XOR (% edi) (% ecx) *)
  0xc5; 0xe5; 0xfe; 0x75; 0x60;
                           (* VPADDD (%_% ymm6) (%_% ymm3) (Memop Word256 (%% (rbp,96))) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf3; 0x0d;
                           (* RORX (% r14d) (% ebx) (Imm8 (word 13)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xeb; 0x02;
                           (* RORX (% r13d) (% ebx) (Imm8 (word 2)) *)
  0x45; 0x8d; 0x04; 0x00;  (* LEA (% r8d) (%%% (r8,0,rax)) *)
  0x41; 0x21; 0xff;        (* AND (% r15d) (% edi) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x41; 0x31; 0xcf;        (* XOR (% r15d) (% ecx) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x42; 0x8d; 0x04; 0x38;  (* LEA (% eax) (%%% (rax,0,r15)) *)
  0x45; 0x89; 0xcc;        (* MOV (% r12d) (% r9d) *)
  0xc5; 0xfd; 0x7f; 0x74; 0x24; 0x20;
                           (* VMOVDQA (Memop Word256 (%% (rsp,32))) (%_% ymm6) *)
  0x48; 0x8d; 0xad; 0x80; 0x00; 0x00; 0x00;
                           (* LEA (% rbp) (%% (rbp,128)) *)
  0x80; 0x7d; 0x03; 0x00;  (* CMP (Memop Byte (%% (rbp,3))) (Imm8 (word 0)) *)
  0x0f; 0x85; 0x35; 0xf7; 0xff; 0xff;
                           (* JNE (Imm32 (word 4294965045)) *)
  0x44; 0x03; 0x5c; 0x24; 0x40;
                           (* ADD (% r11d) (Memop Doubleword (%% (rsp,64))) *)
  0x45; 0x21; 0xc4;        (* AND (% r12d) (% r8d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe8; 0x19;
                           (* RORX (% r13d) (% r8d) (Imm8 (word 25)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf8; 0x0b;
                           (* RORX (% r15d) (% r8d) (Imm8 (word 11)) *)
  0x42; 0x8d; 0x04; 0x30;  (* LEA (% eax) (%%% (rax,0,r14)) *)
  0x47; 0x8d; 0x1c; 0x23;  (* LEA (% r11d) (%%% (r11,0,r12)) *)
  0xc4; 0x42; 0x38; 0xf2; 0xe2;
                           (* ANDN (% r12d) (% r8d) (% r10d) *)
  0x45; 0x31; 0xfd;        (* XOR (% r13d) (% r15d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf0; 0x06;
                           (* RORX (% r14d) (% r8d) (Imm8 (word 6)) *)
  0x47; 0x8d; 0x1c; 0x23;  (* LEA (% r11d) (%%% (r11,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x41; 0x89; 0xc7;        (* MOV (% r15d) (% eax) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe0; 0x16;
                           (* RORX (% r12d) (% eax) (Imm8 (word 22)) *)
  0x47; 0x8d; 0x1c; 0x2b;  (* LEA (% r11d) (%%% (r11,0,r13)) *)
  0x41; 0x31; 0xdf;        (* XOR (% r15d) (% ebx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf0; 0x0d;
                           (* RORX (% r14d) (% eax) (Imm8 (word 13)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe8; 0x02;
                           (* RORX (% r13d) (% eax) (Imm8 (word 2)) *)
  0x42; 0x8d; 0x14; 0x1a;  (* LEA (% edx) (%%% (rdx,0,r11)) *)
  0x44; 0x21; 0xff;        (* AND (% edi) (% r15d) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x31; 0xdf;              (* XOR (% edi) (% ebx) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x45; 0x8d; 0x1c; 0x3b;  (* LEA (% r11d) (%%% (r11,0,rdi)) *)
  0x45; 0x89; 0xc4;        (* MOV (% r12d) (% r8d) *)
  0x44; 0x03; 0x54; 0x24; 0x44;
                           (* ADD (% r10d) (Memop Doubleword (%% (rsp,68))) *)
  0x41; 0x21; 0xd4;        (* AND (% r12d) (% edx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xea; 0x19;
                           (* RORX (% r13d) (% edx) (Imm8 (word 25)) *)
  0xc4; 0xe3; 0x7b; 0xf0; 0xfa; 0x0b;
                           (* RORX (% edi) (% edx) (Imm8 (word 11)) *)
  0x47; 0x8d; 0x1c; 0x33;  (* LEA (% r11d) (%%% (r11,0,r14)) *)
  0x47; 0x8d; 0x14; 0x22;  (* LEA (% r10d) (%%% (r10,0,r12)) *)
  0xc4; 0x42; 0x68; 0xf2; 0xe1;
                           (* ANDN (% r12d) (% edx) (% r9d) *)
  0x41; 0x31; 0xfd;        (* XOR (% r13d) (% edi) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf2; 0x06;
                           (* RORX (% r14d) (% edx) (Imm8 (word 6)) *)
  0x47; 0x8d; 0x14; 0x22;  (* LEA (% r10d) (%%% (r10,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x44; 0x89; 0xdf;        (* MOV (% edi) (% r11d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe3; 0x16;
                           (* RORX (% r12d) (% r11d) (Imm8 (word 22)) *)
  0x47; 0x8d; 0x14; 0x2a;  (* LEA (% r10d) (%%% (r10,0,r13)) *)
  0x31; 0xc7;              (* XOR (% edi) (% eax) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf3; 0x0d;
                           (* RORX (% r14d) (% r11d) (Imm8 (word 13)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xeb; 0x02;
                           (* RORX (% r13d) (% r11d) (Imm8 (word 2)) *)
  0x42; 0x8d; 0x0c; 0x11;  (* LEA (% ecx) (%%% (rcx,0,r10)) *)
  0x41; 0x21; 0xff;        (* AND (% r15d) (% edi) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x41; 0x31; 0xc7;        (* XOR (% r15d) (% eax) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x47; 0x8d; 0x14; 0x3a;  (* LEA (% r10d) (%%% (r10,0,r15)) *)
  0x41; 0x89; 0xd4;        (* MOV (% r12d) (% edx) *)
  0x44; 0x03; 0x4c; 0x24; 0x48;
                           (* ADD (% r9d) (Memop Doubleword (%% (rsp,72))) *)
  0x41; 0x21; 0xcc;        (* AND (% r12d) (% ecx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe9; 0x19;
                           (* RORX (% r13d) (% ecx) (Imm8 (word 25)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf9; 0x0b;
                           (* RORX (% r15d) (% ecx) (Imm8 (word 11)) *)
  0x47; 0x8d; 0x14; 0x32;  (* LEA (% r10d) (%%% (r10,0,r14)) *)
  0x47; 0x8d; 0x0c; 0x21;  (* LEA (% r9d) (%%% (r9,0,r12)) *)
  0xc4; 0x42; 0x70; 0xf2; 0xe0;
                           (* ANDN (% r12d) (% ecx) (% r8d) *)
  0x45; 0x31; 0xfd;        (* XOR (% r13d) (% r15d) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf1; 0x06;
                           (* RORX (% r14d) (% ecx) (Imm8 (word 6)) *)
  0x47; 0x8d; 0x0c; 0x21;  (* LEA (% r9d) (%%% (r9,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x45; 0x89; 0xd7;        (* MOV (% r15d) (% r10d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe2; 0x16;
                           (* RORX (% r12d) (% r10d) (Imm8 (word 22)) *)
  0x47; 0x8d; 0x0c; 0x29;  (* LEA (% r9d) (%%% (r9,0,r13)) *)
  0x45; 0x31; 0xdf;        (* XOR (% r15d) (% r11d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf2; 0x0d;
                           (* RORX (% r14d) (% r10d) (Imm8 (word 13)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xea; 0x02;
                           (* RORX (% r13d) (% r10d) (Imm8 (word 2)) *)
  0x42; 0x8d; 0x1c; 0x0b;  (* LEA (% ebx) (%%% (rbx,0,r9)) *)
  0x44; 0x21; 0xff;        (* AND (% edi) (% r15d) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x44; 0x31; 0xdf;        (* XOR (% edi) (% r11d) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x45; 0x8d; 0x0c; 0x39;  (* LEA (% r9d) (%%% (r9,0,rdi)) *)
  0x41; 0x89; 0xcc;        (* MOV (% r12d) (% ecx) *)
  0x44; 0x03; 0x44; 0x24; 0x4c;
                           (* ADD (% r8d) (Memop Doubleword (%% (rsp,76))) *)
  0x41; 0x21; 0xdc;        (* AND (% r12d) (% ebx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xeb; 0x19;
                           (* RORX (% r13d) (% ebx) (Imm8 (word 25)) *)
  0xc4; 0xe3; 0x7b; 0xf0; 0xfb; 0x0b;
                           (* RORX (% edi) (% ebx) (Imm8 (word 11)) *)
  0x47; 0x8d; 0x0c; 0x31;  (* LEA (% r9d) (%%% (r9,0,r14)) *)
  0x47; 0x8d; 0x04; 0x20;  (* LEA (% r8d) (%%% (r8,0,r12)) *)
  0xc4; 0x62; 0x60; 0xf2; 0xe2;
                           (* ANDN (% r12d) (% ebx) (% edx) *)
  0x41; 0x31; 0xfd;        (* XOR (% r13d) (% edi) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf3; 0x06;
                           (* RORX (% r14d) (% ebx) (Imm8 (word 6)) *)
  0x47; 0x8d; 0x04; 0x20;  (* LEA (% r8d) (%%% (r8,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x44; 0x89; 0xcf;        (* MOV (% edi) (% r9d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe1; 0x16;
                           (* RORX (% r12d) (% r9d) (Imm8 (word 22)) *)
  0x47; 0x8d; 0x04; 0x28;  (* LEA (% r8d) (%%% (r8,0,r13)) *)
  0x44; 0x31; 0xd7;        (* XOR (% edi) (% r10d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf1; 0x0d;
                           (* RORX (% r14d) (% r9d) (Imm8 (word 13)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe9; 0x02;
                           (* RORX (% r13d) (% r9d) (Imm8 (word 2)) *)
  0x42; 0x8d; 0x04; 0x00;  (* LEA (% eax) (%%% (rax,0,r8)) *)
  0x41; 0x21; 0xff;        (* AND (% r15d) (% edi) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x45; 0x31; 0xd7;        (* XOR (% r15d) (% r10d) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x47; 0x8d; 0x04; 0x38;  (* LEA (% r8d) (%%% (r8,0,r15)) *)
  0x41; 0x89; 0xdc;        (* MOV (% r12d) (% ebx) *)
  0x03; 0x54; 0x24; 0x60;  (* ADD (% edx) (Memop Doubleword (%% (rsp,96))) *)
  0x41; 0x21; 0xc4;        (* AND (% r12d) (% eax) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe8; 0x19;
                           (* RORX (% r13d) (% eax) (Imm8 (word 25)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf8; 0x0b;
                           (* RORX (% r15d) (% eax) (Imm8 (word 11)) *)
  0x47; 0x8d; 0x04; 0x30;  (* LEA (% r8d) (%%% (r8,0,r14)) *)
  0x42; 0x8d; 0x14; 0x22;  (* LEA (% edx) (%%% (rdx,0,r12)) *)
  0xc4; 0x62; 0x78; 0xf2; 0xe1;
                           (* ANDN (% r12d) (% eax) (% ecx) *)
  0x45; 0x31; 0xfd;        (* XOR (% r13d) (% r15d) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf0; 0x06;
                           (* RORX (% r14d) (% eax) (Imm8 (word 6)) *)
  0x42; 0x8d; 0x14; 0x22;  (* LEA (% edx) (%%% (rdx,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x45; 0x89; 0xc7;        (* MOV (% r15d) (% r8d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe0; 0x16;
                           (* RORX (% r12d) (% r8d) (Imm8 (word 22)) *)
  0x42; 0x8d; 0x14; 0x2a;  (* LEA (% edx) (%%% (rdx,0,r13)) *)
  0x45; 0x31; 0xcf;        (* XOR (% r15d) (% r9d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf0; 0x0d;
                           (* RORX (% r14d) (% r8d) (Imm8 (word 13)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe8; 0x02;
                           (* RORX (% r13d) (% r8d) (Imm8 (word 2)) *)
  0x45; 0x8d; 0x1c; 0x13;  (* LEA (% r11d) (%%% (r11,0,rdx)) *)
  0x44; 0x21; 0xff;        (* AND (% edi) (% r15d) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x44; 0x31; 0xcf;        (* XOR (% edi) (% r9d) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x8d; 0x14; 0x3a;        (* LEA (% edx) (%%% (rdx,0,rdi)) *)
  0x41; 0x89; 0xc4;        (* MOV (% r12d) (% eax) *)
  0x03; 0x4c; 0x24; 0x64;  (* ADD (% ecx) (Memop Doubleword (%% (rsp,100))) *)
  0x45; 0x21; 0xdc;        (* AND (% r12d) (% r11d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xeb; 0x19;
                           (* RORX (% r13d) (% r11d) (Imm8 (word 25)) *)
  0xc4; 0xc3; 0x7b; 0xf0; 0xfb; 0x0b;
                           (* RORX (% edi) (% r11d) (Imm8 (word 11)) *)
  0x42; 0x8d; 0x14; 0x32;  (* LEA (% edx) (%%% (rdx,0,r14)) *)
  0x42; 0x8d; 0x0c; 0x21;  (* LEA (% ecx) (%%% (rcx,0,r12)) *)
  0xc4; 0x62; 0x20; 0xf2; 0xe3;
                           (* ANDN (% r12d) (% r11d) (% ebx) *)
  0x41; 0x31; 0xfd;        (* XOR (% r13d) (% edi) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf3; 0x06;
                           (* RORX (% r14d) (% r11d) (Imm8 (word 6)) *)
  0x42; 0x8d; 0x0c; 0x21;  (* LEA (% ecx) (%%% (rcx,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x89; 0xd7;              (* MOV (% edi) (% edx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe2; 0x16;
                           (* RORX (% r12d) (% edx) (Imm8 (word 22)) *)
  0x42; 0x8d; 0x0c; 0x29;  (* LEA (% ecx) (%%% (rcx,0,r13)) *)
  0x44; 0x31; 0xc7;        (* XOR (% edi) (% r8d) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf2; 0x0d;
                           (* RORX (% r14d) (% edx) (Imm8 (word 13)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xea; 0x02;
                           (* RORX (% r13d) (% edx) (Imm8 (word 2)) *)
  0x45; 0x8d; 0x14; 0x0a;  (* LEA (% r10d) (%%% (r10,0,rcx)) *)
  0x41; 0x21; 0xff;        (* AND (% r15d) (% edi) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x45; 0x31; 0xc7;        (* XOR (% r15d) (% r8d) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x42; 0x8d; 0x0c; 0x39;  (* LEA (% ecx) (%%% (rcx,0,r15)) *)
  0x45; 0x89; 0xdc;        (* MOV (% r12d) (% r11d) *)
  0x03; 0x5c; 0x24; 0x68;  (* ADD (% ebx) (Memop Doubleword (%% (rsp,104))) *)
  0x45; 0x21; 0xd4;        (* AND (% r12d) (% r10d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xea; 0x19;
                           (* RORX (% r13d) (% r10d) (Imm8 (word 25)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xfa; 0x0b;
                           (* RORX (% r15d) (% r10d) (Imm8 (word 11)) *)
  0x42; 0x8d; 0x0c; 0x31;  (* LEA (% ecx) (%%% (rcx,0,r14)) *)
  0x42; 0x8d; 0x1c; 0x23;  (* LEA (% ebx) (%%% (rbx,0,r12)) *)
  0xc4; 0x62; 0x28; 0xf2; 0xe0;
                           (* ANDN (% r12d) (% r10d) (% eax) *)
  0x45; 0x31; 0xfd;        (* XOR (% r13d) (% r15d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf2; 0x06;
                           (* RORX (% r14d) (% r10d) (Imm8 (word 6)) *)
  0x42; 0x8d; 0x1c; 0x23;  (* LEA (% ebx) (%%% (rbx,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x41; 0x89; 0xcf;        (* MOV (% r15d) (% ecx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe1; 0x16;
                           (* RORX (% r12d) (% ecx) (Imm8 (word 22)) *)
  0x42; 0x8d; 0x1c; 0x2b;  (* LEA (% ebx) (%%% (rbx,0,r13)) *)
  0x41; 0x31; 0xd7;        (* XOR (% r15d) (% edx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf1; 0x0d;
                           (* RORX (% r14d) (% ecx) (Imm8 (word 13)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe9; 0x02;
                           (* RORX (% r13d) (% ecx) (Imm8 (word 2)) *)
  0x45; 0x8d; 0x0c; 0x19;  (* LEA (% r9d) (%%% (r9,0,rbx)) *)
  0x44; 0x21; 0xff;        (* AND (% edi) (% r15d) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x31; 0xd7;              (* XOR (% edi) (% edx) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x8d; 0x1c; 0x3b;        (* LEA (% ebx) (%%% (rbx,0,rdi)) *)
  0x45; 0x89; 0xd4;        (* MOV (% r12d) (% r10d) *)
  0x03; 0x44; 0x24; 0x6c;  (* ADD (% eax) (Memop Doubleword (%% (rsp,108))) *)
  0x45; 0x21; 0xcc;        (* AND (% r12d) (% r9d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe9; 0x19;
                           (* RORX (% r13d) (% r9d) (Imm8 (word 25)) *)
  0xc4; 0xc3; 0x7b; 0xf0; 0xf9; 0x0b;
                           (* RORX (% edi) (% r9d) (Imm8 (word 11)) *)
  0x42; 0x8d; 0x1c; 0x33;  (* LEA (% ebx) (%%% (rbx,0,r14)) *)
  0x42; 0x8d; 0x04; 0x20;  (* LEA (% eax) (%%% (rax,0,r12)) *)
  0xc4; 0x42; 0x30; 0xf2; 0xe3;
                           (* ANDN (% r12d) (% r9d) (% r11d) *)
  0x41; 0x31; 0xfd;        (* XOR (% r13d) (% edi) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf1; 0x06;
                           (* RORX (% r14d) (% r9d) (Imm8 (word 6)) *)
  0x42; 0x8d; 0x04; 0x20;  (* LEA (% eax) (%%% (rax,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x89; 0xdf;              (* MOV (% edi) (% ebx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe3; 0x16;
                           (* RORX (% r12d) (% ebx) (Imm8 (word 22)) *)
  0x42; 0x8d; 0x04; 0x28;  (* LEA (% eax) (%%% (rax,0,r13)) *)
  0x31; 0xcf;              (* XOR (% edi) (% ecx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf3; 0x0d;
                           (* RORX (% r14d) (% ebx) (Imm8 (word 13)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xeb; 0x02;
                           (* RORX (% r13d) (% ebx) (Imm8 (word 2)) *)
  0x45; 0x8d; 0x04; 0x00;  (* LEA (% r8d) (%%% (r8,0,rax)) *)
  0x41; 0x21; 0xff;        (* AND (% r15d) (% edi) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x41; 0x31; 0xcf;        (* XOR (% r15d) (% ecx) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x42; 0x8d; 0x04; 0x38;  (* LEA (% eax) (%%% (rax,0,r15)) *)
  0x45; 0x89; 0xcc;        (* MOV (% r12d) (% r9d) *)
  0x44; 0x03; 0x1c; 0x24;  (* ADD (% r11d) (Memop Doubleword (%% (rsp,0))) *)
  0x45; 0x21; 0xc4;        (* AND (% r12d) (% r8d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe8; 0x19;
                           (* RORX (% r13d) (% r8d) (Imm8 (word 25)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf8; 0x0b;
                           (* RORX (% r15d) (% r8d) (Imm8 (word 11)) *)
  0x42; 0x8d; 0x04; 0x30;  (* LEA (% eax) (%%% (rax,0,r14)) *)
  0x47; 0x8d; 0x1c; 0x23;  (* LEA (% r11d) (%%% (r11,0,r12)) *)
  0xc4; 0x42; 0x38; 0xf2; 0xe2;
                           (* ANDN (% r12d) (% r8d) (% r10d) *)
  0x45; 0x31; 0xfd;        (* XOR (% r13d) (% r15d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf0; 0x06;
                           (* RORX (% r14d) (% r8d) (Imm8 (word 6)) *)
  0x47; 0x8d; 0x1c; 0x23;  (* LEA (% r11d) (%%% (r11,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x41; 0x89; 0xc7;        (* MOV (% r15d) (% eax) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe0; 0x16;
                           (* RORX (% r12d) (% eax) (Imm8 (word 22)) *)
  0x47; 0x8d; 0x1c; 0x2b;  (* LEA (% r11d) (%%% (r11,0,r13)) *)
  0x41; 0x31; 0xdf;        (* XOR (% r15d) (% ebx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf0; 0x0d;
                           (* RORX (% r14d) (% eax) (Imm8 (word 13)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe8; 0x02;
                           (* RORX (% r13d) (% eax) (Imm8 (word 2)) *)
  0x42; 0x8d; 0x14; 0x1a;  (* LEA (% edx) (%%% (rdx,0,r11)) *)
  0x44; 0x21; 0xff;        (* AND (% edi) (% r15d) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x31; 0xdf;              (* XOR (% edi) (% ebx) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x45; 0x8d; 0x1c; 0x3b;  (* LEA (% r11d) (%%% (r11,0,rdi)) *)
  0x45; 0x89; 0xc4;        (* MOV (% r12d) (% r8d) *)
  0x44; 0x03; 0x54; 0x24; 0x04;
                           (* ADD (% r10d) (Memop Doubleword (%% (rsp,4))) *)
  0x41; 0x21; 0xd4;        (* AND (% r12d) (% edx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xea; 0x19;
                           (* RORX (% r13d) (% edx) (Imm8 (word 25)) *)
  0xc4; 0xe3; 0x7b; 0xf0; 0xfa; 0x0b;
                           (* RORX (% edi) (% edx) (Imm8 (word 11)) *)
  0x47; 0x8d; 0x1c; 0x33;  (* LEA (% r11d) (%%% (r11,0,r14)) *)
  0x47; 0x8d; 0x14; 0x22;  (* LEA (% r10d) (%%% (r10,0,r12)) *)
  0xc4; 0x42; 0x68; 0xf2; 0xe1;
                           (* ANDN (% r12d) (% edx) (% r9d) *)
  0x41; 0x31; 0xfd;        (* XOR (% r13d) (% edi) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf2; 0x06;
                           (* RORX (% r14d) (% edx) (Imm8 (word 6)) *)
  0x47; 0x8d; 0x14; 0x22;  (* LEA (% r10d) (%%% (r10,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x44; 0x89; 0xdf;        (* MOV (% edi) (% r11d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe3; 0x16;
                           (* RORX (% r12d) (% r11d) (Imm8 (word 22)) *)
  0x47; 0x8d; 0x14; 0x2a;  (* LEA (% r10d) (%%% (r10,0,r13)) *)
  0x31; 0xc7;              (* XOR (% edi) (% eax) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf3; 0x0d;
                           (* RORX (% r14d) (% r11d) (Imm8 (word 13)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xeb; 0x02;
                           (* RORX (% r13d) (% r11d) (Imm8 (word 2)) *)
  0x42; 0x8d; 0x0c; 0x11;  (* LEA (% ecx) (%%% (rcx,0,r10)) *)
  0x41; 0x21; 0xff;        (* AND (% r15d) (% edi) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x41; 0x31; 0xc7;        (* XOR (% r15d) (% eax) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x47; 0x8d; 0x14; 0x3a;  (* LEA (% r10d) (%%% (r10,0,r15)) *)
  0x41; 0x89; 0xd4;        (* MOV (% r12d) (% edx) *)
  0x44; 0x03; 0x4c; 0x24; 0x08;
                           (* ADD (% r9d) (Memop Doubleword (%% (rsp,8))) *)
  0x41; 0x21; 0xcc;        (* AND (% r12d) (% ecx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe9; 0x19;
                           (* RORX (% r13d) (% ecx) (Imm8 (word 25)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf9; 0x0b;
                           (* RORX (% r15d) (% ecx) (Imm8 (word 11)) *)
  0x47; 0x8d; 0x14; 0x32;  (* LEA (% r10d) (%%% (r10,0,r14)) *)
  0x47; 0x8d; 0x0c; 0x21;  (* LEA (% r9d) (%%% (r9,0,r12)) *)
  0xc4; 0x42; 0x70; 0xf2; 0xe0;
                           (* ANDN (% r12d) (% ecx) (% r8d) *)
  0x45; 0x31; 0xfd;        (* XOR (% r13d) (% r15d) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf1; 0x06;
                           (* RORX (% r14d) (% ecx) (Imm8 (word 6)) *)
  0x47; 0x8d; 0x0c; 0x21;  (* LEA (% r9d) (%%% (r9,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x45; 0x89; 0xd7;        (* MOV (% r15d) (% r10d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe2; 0x16;
                           (* RORX (% r12d) (% r10d) (Imm8 (word 22)) *)
  0x47; 0x8d; 0x0c; 0x29;  (* LEA (% r9d) (%%% (r9,0,r13)) *)
  0x45; 0x31; 0xdf;        (* XOR (% r15d) (% r11d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf2; 0x0d;
                           (* RORX (% r14d) (% r10d) (Imm8 (word 13)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xea; 0x02;
                           (* RORX (% r13d) (% r10d) (Imm8 (word 2)) *)
  0x42; 0x8d; 0x1c; 0x0b;  (* LEA (% ebx) (%%% (rbx,0,r9)) *)
  0x44; 0x21; 0xff;        (* AND (% edi) (% r15d) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x44; 0x31; 0xdf;        (* XOR (% edi) (% r11d) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x45; 0x8d; 0x0c; 0x39;  (* LEA (% r9d) (%%% (r9,0,rdi)) *)
  0x41; 0x89; 0xcc;        (* MOV (% r12d) (% ecx) *)
  0x44; 0x03; 0x44; 0x24; 0x0c;
                           (* ADD (% r8d) (Memop Doubleword (%% (rsp,12))) *)
  0x41; 0x21; 0xdc;        (* AND (% r12d) (% ebx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xeb; 0x19;
                           (* RORX (% r13d) (% ebx) (Imm8 (word 25)) *)
  0xc4; 0xe3; 0x7b; 0xf0; 0xfb; 0x0b;
                           (* RORX (% edi) (% ebx) (Imm8 (word 11)) *)
  0x47; 0x8d; 0x0c; 0x31;  (* LEA (% r9d) (%%% (r9,0,r14)) *)
  0x47; 0x8d; 0x04; 0x20;  (* LEA (% r8d) (%%% (r8,0,r12)) *)
  0xc4; 0x62; 0x60; 0xf2; 0xe2;
                           (* ANDN (% r12d) (% ebx) (% edx) *)
  0x41; 0x31; 0xfd;        (* XOR (% r13d) (% edi) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf3; 0x06;
                           (* RORX (% r14d) (% ebx) (Imm8 (word 6)) *)
  0x47; 0x8d; 0x04; 0x20;  (* LEA (% r8d) (%%% (r8,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x44; 0x89; 0xcf;        (* MOV (% edi) (% r9d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe1; 0x16;
                           (* RORX (% r12d) (% r9d) (Imm8 (word 22)) *)
  0x47; 0x8d; 0x04; 0x28;  (* LEA (% r8d) (%%% (r8,0,r13)) *)
  0x44; 0x31; 0xd7;        (* XOR (% edi) (% r10d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf1; 0x0d;
                           (* RORX (% r14d) (% r9d) (Imm8 (word 13)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe9; 0x02;
                           (* RORX (% r13d) (% r9d) (Imm8 (word 2)) *)
  0x42; 0x8d; 0x04; 0x00;  (* LEA (% eax) (%%% (rax,0,r8)) *)
  0x41; 0x21; 0xff;        (* AND (% r15d) (% edi) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x45; 0x31; 0xd7;        (* XOR (% r15d) (% r10d) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x47; 0x8d; 0x04; 0x38;  (* LEA (% r8d) (%%% (r8,0,r15)) *)
  0x41; 0x89; 0xdc;        (* MOV (% r12d) (% ebx) *)
  0x03; 0x54; 0x24; 0x20;  (* ADD (% edx) (Memop Doubleword (%% (rsp,32))) *)
  0x41; 0x21; 0xc4;        (* AND (% r12d) (% eax) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe8; 0x19;
                           (* RORX (% r13d) (% eax) (Imm8 (word 25)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf8; 0x0b;
                           (* RORX (% r15d) (% eax) (Imm8 (word 11)) *)
  0x47; 0x8d; 0x04; 0x30;  (* LEA (% r8d) (%%% (r8,0,r14)) *)
  0x42; 0x8d; 0x14; 0x22;  (* LEA (% edx) (%%% (rdx,0,r12)) *)
  0xc4; 0x62; 0x78; 0xf2; 0xe1;
                           (* ANDN (% r12d) (% eax) (% ecx) *)
  0x45; 0x31; 0xfd;        (* XOR (% r13d) (% r15d) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf0; 0x06;
                           (* RORX (% r14d) (% eax) (Imm8 (word 6)) *)
  0x42; 0x8d; 0x14; 0x22;  (* LEA (% edx) (%%% (rdx,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x45; 0x89; 0xc7;        (* MOV (% r15d) (% r8d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe0; 0x16;
                           (* RORX (% r12d) (% r8d) (Imm8 (word 22)) *)
  0x42; 0x8d; 0x14; 0x2a;  (* LEA (% edx) (%%% (rdx,0,r13)) *)
  0x45; 0x31; 0xcf;        (* XOR (% r15d) (% r9d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf0; 0x0d;
                           (* RORX (% r14d) (% r8d) (Imm8 (word 13)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe8; 0x02;
                           (* RORX (% r13d) (% r8d) (Imm8 (word 2)) *)
  0x45; 0x8d; 0x1c; 0x13;  (* LEA (% r11d) (%%% (r11,0,rdx)) *)
  0x44; 0x21; 0xff;        (* AND (% edi) (% r15d) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x44; 0x31; 0xcf;        (* XOR (% edi) (% r9d) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x8d; 0x14; 0x3a;        (* LEA (% edx) (%%% (rdx,0,rdi)) *)
  0x41; 0x89; 0xc4;        (* MOV (% r12d) (% eax) *)
  0x03; 0x4c; 0x24; 0x24;  (* ADD (% ecx) (Memop Doubleword (%% (rsp,36))) *)
  0x45; 0x21; 0xdc;        (* AND (% r12d) (% r11d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xeb; 0x19;
                           (* RORX (% r13d) (% r11d) (Imm8 (word 25)) *)
  0xc4; 0xc3; 0x7b; 0xf0; 0xfb; 0x0b;
                           (* RORX (% edi) (% r11d) (Imm8 (word 11)) *)
  0x42; 0x8d; 0x14; 0x32;  (* LEA (% edx) (%%% (rdx,0,r14)) *)
  0x42; 0x8d; 0x0c; 0x21;  (* LEA (% ecx) (%%% (rcx,0,r12)) *)
  0xc4; 0x62; 0x20; 0xf2; 0xe3;
                           (* ANDN (% r12d) (% r11d) (% ebx) *)
  0x41; 0x31; 0xfd;        (* XOR (% r13d) (% edi) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf3; 0x06;
                           (* RORX (% r14d) (% r11d) (Imm8 (word 6)) *)
  0x42; 0x8d; 0x0c; 0x21;  (* LEA (% ecx) (%%% (rcx,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x89; 0xd7;              (* MOV (% edi) (% edx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe2; 0x16;
                           (* RORX (% r12d) (% edx) (Imm8 (word 22)) *)
  0x42; 0x8d; 0x0c; 0x29;  (* LEA (% ecx) (%%% (rcx,0,r13)) *)
  0x44; 0x31; 0xc7;        (* XOR (% edi) (% r8d) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf2; 0x0d;
                           (* RORX (% r14d) (% edx) (Imm8 (word 13)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xea; 0x02;
                           (* RORX (% r13d) (% edx) (Imm8 (word 2)) *)
  0x45; 0x8d; 0x14; 0x0a;  (* LEA (% r10d) (%%% (r10,0,rcx)) *)
  0x41; 0x21; 0xff;        (* AND (% r15d) (% edi) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x45; 0x31; 0xc7;        (* XOR (% r15d) (% r8d) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x42; 0x8d; 0x0c; 0x39;  (* LEA (% ecx) (%%% (rcx,0,r15)) *)
  0x45; 0x89; 0xdc;        (* MOV (% r12d) (% r11d) *)
  0x03; 0x5c; 0x24; 0x28;  (* ADD (% ebx) (Memop Doubleword (%% (rsp,40))) *)
  0x45; 0x21; 0xd4;        (* AND (% r12d) (% r10d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xea; 0x19;
                           (* RORX (% r13d) (% r10d) (Imm8 (word 25)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xfa; 0x0b;
                           (* RORX (% r15d) (% r10d) (Imm8 (word 11)) *)
  0x42; 0x8d; 0x0c; 0x31;  (* LEA (% ecx) (%%% (rcx,0,r14)) *)
  0x42; 0x8d; 0x1c; 0x23;  (* LEA (% ebx) (%%% (rbx,0,r12)) *)
  0xc4; 0x62; 0x28; 0xf2; 0xe0;
                           (* ANDN (% r12d) (% r10d) (% eax) *)
  0x45; 0x31; 0xfd;        (* XOR (% r13d) (% r15d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf2; 0x06;
                           (* RORX (% r14d) (% r10d) (Imm8 (word 6)) *)
  0x42; 0x8d; 0x1c; 0x23;  (* LEA (% ebx) (%%% (rbx,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x41; 0x89; 0xcf;        (* MOV (% r15d) (% ecx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe1; 0x16;
                           (* RORX (% r12d) (% ecx) (Imm8 (word 22)) *)
  0x42; 0x8d; 0x1c; 0x2b;  (* LEA (% ebx) (%%% (rbx,0,r13)) *)
  0x41; 0x31; 0xd7;        (* XOR (% r15d) (% edx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf1; 0x0d;
                           (* RORX (% r14d) (% ecx) (Imm8 (word 13)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe9; 0x02;
                           (* RORX (% r13d) (% ecx) (Imm8 (word 2)) *)
  0x45; 0x8d; 0x0c; 0x19;  (* LEA (% r9d) (%%% (r9,0,rbx)) *)
  0x44; 0x21; 0xff;        (* AND (% edi) (% r15d) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x31; 0xd7;              (* XOR (% edi) (% edx) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x8d; 0x1c; 0x3b;        (* LEA (% ebx) (%%% (rbx,0,rdi)) *)
  0x45; 0x89; 0xd4;        (* MOV (% r12d) (% r10d) *)
  0x03; 0x44; 0x24; 0x2c;  (* ADD (% eax) (Memop Doubleword (%% (rsp,44))) *)
  0x45; 0x21; 0xcc;        (* AND (% r12d) (% r9d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe9; 0x19;
                           (* RORX (% r13d) (% r9d) (Imm8 (word 25)) *)
  0xc4; 0xc3; 0x7b; 0xf0; 0xf9; 0x0b;
                           (* RORX (% edi) (% r9d) (Imm8 (word 11)) *)
  0x42; 0x8d; 0x1c; 0x33;  (* LEA (% ebx) (%%% (rbx,0,r14)) *)
  0x42; 0x8d; 0x04; 0x20;  (* LEA (% eax) (%%% (rax,0,r12)) *)
  0xc4; 0x42; 0x30; 0xf2; 0xe3;
                           (* ANDN (% r12d) (% r9d) (% r11d) *)
  0x41; 0x31; 0xfd;        (* XOR (% r13d) (% edi) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf1; 0x06;
                           (* RORX (% r14d) (% r9d) (Imm8 (word 6)) *)
  0x42; 0x8d; 0x04; 0x20;  (* LEA (% eax) (%%% (rax,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x89; 0xdf;              (* MOV (% edi) (% ebx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe3; 0x16;
                           (* RORX (% r12d) (% ebx) (Imm8 (word 22)) *)
  0x42; 0x8d; 0x04; 0x28;  (* LEA (% eax) (%%% (rax,0,r13)) *)
  0x31; 0xcf;              (* XOR (% edi) (% ecx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf3; 0x0d;
                           (* RORX (% r14d) (% ebx) (Imm8 (word 13)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xeb; 0x02;
                           (* RORX (% r13d) (% ebx) (Imm8 (word 2)) *)
  0x45; 0x8d; 0x04; 0x00;  (* LEA (% r8d) (%%% (r8,0,rax)) *)
  0x41; 0x21; 0xff;        (* AND (% r15d) (% edi) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x41; 0x31; 0xcf;        (* XOR (% r15d) (% ecx) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x42; 0x8d; 0x04; 0x38;  (* LEA (% eax) (%%% (rax,0,r15)) *)
  0x45; 0x89; 0xcc;        (* MOV (% r12d) (% r9d) *)
  0x48; 0x8b; 0xbc; 0x24; 0x00; 0x02; 0x00; 0x00;
                           (* MOV (% rdi) (Memop Quadword (%% (rsp,512))) *)
  0x44; 0x01; 0xf0;        (* ADD (% eax) (% r14d) *)
  0x48; 0x8d; 0xac; 0x24; 0xc0; 0x01; 0x00; 0x00;
                           (* LEA (% rbp) (%% (rsp,448)) *)
  0x03; 0x07;              (* ADD (% eax) (Memop Doubleword (%% (rdi,0))) *)
  0x03; 0x5f; 0x04;        (* ADD (% ebx) (Memop Doubleword (%% (rdi,4))) *)
  0x03; 0x4f; 0x08;        (* ADD (% ecx) (Memop Doubleword (%% (rdi,8))) *)
  0x03; 0x57; 0x0c;        (* ADD (% edx) (Memop Doubleword (%% (rdi,12))) *)
  0x44; 0x03; 0x47; 0x10;  (* ADD (% r8d) (Memop Doubleword (%% (rdi,16))) *)
  0x44; 0x03; 0x4f; 0x14;  (* ADD (% r9d) (Memop Doubleword (%% (rdi,20))) *)
  0x44; 0x03; 0x57; 0x18;  (* ADD (% r10d) (Memop Doubleword (%% (rdi,24))) *)
  0x44; 0x03; 0x5f; 0x1c;  (* ADD (% r11d) (Memop Doubleword (%% (rdi,28))) *)
  0x89; 0x07;              (* MOV (Memop Doubleword (%% (rdi,0))) (% eax) *)
  0x89; 0x5f; 0x04;        (* MOV (Memop Doubleword (%% (rdi,4))) (% ebx) *)
  0x89; 0x4f; 0x08;        (* MOV (Memop Doubleword (%% (rdi,8))) (% ecx) *)
  0x89; 0x57; 0x0c;        (* MOV (Memop Doubleword (%% (rdi,12))) (% edx) *)
  0x44; 0x89; 0x47; 0x10;  (* MOV (Memop Doubleword (%% (rdi,16))) (% r8d) *)
  0x44; 0x89; 0x4f; 0x14;  (* MOV (Memop Doubleword (%% (rdi,20))) (% r9d) *)
  0x44; 0x89; 0x57; 0x18;  (* MOV (Memop Doubleword (%% (rdi,24))) (% r10d) *)
  0x44; 0x89; 0x5f; 0x1c;  (* MOV (Memop Doubleword (%% (rdi,28))) (% r11d) *)
  0x48; 0x3b; 0x75; 0x50;  (* CMP (% rsi) (Memop Quadword (%% (rbp,80))) *)
  0x0f; 0x84; 0x9a; 0x03; 0x00; 0x00;
                           (* JE (Imm32 (word 922)) *)
  0x45; 0x31; 0xf6;        (* XOR (% r14d) (% r14d) *)
  0x89; 0xdf;              (* MOV (% edi) (% ebx) *)
  0x31; 0xcf;              (* XOR (% edi) (% ecx) *)
  0x45; 0x89; 0xcc;        (* MOV (% r12d) (% r9d) *)
  0xeb; 0x0f;              (* JMP (Imm8 (word 15)) *)
  0x66; 0x2e; 0x0f; 0x1f; 0x84; 0x00; 0x00; 0x00; 0x00; 0x00;
                           (* NOP_N (Memop Word (%%% (rax,0,rax))) *)
  0x0f; 0x1f; 0x44; 0x00; 0x00;
                           (* NOP_N (Memop Doubleword (%%% (rax,0,rax))) *)
  0x44; 0x03; 0x5d; 0x10;  (* ADD (% r11d) (Memop Doubleword (%% (rbp,16))) *)
  0x45; 0x21; 0xc4;        (* AND (% r12d) (% r8d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe8; 0x19;
                           (* RORX (% r13d) (% r8d) (Imm8 (word 25)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf8; 0x0b;
                           (* RORX (% r15d) (% r8d) (Imm8 (word 11)) *)
  0x42; 0x8d; 0x04; 0x30;  (* LEA (% eax) (%%% (rax,0,r14)) *)
  0x47; 0x8d; 0x1c; 0x23;  (* LEA (% r11d) (%%% (r11,0,r12)) *)
  0xc4; 0x42; 0x38; 0xf2; 0xe2;
                           (* ANDN (% r12d) (% r8d) (% r10d) *)
  0x45; 0x31; 0xfd;        (* XOR (% r13d) (% r15d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf0; 0x06;
                           (* RORX (% r14d) (% r8d) (Imm8 (word 6)) *)
  0x47; 0x8d; 0x1c; 0x23;  (* LEA (% r11d) (%%% (r11,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x41; 0x89; 0xc7;        (* MOV (% r15d) (% eax) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe0; 0x16;
                           (* RORX (% r12d) (% eax) (Imm8 (word 22)) *)
  0x47; 0x8d; 0x1c; 0x2b;  (* LEA (% r11d) (%%% (r11,0,r13)) *)
  0x41; 0x31; 0xdf;        (* XOR (% r15d) (% ebx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf0; 0x0d;
                           (* RORX (% r14d) (% eax) (Imm8 (word 13)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe8; 0x02;
                           (* RORX (% r13d) (% eax) (Imm8 (word 2)) *)
  0x42; 0x8d; 0x14; 0x1a;  (* LEA (% edx) (%%% (rdx,0,r11)) *)
  0x44; 0x21; 0xff;        (* AND (% edi) (% r15d) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x31; 0xdf;              (* XOR (% edi) (% ebx) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x45; 0x8d; 0x1c; 0x3b;  (* LEA (% r11d) (%%% (r11,0,rdi)) *)
  0x45; 0x89; 0xc4;        (* MOV (% r12d) (% r8d) *)
  0x44; 0x03; 0x55; 0x14;  (* ADD (% r10d) (Memop Doubleword (%% (rbp,20))) *)
  0x41; 0x21; 0xd4;        (* AND (% r12d) (% edx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xea; 0x19;
                           (* RORX (% r13d) (% edx) (Imm8 (word 25)) *)
  0xc4; 0xe3; 0x7b; 0xf0; 0xfa; 0x0b;
                           (* RORX (% edi) (% edx) (Imm8 (word 11)) *)
  0x47; 0x8d; 0x1c; 0x33;  (* LEA (% r11d) (%%% (r11,0,r14)) *)
  0x47; 0x8d; 0x14; 0x22;  (* LEA (% r10d) (%%% (r10,0,r12)) *)
  0xc4; 0x42; 0x68; 0xf2; 0xe1;
                           (* ANDN (% r12d) (% edx) (% r9d) *)
  0x41; 0x31; 0xfd;        (* XOR (% r13d) (% edi) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf2; 0x06;
                           (* RORX (% r14d) (% edx) (Imm8 (word 6)) *)
  0x47; 0x8d; 0x14; 0x22;  (* LEA (% r10d) (%%% (r10,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x44; 0x89; 0xdf;        (* MOV (% edi) (% r11d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe3; 0x16;
                           (* RORX (% r12d) (% r11d) (Imm8 (word 22)) *)
  0x47; 0x8d; 0x14; 0x2a;  (* LEA (% r10d) (%%% (r10,0,r13)) *)
  0x31; 0xc7;              (* XOR (% edi) (% eax) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf3; 0x0d;
                           (* RORX (% r14d) (% r11d) (Imm8 (word 13)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xeb; 0x02;
                           (* RORX (% r13d) (% r11d) (Imm8 (word 2)) *)
  0x42; 0x8d; 0x0c; 0x11;  (* LEA (% ecx) (%%% (rcx,0,r10)) *)
  0x41; 0x21; 0xff;        (* AND (% r15d) (% edi) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x41; 0x31; 0xc7;        (* XOR (% r15d) (% eax) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x47; 0x8d; 0x14; 0x3a;  (* LEA (% r10d) (%%% (r10,0,r15)) *)
  0x41; 0x89; 0xd4;        (* MOV (% r12d) (% edx) *)
  0x44; 0x03; 0x4d; 0x18;  (* ADD (% r9d) (Memop Doubleword (%% (rbp,24))) *)
  0x41; 0x21; 0xcc;        (* AND (% r12d) (% ecx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe9; 0x19;
                           (* RORX (% r13d) (% ecx) (Imm8 (word 25)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf9; 0x0b;
                           (* RORX (% r15d) (% ecx) (Imm8 (word 11)) *)
  0x47; 0x8d; 0x14; 0x32;  (* LEA (% r10d) (%%% (r10,0,r14)) *)
  0x47; 0x8d; 0x0c; 0x21;  (* LEA (% r9d) (%%% (r9,0,r12)) *)
  0xc4; 0x42; 0x70; 0xf2; 0xe0;
                           (* ANDN (% r12d) (% ecx) (% r8d) *)
  0x45; 0x31; 0xfd;        (* XOR (% r13d) (% r15d) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf1; 0x06;
                           (* RORX (% r14d) (% ecx) (Imm8 (word 6)) *)
  0x47; 0x8d; 0x0c; 0x21;  (* LEA (% r9d) (%%% (r9,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x45; 0x89; 0xd7;        (* MOV (% r15d) (% r10d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe2; 0x16;
                           (* RORX (% r12d) (% r10d) (Imm8 (word 22)) *)
  0x47; 0x8d; 0x0c; 0x29;  (* LEA (% r9d) (%%% (r9,0,r13)) *)
  0x45; 0x31; 0xdf;        (* XOR (% r15d) (% r11d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf2; 0x0d;
                           (* RORX (% r14d) (% r10d) (Imm8 (word 13)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xea; 0x02;
                           (* RORX (% r13d) (% r10d) (Imm8 (word 2)) *)
  0x42; 0x8d; 0x1c; 0x0b;  (* LEA (% ebx) (%%% (rbx,0,r9)) *)
  0x44; 0x21; 0xff;        (* AND (% edi) (% r15d) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x44; 0x31; 0xdf;        (* XOR (% edi) (% r11d) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x45; 0x8d; 0x0c; 0x39;  (* LEA (% r9d) (%%% (r9,0,rdi)) *)
  0x41; 0x89; 0xcc;        (* MOV (% r12d) (% ecx) *)
  0x44; 0x03; 0x45; 0x1c;  (* ADD (% r8d) (Memop Doubleword (%% (rbp,28))) *)
  0x41; 0x21; 0xdc;        (* AND (% r12d) (% ebx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xeb; 0x19;
                           (* RORX (% r13d) (% ebx) (Imm8 (word 25)) *)
  0xc4; 0xe3; 0x7b; 0xf0; 0xfb; 0x0b;
                           (* RORX (% edi) (% ebx) (Imm8 (word 11)) *)
  0x47; 0x8d; 0x0c; 0x31;  (* LEA (% r9d) (%%% (r9,0,r14)) *)
  0x47; 0x8d; 0x04; 0x20;  (* LEA (% r8d) (%%% (r8,0,r12)) *)
  0xc4; 0x62; 0x60; 0xf2; 0xe2;
                           (* ANDN (% r12d) (% ebx) (% edx) *)
  0x41; 0x31; 0xfd;        (* XOR (% r13d) (% edi) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf3; 0x06;
                           (* RORX (% r14d) (% ebx) (Imm8 (word 6)) *)
  0x47; 0x8d; 0x04; 0x20;  (* LEA (% r8d) (%%% (r8,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x44; 0x89; 0xcf;        (* MOV (% edi) (% r9d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe1; 0x16;
                           (* RORX (% r12d) (% r9d) (Imm8 (word 22)) *)
  0x47; 0x8d; 0x04; 0x28;  (* LEA (% r8d) (%%% (r8,0,r13)) *)
  0x44; 0x31; 0xd7;        (* XOR (% edi) (% r10d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf1; 0x0d;
                           (* RORX (% r14d) (% r9d) (Imm8 (word 13)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe9; 0x02;
                           (* RORX (% r13d) (% r9d) (Imm8 (word 2)) *)
  0x42; 0x8d; 0x04; 0x00;  (* LEA (% eax) (%%% (rax,0,r8)) *)
  0x41; 0x21; 0xff;        (* AND (% r15d) (% edi) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x45; 0x31; 0xd7;        (* XOR (% r15d) (% r10d) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x47; 0x8d; 0x04; 0x38;  (* LEA (% r8d) (%%% (r8,0,r15)) *)
  0x41; 0x89; 0xdc;        (* MOV (% r12d) (% ebx) *)
  0x03; 0x55; 0x30;        (* ADD (% edx) (Memop Doubleword (%% (rbp,48))) *)
  0x41; 0x21; 0xc4;        (* AND (% r12d) (% eax) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe8; 0x19;
                           (* RORX (% r13d) (% eax) (Imm8 (word 25)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf8; 0x0b;
                           (* RORX (% r15d) (% eax) (Imm8 (word 11)) *)
  0x47; 0x8d; 0x04; 0x30;  (* LEA (% r8d) (%%% (r8,0,r14)) *)
  0x42; 0x8d; 0x14; 0x22;  (* LEA (% edx) (%%% (rdx,0,r12)) *)
  0xc4; 0x62; 0x78; 0xf2; 0xe1;
                           (* ANDN (% r12d) (% eax) (% ecx) *)
  0x45; 0x31; 0xfd;        (* XOR (% r13d) (% r15d) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf0; 0x06;
                           (* RORX (% r14d) (% eax) (Imm8 (word 6)) *)
  0x42; 0x8d; 0x14; 0x22;  (* LEA (% edx) (%%% (rdx,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x45; 0x89; 0xc7;        (* MOV (% r15d) (% r8d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe0; 0x16;
                           (* RORX (% r12d) (% r8d) (Imm8 (word 22)) *)
  0x42; 0x8d; 0x14; 0x2a;  (* LEA (% edx) (%%% (rdx,0,r13)) *)
  0x45; 0x31; 0xcf;        (* XOR (% r15d) (% r9d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf0; 0x0d;
                           (* RORX (% r14d) (% r8d) (Imm8 (word 13)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe8; 0x02;
                           (* RORX (% r13d) (% r8d) (Imm8 (word 2)) *)
  0x45; 0x8d; 0x1c; 0x13;  (* LEA (% r11d) (%%% (r11,0,rdx)) *)
  0x44; 0x21; 0xff;        (* AND (% edi) (% r15d) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x44; 0x31; 0xcf;        (* XOR (% edi) (% r9d) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x8d; 0x14; 0x3a;        (* LEA (% edx) (%%% (rdx,0,rdi)) *)
  0x41; 0x89; 0xc4;        (* MOV (% r12d) (% eax) *)
  0x03; 0x4d; 0x34;        (* ADD (% ecx) (Memop Doubleword (%% (rbp,52))) *)
  0x45; 0x21; 0xdc;        (* AND (% r12d) (% r11d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xeb; 0x19;
                           (* RORX (% r13d) (% r11d) (Imm8 (word 25)) *)
  0xc4; 0xc3; 0x7b; 0xf0; 0xfb; 0x0b;
                           (* RORX (% edi) (% r11d) (Imm8 (word 11)) *)
  0x42; 0x8d; 0x14; 0x32;  (* LEA (% edx) (%%% (rdx,0,r14)) *)
  0x42; 0x8d; 0x0c; 0x21;  (* LEA (% ecx) (%%% (rcx,0,r12)) *)
  0xc4; 0x62; 0x20; 0xf2; 0xe3;
                           (* ANDN (% r12d) (% r11d) (% ebx) *)
  0x41; 0x31; 0xfd;        (* XOR (% r13d) (% edi) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf3; 0x06;
                           (* RORX (% r14d) (% r11d) (Imm8 (word 6)) *)
  0x42; 0x8d; 0x0c; 0x21;  (* LEA (% ecx) (%%% (rcx,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x89; 0xd7;              (* MOV (% edi) (% edx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe2; 0x16;
                           (* RORX (% r12d) (% edx) (Imm8 (word 22)) *)
  0x42; 0x8d; 0x0c; 0x29;  (* LEA (% ecx) (%%% (rcx,0,r13)) *)
  0x44; 0x31; 0xc7;        (* XOR (% edi) (% r8d) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf2; 0x0d;
                           (* RORX (% r14d) (% edx) (Imm8 (word 13)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xea; 0x02;
                           (* RORX (% r13d) (% edx) (Imm8 (word 2)) *)
  0x45; 0x8d; 0x14; 0x0a;  (* LEA (% r10d) (%%% (r10,0,rcx)) *)
  0x41; 0x21; 0xff;        (* AND (% r15d) (% edi) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x45; 0x31; 0xc7;        (* XOR (% r15d) (% r8d) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x42; 0x8d; 0x0c; 0x39;  (* LEA (% ecx) (%%% (rcx,0,r15)) *)
  0x45; 0x89; 0xdc;        (* MOV (% r12d) (% r11d) *)
  0x03; 0x5d; 0x38;        (* ADD (% ebx) (Memop Doubleword (%% (rbp,56))) *)
  0x45; 0x21; 0xd4;        (* AND (% r12d) (% r10d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xea; 0x19;
                           (* RORX (% r13d) (% r10d) (Imm8 (word 25)) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xfa; 0x0b;
                           (* RORX (% r15d) (% r10d) (Imm8 (word 11)) *)
  0x42; 0x8d; 0x0c; 0x31;  (* LEA (% ecx) (%%% (rcx,0,r14)) *)
  0x42; 0x8d; 0x1c; 0x23;  (* LEA (% ebx) (%%% (rbx,0,r12)) *)
  0xc4; 0x62; 0x28; 0xf2; 0xe0;
                           (* ANDN (% r12d) (% r10d) (% eax) *)
  0x45; 0x31; 0xfd;        (* XOR (% r13d) (% r15d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf2; 0x06;
                           (* RORX (% r14d) (% r10d) (Imm8 (word 6)) *)
  0x42; 0x8d; 0x1c; 0x23;  (* LEA (% ebx) (%%% (rbx,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x41; 0x89; 0xcf;        (* MOV (% r15d) (% ecx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe1; 0x16;
                           (* RORX (% r12d) (% ecx) (Imm8 (word 22)) *)
  0x42; 0x8d; 0x1c; 0x2b;  (* LEA (% ebx) (%%% (rbx,0,r13)) *)
  0x41; 0x31; 0xd7;        (* XOR (% r15d) (% edx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf1; 0x0d;
                           (* RORX (% r14d) (% ecx) (Imm8 (word 13)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe9; 0x02;
                           (* RORX (% r13d) (% ecx) (Imm8 (word 2)) *)
  0x45; 0x8d; 0x0c; 0x19;  (* LEA (% r9d) (%%% (r9,0,rbx)) *)
  0x44; 0x21; 0xff;        (* AND (% edi) (% r15d) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x31; 0xd7;              (* XOR (% edi) (% edx) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x8d; 0x1c; 0x3b;        (* LEA (% ebx) (%%% (rbx,0,rdi)) *)
  0x45; 0x89; 0xd4;        (* MOV (% r12d) (% r10d) *)
  0x03; 0x45; 0x3c;        (* ADD (% eax) (Memop Doubleword (%% (rbp,60))) *)
  0x45; 0x21; 0xcc;        (* AND (% r12d) (% r9d) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xe9; 0x19;
                           (* RORX (% r13d) (% r9d) (Imm8 (word 25)) *)
  0xc4; 0xc3; 0x7b; 0xf0; 0xf9; 0x0b;
                           (* RORX (% edi) (% r9d) (Imm8 (word 11)) *)
  0x42; 0x8d; 0x1c; 0x33;  (* LEA (% ebx) (%%% (rbx,0,r14)) *)
  0x42; 0x8d; 0x04; 0x20;  (* LEA (% eax) (%%% (rax,0,r12)) *)
  0xc4; 0x42; 0x30; 0xf2; 0xe3;
                           (* ANDN (% r12d) (% r9d) (% r11d) *)
  0x41; 0x31; 0xfd;        (* XOR (% r13d) (% edi) *)
  0xc4; 0x43; 0x7b; 0xf0; 0xf1; 0x06;
                           (* RORX (% r14d) (% r9d) (Imm8 (word 6)) *)
  0x42; 0x8d; 0x04; 0x20;  (* LEA (% eax) (%%% (rax,0,r12)) *)
  0x45; 0x31; 0xf5;        (* XOR (% r13d) (% r14d) *)
  0x89; 0xdf;              (* MOV (% edi) (% ebx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xe3; 0x16;
                           (* RORX (% r12d) (% ebx) (Imm8 (word 22)) *)
  0x42; 0x8d; 0x04; 0x28;  (* LEA (% eax) (%%% (rax,0,r13)) *)
  0x31; 0xcf;              (* XOR (% edi) (% ecx) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xf3; 0x0d;
                           (* RORX (% r14d) (% ebx) (Imm8 (word 13)) *)
  0xc4; 0x63; 0x7b; 0xf0; 0xeb; 0x02;
                           (* RORX (% r13d) (% ebx) (Imm8 (word 2)) *)
  0x45; 0x8d; 0x04; 0x00;  (* LEA (% r8d) (%%% (r8,0,rax)) *)
  0x41; 0x21; 0xff;        (* AND (% r15d) (% edi) *)
  0x45; 0x31; 0xe6;        (* XOR (% r14d) (% r12d) *)
  0x41; 0x31; 0xcf;        (* XOR (% r15d) (% ecx) *)
  0x45; 0x31; 0xee;        (* XOR (% r14d) (% r13d) *)
  0x42; 0x8d; 0x04; 0x38;  (* LEA (% eax) (%%% (rax,0,r15)) *)
  0x45; 0x89; 0xcc;        (* MOV (% r12d) (% r9d) *)
  0x48; 0x8d; 0x6d; 0xc0;  (* LEA (% rbp) (%% (rbp,18446744073709551552)) *)
  0x48; 0x39; 0xe5;        (* CMP (% rbp) (% rsp) *)
  0x0f; 0x83; 0xe7; 0xfc; 0xff; 0xff;
                           (* JAE (Imm32 (word 4294966503)) *)
  0x48; 0x8b; 0xbc; 0x24; 0x00; 0x02; 0x00; 0x00;
                           (* MOV (% rdi) (Memop Quadword (%% (rsp,512))) *)
  0x44; 0x01; 0xf0;        (* ADD (% eax) (% r14d) *)
  0x48; 0x8d; 0xa4; 0x24; 0xc0; 0x01; 0x00; 0x00;
                           (* LEA (% rsp) (%% (rsp,448)) *)
  0x03; 0x07;              (* ADD (% eax) (Memop Doubleword (%% (rdi,0))) *)
  0x03; 0x5f; 0x04;        (* ADD (% ebx) (Memop Doubleword (%% (rdi,4))) *)
  0x03; 0x4f; 0x08;        (* ADD (% ecx) (Memop Doubleword (%% (rdi,8))) *)
  0x03; 0x57; 0x0c;        (* ADD (% edx) (Memop Doubleword (%% (rdi,12))) *)
  0x44; 0x03; 0x47; 0x10;  (* ADD (% r8d) (Memop Doubleword (%% (rdi,16))) *)
  0x44; 0x03; 0x4f; 0x14;  (* ADD (% r9d) (Memop Doubleword (%% (rdi,20))) *)
  0x48; 0x8d; 0xb6; 0x80; 0x00; 0x00; 0x00;
                           (* LEA (% rsi) (%% (rsi,128)) *)
  0x44; 0x03; 0x57; 0x18;  (* ADD (% r10d) (Memop Doubleword (%% (rdi,24))) *)
  0x49; 0x89; 0xf4;        (* MOV (% r12) (% rsi) *)
  0x44; 0x03; 0x5f; 0x1c;  (* ADD (% r11d) (Memop Doubleword (%% (rdi,28))) *)
  0x48; 0x3b; 0x74; 0x24; 0x50;
                           (* CMP (% rsi) (Memop Quadword (%% (rsp,80))) *)
  0x89; 0x07;              (* MOV (Memop Doubleword (%% (rdi,0))) (% eax) *)
  0x4c; 0x0f; 0x44; 0xe4;  (* CMOVE (% r12) (% rsp) *)
  0x89; 0x5f; 0x04;        (* MOV (Memop Doubleword (%% (rdi,4))) (% ebx) *)
  0x89; 0x4f; 0x08;        (* MOV (Memop Doubleword (%% (rdi,8))) (% ecx) *)
  0x89; 0x57; 0x0c;        (* MOV (Memop Doubleword (%% (rdi,12))) (% edx) *)
  0x44; 0x89; 0x47; 0x10;  (* MOV (Memop Doubleword (%% (rdi,16))) (% r8d) *)
  0x44; 0x89; 0x4f; 0x14;  (* MOV (Memop Doubleword (%% (rdi,20))) (% r9d) *)
  0x44; 0x89; 0x57; 0x18;  (* MOV (Memop Doubleword (%% (rdi,24))) (% r10d) *)
  0x44; 0x89; 0x5f; 0x1c;  (* MOV (Memop Doubleword (%% (rdi,28))) (% r11d) *)
  0x0f; 0x86; 0x85; 0xec; 0xff; 0xff;
                           (* JBE (Imm32 (word 4294962309)) *)
  0x48; 0x8d; 0x2c; 0x24;  (* LEA (% rbp) (%% (rsp,0)) *)
  0x48; 0x8b; 0x75; 0x58;  (* MOV (% rsi) (Memop Quadword (%% (rbp,88))) *)
  0xc5; 0xf8; 0x77;        (* VZEROUPPER *)
  0x4c; 0x8b; 0x7e; 0xd0;  (* MOV (% r15) (Memop Quadword (%% (rsi,18446744073709551568))) *)
  0x4c; 0x8b; 0x76; 0xd8;  (* MOV (% r14) (Memop Quadword (%% (rsi,18446744073709551576))) *)
  0x4c; 0x8b; 0x6e; 0xe0;  (* MOV (% r13) (Memop Quadword (%% (rsi,18446744073709551584))) *)
  0x4c; 0x8b; 0x66; 0xe8;  (* MOV (% r12) (Memop Quadword (%% (rsi,18446744073709551592))) *)
  0x48; 0x8b; 0x6e; 0xf0;  (* MOV (% rbp) (Memop Quadword (%% (rsi,18446744073709551600))) *)
  0x48; 0x8b; 0x5e; 0xf8;  (* MOV (% rbx) (Memop Quadword (%% (rsi,18446744073709551608))) *)
  0x48; 0x8d; 0x26;        (* LEA (% rsp) (%% (rsi,0)) *)
  0xf3; 0xc3               (* RET *)
]]);;
let sha256_avx2_k256 = hd sha256_avx2_data;;
let SHA256_AVX2_EXEC = X86_MK_EXEC_RULE sha256_avx2_mc;;


(* ------------------------------------------------------------------------- *)
(* The 32-bit scalar instructions' results as plain 32-bit words.            *)
(* ------------------------------------------------------------------------- *)

let SHA256_ZX_ZX = prove
 (`!x:int32. (word_zx:int64->int32) (word_zx x) = x`,
  SIMP_TAC[WORD_ZX_ZX; DIMINDEX_32; DIMINDEX_64; ARITH]);;

let SHA256_SX_ZX = prove
 (`!x:int32. (word_sx:int64->int32) (word_zx x) = x`,
  SIMP_TAC[WORD_SX_ZX; DIMINDEX_32; DIMINDEX_64; ARITH; SHA256_ZX_ZX]);;

let SHA256_LEA32 = prove
 (`!x y:int32. (word_sx:int64->int32)
      (word_add (word_zx x) (word (1 * val ((word_zx:int32->int64) y)))) = word_add x y`,
  REWRITE_TAC[MULT_CLAUSES; WORD_VAL] THEN
  SIMP_TAC[WORD_SX_ZX; WORD_ZX_ADD; DIMINDEX_32; DIMINDEX_64; ARITH; SHA256_ZX_ZX]);;

let SHA256_SUB_ADD = WORD_RULE `!a p:int32. word_add (word_sub a p) p = a`;;

(* ------------------------------------------------------------------------- *)
(* The rounds. Sigma0 of a is added to the new a a round late, and Maj       *)
(* reuses the previous round's b xor c.                                      *)
(* ------------------------------------------------------------------------- *)

let SHA256_CH_ADD = prove
 (`!e f g x:int32. word_add (word_add x (word_and f e)) (word_and (word_not e) g) =
                   word_add x (sha_choose e f g)`,
  REWRITE_TAC[GSYM WORD_ADD_ASSOC; sha_choose] THEN
  REPEAT GEN_TAC THEN AP_TERM_TAC THEN CONV_TAC WORD_BLAST);;

let SHA256_MAJ_XOR = prove
 (`!a b c:int32. word_xor (word_and (word_xor b c) (word_xor a b)) b = sha_maj a b c`,
  REWRITE_TAC[sha_maj] THEN CONV_TAC WORD_BLAST);;

let SHA256_SIGMA1_RORX = prove
 (`!e:int32. word_xor (word_xor (word_ror e 25) (word_ror e 11)) (word_ror e 6) =
             sha_hash_sigma_1 e`,
  REWRITE_TAC[sha_hash_sigma_1] THEN CONV_TAC WORD_BLAST);;

let SHA256_SIGMA0_RORX = prove
 (`!a:int32. word_xor (word_xor (word_ror a 13) (word_ror a 22)) (word_ror a 2) =
             sha_hash_sigma_0 a`,
  REWRITE_TAC[sha_hash_sigma_0] THEN CONV_TAC WORD_BLAST);;

let SHA256_AVX2_ROUND = prove
 (`!S k w a b c d e f g h:int32.
     EL 0 S = a /\ EL 1 S = b /\ EL 2 S = c /\ EL 3 S = d /\
     EL 4 S = e /\ EL 5 S = f /\ EL 6 S = g /\ EL 7 S = h
     ==> word_add
          (word_add (word_add (word_add (word_add h (word_add w k)) (word_and f e))
                              (word_and (word_not e) g))
                    (word_xor (word_xor (word_ror e 25) (word_ror e 11)) (word_ror e 6)))
          (word_xor (word_and (word_xor b c) (word_xor a b)) b) =
         word_sub (EL 0 (sha256_round S k w)) (sha_hash_sigma_0 a) /\
         word_add d
          (word_add (word_add (word_add (word_add h (word_add w k)) (word_and f e))
                              (word_and (word_not e) g))
                    (word_xor (word_xor (word_ror e 25) (word_ror e 11)) (word_ror e 6))) =
         EL 4 (sha256_round S k w)`,
  REPEAT GEN_TAC THEN STRIP_TAC THEN
  REWRITE_TAC[sha256_round] THEN CONV_TAC(TOP_DEPTH_CONV let_CONV) THEN
  CONV_TAC(DEPTH_CONV EL_CONV) THEN ASM_REWRITE_TAC[] THEN
  REWRITE_TAC[SHA256_CH_ADD; SHA256_MAJ_XOR; SHA256_SIGMA1_RORX] THEN
  CONV_TAC WORD_RULE);;

let SHA256_ROUND_SHIFT = prove
 (`!S k w. EL 1 (sha256_round S k w) = EL 0 S /\ EL 2 (sha256_round S k w) = EL 1 S /\
           EL 3 (sha256_round S k w) = EL 2 S /\ EL 5 (sha256_round S k w) = EL 4 S /\
           EL 6 (sha256_round S k w) = EL 5 S /\ EL 7 (sha256_round S k w) = EL 6 S`,
  REWRITE_TAC[sha256_round] THEN CONV_TAC(TOP_DEPTH_CONV let_CONV) THEN
  CONV_TAC(DEPTH_CONV EL_CONV) THEN REWRITE_TAC[]);;

let SHA256_CR_SHIFT = prove
 (`!M H t.
     EL 1 (sha256_compress_rounds M H (t + 1)) = EL 0 (sha256_compress_rounds M H t) /\
     EL 2 (sha256_compress_rounds M H (t + 1)) = EL 1 (sha256_compress_rounds M H t) /\
     EL 3 (sha256_compress_rounds M H (t + 1)) = EL 2 (sha256_compress_rounds M H t) /\
     EL 5 (sha256_compress_rounds M H (t + 1)) = EL 4 (sha256_compress_rounds M H t) /\
     EL 6 (sha256_compress_rounds M H (t + 1)) = EL 5 (sha256_compress_rounds M H t) /\
     EL 7 (sha256_compress_rounds M H (t + 1)) = EL 6 (sha256_compress_rounds M H t)`,
  REWRITE_TAC[sha256_compress_rounds; SHA256_ROUND_SHIFT]);;

(* Every state word is named after the round that made it: the a-line
   EL 0 (C j) or the e-line EL 4 (C j) of round j, where C j is
   sha256_compress_rounds M H j, or a word of H, so a word keeps its name as
   the rounds go by and each round's fold is fixed in advance. *)
let sha256_cr t = mk_comb(`sha256_compress_rounds (M:int32 list) (H:int32 list)`, mk_small_numeral t);;
let sha256_el k l = mk_comb(mk_comb(`EL:num->int32 list->int32`, mk_small_numeral k), l);;
let sha256_canon t k =
  let base = if k < 4 then 0 else 4 in
  let j = t - (k - base) in
  if j >= 1 then sha256_el base (sha256_cr j) else sha256_el (k - t) `H:int32 list`;;

(* |- EL k (C t) = its name *)
let rec SHA256_CANON t k =
  let tm = sha256_el k (sha256_cr t) in
  if t = 0 then REWRITE_CONV[sha256_compress_rounds] tm
  else if k = 0 || k = 4 then REFL tm
  else
    let th = CONV_RULE(DEPTH_CONV NUM_ADD_CONV)
      (SPECL [`M:int32 list`; `H:int32 list`; mk_small_numeral (t-1)] SHA256_CR_SHIFT) in
    TRANS (REWRITE_CONV[th] tm) (SHA256_CANON (t-1) (k-1));;

let SHA256_K_AT t =
  (REWRITE_CONV[sha256_constants] THENC EL_CONV)
    (mk_comb(mk_comb(`EL:num->int32 list->int32`, mk_small_numeral t), `sha256_constants`));;

(* Round t's new a, less Sigma0 of the old, and its new e, as the routine
   computes them from the names of the round's inputs. *)
let SHA256_ROUND_AT t =
  let k = rhs(concl(SHA256_K_AT t))
  and w = mk_comb(`sha256_msg_schedule (M:int32 list)`, mk_small_numeral t) in
  let th = ISPECL ([sha256_cr t; k; w] @ map (sha256_canon t) (0--7)) SHA256_AVX2_ROUND in
  let th = MP th (end_itlist CONJ (map (SHA256_CANON t) (0--7))) in
  let step = CONV_RULE(DEPTH_CONV NUM_ADD_CONV)
    (INST [`M:int32 list`,`m:int32 list`; `H:int32 list`,`hsh:int32 list`;
           mk_small_numeral t,`n:num`] (CONJUNCT2 sha256_compress_rounds)) in
  REWRITE_RULE[GSYM (REWRITE_RULE[SHA256_K_AT t] step)] th;;

let SHA256_ROUND_THS = map SHA256_ROUND_AT (0--63);;

(* ------------------------------------------------------------------------- *)
(* The message schedule, in each 32-bit lane of the 256-bit registers.       *)
(* ------------------------------------------------------------------------- *)

let SHA256_SUBWORD_USHR = prove
 (`!(x:N word) n p l. p + n + l <= dimindex(:N)
     ==> (word_subword (word_ushr x n) (p,l):M word) = word_subword x (p + n,l)`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[WORD_EQ_BITS_ALT; BIT_WORD_SUBWORD; BIT_WORD_USHR] THEN
  X_GEN_TAC `i:num` THEN DISCH_TAC THEN REWRITE_TAC[ADD_AC] THEN
  ASM_CASES_TAC `i < l` THEN ASM_REWRITE_TAC[] THEN
  MATCH_MP_TAC(TAUT `p ==> (p /\ q <=> q)`) THEN ASM_ARITH_TAC);;

let SHA256_USHR_CONV tm =
  let th = PART_MATCH (lhand o rand) SHA256_SUBWORD_USHR tm in
  let th = MP th (EQT_ELIM (DEPTH_CONV(DIMINDEX_CONV ORELSEC NUM_RED_CONV) (lhand (concl th)))) in
  CONV_RULE (RAND_CONV (RAND_CONV (LAND_CONV NUM_ADD_CONV))) th;;

(* sigma0 from 32-bit shifts, and sigma1's rotations from 64-bit shifts of a
   word duplicated into both halves, whose low halves vpshufb gathers byte by
   byte. *)
let SHA256_SIGMA0_AVX2 = prove
 (`!x:int32.
     word_xor (word_xor (word_xor (word_xor (word_ushr x 3) (word_ushr x 7)) (word_shl x 14))
                        (word_ushr (word_ushr x 7) 11))
              (word_shl (word_shl x 14) 11) = sha_msg_sigma_0 x`,
  REWRITE_TAC[sha_msg_sigma_0] THEN CONV_TAC WORD_BLAST);;

let SHA256_SIGMA1_AVX2 = prove
 (`!w:int32.
     (word_join:int16->int16->int32)
      ((word_join:byte->byte->int16)
        (word_xor (word_xor (word_subword (word_ushr w 10) (24,8)) (word_subword w (9,8)))
                  (word_subword w (11,8)))
        (word_xor (word_xor (word_subword (word_ushr w 10) (16,8)) (word_subword w (1,8)))
                  (word_subword w (3,8))))
      ((word_join:byte->byte->int16)
        (word_xor (word_xor (word_subword w (18,8))
                            (word_subword ((word_join:int32->int32->int64) w w) (25,8)))
                  (word_subword ((word_join:int32->int32->int64) w w) (27,8)))
        (word_xor (word_xor (word_subword w (10,8)) (word_subword w (17,8)))
                  (word_subword w (19,8)))) = sha_msg_sigma_1 w`,
  REWRITE_TAC[sha_msg_sigma_1] THEN CONV_TAC WORD_BLAST);;

(* The routine's sum for schedule word t, in the order it adds them. *)
let SHA256_SCHED_AT t =
  let s j = mk_comb(`sha256_msg_schedule (M:int32 list)`, mk_small_numeral j) in
  let tm = subst [s (t-16),`w0:int32`; s (t-7),`w9:int32`; s (t-15),`w1:int32`;
                  s (t-2),`w14:int32`; s t,`wt:int32`]
    `word_add (word_add (word_add w0 w9) (sha_msg_sigma_0 w1)) (sha_msg_sigma_1 w14) = wt` in
  prove(tm, CONV_TAC(RAND_CONV(REWR_CONV sha256_msg_schedule)) THEN
            CONV_TAC(DEPTH_CONV NUM_RED_CONV) THEN REWRITE_TAC[] THEN CONV_TAC WORD_RULE);;

let SHA256_SCHED_THS = map SHA256_SCHED_AT (16--63);;

let SHA256_SCHED_SMALL = map (fun t ->
  let tm = mk_comb(`sha256_msg_schedule (M:int32 list)`, mk_small_numeral t) in
  SYM(CONV_RULE(RAND_CONV(RATOR_CONV(LAND_CONV NUM_LT_CONV) THENC REWRITE_CONV[]))
        (REWR_CONV sha256_msg_schedule tm))) (0--15);;

(* vpshufb's byte swap undoing the load of a big-endian word. *)
let SHA256_BSWAP = prove
 (`!w:int32. (word_join:int16->int16->int32)
      ((word_join:byte->byte->int16) (word_subword (word_bytereverse w) (0,8))
                                     (word_subword (word_bytereverse w) (8,8)))
      ((word_join:byte->byte->int16) (word_subword (word_bytereverse w) (16,8))
                                     (word_subword (word_bytereverse w) (24,8))) = w`,
  CONV_TAC WORD_BLAST);;

let SHA256_LANE_CONV =
  TOP_DEPTH_CONV
   (REWR_CONV WORD_SUBWORD_AND ORELSEC REWR_CONV WORD_SUBWORD_XOR ORELSEC
    SHA256_USHR_CONV ORELSEC WORD_SIMPLE_SUBWORD_CONV) THENC
  DEPTH_CONV WORD_NUM_RED_CONV THENC
  REWRITE_CONV([SHA256_SIGMA0_AVX2; SHA256_SIGMA1_AVX2; WORD_ADD_0; SHA256_BSWAP] @
               SHA256_SCHED_THS);;

(* ------------------------------------------------------------------------- *)
(* Pointers, stack stores, and the step tactic.                              *)
(* ------------------------------------------------------------------------- *)

let SHA256_SUB_CONST = prove
 (`!x:int64 n. word_sub x (word n) = word_add x (word_neg (word n))`,
  CONV_TAC WORD_RULE);;

let SHA256_PTR_CONV =
  REWRITE_CONV[SHA256_SUB_CONST] THENC DEPTH_CONV WORD_RED_CONV THENC
  REWRITE_CONV[WORD_ADD_ASSOC_CONSTS] THENC
  DEPTH_CONV (NUM_ADD_CONV ORELSEC WORD_RED_CONV);;

let SHA256_RIPREL_FOLD = prove
 (`!pc ofs ofs2 k.
     riprel32_within_bounds (k + (ofs + ofs2)) (pc + ofs) ==>
     word (val (word (pc+ofs):(64)word) +
           val (word_sx (iword (&k - (&pc + -- &ofs2)):int32):(64)word)):int64 =
     word_add (word k) (word (ofs + ofs2))`,
  REPEAT STRIP_TAC THEN REWRITE_TAC[GSYM WORD_ADD] THEN
  ASM_MESON_TAC[RIP_REL_ADDR_FOLD]);;

let SHA256_RIPREL_FOLD0 = prove
 (`!pc ofs k.
     riprel32_within_bounds k (pc + ofs) ==>
     word (val (word (pc+ofs):(64)word) +
           val (word_sx (iword (&k - (&pc + &ofs)):int32):(64)word)):int64 =
     word k`,
  MESON_TAC[RIP_REL_ADDR_FOLD]);;

(* The routine's 64-bit registers, each as a base plus a constant. *)
let SHA256_PTR_TAC =
  let is64 th = let c = concl th in is_eq c && type_of (lhs c) = `:int64` &&
    (try fst(dest_const(fst(strip_comb (lhs c)))) = "read" with Failure _ -> false) &&
    (try mem (fst(dest_const(fst(strip_comb (rhs c))))) ["word_add"; "word_sub"]
     with Failure _ -> false) in
  RULE_ASSUM_TAC(fun th -> if is64 th then CONV_RULE(RAND_CONV SHA256_PTR_CONV) th else th);;

let SHA256_LANE_TAC =
  let simdable = can (term_match [] `read X (s:x86state):int256 = whatever`) in
  TRY(FIRST_X_ASSUM
    (ASSUME_TAC o CONV_RULE(RAND_CONV SHA256_LANE_CONV) o check (simdable o concl)));;

(* A 256-bit store to the stack frame at base as eight 32-bit facts, which
   the rounds read. *)
let SHA256_SPLIT_TAC =
  let pat = `read (memory :> bytes256 (word_add base (word n))) s = v` in
  let split k th = CONJUNCTS
    (GEN_REWRITE_RULE I [el k (CONJUNCTS READ_MEMORY_BYTESIZED_UNSPLIT)] th) in
  let norm = CONV_RULE (BINOP2_CONV SHA256_PTR_CONV SHA256_LANE_CONV) in
  REPEAT(FIRST_X_ASSUM(fun th ->
    if can (term_match [`base:int64`] pat) (concl th) then
      MAP_EVERY (ASSUME_TAC o norm) (flat (map (split 2) (flat (map (split 1) (split 0 th)))))
    else failwith "SHA256_SPLIT_TAC"));;

let SHA256_NORM_RULE =
  REWRITE_RULE[SHA256_ZX_ZX; SHA256_LEA32; SHA256_SX_ZX; SHA256_SUB_ADD; WORD_ADD_0;
               SHA256_SIGMA0_RORX];;

let SHA256_STEP_TAC n =
  X86_STEPS_TAC SHA256_AVX2_EXEC [n] THEN
  RULE_ASSUM_TAC SHA256_NORM_RULE THEN SHA256_PTR_TAC THEN
  SHA256_LANE_TAC THEN SHA256_SPLIT_TAC THEN
  RULE_ASSUM_TAC(REWRITE_RULE SHA256_ROUND_THS);;


(* ------------------------------------------------------------------------- *)
(* The round constants and byte-shuffle masks in the K256 table.             *)
(* ------------------------------------------------------------------------- *)

(* Each 32-byte row holds four round constants twice, once for each lane;
   after them come vpshufb's byte-swap mask and the two masks that gather
   sigma1's halves, and the inner loop stops at the zero byte the first mask
   has where a row's last constant would. *)
let SHA256_AVX2_K256 = prove
 (`!s k. bytes_loaded s (word k) sha256_avx2_k256
        ==> read (memory :> bytes256 (word k)) s = word 0xe9b5dba5b5c0fbcf71374491428a2f98e9b5dba5b5c0fbcf71374491428a2f98 /\
      read (memory :> bytes256 (word_add (word k) (word 32))) s = word 0xab1c5ed5923f82a459f111f13956c25bab1c5ed5923f82a459f111f13956c25b /\
      read (memory :> bytes256 (word_add (word k) (word 64))) s = word 0x550c7dc3243185be12835b01d807aa98550c7dc3243185be12835b01d807aa98 /\
      read (memory :> bytes256 (word_add (word k) (word 96))) s = word 0xc19bf1749bdc06a780deb1fe72be5d74c19bf1749bdc06a780deb1fe72be5d74 /\
      read (memory :> bytes256 (word_add (word k) (word 128))) s = word 0x240ca1cc0fc19dc6efbe4786e49b69c1240ca1cc0fc19dc6efbe4786e49b69c1 /\
      read (memory :> bytes256 (word_add (word k) (word 160))) s = word 0x76f988da5cb0a9dc4a7484aa2de92c6f76f988da5cb0a9dc4a7484aa2de92c6f /\
      read (memory :> bytes256 (word_add (word k) (word 192))) s = word 0xbf597fc7b00327c8a831c66d983e5152bf597fc7b00327c8a831c66d983e5152 /\
      read (memory :> bytes256 (word_add (word k) (word 224))) s = word 0x1429296706ca6351d5a79147c6e00bf31429296706ca6351d5a79147c6e00bf3 /\
      read (memory :> bytes256 (word_add (word k) (word 256))) s = word 0x53380d134d2c6dfc2e1b213827b70a8553380d134d2c6dfc2e1b213827b70a85 /\
      read (memory :> bytes256 (word_add (word k) (word 288))) s = word 0x92722c8581c2c92e766a0abb650a735492722c8581c2c92e766a0abb650a7354 /\
      read (memory :> bytes256 (word_add (word k) (word 320))) s = word 0xc76c51a3c24b8b70a81a664ba2bfe8a1c76c51a3c24b8b70a81a664ba2bfe8a1 /\
      read (memory :> bytes256 (word_add (word k) (word 352))) s = word 0x106aa070f40e3585d6990624d192e819106aa070f40e3585d6990624d192e819 /\
      read (memory :> bytes256 (word_add (word k) (word 384))) s = word 0x34b0bcb52748774c1e376c0819a4c11634b0bcb52748774c1e376c0819a4c116 /\
      read (memory :> bytes256 (word_add (word k) (word 416))) s = word 0x682e6ff35b9cca4f4ed8aa4a391c0cb3682e6ff35b9cca4f4ed8aa4a391c0cb3 /\
      read (memory :> bytes256 (word_add (word k) (word 448))) s = word 0x8cc7020884c8781478a5636f748f82ee8cc7020884c8781478a5636f748f82ee /\
      read (memory :> bytes256 (word_add (word k) (word 480))) s = word 0xc67178f2bef9a3f7a4506ceb90befffac67178f2bef9a3f7a4506ceb90befffa /\
      read (memory :> bytes256 (word_add (word k) (word 512))) s = word 0x0c0d0e0f08090a0b04050607000102030c0d0e0f08090a0b0405060700010203 /\
      read (memory :> bytes256 (word_add (word k) (word 544))) s = word 0xffffffffffffffff0b0a090803020100ffffffffffffffff0b0a090803020100 /\
      read (memory :> bytes256 (word_add (word k) (word 576))) s = word 0x0b0a090803020100ffffffffffffffff0b0a090803020100ffffffffffffffff /\
      read (memory :> bytes8 (word_add (word k) (word 131))) s = word 228 /\
      read (memory :> bytes8 (word_add (word k) (word 259))) s = word 39 /\
      read (memory :> bytes8 (word_add (word k) (word 387))) s = word 25 /\
      read (memory :> bytes8 (word_add (word k) (word 515))) s = word 0`,
  REPEAT GEN_TAC THEN
  GEN_REWRITE_TAC (LAND_CONV o RATOR_CONV o RAND_CONV o RAND_CONV)
    [ARITH_RULE `k = k + 0`] THEN
  REWRITE_TAC[sha256_avx2_k256] THEN CONV_TAC(LAND_CONV DATA64_CONV) THEN REWRITE_TAC[bytes_loaded_nil] THEN
  STRIP_TAC THEN RULE_ASSUM_TAC(REWRITE_RULE[ADD_CLAUSES]) THEN
  MAP_EVERY (fun off ->
    let a = mk_comb(`word:num->int64`, mk_binop `(+):num->num->num` `k:num` (mk_small_numeral off)) in
    FIRST_ASSUM(fun th ->
      if rand(rand(rand(rator(lhand(concl th))))) <> a then failwith "" else
      let split k = GEN_REWRITE_RULE I [el k (CONJUNCTS READ_MEMORY_BYTESIZED_UNSPLIT)] in
      let th3 = CONJUNCT2(split 4 (CONJUNCT2(split 3 (CONJUNCT1(split 2 th))))) in
      ASSUME_TAC(CONV_RULE(RAND_CONV WORD_REDUCE_CONV)
        (REWRITE_RULE[GSYM WORD_ADD; GSYM ADD_ASSOC] th3))))
    [128; 256; 384; 512] THEN
  RULE_ASSUM_TAC(CONV_RULE(DEPTH_CONV NUM_ADD_CONV)) THEN
  REWRITE_TAC[CONJUNCT1 READ_MEMORY_BYTESIZED_SPLIT;
              CONJUNCT1(CONJUNCT2 READ_MEMORY_BYTESIZED_SPLIT)] THEN
  REWRITE_TAC[GSYM WORD_ADD; GSYM ADD_ASSOC] THEN
  CONV_TAC(DEPTH_CONV NUM_ADD_CONV) THEN
  REWRITE_TAC[ADD_CLAUSES] THEN ASM_REWRITE_TAC[] THEN
  CONV_TAC WORD_REDUCE_CONV);;


(* ------------------------------------------------------------------------- *)
(* The message, as the value of the whole input region.                      *)
(* ------------------------------------------------------------------------- *)

let SHA256_READ_SLICE32 = prove
 (`!a l v (s:x86state) off.
     read (memory :> bytes(a,l)) s = v /\ off + 4 <= l
     ==> read (memory :> bytes32 (word_add a (word off))) s =
         word((v DIV 2 EXP (8 * off)) MOD 2 EXP (8 * 4))`,
  REPEAT GEN_TAC THEN DISCH_THEN(CONJUNCTS_THEN2 (SUBST1_TAC o SYM) ASSUME_TAC) THEN
  REWRITE_TAC[READ_COMPONENT_COMPOSE; READ_BYTES_DIV; READ_BYTES_MOD] THEN
  REWRITE_TAC[bytes32; READ_COMPONENT_COMPOSE; asword; through; read] THEN
  SUBGOAL_THEN `MIN (l - off) 4 = 4` (fun th -> REWRITE_TAC[th]) THEN
  ASM_ARITH_TAC);;

(* The lower loop's exit test compares the frame pointers it steps down. *)
let SHA256_COND_TAC (asl,w) =
  let is_cmp th = can (term_match [] `val (x:int64) <= val (y:int64)`) (concl th) ||
                  can (term_match [] `~(val (x:int64) <= val (y:int64))`) (concl th) in
  let cmps = filter is_cmp (map snd asl) in
  let is_ripcond th = let c = concl th in
    is_eq c && (try rator(lhs c) = `read RIP` with Failure _ -> false) && is_cond (rhs c) in
  RULE_ASSUM_TAC(fun th -> if is_ripcond th then REWRITE_RULE cmps th else th) (asl,w);;

let SHA256_BASE_CMPS = prove
 (`!base:int64. 32 <= val base /\ val base + 576 <= 2 EXP 64
   ==> val (word_add base (word 32)) <= val (word_add base (word 416)) /\
       val (word_add base (word 32)) <= val (word_add base (word 352)) /\
       val (word_add base (word 32)) <= val (word_add base (word 288)) /\
       val (word_add base (word 32)) <= val (word_add base (word 224)) /\
       val (word_add base (word 32)) <= val (word_add base (word 160)) /\
       val (word_add base (word 32)) <= val (word_add base (word 96)) /\
       val (word_add base (word 32)) <= val (word_add base (word 32)) /\
       ~(val (word_add base (word 32)) <=
         val (word_add base (word 18446744073709551584)))`,
  GEN_TAC THEN STRIP_TAC THEN
  REWRITE_TAC[VAL_WORD_ADD_CASES; DIMINDEX_64] THEN CONV_TAC(DEPTH_CONV WORD_RED_CONV) THEN
  REWRITE_TAC[VAL_WORD; DIMINDEX_64] THEN CONV_TAC(DEPTH_CONV NUM_RED_CONV) THEN
  REPEAT COND_CASES_TAC THEN ASM_ARITH_TAC);;


(* ------------------------------------------------------------------------- *)
(* Block A: from the loop's head to its feed-forward, with block B's         *)
(* schedule words left on the stack.                                        *)
(* ------------------------------------------------------------------------- *)

(* The frame is the 1024-byte-aligned area the prologue makes, which this
   calls base + 32: the loop's head finds the stack pointer at base + 480 and
   the context pointer, the end of the input, and the caller's stack pointer
   at base + 544, 560, and 568. Block A's rounds slide the stack pointer down
   64 bytes per eight rounds, leaving round t's schedule word plus constant,
   for block B, at base + sha256_avx2_slot t. *)
let sha256_avx2_slot = new_definition
 `sha256_avx2_slot t = 496 - 64 * (t DIV 8) + 32 * ((t MOD 8) DIV 4) + 4 * (t MOD 4)`;;

let SHA256_AVX2_BLOCK_A = prove
 (`!pc k256 base pa pb ctx rsp0 (H:int32 list) (MA:int32 list) (MB:int32 list).
     aligned 64 (word k256:int64) /\ aligned 32 (base:int64) /\
     nonoverlapping (word pc,0x1423) (base,544) /\
     nonoverlapping (word k256,640) (base,544) /\
     nonoverlapping (ctx,32) (base,544) /\ nonoverlapping (ctx,32) (word pc,0x1423) /\
     nonoverlapping (ctx,32) (word k256,640) /\
     riprel32_within_bounds (k256 + 512) (pc + 136) /\
     riprel32_within_bounds k256 (pc + 204)
     ==> ensures x86
      (\s. bytes_loaded s (word pc) (sha256_avx2_mc pc k256) /\
        read RIP s = word(pc + 0x80) /\
        read RSP s = word_add base (word 480) /\
        read RSI s = word_add pa (word 64) /\ read R12 s = pb /\
        read RAX s = word_zx (EL 0 H) /\
        read RBX s = word_zx (EL 1 H) /\
        read RCX s = word_zx (EL 2 H) /\
        read RDX s = word_zx (EL 3 H) /\
        read R8 s = word_zx (EL 4 H) /\
        read R9 s = word_zx (EL 5 H) /\
        read R10 s = word_zx (EL 6 H) /\
        read R11 s = word_zx (EL 7 H) /\
        read YMM8 s = word 0xffffffffffffffff0b0a090803020100ffffffffffffffff0b0a090803020100 /\
        read YMM9 s = word 0x0b0a090803020100ffffffffffffffff0b0a090803020100ffffffffffffffff /\
        bytes_loaded s (word k256) sha256_avx2_k256 /\
        read (memory :> bytes128 pa) s =
          (word_join:int64->int64->int128) (word_join (word_bytereverse (EL 3 MA)) (word_bytereverse (EL 2 MA)))
                                           (word_join (word_bytereverse (EL 1 MA)) (word_bytereverse (EL 0 MA))) /\
        read (memory :> bytes128 (word_add pa (word 16))) s =
          (word_join:int64->int64->int128) (word_join (word_bytereverse (EL 7 MA)) (word_bytereverse (EL 6 MA)))
                                           (word_join (word_bytereverse (EL 5 MA)) (word_bytereverse (EL 4 MA))) /\
        read (memory :> bytes128 (word_add pa (word 32))) s =
          (word_join:int64->int64->int128) (word_join (word_bytereverse (EL 11 MA)) (word_bytereverse (EL 10 MA)))
                                           (word_join (word_bytereverse (EL 9 MA)) (word_bytereverse (EL 8 MA))) /\
        read (memory :> bytes128 (word_add pa (word 48))) s =
          (word_join:int64->int64->int128) (word_join (word_bytereverse (EL 15 MA)) (word_bytereverse (EL 14 MA)))
                                           (word_join (word_bytereverse (EL 13 MA)) (word_bytereverse (EL 12 MA))) /\
        read (memory :> bytes128 pb) s =
          (word_join:int64->int64->int128) (word_join (word_bytereverse (EL 3 MB)) (word_bytereverse (EL 2 MB)))
                                           (word_join (word_bytereverse (EL 1 MB)) (word_bytereverse (EL 0 MB))) /\
        read (memory :> bytes128 (word_add pb (word 16))) s =
          (word_join:int64->int64->int128) (word_join (word_bytereverse (EL 7 MB)) (word_bytereverse (EL 6 MB)))
                                           (word_join (word_bytereverse (EL 5 MB)) (word_bytereverse (EL 4 MB))) /\
        read (memory :> bytes128 (word_add pb (word 32))) s =
          (word_join:int64->int64->int128) (word_join (word_bytereverse (EL 11 MB)) (word_bytereverse (EL 10 MB)))
                                           (word_join (word_bytereverse (EL 9 MB)) (word_bytereverse (EL 8 MB))) /\
        read (memory :> bytes128 (word_add pb (word 48))) s =
          (word_join:int64->int64->int128) (word_join (word_bytereverse (EL 15 MB)) (word_bytereverse (EL 14 MB)))
                                           (word_join (word_bytereverse (EL 13 MB)) (word_bytereverse (EL 12 MB))) /\
        read (memory :> bytes64 (word_add base (word 544))) s = ctx /\
        read (memory :> bytes64 (word_add base (word 568))) s = rsp0 /\
        read (memory :> bytes32 ctx) s = EL 0 H /\
        read (memory :> bytes32 (word_add ctx (word 4))) s = EL 1 H /\
        read (memory :> bytes32 (word_add ctx (word 8))) s = EL 2 H /\
        read (memory :> bytes32 (word_add ctx (word 12))) s = EL 3 H /\
        read (memory :> bytes32 (word_add ctx (word 16))) s = EL 4 H /\
        read (memory :> bytes32 (word_add ctx (word 20))) s = EL 5 H /\
        read (memory :> bytes32 (word_add ctx (word 24))) s = EL 6 H /\
        read (memory :> bytes32 (word_add ctx (word 28))) s = EL 7 H)
      (\s. read RIP s = word(pc + 0x105b) /\
        read RSP s = word_add base (word 32) /\
        read RBP s = word_add base (word 480) /\
        read RDI s = ctx /\
        read RAX s = word_zx (EL 0 (sha256_block MA H)) /\
        read RBX s = word_zx (EL 1 (sha256_block MA H)) /\
        read RCX s = word_zx (EL 2 (sha256_block MA H)) /\
        read RDX s = word_zx (EL 3 (sha256_block MA H)) /\
        read R8 s = word_zx (EL 4 (sha256_block MA H)) /\
        read R9 s = word_zx (EL 5 (sha256_block MA H)) /\
        read R10 s = word_zx (EL 6 (sha256_block MA H)) /\
        read R11 s = word_zx (EL 7 (sha256_block MA H)) /\
        read (memory :> bytes32 ctx) s = EL 0 (sha256_block MA H) /\
        read (memory :> bytes32 (word_add ctx (word 4))) s = EL 1 (sha256_block MA H) /\
        read (memory :> bytes32 (word_add ctx (word 8))) s = EL 2 (sha256_block MA H) /\
        read (memory :> bytes32 (word_add ctx (word 12))) s = EL 3 (sha256_block MA H) /\
        read (memory :> bytes32 (word_add ctx (word 16))) s = EL 4 (sha256_block MA H) /\
        read (memory :> bytes32 (word_add ctx (word 20))) s = EL 5 (sha256_block MA H) /\
        read (memory :> bytes32 (word_add ctx (word 24))) s = EL 6 (sha256_block MA H) /\
        read (memory :> bytes32 (word_add ctx (word 28))) s = EL 7 (sha256_block MA H) /\
        (!t. t < 64
             ==> read (memory :> bytes32 (word_add base (word (sha256_avx2_slot t)))) s =
                 word_add (sha256_msg_schedule MB t) (EL t sha256_constants)))
      (MAYCHANGE [RIP; RSP; RBP; RAX; RBX; RCX; RDX; RDI;
                  R8; R9; R10; R11; R12; R13; R14; R15] ,,
       MAYCHANGE [ZMM0; ZMM1; ZMM2; ZMM3; ZMM4; ZMM5; ZMM6; ZMM7] ,,
       MAYCHANGE SOME_FLAGS ,, MAYCHANGE [events] ,,
       MAYCHANGE [memory :> bytes(base,544); memory :> bytes(ctx,32)])`,
  MAP_EVERY X_GEN_TAC
   [`pc:num`; `k256:num`; `base:int64`; `pa:int64`; `pb:int64`; `ctx:int64`;
    `rsp0:int64`; `H:int32 list`; `MA:int32 list`; `MB:int32 list`] THEN
  STRIP_TAC THEN REWRITE_TAC[SOME_FLAGS; fst SHA256_AVX2_EXEC] THEN
  ENSURES_INIT_TAC "s0" THEN
  FIRST_X_ASSUM(STRIP_ASSUME_TAC o MATCH_MP SHA256_AVX2_K256 o
    check (can (term_match [] `bytes_loaded s (word k) sha256_avx2_k256`) o concl)) THEN
  RULE_ASSUM_TAC(fun th ->
    if can (find_term ((=) `word_bytereverse:int32->int32`)) (concl th)
    then REWRITE_RULE (map (INST [`MA:int32 list`,`M:int32 list`]) SHA256_SCHED_SMALL @
                       map (INST [`MB:int32 list`,`M:int32 list`]) SHA256_SCHED_SMALL) th
    else th) THEN
  FIRST_ASSUM(ASSUME_TAC o MATCH_MP (SPECL [`pc:num`; `136`; `376`; `k256:num`] SHA256_RIPREL_FOLD) o
    CONV_RULE(LAND_CONV(RAND_CONV(ONCE_REWRITE_CONV[ARITH_RULE `512 = 136 + 376`]))) o
    check ((=) `riprel32_within_bounds (k256 + 512) (pc + 136)` o concl)) THEN
  FIRST_ASSUM(ASSUME_TAC o MATCH_MP (SPECL [`pc:num`; `204`; `k256:num`] SHA256_RIPREL_FOLD0) o
    check ((=) `riprel32_within_bounds k256 (pc + 204)` o concl)) THEN
  RULE_ASSUM_TAC(CONV_RULE(ONCE_DEPTH_CONV NUM_ADD_CONV)) THEN
  SUBGOAL_THEN `aligned 32 (word k256:int64)` ASSUME_TAC THENL
   [ASM_MESON_TAC[ALIGNED_WORD_WEAKEN; DIVIDES_CONV `32 divides 64`]; ALL_TAC] THEN
  MAP_EVERY SHA256_STEP_TAC (1--1985) THEN
  ENSURES_FINAL_STATE_TAC THEN
  CONV_TAC(ONCE_DEPTH_CONV EXPAND_CASES_CONV) THEN
  REWRITE_TAC[sha256_avx2_slot; sha256_block] THEN
  CONV_TAC(TOP_DEPTH_CONV let_CONV) THEN
  REWRITE_TAC(map (INST [`MA:int32 list`,`M:int32 list`] o SHA256_CANON 64) (0--7) @
              map SHA256_K_AT (0--63)) THEN
  CONV_TAC(DEPTH_CONV(NUM_RED_CONV ORELSEC EL_CONV)) THEN
  REWRITE_TAC(map (INST [`MA:int32 list`,`M:int32 list`] o SHA256_CANON 64) (0--7)) THEN
  ASM_REWRITE_TAC[]);;


(* ------------------------------------------------------------------------- *)
(* Block B: its rounds from the schedule words block A left on the stack,    *)
(* then its feed-forward and the test for another pair.                     *)
(* ------------------------------------------------------------------------- *)

let SHA256_AVX2_BLOCK_B = prove
 (`!pc k256 base pa ctx endp (H:int32 list) (MB:int32 list).
     nonoverlapping (ctx,32) (base,576) /\ nonoverlapping (ctx,32) (word pc,0x1423) /\
     32 <= val base /\ val base + 576 <= 2 EXP 64
     ==> ensures x86
      (\s. bytes_loaded s (word pc) (sha256_avx2_mc pc k256) /\
        read RIP s = word(pc + 0x1065) /\
        read RSP s = word_add base (word 32) /\
        read RBP s = word_add base (word 480) /\
        read RSI s = word_add pa (word 64) /\
        read RAX s = word_zx (EL 0 H) /\
        read RBX s = word_zx (EL 1 H) /\
        read RCX s = word_zx (EL 2 H) /\
        read RDX s = word_zx (EL 3 H) /\
        read R8 s = word_zx (EL 4 H) /\
        read R9 s = word_zx (EL 5 H) /\
        read R10 s = word_zx (EL 6 H) /\
        read R11 s = word_zx (EL 7 H) /\
        read (memory :> bytes64 (word_add base (word 544))) s = ctx /\
        read (memory :> bytes64 (word_add base (word 560))) s = endp /\
        read (memory :> bytes32 ctx) s = EL 0 H /\
        read (memory :> bytes32 (word_add ctx (word 4))) s = EL 1 H /\
        read (memory :> bytes32 (word_add ctx (word 8))) s = EL 2 H /\
        read (memory :> bytes32 (word_add ctx (word 12))) s = EL 3 H /\
        read (memory :> bytes32 (word_add ctx (word 16))) s = EL 4 H /\
        read (memory :> bytes32 (word_add ctx (word 20))) s = EL 5 H /\
        read (memory :> bytes32 (word_add ctx (word 24))) s = EL 6 H /\
        read (memory :> bytes32 (word_add ctx (word 28))) s = EL 7 H /\
        (!t. t < 64
             ==> read (memory :> bytes32 (word_add base (word (sha256_avx2_slot t)))) s =
                 word_add (sha256_msg_schedule MB t) (EL t sha256_constants)))
      (\s. read RIP s = word(pc + 0x13f5) /\
        read RSP s = word_add base (word 480) /\
        read RSI s = word_add pa (word 192) /\
        read R12 s = (if val (word_sub (word_add pa (word 192)) endp) = 0
                      then word_add base (word 480) else word_add pa (word 192)) /\
        (read CF s <=> val (word_add pa (word 192)) < val endp) /\
        (read ZF s <=> val (word_sub (word_add pa (word 192)) endp) = 0) /\
        read RAX s = word_zx (EL 0 (sha256_block MB H)) /\
        read RBX s = word_zx (EL 1 (sha256_block MB H)) /\
        read RCX s = word_zx (EL 2 (sha256_block MB H)) /\
        read RDX s = word_zx (EL 3 (sha256_block MB H)) /\
        read R8 s = word_zx (EL 4 (sha256_block MB H)) /\
        read R9 s = word_zx (EL 5 (sha256_block MB H)) /\
        read R10 s = word_zx (EL 6 (sha256_block MB H)) /\
        read R11 s = word_zx (EL 7 (sha256_block MB H)) /\
        read (memory :> bytes32 ctx) s = EL 0 (sha256_block MB H) /\
        read (memory :> bytes32 (word_add ctx (word 4))) s = EL 1 (sha256_block MB H) /\
        read (memory :> bytes32 (word_add ctx (word 8))) s = EL 2 (sha256_block MB H) /\
        read (memory :> bytes32 (word_add ctx (word 12))) s = EL 3 (sha256_block MB H) /\
        read (memory :> bytes32 (word_add ctx (word 16))) s = EL 4 (sha256_block MB H) /\
        read (memory :> bytes32 (word_add ctx (word 20))) s = EL 5 (sha256_block MB H) /\
        read (memory :> bytes32 (word_add ctx (word 24))) s = EL 6 (sha256_block MB H) /\
        read (memory :> bytes32 (word_add ctx (word 28))) s = EL 7 (sha256_block MB H))
      (MAYCHANGE [RIP; RSP; RBP; RSI; RAX; RBX; RCX; RDX; RDI;
                  R8; R9; R10; R11; R12; R13; R14; R15] ,,
       MAYCHANGE SOME_FLAGS ,, MAYCHANGE [events] ,,
       MAYCHANGE [memory :> bytes(ctx,32)])`,
  MAP_EVERY X_GEN_TAC
   [`pc:num`; `k256:num`; `base:int64`; `pa:int64`; `ctx:int64`; `endp:int64`;
    `H:int32 list`; `MB:int32 list`] THEN
  STRIP_TAC THEN REWRITE_TAC[SOME_FLAGS; fst SHA256_AVX2_EXEC] THEN
  ENSURES_INIT_TAC "s0" THEN
  FIRST_X_ASSUM(MP_TAC o check (is_forall o concl)) THEN
  CONV_TAC(LAND_CONV EXPAND_CASES_CONV) THEN
  REWRITE_TAC[sha256_avx2_slot] THEN CONV_TAC(LAND_CONV(DEPTH_CONV NUM_RED_CONV)) THEN
  REWRITE_TAC(map SHA256_K_AT (0--63)) THEN STRIP_TAC THEN
  MP_TAC(SPEC `base:int64` SHA256_BASE_CMPS) THEN ASM_REWRITE_TAC[] THEN STRIP_TAC THEN
  MAP_EVERY (fun n -> SHA256_STEP_TAC n THEN SHA256_COND_TAC) (1--1588) THEN
  ENSURES_FINAL_STATE_TAC THEN
  REWRITE_TAC[sha256_block] THEN CONV_TAC(TOP_DEPTH_CONV let_CONV) THEN
  CONV_TAC(DEPTH_CONV EL_CONV) THEN
  REWRITE_TAC(map (INST [`MB:int32 list`,`M:int32 list`] o SHA256_CANON 64) (0--7)) THEN
  ASM_REWRITE_TAC[]);;
