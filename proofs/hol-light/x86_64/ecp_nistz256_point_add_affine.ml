(*
 * SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0
 *)

(* ========================================================================= *)
(* aws-lc's P-256 mixed addition with mulq on x86_64, as rind's build emits  *)
(* it.                                                                       *)
(* ========================================================================= *)

needs "x86/proofs/base.ml";;
needs "common/ecencoding.ml";;
needs "EC/jacobian.ml";;
needs "EC/nistp256.ml";;

(* admin/prove writes the function's object, as rind's release build emits
   it, to x86_64/ecp_nistz256_point_add_affine.o: its section as .text, with
   the field helpers it carries, and the table it reads as .rodata. The
   definition fails unless its instructions are these. *)
let ecp_nistz256_point_add_affine_mc,
    (ecp_nistz256_point_add_affine_data::_) =
  define_assert_relocs_from_elf "ecp_nistz256_point_add_affine_mc"
  "x86_64/ecp_nistz256_point_add_affine.o"
  (fun b ADDR -> [b[
  0x55;                    (* PUSH (% rbp) *)
  0x53;                    (* PUSH (% rbx) *)
  0x41; 0x54;              (* PUSH (% r12) *)
  0x41; 0x55;              (* PUSH (% r13) *)
  0x41; 0x56;              (* PUSH (% r14) *)
  0x41; 0x57;              (* PUSH (% r15) *)
  0x48; 0x81; 0xec; 0xe8; 0x01; 0x00; 0x00;
                           (* SUB (% rsp) (Imm32 (word 488)) *)
  0xf3; 0x0f; 0x6f; 0x06;  (* MOVDQU (%_% xmm0) (Memop Word128 (%% (rsi,0))) *)
  0x48; 0x89; 0xd3;        (* MOV (% rbx) (% rdx) *)
  0xf3; 0x0f; 0x6f; 0x4e; 0x10;
                           (* MOVDQU (%_% xmm1) (Memop Word128 (%% (rsi,16))) *)
  0xf3; 0x0f; 0x6f; 0x56; 0x20;
                           (* MOVDQU (%_% xmm2) (Memop Word128 (%% (rsi,32))) *)
  0xf3; 0x0f; 0x6f; 0x5e; 0x30;
                           (* MOVDQU (%_% xmm3) (Memop Word128 (%% (rsi,48))) *)
  0xf3; 0x0f; 0x6f; 0x66; 0x40;
                           (* MOVDQU (%_% xmm4) (Memop Word128 (%% (rsi,64))) *)
  0xf3; 0x0f; 0x6f; 0x6e; 0x50;
                           (* MOVDQU (%_% xmm5) (Memop Word128 (%% (rsi,80))) *)
  0x48; 0x8b; 0x46; 0x40;  (* MOV (% rax) (Memop Quadword (%% (rsi,64))) *)
  0x4c; 0x8b; 0x76; 0x48;  (* MOV (% r14) (Memop Quadword (%% (rsi,72))) *)
  0x4c; 0x8b; 0x7e; 0x50;  (* MOV (% r15) (Memop Quadword (%% (rsi,80))) *)
  0x4c; 0x8b; 0x46; 0x58;  (* MOV (% r8) (Memop Quadword (%% (rsi,88))) *)
  0x66; 0x0f; 0x7f; 0x84; 0x24; 0x40; 0x01; 0x00; 0x00;
                           (* MOVDQA (Memop Word128 (%% (rsp,320))) (%_% xmm0) *)
  0x66; 0x0f; 0x7f; 0x8c; 0x24; 0x50; 0x01; 0x00; 0x00;
                           (* MOVDQA (Memop Word128 (%% (rsp,336))) (%_% xmm1) *)
  0x66; 0x0f; 0x7f; 0x94; 0x24; 0x60; 0x01; 0x00; 0x00;
                           (* MOVDQA (Memop Word128 (%% (rsp,352))) (%_% xmm2) *)
  0x66; 0x0f; 0x7f; 0x9c; 0x24; 0x70; 0x01; 0x00; 0x00;
                           (* MOVDQA (Memop Word128 (%% (rsp,368))) (%_% xmm3) *)
  0x66; 0x0f; 0x7f; 0xa4; 0x24; 0x80; 0x01; 0x00; 0x00;
                           (* MOVDQA (Memop Word128 (%% (rsp,384))) (%_% xmm4) *)
  0x66; 0x0f; 0x7f; 0xac; 0x24; 0x90; 0x01; 0x00; 0x00;
                           (* MOVDQA (Memop Word128 (%% (rsp,400))) (%_% xmm5) *)
  0x66; 0x0f; 0xeb; 0xec;  (* POR (%_% xmm5) (%_% xmm4) *)
  0xf3; 0x0f; 0x6f; 0x03;  (* MOVDQU (%_% xmm0) (Memop Word128 (%% (rbx,0))) *)
  0x66; 0x0f; 0x70; 0xdd; 0xb1;
                           (* PSHUFD (%_% xmm3) (%_% xmm5) (Imm8 (word 177)) *)
  0xf3; 0x0f; 0x6f; 0x4b; 0x10;
                           (* MOVDQU (%_% xmm1) (Memop Word128 (%% (rbx,16))) *)
  0xf3; 0x0f; 0x6f; 0x53; 0x20;
                           (* MOVDQU (%_% xmm2) (Memop Word128 (%% (rbx,32))) *)
  0x66; 0x0f; 0xeb; 0xeb;  (* POR (%_% xmm5) (%_% xmm3) *)
  0xf3; 0x0f; 0x6f; 0x5b; 0x30;
                           (* MOVDQU (%_% xmm3) (Memop Word128 (%% (rbx,48))) *)
  0x66; 0x0f; 0x7f; 0x84; 0x24; 0xa0; 0x01; 0x00; 0x00;
                           (* MOVDQA (Memop Word128 (%% (rsp,416))) (%_% xmm0) *)
  0x66; 0x0f; 0x70; 0xe5; 0x1e;
                           (* PSHUFD (%_% xmm4) (%_% xmm5) (Imm8 (word 30)) *)
  0x66; 0x0f; 0x7f; 0x8c; 0x24; 0xb0; 0x01; 0x00; 0x00;
                           (* MOVDQA (Memop Word128 (%% (rsp,432))) (%_% xmm1) *)
  0x66; 0x0f; 0xeb; 0xc8;  (* POR (%_% xmm1) (%_% xmm0) *)
  0x66; 0x48; 0x0f; 0x6e; 0xc7;
                           (* MOVQ (%_% xmm0) (% rdi) *)
  0x66; 0x0f; 0x7f; 0x94; 0x24; 0xc0; 0x01; 0x00; 0x00;
                           (* MOVDQA (Memop Word128 (%% (rsp,448))) (%_% xmm2) *)
  0x66; 0x0f; 0x7f; 0x9c; 0x24; 0xd0; 0x01; 0x00; 0x00;
                           (* MOVDQA (Memop Word128 (%% (rsp,464))) (%_% xmm3) *)
  0x66; 0x0f; 0xeb; 0xda;  (* POR (%_% xmm3) (%_% xmm2) *)
  0x66; 0x0f; 0xeb; 0xec;  (* POR (%_% xmm5) (%_% xmm4) *)
  0x66; 0x0f; 0xef; 0xe4;  (* PXOR (%_% xmm4) (%_% xmm4) *)
  0x66; 0x0f; 0xeb; 0xd9;  (* POR (%_% xmm3) (%_% xmm1) *)
  0x48; 0x8d; 0x76; 0x40;  (* LEA (% rsi) (%% (rsi,64)) *)
  0x48; 0x8d; 0x7c; 0x24; 0x20;
                           (* LEA (% rdi) (%% (rsp,32)) *)
  0xe8; 0xb9; 0x06; 0x00; 0x00;
                           (* CALL (Imm32 (word 1721)) *)
  0x66; 0x0f; 0x76; 0xec;  (* PCMPEQD (%_% xmm5) (%_% xmm4) *)
  0x66; 0x0f; 0x70; 0xe3; 0xb1;
                           (* PSHUFD (%_% xmm4) (%_% xmm3) (Imm8 (word 177)) *)
  0x48; 0x8b; 0x03;        (* MOV (% rax) (Memop Quadword (%% (rbx,0))) *)
  0x4d; 0x89; 0xe1;        (* MOV (% r9) (% r12) *)
  0x66; 0x0f; 0xeb; 0xe3;  (* POR (%_% xmm4) (%_% xmm3) *)
  0x66; 0x0f; 0x70; 0xed; 0x00;
                           (* PSHUFD (%_% xmm5) (%_% xmm5) (Imm8 (word 0)) *)
  0x66; 0x0f; 0x70; 0xdc; 0x1e;
                           (* PSHUFD (%_% xmm3) (%_% xmm4) (Imm8 (word 30)) *)
  0x4d; 0x89; 0xea;        (* MOV (% r10) (% r13) *)
  0x66; 0x0f; 0xeb; 0xe3;  (* POR (%_% xmm4) (%_% xmm3) *)
  0x66; 0x0f; 0xef; 0xdb;  (* PXOR (%_% xmm3) (%_% xmm3) *)
  0x4d; 0x89; 0xf3;        (* MOV (% r11) (% r14) *)
  0x66; 0x0f; 0x76; 0xe3;  (* PCMPEQD (%_% xmm4) (%_% xmm3) *)
  0x66; 0x0f; 0x70; 0xe4; 0x00;
                           (* PSHUFD (%_% xmm4) (%_% xmm4) (Imm8 (word 0)) *)
  0x48; 0x8d; 0x74; 0x24; 0x20;
                           (* LEA (% rsi) (%% (rsp,32)) *)
  0x4d; 0x89; 0xfc;        (* MOV (% r12) (% r15) *)
  0x48; 0x8d; 0x3c; 0x24;  (* LEA (% rdi) (%% (rsp,0)) *)
  0xe8; 0x34; 0x04; 0x00; 0x00;
                           (* CALL (Imm32 (word 1076)) *)
  0x48; 0x8d; 0x9c; 0x24; 0x40; 0x01; 0x00; 0x00;
                           (* LEA (% rbx) (%% (rsp,320)) *)
  0x48; 0x8d; 0x7c; 0x24; 0x40;
                           (* LEA (% rdi) (%% (rsp,64)) *)
  0xe8; 0x22; 0x08; 0x00; 0x00;
                           (* CALL (Imm32 (word 2082)) *)
  0x48; 0x8b; 0x84; 0x24; 0x80; 0x01; 0x00; 0x00;
                           (* MOV (% rax) (Memop Quadword (%% (rsp,384))) *)
  0x48; 0x8d; 0x9c; 0x24; 0x80; 0x01; 0x00; 0x00;
                           (* LEA (% rbx) (%% (rsp,384)) *)
  0x4c; 0x8b; 0x4c; 0x24; 0x20;
                           (* MOV (% r9) (Memop Quadword (%% (rsp,32))) *)
  0x4c; 0x8b; 0x54; 0x24; 0x28;
                           (* MOV (% r10) (Memop Quadword (%% (rsp,40))) *)
  0x48; 0x8d; 0x74; 0x24; 0x20;
                           (* LEA (% rsi) (%% (rsp,32)) *)
  0x4c; 0x8b; 0x5c; 0x24; 0x30;
                           (* MOV (% r11) (Memop Quadword (%% (rsp,48))) *)
  0x4c; 0x8b; 0x64; 0x24; 0x38;
                           (* MOV (% r12) (Memop Quadword (%% (rsp,56))) *)
  0x48; 0x8d; 0x7c; 0x24; 0x20;
                           (* LEA (% rdi) (%% (rsp,32)) *)
  0xe8; 0xef; 0x03; 0x00; 0x00;
                           (* CALL (Imm32 (word 1007)) *)
  0x48; 0x8b; 0x84; 0x24; 0x80; 0x01; 0x00; 0x00;
                           (* MOV (% rax) (Memop Quadword (%% (rsp,384))) *)
  0x48; 0x8d; 0x9c; 0x24; 0x80; 0x01; 0x00; 0x00;
                           (* LEA (% rbx) (%% (rsp,384)) *)
  0x4c; 0x8b; 0x4c; 0x24; 0x40;
                           (* MOV (% r9) (Memop Quadword (%% (rsp,64))) *)
  0x4c; 0x8b; 0x54; 0x24; 0x48;
                           (* MOV (% r10) (Memop Quadword (%% (rsp,72))) *)
  0x48; 0x8d; 0x74; 0x24; 0x40;
                           (* LEA (% rsi) (%% (rsp,64)) *)
  0x4c; 0x8b; 0x5c; 0x24; 0x50;
                           (* MOV (% r11) (Memop Quadword (%% (rsp,80))) *)
  0x4c; 0x8b; 0x64; 0x24; 0x58;
                           (* MOV (% r12) (Memop Quadword (%% (rsp,88))) *)
  0x48; 0x8d; 0xbc; 0x24; 0x20; 0x01; 0x00; 0x00;
                           (* LEA (% rdi) (%% (rsp,288)) *)
  0xe8; 0xb9; 0x03; 0x00; 0x00;
                           (* CALL (Imm32 (word 953)) *)
  0x48; 0x8b; 0x84; 0x24; 0xc0; 0x01; 0x00; 0x00;
                           (* MOV (% rax) (Memop Quadword (%% (rsp,448))) *)
  0x48; 0x8d; 0x9c; 0x24; 0xc0; 0x01; 0x00; 0x00;
                           (* LEA (% rbx) (%% (rsp,448)) *)
  0x4c; 0x8b; 0x4c; 0x24; 0x20;
                           (* MOV (% r9) (Memop Quadword (%% (rsp,32))) *)
  0x4c; 0x8b; 0x54; 0x24; 0x28;
                           (* MOV (% r10) (Memop Quadword (%% (rsp,40))) *)
  0x48; 0x8d; 0x74; 0x24; 0x20;
                           (* LEA (% rsi) (%% (rsp,32)) *)
  0x4c; 0x8b; 0x5c; 0x24; 0x30;
                           (* MOV (% r11) (Memop Quadword (%% (rsp,48))) *)
  0x4c; 0x8b; 0x64; 0x24; 0x38;
                           (* MOV (% r12) (Memop Quadword (%% (rsp,56))) *)
  0x48; 0x8d; 0x7c; 0x24; 0x20;
                           (* LEA (% rdi) (%% (rsp,32)) *)
  0xe8; 0x86; 0x03; 0x00; 0x00;
                           (* CALL (Imm32 (word 902)) *)
  0x48; 0x8d; 0x9c; 0x24; 0x60; 0x01; 0x00; 0x00;
                           (* LEA (% rbx) (%% (rsp,352)) *)
  0x48; 0x8d; 0x7c; 0x24; 0x60;
                           (* LEA (% rdi) (%% (rsp,96)) *)
  0xe8; 0x74; 0x07; 0x00; 0x00;
                           (* CALL (Imm32 (word 1908)) *)
  0x48; 0x8b; 0x44; 0x24; 0x40;
                           (* MOV (% rax) (Memop Quadword (%% (rsp,64))) *)
  0x4c; 0x8b; 0x74; 0x24; 0x48;
                           (* MOV (% r14) (Memop Quadword (%% (rsp,72))) *)
  0x48; 0x8d; 0x74; 0x24; 0x40;
                           (* LEA (% rsi) (%% (rsp,64)) *)
  0x4c; 0x8b; 0x7c; 0x24; 0x50;
                           (* MOV (% r15) (Memop Quadword (%% (rsp,80))) *)
  0x4c; 0x8b; 0x44; 0x24; 0x58;
                           (* MOV (% r8) (Memop Quadword (%% (rsp,88))) *)
  0x48; 0x8d; 0xbc; 0x24; 0x80; 0x00; 0x00; 0x00;
                           (* LEA (% rdi) (%% (rsp,128)) *)
  0xe8; 0x8e; 0x05; 0x00; 0x00;
                           (* CALL (Imm32 (word 1422)) *)
  0x48; 0x8b; 0x44; 0x24; 0x60;
                           (* MOV (% rax) (Memop Quadword (%% (rsp,96))) *)
  0x4c; 0x8b; 0x74; 0x24; 0x68;
                           (* MOV (% r14) (Memop Quadword (%% (rsp,104))) *)
  0x48; 0x8d; 0x74; 0x24; 0x60;
                           (* LEA (% rsi) (%% (rsp,96)) *)
  0x4c; 0x8b; 0x7c; 0x24; 0x70;
                           (* MOV (% r15) (Memop Quadword (%% (rsp,112))) *)
  0x4c; 0x8b; 0x44; 0x24; 0x78;
                           (* MOV (% r8) (Memop Quadword (%% (rsp,120))) *)
  0x48; 0x8d; 0xbc; 0x24; 0xc0; 0x00; 0x00; 0x00;
                           (* LEA (% rdi) (%% (rsp,192)) *)
  0xe8; 0x68; 0x05; 0x00; 0x00;
                           (* CALL (Imm32 (word 1384)) *)
  0x48; 0x8b; 0x84; 0x24; 0x80; 0x00; 0x00; 0x00;
                           (* MOV (% rax) (Memop Quadword (%% (rsp,128))) *)
  0x48; 0x8d; 0x9c; 0x24; 0x80; 0x00; 0x00; 0x00;
                           (* LEA (% rbx) (%% (rsp,128)) *)
  0x4c; 0x8b; 0x4c; 0x24; 0x40;
                           (* MOV (% r9) (Memop Quadword (%% (rsp,64))) *)
  0x4c; 0x8b; 0x54; 0x24; 0x48;
                           (* MOV (% r10) (Memop Quadword (%% (rsp,72))) *)
  0x48; 0x8d; 0x74; 0x24; 0x40;
                           (* LEA (% rsi) (%% (rsp,64)) *)
  0x4c; 0x8b; 0x5c; 0x24; 0x50;
                           (* MOV (% r11) (Memop Quadword (%% (rsp,80))) *)
  0x4c; 0x8b; 0x64; 0x24; 0x58;
                           (* MOV (% r12) (Memop Quadword (%% (rsp,88))) *)
  0x48; 0x8d; 0xbc; 0x24; 0xa0; 0x00; 0x00; 0x00;
                           (* LEA (% rdi) (%% (rsp,160)) *)
  0xe8; 0xf2; 0x02; 0x00; 0x00;
                           (* CALL (Imm32 (word 754)) *)
  0x48; 0x8b; 0x84; 0x24; 0x40; 0x01; 0x00; 0x00;
                           (* MOV (% rax) (Memop Quadword (%% (rsp,320))) *)
  0x48; 0x8d; 0x9c; 0x24; 0x40; 0x01; 0x00; 0x00;
                           (* LEA (% rbx) (%% (rsp,320)) *)
  0x4c; 0x8b; 0x8c; 0x24; 0x80; 0x00; 0x00; 0x00;
                           (* MOV (% r9) (Memop Quadword (%% (rsp,128))) *)
  0x4c; 0x8b; 0x94; 0x24; 0x88; 0x00; 0x00; 0x00;
                           (* MOV (% r10) (Memop Quadword (%% (rsp,136))) *)
  0x48; 0x8d; 0xb4; 0x24; 0x80; 0x00; 0x00; 0x00;
                           (* LEA (% rsi) (%% (rsp,128)) *)
  0x4c; 0x8b; 0x9c; 0x24; 0x90; 0x00; 0x00; 0x00;
                           (* MOV (% r11) (Memop Quadword (%% (rsp,144))) *)
  0x4c; 0x8b; 0xa4; 0x24; 0x98; 0x00; 0x00; 0x00;
                           (* MOV (% r12) (Memop Quadword (%% (rsp,152))) *)
  0x48; 0x8d; 0x3c; 0x24;  (* LEA (% rdi) (%% (rsp,0)) *)
  0xe8; 0xb1; 0x02; 0x00; 0x00;
                           (* CALL (Imm32 (word 689)) *)
  0x4d; 0x31; 0xdb;        (* XOR (% r11) (% r11) *)
  0x4d; 0x01; 0xe4;        (* ADD (% r12) (% r12) *)
  0x48; 0x8d; 0xb4; 0x24; 0xc0; 0x00; 0x00; 0x00;
                           (* LEA (% rsi) (%% (rsp,192)) *)
  0x4d; 0x11; 0xed;        (* ADC (% r13) (% r13) *)
  0x4c; 0x89; 0xe0;        (* MOV (% rax) (% r12) *)
  0x4d; 0x11; 0xc0;        (* ADC (% r8) (% r8) *)
  0x4d; 0x11; 0xc9;        (* ADC (% r9) (% r9) *)
  0x4c; 0x89; 0xed;        (* MOV (% rbp) (% r13) *)
  0x49; 0x83; 0xd3; 0x00;  (* ADC (% r11) (Imm8 (word 0)) *)
  0x49; 0x83; 0xec; 0xff;  (* SUB (% r12) (Imm8 (word 255)) *)
  0x4c; 0x89; 0xc1;        (* MOV (% rcx) (% r8) *)
  0x4d; 0x19; 0xf5;        (* SBB (% r13) (% r14) *)
  0x49; 0x83; 0xd8; 0x00;  (* SBB (% r8) (Imm8 (word 0)) *)
  0x4d; 0x89; 0xca;        (* MOV (% r10) (% r9) *)
  0x4d; 0x19; 0xf9;        (* SBB (% r9) (% r15) *)
  0x49; 0x83; 0xdb; 0x00;  (* SBB (% r11) (Imm8 (word 0)) *)
  0x4c; 0x0f; 0x42; 0xe0;  (* CMOVB (% r12) (% rax) *)
  0x48; 0x8b; 0x06;        (* MOV (% rax) (Memop Quadword (%% (rsi,0))) *)
  0x4c; 0x0f; 0x42; 0xed;  (* CMOVB (% r13) (% rbp) *)
  0x48; 0x8b; 0x6e; 0x08;  (* MOV (% rbp) (Memop Quadword (%% (rsi,8))) *)
  0x4c; 0x0f; 0x42; 0xc1;  (* CMOVB (% r8) (% rcx) *)
  0x48; 0x8b; 0x4e; 0x10;  (* MOV (% rcx) (Memop Quadword (%% (rsi,16))) *)
  0x4d; 0x0f; 0x42; 0xca;  (* CMOVB (% r9) (% r10) *)
  0x4c; 0x8b; 0x56; 0x18;  (* MOV (% r10) (Memop Quadword (%% (rsi,24))) *)
  0xe8; 0xb4; 0x06; 0x00; 0x00;
                           (* CALL (Imm32 (word 1716)) *)
  0x48; 0x8d; 0x9c; 0x24; 0xa0; 0x00; 0x00; 0x00;
                           (* LEA (% rbx) (%% (rsp,160)) *)
  0x48; 0x8d; 0xbc; 0x24; 0xe0; 0x00; 0x00; 0x00;
                           (* LEA (% rdi) (%% (rsp,224)) *)
  0xe8; 0x3f; 0x06; 0x00; 0x00;
                           (* CALL (Imm32 (word 1599)) *)
  0x48; 0x8b; 0x04; 0x24;  (* MOV (% rax) (Memop Quadword (%% (rsp,0))) *)
  0x48; 0x8b; 0x6c; 0x24; 0x08;
                           (* MOV (% rbp) (Memop Quadword (%% (rsp,8))) *)
  0x48; 0x8b; 0x4c; 0x24; 0x10;
                           (* MOV (% rcx) (Memop Quadword (%% (rsp,16))) *)
  0x4c; 0x8b; 0x54; 0x24; 0x18;
                           (* MOV (% r10) (Memop Quadword (%% (rsp,24))) *)
  0x48; 0x8d; 0x7c; 0x24; 0x40;
                           (* LEA (% rdi) (%% (rsp,64)) *)
  0xe8; 0x82; 0x06; 0x00; 0x00;
                           (* CALL (Imm32 (word 1666)) *)
  0x4c; 0x89; 0x27;        (* MOV (Memop Quadword (%% (rdi,0))) (% r12) *)
  0x4c; 0x89; 0x6f; 0x08;  (* MOV (Memop Quadword (%% (rdi,8))) (% r13) *)
  0x4c; 0x89; 0x47; 0x10;  (* MOV (Memop Quadword (%% (rdi,16))) (% r8) *)
  0x4c; 0x89; 0x4f; 0x18;  (* MOV (Memop Quadword (%% (rdi,24))) (% r9) *)
  0x48; 0x8b; 0x84; 0x24; 0x60; 0x01; 0x00; 0x00;
                           (* MOV (% rax) (Memop Quadword (%% (rsp,352))) *)
  0x48; 0x8d; 0x9c; 0x24; 0x60; 0x01; 0x00; 0x00;
                           (* LEA (% rbx) (%% (rsp,352)) *)
  0x4c; 0x8b; 0x8c; 0x24; 0xa0; 0x00; 0x00; 0x00;
                           (* MOV (% r9) (Memop Quadword (%% (rsp,160))) *)
  0x4c; 0x8b; 0x94; 0x24; 0xa8; 0x00; 0x00; 0x00;
                           (* MOV (% r10) (Memop Quadword (%% (rsp,168))) *)
  0x48; 0x8d; 0xb4; 0x24; 0xa0; 0x00; 0x00; 0x00;
                           (* LEA (% rsi) (%% (rsp,160)) *)
  0x4c; 0x8b; 0x9c; 0x24; 0xb0; 0x00; 0x00; 0x00;
                           (* MOV (% r11) (Memop Quadword (%% (rsp,176))) *)
  0x4c; 0x8b; 0xa4; 0x24; 0xb8; 0x00; 0x00; 0x00;
                           (* MOV (% r12) (Memop Quadword (%% (rsp,184))) *)
  0x48; 0x8d; 0x7c; 0x24; 0x20;
                           (* LEA (% rdi) (%% (rsp,32)) *)
  0xe8; 0xd1; 0x01; 0x00; 0x00;
                           (* CALL (Imm32 (word 465)) *)
  0x48; 0x8b; 0x44; 0x24; 0x60;
                           (* MOV (% rax) (Memop Quadword (%% (rsp,96))) *)
  0x48; 0x8d; 0x5c; 0x24; 0x60;
                           (* LEA (% rbx) (%% (rsp,96)) *)
  0x4c; 0x8b; 0x4c; 0x24; 0x40;
                           (* MOV (% r9) (Memop Quadword (%% (rsp,64))) *)
  0x4c; 0x8b; 0x54; 0x24; 0x48;
                           (* MOV (% r10) (Memop Quadword (%% (rsp,72))) *)
  0x48; 0x8d; 0x74; 0x24; 0x40;
                           (* LEA (% rsi) (%% (rsp,64)) *)
  0x4c; 0x8b; 0x5c; 0x24; 0x50;
                           (* MOV (% r11) (Memop Quadword (%% (rsp,80))) *)
  0x4c; 0x8b; 0x64; 0x24; 0x58;
                           (* MOV (% r12) (Memop Quadword (%% (rsp,88))) *)
  0x48; 0x8d; 0x7c; 0x24; 0x40;
                           (* LEA (% rdi) (%% (rsp,64)) *)
  0xe8; 0xa4; 0x01; 0x00; 0x00;
                           (* CALL (Imm32 (word 420)) *)
  0x48; 0x8d; 0x5c; 0x24; 0x20;
                           (* LEA (% rbx) (%% (rsp,32)) *)
  0x48; 0x8d; 0xbc; 0x24; 0x00; 0x01; 0x00; 0x00;
                           (* LEA (% rdi) (%% (rsp,256)) *)
  0xe8; 0x92; 0x05; 0x00; 0x00;
                           (* CALL (Imm32 (word 1426)) *)
  0x66; 0x48; 0x0f; 0x7e; 0xc7;
                           (* MOVQ (% rdi) (%_% xmm0) *)
  0x66; 0x0f; 0x6f; 0xc5;  (* MOVDQA (%_% xmm0) (%_% xmm5) *)
  0x66; 0x0f; 0x6f; 0xcd;  (* MOVDQA (%_% xmm1) (%_% xmm5) *)
  0x66; 0x0f; 0xdf; 0x84; 0x24; 0x20; 0x01; 0x00; 0x00;
                           (* PANDN (%_% xmm0) (Memop Word128 (%% (rsp,288))) *)
  0x66; 0x0f; 0x6f; 0xd5;  (* MOVDQA (%_% xmm2) (%_% xmm5) *)
  0x66; 0x0f; 0xdf; 0x8c; 0x24; 0x30; 0x01; 0x00; 0x00;
                           (* PANDN (%_% xmm1) (Memop Word128 (%% (rsp,304))) *)
  0x66; 0x0f; 0x6f; 0xdd;  (* MOVDQA (%_% xmm3) (%_% xmm5) *)
  0x66; 0x0f; 0xdb; 0x15]; ADDR ("WHOLE_READONLY_data",(124)); b[
                           (* PAND (%_% xmm2)
(Memop Word128
(Riprel (word_sx (iword (&WHOLE_READONLY_data - (&pc + &893)))))) *)
  0x66; 0x0f; 0xdb; 0x1d]; ADDR ("WHOLE_READONLY_data",(140)); b[
                           (* PAND (%_% xmm3)
(Memop Word128
(Riprel (word_sx (iword (&WHOLE_READONLY_data - (&pc + &885)))))) *)
  0x66; 0x0f; 0xeb; 0xd0;  (* POR (%_% xmm2) (%_% xmm0) *)
  0x66; 0x0f; 0xeb; 0xd9;  (* POR (%_% xmm3) (%_% xmm1) *)
  0x66; 0x0f; 0x6f; 0xc4;  (* MOVDQA (%_% xmm0) (%_% xmm4) *)
  0x66; 0x0f; 0x6f; 0xcc;  (* MOVDQA (%_% xmm1) (%_% xmm4) *)
  0x66; 0x0f; 0xdf; 0xc2;  (* PANDN (%_% xmm0) (%_% xmm2) *)
  0x66; 0x0f; 0x6f; 0xd4;  (* MOVDQA (%_% xmm2) (%_% xmm4) *)
  0x66; 0x0f; 0xdf; 0xcb;  (* PANDN (%_% xmm1) (%_% xmm3) *)
  0x66; 0x0f; 0x6f; 0xdc;  (* MOVDQA (%_% xmm3) (%_% xmm4) *)
  0x66; 0x0f; 0xdb; 0x94; 0x24; 0x80; 0x01; 0x00; 0x00;
                           (* PAND (%_% xmm2) (Memop Word128 (%% (rsp,384))) *)
  0x66; 0x0f; 0xdb; 0x9c; 0x24; 0x90; 0x01; 0x00; 0x00;
                           (* PAND (%_% xmm3) (Memop Word128 (%% (rsp,400))) *)
  0x66; 0x0f; 0xeb; 0xd0;  (* POR (%_% xmm2) (%_% xmm0) *)
  0x66; 0x0f; 0xeb; 0xd9;  (* POR (%_% xmm3) (%_% xmm1) *)
  0xf3; 0x0f; 0x7f; 0x57; 0x40;
                           (* MOVDQU (Memop Word128 (%% (rdi,64))) (%_% xmm2) *)
  0xf3; 0x0f; 0x7f; 0x5f; 0x50;
                           (* MOVDQU (Memop Word128 (%% (rdi,80))) (%_% xmm3) *)
  0x66; 0x0f; 0x6f; 0xc5;  (* MOVDQA (%_% xmm0) (%_% xmm5) *)
  0x66; 0x0f; 0x6f; 0xcd;  (* MOVDQA (%_% xmm1) (%_% xmm5) *)
  0x66; 0x0f; 0xdf; 0x84; 0x24; 0xe0; 0x00; 0x00; 0x00;
                           (* PANDN (%_% xmm0) (Memop Word128 (%% (rsp,224))) *)
  0x66; 0x0f; 0x6f; 0xd5;  (* MOVDQA (%_% xmm2) (%_% xmm5) *)
  0x66; 0x0f; 0xdf; 0x8c; 0x24; 0xf0; 0x00; 0x00; 0x00;
                           (* PANDN (%_% xmm1) (Memop Word128 (%% (rsp,240))) *)
  0x66; 0x0f; 0x6f; 0xdd;  (* MOVDQA (%_% xmm3) (%_% xmm5) *)
  0x66; 0x0f; 0xdb; 0x94; 0x24; 0xa0; 0x01; 0x00; 0x00;
                           (* PAND (%_% xmm2) (Memop Word128 (%% (rsp,416))) *)
  0x66; 0x0f; 0xdb; 0x9c; 0x24; 0xb0; 0x01; 0x00; 0x00;
                           (* PAND (%_% xmm3) (Memop Word128 (%% (rsp,432))) *)
  0x66; 0x0f; 0xeb; 0xd0;  (* POR (%_% xmm2) (%_% xmm0) *)
  0x66; 0x0f; 0xeb; 0xd9;  (* POR (%_% xmm3) (%_% xmm1) *)
  0x66; 0x0f; 0x6f; 0xc4;  (* MOVDQA (%_% xmm0) (%_% xmm4) *)
  0x66; 0x0f; 0x6f; 0xcc;  (* MOVDQA (%_% xmm1) (%_% xmm4) *)
  0x66; 0x0f; 0xdf; 0xc2;  (* PANDN (%_% xmm0) (%_% xmm2) *)
  0x66; 0x0f; 0x6f; 0xd4;  (* MOVDQA (%_% xmm2) (%_% xmm4) *)
  0x66; 0x0f; 0xdf; 0xcb;  (* PANDN (%_% xmm1) (%_% xmm3) *)
  0x66; 0x0f; 0x6f; 0xdc;  (* MOVDQA (%_% xmm3) (%_% xmm4) *)
  0x66; 0x0f; 0xdb; 0x94; 0x24; 0x40; 0x01; 0x00; 0x00;
                           (* PAND (%_% xmm2) (Memop Word128 (%% (rsp,320))) *)
  0x66; 0x0f; 0xdb; 0x9c; 0x24; 0x50; 0x01; 0x00; 0x00;
                           (* PAND (%_% xmm3) (Memop Word128 (%% (rsp,336))) *)
  0x66; 0x0f; 0xeb; 0xd0;  (* POR (%_% xmm2) (%_% xmm0) *)
  0x66; 0x0f; 0xeb; 0xd9;  (* POR (%_% xmm3) (%_% xmm1) *)
  0xf3; 0x0f; 0x7f; 0x17;  (* MOVDQU (Memop Word128 (%% (rdi,0))) (%_% xmm2) *)
  0xf3; 0x0f; 0x7f; 0x5f; 0x10;
                           (* MOVDQU (Memop Word128 (%% (rdi,16))) (%_% xmm3) *)
  0x66; 0x0f; 0x6f; 0xc5;  (* MOVDQA (%_% xmm0) (%_% xmm5) *)
  0x66; 0x0f; 0x6f; 0xcd;  (* MOVDQA (%_% xmm1) (%_% xmm5) *)
  0x66; 0x0f; 0xdf; 0x84; 0x24; 0x00; 0x01; 0x00; 0x00;
                           (* PANDN (%_% xmm0) (Memop Word128 (%% (rsp,256))) *)
  0x66; 0x0f; 0x6f; 0xd5;  (* MOVDQA (%_% xmm2) (%_% xmm5) *)
  0x66; 0x0f; 0xdf; 0x8c; 0x24; 0x10; 0x01; 0x00; 0x00;
                           (* PANDN (%_% xmm1) (Memop Word128 (%% (rsp,272))) *)
  0x66; 0x0f; 0x6f; 0xdd;  (* MOVDQA (%_% xmm3) (%_% xmm5) *)
  0x66; 0x0f; 0xdb; 0x94; 0x24; 0xc0; 0x01; 0x00; 0x00;
                           (* PAND (%_% xmm2) (Memop Word128 (%% (rsp,448))) *)
  0x66; 0x0f; 0xdb; 0x9c; 0x24; 0xd0; 0x01; 0x00; 0x00;
                           (* PAND (%_% xmm3) (Memop Word128 (%% (rsp,464))) *)
  0x66; 0x0f; 0xeb; 0xd0;  (* POR (%_% xmm2) (%_% xmm0) *)
  0x66; 0x0f; 0xeb; 0xd9;  (* POR (%_% xmm3) (%_% xmm1) *)
  0x66; 0x0f; 0x6f; 0xc4;  (* MOVDQA (%_% xmm0) (%_% xmm4) *)
  0x66; 0x0f; 0x6f; 0xcc;  (* MOVDQA (%_% xmm1) (%_% xmm4) *)
  0x66; 0x0f; 0xdf; 0xc2;  (* PANDN (%_% xmm0) (%_% xmm2) *)
  0x66; 0x0f; 0x6f; 0xd4;  (* MOVDQA (%_% xmm2) (%_% xmm4) *)
  0x66; 0x0f; 0xdf; 0xcb;  (* PANDN (%_% xmm1) (%_% xmm3) *)
  0x66; 0x0f; 0x6f; 0xdc;  (* MOVDQA (%_% xmm3) (%_% xmm4) *)
  0x66; 0x0f; 0xdb; 0x94; 0x24; 0x60; 0x01; 0x00; 0x00;
                           (* PAND (%_% xmm2) (Memop Word128 (%% (rsp,352))) *)
  0x66; 0x0f; 0xdb; 0x9c; 0x24; 0x70; 0x01; 0x00; 0x00;
                           (* PAND (%_% xmm3) (Memop Word128 (%% (rsp,368))) *)
  0x66; 0x0f; 0xeb; 0xd0;  (* POR (%_% xmm2) (%_% xmm0) *)
  0x66; 0x0f; 0xeb; 0xd9;  (* POR (%_% xmm3) (%_% xmm1) *)
  0xf3; 0x0f; 0x7f; 0x57; 0x20;
                           (* MOVDQU (Memop Word128 (%% (rdi,32))) (%_% xmm2) *)
  0xf3; 0x0f; 0x7f; 0x5f; 0x30;
                           (* MOVDQU (Memop Word128 (%% (rdi,48))) (%_% xmm3) *)
  0x48; 0x8d; 0xb4; 0x24; 0x18; 0x02; 0x00; 0x00;
                           (* LEA (% rsi) (%% (rsp,536)) *)
  0x4c; 0x8b; 0x7e; 0xd0;  (* MOV (% r15) (Memop Quadword (%% (rsi,18446744073709551568))) *)
  0x4c; 0x8b; 0x76; 0xd8;  (* MOV (% r14) (Memop Quadword (%% (rsi,18446744073709551576))) *)
  0x4c; 0x8b; 0x6e; 0xe0;  (* MOV (% r13) (Memop Quadword (%% (rsi,18446744073709551584))) *)
  0x4c; 0x8b; 0x66; 0xe8;  (* MOV (% r12) (Memop Quadword (%% (rsi,18446744073709551592))) *)
  0x48; 0x8b; 0x5e; 0xf0;  (* MOV (% rbx) (Memop Quadword (%% (rsi,18446744073709551600))) *)
  0x48; 0x8b; 0x6e; 0xf8;  (* MOV (% rbp) (Memop Quadword (%% (rsi,18446744073709551608))) *)
  0x48; 0x8d; 0x26;        (* LEA (% rsp) (%% (rsi,0)) *)
  0xf3; 0xc3;              (* RET *)
  0x0f; 0x1f; 0x00;        (* NOP_N (Memop Doubleword (%% (rax,0))) *)
  0x48; 0x89; 0xc5;        (* MOV (% rbp) (% rax) *)
  0x49; 0xf7; 0xe1;        (* MUL2 (% rdx,% rax) (% r9) *)
  0x4c; 0x8b; 0x35]; ADDR ("WHOLE_READONLY_data",(4)); b[
                           (* MOV (% r14)
(Memop Quadword
(Riprel (word_sx (iword (&WHOLE_READONLY_data - (&pc + &1381)))))) *)
  0x49; 0x89; 0xc0;        (* MOV (% r8) (% rax) *)
  0x48; 0x89; 0xe8;        (* MOV (% rax) (% rbp) *)
  0x49; 0x89; 0xd1;        (* MOV (% r9) (% rdx) *)
  0x49; 0xf7; 0xe2;        (* MUL2 (% rdx,% rax) (% r10) *)
  0x4c; 0x8b; 0x3d]; ADDR ("WHOLE_READONLY_data",(20)); b[
                           (* MOV (% r15)
(Memop Quadword
(Riprel (word_sx (iword (&WHOLE_READONLY_data - (&pc + &1384)))))) *)
  0x49; 0x01; 0xc1;        (* ADD (% r9) (% rax) *)
  0x48; 0x89; 0xe8;        (* MOV (% rax) (% rbp) *)
  0x48; 0x83; 0xd2; 0x00;  (* ADC (% rdx) (Imm8 (word 0)) *)
  0x49; 0x89; 0xd2;        (* MOV (% r10) (% rdx) *)
  0x49; 0xf7; 0xe3;        (* MUL2 (% rdx,% rax) (% r11) *)
  0x49; 0x01; 0xc2;        (* ADD (% r10) (% rax) *)
  0x48; 0x89; 0xe8;        (* MOV (% rax) (% rbp) *)
  0x48; 0x83; 0xd2; 0x00;  (* ADC (% rdx) (Imm8 (word 0)) *)
  0x49; 0x89; 0xd3;        (* MOV (% r11) (% rdx) *)
  0x49; 0xf7; 0xe4;        (* MUL2 (% rdx,% rax) (% r12) *)
  0x49; 0x01; 0xc3;        (* ADD (% r11) (% rax) *)
  0x4c; 0x89; 0xc0;        (* MOV (% rax) (% r8) *)
  0x48; 0x83; 0xd2; 0x00;  (* ADC (% rdx) (Imm8 (word 0)) *)
  0x4d; 0x31; 0xed;        (* XOR (% r13) (% r13) *)
  0x49; 0x89; 0xd4;        (* MOV (% r12) (% rdx) *)
  0x4c; 0x89; 0xc5;        (* MOV (% rbp) (% r8) *)
  0x49; 0xc1; 0xe0; 0x20;  (* SHL (% r8) (Imm8 (word 32)) *)
  0x49; 0xf7; 0xe7;        (* MUL2 (% rdx,% rax) (% r15) *)
  0x48; 0xc1; 0xed; 0x20;  (* SHR (% rbp) (Imm8 (word 32)) *)
  0x4d; 0x01; 0xc1;        (* ADD (% r9) (% r8) *)
  0x49; 0x11; 0xea;        (* ADC (% r10) (% rbp) *)
  0x49; 0x11; 0xc3;        (* ADC (% r11) (% rax) *)
  0x48; 0x8b; 0x43; 0x08;  (* MOV (% rax) (Memop Quadword (%% (rbx,8))) *)
  0x49; 0x11; 0xd4;        (* ADC (% r12) (% rdx) *)
  0x49; 0x83; 0xd5; 0x00;  (* ADC (% r13) (Imm8 (word 0)) *)
  0x4d; 0x31; 0xc0;        (* XOR (% r8) (% r8) *)
  0x48; 0x89; 0xc5;        (* MOV (% rbp) (% rax) *)
  0x48; 0xf7; 0x26;        (* MUL2 (% rdx,% rax) (Memop Quadword (%% (rsi,0))) *)
  0x49; 0x01; 0xc1;        (* ADD (% r9) (% rax) *)
  0x48; 0x89; 0xe8;        (* MOV (% rax) (% rbp) *)
  0x48; 0x83; 0xd2; 0x00;  (* ADC (% rdx) (Imm8 (word 0)) *)
  0x48; 0x89; 0xd1;        (* MOV (% rcx) (% rdx) *)
  0x48; 0xf7; 0x66; 0x08;  (* MUL2 (% rdx,% rax) (Memop Quadword (%% (rsi,8))) *)
  0x49; 0x01; 0xca;        (* ADD (% r10) (% rcx) *)
  0x48; 0x83; 0xd2; 0x00;  (* ADC (% rdx) (Imm8 (word 0)) *)
  0x49; 0x01; 0xc2;        (* ADD (% r10) (% rax) *)
  0x48; 0x89; 0xe8;        (* MOV (% rax) (% rbp) *)
  0x48; 0x83; 0xd2; 0x00;  (* ADC (% rdx) (Imm8 (word 0)) *)
  0x48; 0x89; 0xd1;        (* MOV (% rcx) (% rdx) *)
  0x48; 0xf7; 0x66; 0x10;  (* MUL2 (% rdx,% rax) (Memop Quadword (%% (rsi,16))) *)
  0x49; 0x01; 0xcb;        (* ADD (% r11) (% rcx) *)
  0x48; 0x83; 0xd2; 0x00;  (* ADC (% rdx) (Imm8 (word 0)) *)
  0x49; 0x01; 0xc3;        (* ADD (% r11) (% rax) *)
  0x48; 0x89; 0xe8;        (* MOV (% rax) (% rbp) *)
  0x48; 0x83; 0xd2; 0x00;  (* ADC (% rdx) (Imm8 (word 0)) *)
  0x48; 0x89; 0xd1;        (* MOV (% rcx) (% rdx) *)
  0x48; 0xf7; 0x66; 0x18;  (* MUL2 (% rdx,% rax) (Memop Quadword (%% (rsi,24))) *)
  0x49; 0x01; 0xcc;        (* ADD (% r12) (% rcx) *)
  0x48; 0x83; 0xd2; 0x00;  (* ADC (% rdx) (Imm8 (word 0)) *)
  0x49; 0x01; 0xc4;        (* ADD (% r12) (% rax) *)
  0x4c; 0x89; 0xc8;        (* MOV (% rax) (% r9) *)
  0x49; 0x11; 0xd5;        (* ADC (% r13) (% rdx) *)
  0x49; 0x83; 0xd0; 0x00;  (* ADC (% r8) (Imm8 (word 0)) *)
  0x4c; 0x89; 0xcd;        (* MOV (% rbp) (% r9) *)
  0x49; 0xc1; 0xe1; 0x20;  (* SHL (% r9) (Imm8 (word 32)) *)
  0x49; 0xf7; 0xe7;        (* MUL2 (% rdx,% rax) (% r15) *)
  0x48; 0xc1; 0xed; 0x20;  (* SHR (% rbp) (Imm8 (word 32)) *)
  0x4d; 0x01; 0xca;        (* ADD (% r10) (% r9) *)
  0x49; 0x11; 0xeb;        (* ADC (% r11) (% rbp) *)
  0x49; 0x11; 0xc4;        (* ADC (% r12) (% rax) *)
  0x48; 0x8b; 0x43; 0x10;  (* MOV (% rax) (Memop Quadword (%% (rbx,16))) *)
  0x49; 0x11; 0xd5;        (* ADC (% r13) (% rdx) *)
  0x49; 0x83; 0xd0; 0x00;  (* ADC (% r8) (Imm8 (word 0)) *)
  0x4d; 0x31; 0xc9;        (* XOR (% r9) (% r9) *)
  0x48; 0x89; 0xc5;        (* MOV (% rbp) (% rax) *)
  0x48; 0xf7; 0x26;        (* MUL2 (% rdx,% rax) (Memop Quadword (%% (rsi,0))) *)
  0x49; 0x01; 0xc2;        (* ADD (% r10) (% rax) *)
  0x48; 0x89; 0xe8;        (* MOV (% rax) (% rbp) *)
  0x48; 0x83; 0xd2; 0x00;  (* ADC (% rdx) (Imm8 (word 0)) *)
  0x48; 0x89; 0xd1;        (* MOV (% rcx) (% rdx) *)
  0x48; 0xf7; 0x66; 0x08;  (* MUL2 (% rdx,% rax) (Memop Quadword (%% (rsi,8))) *)
  0x49; 0x01; 0xcb;        (* ADD (% r11) (% rcx) *)
  0x48; 0x83; 0xd2; 0x00;  (* ADC (% rdx) (Imm8 (word 0)) *)
  0x49; 0x01; 0xc3;        (* ADD (% r11) (% rax) *)
  0x48; 0x89; 0xe8;        (* MOV (% rax) (% rbp) *)
  0x48; 0x83; 0xd2; 0x00;  (* ADC (% rdx) (Imm8 (word 0)) *)
  0x48; 0x89; 0xd1;        (* MOV (% rcx) (% rdx) *)
  0x48; 0xf7; 0x66; 0x10;  (* MUL2 (% rdx,% rax) (Memop Quadword (%% (rsi,16))) *)
  0x49; 0x01; 0xcc;        (* ADD (% r12) (% rcx) *)
  0x48; 0x83; 0xd2; 0x00;  (* ADC (% rdx) (Imm8 (word 0)) *)
  0x49; 0x01; 0xc4;        (* ADD (% r12) (% rax) *)
  0x48; 0x89; 0xe8;        (* MOV (% rax) (% rbp) *)
  0x48; 0x83; 0xd2; 0x00;  (* ADC (% rdx) (Imm8 (word 0)) *)
  0x48; 0x89; 0xd1;        (* MOV (% rcx) (% rdx) *)
  0x48; 0xf7; 0x66; 0x18;  (* MUL2 (% rdx,% rax) (Memop Quadword (%% (rsi,24))) *)
  0x49; 0x01; 0xcd;        (* ADD (% r13) (% rcx) *)
  0x48; 0x83; 0xd2; 0x00;  (* ADC (% rdx) (Imm8 (word 0)) *)
  0x49; 0x01; 0xc5;        (* ADD (% r13) (% rax) *)
  0x4c; 0x89; 0xd0;        (* MOV (% rax) (% r10) *)
  0x49; 0x11; 0xd0;        (* ADC (% r8) (% rdx) *)
  0x49; 0x83; 0xd1; 0x00;  (* ADC (% r9) (Imm8 (word 0)) *)
  0x4c; 0x89; 0xd5;        (* MOV (% rbp) (% r10) *)
  0x49; 0xc1; 0xe2; 0x20;  (* SHL (% r10) (Imm8 (word 32)) *)
  0x49; 0xf7; 0xe7;        (* MUL2 (% rdx,% rax) (% r15) *)
  0x48; 0xc1; 0xed; 0x20;  (* SHR (% rbp) (Imm8 (word 32)) *)
  0x4d; 0x01; 0xd3;        (* ADD (% r11) (% r10) *)
  0x49; 0x11; 0xec;        (* ADC (% r12) (% rbp) *)
  0x49; 0x11; 0xc5;        (* ADC (% r13) (% rax) *)
  0x48; 0x8b; 0x43; 0x18;  (* MOV (% rax) (Memop Quadword (%% (rbx,24))) *)
  0x49; 0x11; 0xd0;        (* ADC (% r8) (% rdx) *)
  0x49; 0x83; 0xd1; 0x00;  (* ADC (% r9) (Imm8 (word 0)) *)
  0x4d; 0x31; 0xd2;        (* XOR (% r10) (% r10) *)
  0x48; 0x89; 0xc5;        (* MOV (% rbp) (% rax) *)
  0x48; 0xf7; 0x26;        (* MUL2 (% rdx,% rax) (Memop Quadword (%% (rsi,0))) *)
  0x49; 0x01; 0xc3;        (* ADD (% r11) (% rax) *)
  0x48; 0x89; 0xe8;        (* MOV (% rax) (% rbp) *)
  0x48; 0x83; 0xd2; 0x00;  (* ADC (% rdx) (Imm8 (word 0)) *)
  0x48; 0x89; 0xd1;        (* MOV (% rcx) (% rdx) *)
  0x48; 0xf7; 0x66; 0x08;  (* MUL2 (% rdx,% rax) (Memop Quadword (%% (rsi,8))) *)
  0x49; 0x01; 0xcc;        (* ADD (% r12) (% rcx) *)
  0x48; 0x83; 0xd2; 0x00;  (* ADC (% rdx) (Imm8 (word 0)) *)
  0x49; 0x01; 0xc4;        (* ADD (% r12) (% rax) *)
  0x48; 0x89; 0xe8;        (* MOV (% rax) (% rbp) *)
  0x48; 0x83; 0xd2; 0x00;  (* ADC (% rdx) (Imm8 (word 0)) *)
  0x48; 0x89; 0xd1;        (* MOV (% rcx) (% rdx) *)
  0x48; 0xf7; 0x66; 0x10;  (* MUL2 (% rdx,% rax) (Memop Quadword (%% (rsi,16))) *)
  0x49; 0x01; 0xcd;        (* ADD (% r13) (% rcx) *)
  0x48; 0x83; 0xd2; 0x00;  (* ADC (% rdx) (Imm8 (word 0)) *)
  0x49; 0x01; 0xc5;        (* ADD (% r13) (% rax) *)
  0x48; 0x89; 0xe8;        (* MOV (% rax) (% rbp) *)
  0x48; 0x83; 0xd2; 0x00;  (* ADC (% rdx) (Imm8 (word 0)) *)
  0x48; 0x89; 0xd1;        (* MOV (% rcx) (% rdx) *)
  0x48; 0xf7; 0x66; 0x18;  (* MUL2 (% rdx,% rax) (Memop Quadword (%% (rsi,24))) *)
  0x49; 0x01; 0xc8;        (* ADD (% r8) (% rcx) *)
  0x48; 0x83; 0xd2; 0x00;  (* ADC (% rdx) (Imm8 (word 0)) *)
  0x49; 0x01; 0xc0;        (* ADD (% r8) (% rax) *)
  0x4c; 0x89; 0xd8;        (* MOV (% rax) (% r11) *)
  0x49; 0x11; 0xd1;        (* ADC (% r9) (% rdx) *)
  0x49; 0x83; 0xd2; 0x00;  (* ADC (% r10) (Imm8 (word 0)) *)
  0x4c; 0x89; 0xdd;        (* MOV (% rbp) (% r11) *)
  0x49; 0xc1; 0xe3; 0x20;  (* SHL (% r11) (Imm8 (word 32)) *)
  0x49; 0xf7; 0xe7;        (* MUL2 (% rdx,% rax) (% r15) *)
  0x48; 0xc1; 0xed; 0x20;  (* SHR (% rbp) (Imm8 (word 32)) *)
  0x4d; 0x01; 0xdc;        (* ADD (% r12) (% r11) *)
  0x49; 0x11; 0xed;        (* ADC (% r13) (% rbp) *)
  0x4c; 0x89; 0xe1;        (* MOV (% rcx) (% r12) *)
  0x49; 0x11; 0xc0;        (* ADC (% r8) (% rax) *)
  0x49; 0x11; 0xd1;        (* ADC (% r9) (% rdx) *)
  0x4c; 0x89; 0xed;        (* MOV (% rbp) (% r13) *)
  0x49; 0x83; 0xd2; 0x00;  (* ADC (% r10) (Imm8 (word 0)) *)
  0x49; 0x83; 0xec; 0xff;  (* SUB (% r12) (Imm8 (word 255)) *)
  0x4c; 0x89; 0xc3;        (* MOV (% rbx) (% r8) *)
  0x4d; 0x19; 0xf5;        (* SBB (% r13) (% r14) *)
  0x49; 0x83; 0xd8; 0x00;  (* SBB (% r8) (Imm8 (word 0)) *)
  0x4c; 0x89; 0xca;        (* MOV (% rdx) (% r9) *)
  0x4d; 0x19; 0xf9;        (* SBB (% r9) (% r15) *)
  0x49; 0x83; 0xda; 0x00;  (* SBB (% r10) (Imm8 (word 0)) *)
  0x4c; 0x0f; 0x42; 0xe1;  (* CMOVB (% r12) (% rcx) *)
  0x4c; 0x0f; 0x42; 0xed;  (* CMOVB (% r13) (% rbp) *)
  0x4c; 0x89; 0x27;        (* MOV (Memop Quadword (%% (rdi,0))) (% r12) *)
  0x4c; 0x0f; 0x42; 0xc3;  (* CMOVB (% r8) (% rbx) *)
  0x4c; 0x89; 0x6f; 0x08;  (* MOV (Memop Quadword (%% (rdi,8))) (% r13) *)
  0x4c; 0x0f; 0x42; 0xca;  (* CMOVB (% r9) (% rdx) *)
  0x4c; 0x89; 0x47; 0x10;  (* MOV (Memop Quadword (%% (rdi,16))) (% r8) *)
  0x4c; 0x89; 0x4f; 0x18;  (* MOV (Memop Quadword (%% (rdi,24))) (% r9) *)
  0xf3; 0xc3;              (* RET *)
  0x66; 0x2e; 0x0f; 0x1f; 0x84; 0x00; 0x00; 0x00; 0x00; 0x00;
                           (* NOP_N (Memop Word (%%% (rax,0,rax))) *)
  0x66; 0x0f; 0x1f; 0x84; 0x00; 0x00; 0x00; 0x00; 0x00;
                           (* NOP_N (Memop Word (%%% (rax,0,rax))) *)
  0x49; 0x89; 0xc5;        (* MOV (% r13) (% rax) *)
  0x49; 0xf7; 0xe6;        (* MUL2 (% rdx,% rax) (% r14) *)
  0x49; 0x89; 0xc1;        (* MOV (% r9) (% rax) *)
  0x4c; 0x89; 0xf8;        (* MOV (% rax) (% r15) *)
  0x49; 0x89; 0xd2;        (* MOV (% r10) (% rdx) *)
  0x49; 0xf7; 0xe5;        (* MUL2 (% rdx,% rax) (% r13) *)
  0x49; 0x01; 0xc2;        (* ADD (% r10) (% rax) *)
  0x4c; 0x89; 0xc0;        (* MOV (% rax) (% r8) *)
  0x48; 0x83; 0xd2; 0x00;  (* ADC (% rdx) (Imm8 (word 0)) *)
  0x49; 0x89; 0xd3;        (* MOV (% r11) (% rdx) *)
  0x49; 0xf7; 0xe5;        (* MUL2 (% rdx,% rax) (% r13) *)
  0x49; 0x01; 0xc3;        (* ADD (% r11) (% rax) *)
  0x4c; 0x89; 0xf8;        (* MOV (% rax) (% r15) *)
  0x48; 0x83; 0xd2; 0x00;  (* ADC (% rdx) (Imm8 (word 0)) *)
  0x49; 0x89; 0xd4;        (* MOV (% r12) (% rdx) *)
  0x49; 0xf7; 0xe6;        (* MUL2 (% rdx,% rax) (% r14) *)
  0x49; 0x01; 0xc3;        (* ADD (% r11) (% rax) *)
  0x4c; 0x89; 0xc0;        (* MOV (% rax) (% r8) *)
  0x48; 0x83; 0xd2; 0x00;  (* ADC (% rdx) (Imm8 (word 0)) *)
  0x48; 0x89; 0xd5;        (* MOV (% rbp) (% rdx) *)
  0x49; 0xf7; 0xe6;        (* MUL2 (% rdx,% rax) (% r14) *)
  0x49; 0x01; 0xc4;        (* ADD (% r12) (% rax) *)
  0x4c; 0x89; 0xc0;        (* MOV (% rax) (% r8) *)
  0x48; 0x83; 0xd2; 0x00;  (* ADC (% rdx) (Imm8 (word 0)) *)
  0x49; 0x01; 0xec;        (* ADD (% r12) (% rbp) *)
  0x49; 0x89; 0xd5;        (* MOV (% r13) (% rdx) *)
  0x49; 0x83; 0xd5; 0x00;  (* ADC (% r13) (Imm8 (word 0)) *)
  0x49; 0xf7; 0xe7;        (* MUL2 (% rdx,% rax) (% r15) *)
  0x4d; 0x31; 0xff;        (* XOR (% r15) (% r15) *)
  0x49; 0x01; 0xc5;        (* ADD (% r13) (% rax) *)
  0x48; 0x8b; 0x06;        (* MOV (% rax) (Memop Quadword (%% (rsi,0))) *)
  0x49; 0x89; 0xd6;        (* MOV (% r14) (% rdx) *)
  0x49; 0x83; 0xd6; 0x00;  (* ADC (% r14) (Imm8 (word 0)) *)
  0x4d; 0x01; 0xc9;        (* ADD (% r9) (% r9) *)
  0x4d; 0x11; 0xd2;        (* ADC (% r10) (% r10) *)
  0x4d; 0x11; 0xdb;        (* ADC (% r11) (% r11) *)
  0x4d; 0x11; 0xe4;        (* ADC (% r12) (% r12) *)
  0x4d; 0x11; 0xed;        (* ADC (% r13) (% r13) *)
  0x4d; 0x11; 0xf6;        (* ADC (% r14) (% r14) *)
  0x49; 0x83; 0xd7; 0x00;  (* ADC (% r15) (Imm8 (word 0)) *)
  0x48; 0xf7; 0xe0;        (* MUL2 (% rdx,% rax) (% rax) *)
  0x49; 0x89; 0xc0;        (* MOV (% r8) (% rax) *)
  0x48; 0x8b; 0x46; 0x08;  (* MOV (% rax) (Memop Quadword (%% (rsi,8))) *)
  0x48; 0x89; 0xd1;        (* MOV (% rcx) (% rdx) *)
  0x48; 0xf7; 0xe0;        (* MUL2 (% rdx,% rax) (% rax) *)
  0x49; 0x01; 0xc9;        (* ADD (% r9) (% rcx) *)
  0x49; 0x11; 0xc2;        (* ADC (% r10) (% rax) *)
  0x48; 0x8b; 0x46; 0x10;  (* MOV (% rax) (Memop Quadword (%% (rsi,16))) *)
  0x48; 0x83; 0xd2; 0x00;  (* ADC (% rdx) (Imm8 (word 0)) *)
  0x48; 0x89; 0xd1;        (* MOV (% rcx) (% rdx) *)
  0x48; 0xf7; 0xe0;        (* MUL2 (% rdx,% rax) (% rax) *)
  0x49; 0x01; 0xcb;        (* ADD (% r11) (% rcx) *)
  0x49; 0x11; 0xc4;        (* ADC (% r12) (% rax) *)
  0x48; 0x8b; 0x46; 0x18;  (* MOV (% rax) (Memop Quadword (%% (rsi,24))) *)
  0x48; 0x83; 0xd2; 0x00;  (* ADC (% rdx) (Imm8 (word 0)) *)
  0x48; 0x89; 0xd1;        (* MOV (% rcx) (% rdx) *)
  0x48; 0xf7; 0xe0;        (* MUL2 (% rdx,% rax) (% rax) *)
  0x49; 0x01; 0xcd;        (* ADD (% r13) (% rcx) *)
  0x49; 0x11; 0xc6;        (* ADC (% r14) (% rax) *)
  0x4c; 0x89; 0xc0;        (* MOV (% rax) (% r8) *)
  0x49; 0x11; 0xd7;        (* ADC (% r15) (% rdx) *)
  0x48; 0x8b; 0x35]; ADDR ("WHOLE_READONLY_data",(4)); b[
                           (* MOV (% rsi)
(Memop Quadword
(Riprel (word_sx (iword (&WHOLE_READONLY_data - (&pc + &2146)))))) *)
  0x48; 0x8b; 0x2d]; ADDR ("WHOLE_READONLY_data",(20)); b[
                           (* MOV (% rbp)
(Memop Quadword
(Riprel (word_sx (iword (&WHOLE_READONLY_data - (&pc + &2137)))))) *)
  0x4c; 0x89; 0xc1;        (* MOV (% rcx) (% r8) *)
  0x49; 0xc1; 0xe0; 0x20;  (* SHL (% r8) (Imm8 (word 32)) *)
  0x48; 0xf7; 0xe5;        (* MUL2 (% rdx,% rax) (% rbp) *)
  0x48; 0xc1; 0xe9; 0x20;  (* SHR (% rcx) (Imm8 (word 32)) *)
  0x4d; 0x01; 0xc1;        (* ADD (% r9) (% r8) *)
  0x49; 0x11; 0xca;        (* ADC (% r10) (% rcx) *)
  0x49; 0x11; 0xc3;        (* ADC (% r11) (% rax) *)
  0x4c; 0x89; 0xc8;        (* MOV (% rax) (% r9) *)
  0x48; 0x83; 0xd2; 0x00;  (* ADC (% rdx) (Imm8 (word 0)) *)
  0x4c; 0x89; 0xc9;        (* MOV (% rcx) (% r9) *)
  0x49; 0xc1; 0xe1; 0x20;  (* SHL (% r9) (Imm8 (word 32)) *)
  0x49; 0x89; 0xd0;        (* MOV (% r8) (% rdx) *)
  0x48; 0xf7; 0xe5;        (* MUL2 (% rdx,% rax) (% rbp) *)
  0x48; 0xc1; 0xe9; 0x20;  (* SHR (% rcx) (Imm8 (word 32)) *)
  0x4d; 0x01; 0xca;        (* ADD (% r10) (% r9) *)
  0x49; 0x11; 0xcb;        (* ADC (% r11) (% rcx) *)
  0x49; 0x11; 0xc0;        (* ADC (% r8) (% rax) *)
  0x4c; 0x89; 0xd0;        (* MOV (% rax) (% r10) *)
  0x48; 0x83; 0xd2; 0x00;  (* ADC (% rdx) (Imm8 (word 0)) *)
  0x4c; 0x89; 0xd1;        (* MOV (% rcx) (% r10) *)
  0x49; 0xc1; 0xe2; 0x20;  (* SHL (% r10) (Imm8 (word 32)) *)
  0x49; 0x89; 0xd1;        (* MOV (% r9) (% rdx) *)
  0x48; 0xf7; 0xe5;        (* MUL2 (% rdx,% rax) (% rbp) *)
  0x48; 0xc1; 0xe9; 0x20;  (* SHR (% rcx) (Imm8 (word 32)) *)
  0x4d; 0x01; 0xd3;        (* ADD (% r11) (% r10) *)
  0x49; 0x11; 0xc8;        (* ADC (% r8) (% rcx) *)
  0x49; 0x11; 0xc1;        (* ADC (% r9) (% rax) *)
  0x4c; 0x89; 0xd8;        (* MOV (% rax) (% r11) *)
  0x48; 0x83; 0xd2; 0x00;  (* ADC (% rdx) (Imm8 (word 0)) *)
  0x4c; 0x89; 0xd9;        (* MOV (% rcx) (% r11) *)
  0x49; 0xc1; 0xe3; 0x20;  (* SHL (% r11) (Imm8 (word 32)) *)
  0x49; 0x89; 0xd2;        (* MOV (% r10) (% rdx) *)
  0x48; 0xf7; 0xe5;        (* MUL2 (% rdx,% rax) (% rbp) *)
  0x48; 0xc1; 0xe9; 0x20;  (* SHR (% rcx) (Imm8 (word 32)) *)
  0x4d; 0x01; 0xd8;        (* ADD (% r8) (% r11) *)
  0x49; 0x11; 0xc9;        (* ADC (% r9) (% rcx) *)
  0x49; 0x11; 0xc2;        (* ADC (% r10) (% rax) *)
  0x48; 0x83; 0xd2; 0x00;  (* ADC (% rdx) (Imm8 (word 0)) *)
  0x4d; 0x31; 0xdb;        (* XOR (% r11) (% r11) *)
  0x4d; 0x01; 0xc4;        (* ADD (% r12) (% r8) *)
  0x4d; 0x11; 0xcd;        (* ADC (% r13) (% r9) *)
  0x4d; 0x89; 0xe0;        (* MOV (% r8) (% r12) *)
  0x4d; 0x11; 0xd6;        (* ADC (% r14) (% r10) *)
  0x49; 0x11; 0xd7;        (* ADC (% r15) (% rdx) *)
  0x4d; 0x89; 0xe9;        (* MOV (% r9) (% r13) *)
  0x49; 0x83; 0xd3; 0x00;  (* ADC (% r11) (Imm8 (word 0)) *)
  0x49; 0x83; 0xec; 0xff;  (* SUB (% r12) (Imm8 (word 255)) *)
  0x4d; 0x89; 0xf2;        (* MOV (% r10) (% r14) *)
  0x49; 0x19; 0xf5;        (* SBB (% r13) (% rsi) *)
  0x49; 0x83; 0xde; 0x00;  (* SBB (% r14) (Imm8 (word 0)) *)
  0x4c; 0x89; 0xf9;        (* MOV (% rcx) (% r15) *)
  0x49; 0x19; 0xef;        (* SBB (% r15) (% rbp) *)
  0x49; 0x83; 0xdb; 0x00;  (* SBB (% r11) (Imm8 (word 0)) *)
  0x4d; 0x0f; 0x42; 0xe0;  (* CMOVB (% r12) (% r8) *)
  0x4d; 0x0f; 0x42; 0xe9;  (* CMOVB (% r13) (% r9) *)
  0x4c; 0x89; 0x27;        (* MOV (Memop Quadword (%% (rdi,0))) (% r12) *)
  0x4d; 0x0f; 0x42; 0xf2;  (* CMOVB (% r14) (% r10) *)
  0x4c; 0x89; 0x6f; 0x08;  (* MOV (Memop Quadword (%% (rdi,8))) (% r13) *)
  0x4c; 0x0f; 0x42; 0xf9;  (* CMOVB (% r15) (% rcx) *)
  0x4c; 0x89; 0x77; 0x10;  (* MOV (Memop Quadword (%% (rdi,16))) (% r14) *)
  0x4c; 0x89; 0x7f; 0x18;  (* MOV (Memop Quadword (%% (rdi,24))) (% r15) *)
  0xf3; 0xc3;              (* RET *)
  0x66; 0x2e; 0x0f; 0x1f; 0x84; 0x00; 0x00; 0x00; 0x00; 0x00;
                           (* NOP_N (Memop Word (%%% (rax,0,rax))) *)
  0x66; 0x2e; 0x0f; 0x1f; 0x84; 0x00; 0x00; 0x00; 0x00; 0x00;
                           (* NOP_N (Memop Word (%%% (rax,0,rax))) *)
  0x66; 0x2e; 0x0f; 0x1f; 0x84; 0x00; 0x00; 0x00; 0x00; 0x00;
                           (* NOP_N (Memop Word (%%% (rax,0,rax))) *)
  0x90;                    (* NOP *)
  0x4c; 0x2b; 0x23;        (* SUB (% r12) (Memop Quadword (%% (rbx,0))) *)
  0x4c; 0x1b; 0x6b; 0x08;  (* SBB (% r13) (Memop Quadword (%% (rbx,8))) *)
  0x4c; 0x89; 0xe0;        (* MOV (% rax) (% r12) *)
  0x4c; 0x1b; 0x43; 0x10;  (* SBB (% r8) (Memop Quadword (%% (rbx,16))) *)
  0x4c; 0x1b; 0x4b; 0x18;  (* SBB (% r9) (Memop Quadword (%% (rbx,24))) *)
  0x4c; 0x89; 0xed;        (* MOV (% rbp) (% r13) *)
  0x4d; 0x19; 0xdb;        (* SBB (% r11) (% r11) *)
  0x49; 0x83; 0xc4; 0xff;  (* ADD (% r12) (Imm8 (word 255)) *)
  0x4c; 0x89; 0xc1;        (* MOV (% rcx) (% r8) *)
  0x4d; 0x11; 0xf5;        (* ADC (% r13) (% r14) *)
  0x49; 0x83; 0xd0; 0x00;  (* ADC (% r8) (Imm8 (word 0)) *)
  0x4d; 0x89; 0xca;        (* MOV (% r10) (% r9) *)
  0x4d; 0x11; 0xf9;        (* ADC (% r9) (% r15) *)
  0x4d; 0x85; 0xdb;        (* TEST (% r11) (% r11) *)
  0x4c; 0x0f; 0x44; 0xe0;  (* CMOVE (% r12) (% rax) *)
  0x4c; 0x0f; 0x44; 0xed;  (* CMOVE (% r13) (% rbp) *)
  0x4c; 0x89; 0x27;        (* MOV (Memop Quadword (%% (rdi,0))) (% r12) *)
  0x4c; 0x0f; 0x44; 0xc1;  (* CMOVE (% r8) (% rcx) *)
  0x4c; 0x89; 0x6f; 0x08;  (* MOV (Memop Quadword (%% (rdi,8))) (% r13) *)
  0x4d; 0x0f; 0x44; 0xca;  (* CMOVE (% r9) (% r10) *)
  0x4c; 0x89; 0x47; 0x10;  (* MOV (Memop Quadword (%% (rdi,16))) (% r8) *)
  0x4c; 0x89; 0x4f; 0x18;  (* MOV (Memop Quadword (%% (rdi,24))) (% r9) *)
  0xf3; 0xc3;              (* RET *)
  0x66; 0x2e; 0x0f; 0x1f; 0x84; 0x00; 0x00; 0x00; 0x00; 0x00;
                           (* NOP_N (Memop Word (%%% (rax,0,rax))) *)
  0x66; 0x0f; 0x1f; 0x44; 0x00; 0x00;
                           (* NOP_N (Memop Word (%%% (rax,0,rax))) *)
  0x4c; 0x29; 0xe0;        (* SUB (% rax) (% r12) *)
  0x4c; 0x19; 0xed;        (* SBB (% rbp) (% r13) *)
  0x49; 0x89; 0xc4;        (* MOV (% r12) (% rax) *)
  0x4c; 0x19; 0xc1;        (* SBB (% rcx) (% r8) *)
  0x4d; 0x19; 0xca;        (* SBB (% r10) (% r9) *)
  0x49; 0x89; 0xed;        (* MOV (% r13) (% rbp) *)
  0x4d; 0x19; 0xdb;        (* SBB (% r11) (% r11) *)
  0x48; 0x83; 0xc0; 0xff;  (* ADD (% rax) (Imm8 (word 255)) *)
  0x49; 0x89; 0xc8;        (* MOV (% r8) (% rcx) *)
  0x4c; 0x11; 0xf5;        (* ADC (% rbp) (% r14) *)
  0x48; 0x83; 0xd1; 0x00;  (* ADC (% rcx) (Imm8 (word 0)) *)
  0x4d; 0x89; 0xd1;        (* MOV (% r9) (% r10) *)
  0x4d; 0x11; 0xfa;        (* ADC (% r10) (% r15) *)
  0x4d; 0x85; 0xdb;        (* TEST (% r11) (% r11) *)
  0x4c; 0x0f; 0x45; 0xe0;  (* CMOVNE (% r12) (% rax) *)
  0x4c; 0x0f; 0x45; 0xed;  (* CMOVNE (% r13) (% rbp) *)
  0x4c; 0x0f; 0x45; 0xc1;  (* CMOVNE (% r8) (% rcx) *)
  0x4d; 0x0f; 0x45; 0xca;  (* CMOVNE (% r9) (% r10) *)
  0xf3; 0xc3               (* RET *)
]]);;

let ECP_NISTZ256_POINT_ADD_AFFINE_EXEC =
  X86_MK_EXEC_RULE ecp_nistz256_point_add_affine_mc;;

(* ------------------------------------------------------------------------- *)
(* Rip-relative reads of the table.                                          *)
(* ------------------------------------------------------------------------- *)

let RIPREL_FOLD = prove
 (`!pc n k tgt.
     riprel32_within_bounds tgt (pc + k) /\ k <= n
     ==> word(val(word(pc + n):int64) +
              val(word_sx(iword(&tgt - (&pc + &k)):int32):int64)):int64 =
         word(tgt + (n - k))`,
  REPEAT GEN_TAC THEN STRIP_TAC THEN
  FIRST_ASSUM(MP_TAC o MATCH_MP WORD32_ADD_SUB_OF_LT) THEN
  REWRITE_TAC[GSYM INT_OF_NUM_ADD] THEN DISCH_TAC THEN
  GEN_REWRITE_TAC LAND_CONV [WORD_ADD] THEN REWRITE_TAC[WORD_VAL] THEN
  SUBGOAL_THEN `word(pc + n):int64 = word_add (word(pc + k)) (word(n - k)) /\
                word(tgt + (n - k)):int64 = word_add (word tgt) (word(n - k))`
   (fun th -> REWRITE_TAC[th]) THENL
   [REWRITE_TAC[GSYM WORD_ADD] THEN AP_TERM_TAC THEN ASM_ARITH_TAC;
    FIRST_X_ASSUM(SUBST1_TAC o SYM) THEN CONV_TAC WORD_RULE]);;
(* Restates the table's word at tbl + (n - k) as the step at pc + n reads it,
   through a displacement relocated against pc + k. *)
let RIPREL_TAC n k =
  let off = n - k in
  let tm = subst [mk_small_numeral n,`n:num`; mk_small_numeral k,`k:num`]
    `word(val(word(pc + n):int64) +
          val(word_sx(iword(&tbl - (&pc + &k)):int32):int64)):int64` in
  SUBGOAL_THEN (mk_eq(tm, mk_comb(`word:num->int64`,
                 mk_binop `(+):num->num->num` `tbl:num` (mk_small_numeral off))))
   (fun th -> RULE_ASSUM_TAC(REWRITE_RULE[GSYM th])) THENL
   [W(MP_TAC o PART_MATCH (lhand o rand) RIPREL_FOLD o lhand o snd) THEN
    ASM_REWRITE_TAC[] THEN CONV_TAC NUM_REDUCE_CONV THEN SIMP_TAC[];
    ALL_TAC];;

(* ------------------------------------------------------------------------- *)
(* The field helpers, each from its entry to its return.                     *)
(* ------------------------------------------------------------------------- *)

let ECP_NISTZ256_MUL_MONTQ_CORRECT = time prove
 (`!z pa pb a0 a1 a2 a3 b0 b1 b2 b3 pc tbl stackpointer returnaddress.
     riprel32_within_bounds tbl (pc + 1381) /\
     riprel32_within_bounds tbl (pc + 1384) /\
     nonoverlapping (word pc,0x9fe) (z,32) /\
     nonoverlapping (word tbl,200) (z,32) /\
     nonoverlapping (stackpointer,8) (z,32)
     ==> ensures x86
          (\s. bytes_loaded s (word pc) (ecp_nistz256_point_add_affine_mc pc tbl) /\
               read RIP s = word(pc + 0x560) /\
               read RSP s = stackpointer /\
               read (memory :> bytes64 stackpointer) s = returnaddress /\
               read (memory :> bytes64 (word(tbl + 8))) s = word 0xffffffff /\
               read (memory :> bytes64 (word(tbl + 24))) s = word 0xffffffff00000001 /\
               read RDI s = z /\ read RSI s = pa /\ read RBX s = pb /\
               read RAX s = b0 /\
               read R9 s = a0 /\ read R10 s = a1 /\ read R11 s = a2 /\ read R12 s = a3 /\
               read (memory :> bytes64 pa) s = a0 /\
               read (memory :> bytes64 (word_add pa (word 8))) s = a1 /\
               read (memory :> bytes64 (word_add pa (word 16))) s = a2 /\
               read (memory :> bytes64 (word_add pa (word 24))) s = a3 /\
               read (memory :> bytes64 pb) s = b0 /\
               read (memory :> bytes64 (word_add pb (word 8))) s = b1 /\
               read (memory :> bytes64 (word_add pb (word 16))) s = b2 /\
               read (memory :> bytes64 (word_add pb (word 24))) s = b3)
          (\s. read RIP s = returnaddress /\
               read RSP s = word_add stackpointer (word 8) /\
               read R14 s = word 0xffffffff /\
               read R15 s = word 0xffffffff00000001 /\
               (bignum_of_wordlist [a0;a1;a2;a3] * bignum_of_wordlist [b0;b1;b2;b3]
                  <= 2 EXP 256 * p_256
                ==> bignum_from_memory (z,4) s =
                      (inverse_mod p_256 (2 EXP 256) *
                       bignum_of_wordlist [a0;a1;a2;a3] *
                       bignum_of_wordlist [b0;b1;b2;b3]) MOD p_256 /\
                    bignum_of_wordlist [read R12 s; read R13 s; read R8 s; read R9 s] =
                      (inverse_mod p_256 (2 EXP 256) *
                       bignum_of_wordlist [a0;a1;a2;a3] *
                       bignum_of_wordlist [b0;b1;b2;b3]) MOD p_256))
          (MAYCHANGE [RIP; RSP; RAX; RBX; RCX; RDX; RBP; R8; R9; R10; R11;
                      R12; R13; R14; R15] ,,
           MAYCHANGE SOME_FLAGS ,, MAYCHANGE [events] ,,
           MAYCHANGE [memory :> bytes(z,8 * 4)])`,
  MAP_EVERY X_GEN_TAC
   [`z:int64`; `pa:int64`; `pb:int64`; `a0:int64`; `a1:int64`; `a2:int64`; `a3:int64`;
    `b0:int64`; `b1:int64`; `b2:int64`; `b3:int64`; `pc:num`; `tbl:num`;
    `stackpointer:int64`; `returnaddress:int64`] THEN
  REWRITE_TAC[C_ARGUMENTS; C_RETURN; SOME_FLAGS; NONOVERLAPPING_CLAUSES] THEN
  DISCH_THEN(REPEAT_TCL CONJUNCTS_THEN ASSUME_TAC) THEN
  ENSURES_INIT_TAC "s0" THEN RIPREL_TAC 1389 1381 THEN RIPREL_TAC 1408 1384 THEN
  X86_ACCSTEPS_TAC ECP_NISTZ256_POINT_ADD_AFFINE_EXEC (1--148) (1--148) THEN
  ABBREV_TAC
   `t = bignum_of_wordlist
          [sum_s142; sum_s143; sum_s145; sum_s146; sum_s148]` THEN
  ASM_CASES_TAC `bignum_of_wordlist [a0;a1;a2;a3] * bignum_of_wordlist [b0;b1;b2;b3]
                  <= 2 EXP 256 * p_256` THENL
   [ALL_TAC;
    X86_STEPS_TAC ECP_NISTZ256_POINT_ADD_AFFINE_EXEC (149--164) THEN
    ENSURES_FINAL_STATE_TAC THEN ASM_REWRITE_TAC[]] THEN
  SUBGOAL_THEN
   `t < 2 * p_256 /\
    (2 EXP 256 * t == bignum_of_wordlist [a0;a1;a2;a3] *
                      bignum_of_wordlist [b0;b1;b2;b3]) (mod p_256)`
  STRIP_ASSUME_TAC THENL
   [ACCUMULATOR_POP_ASSUM_LIST
     (STRIP_ASSUME_TAC o end_itlist CONJ o DECARRY_RULE) THEN
    CONJ_TAC THENL
     [FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP (ARITH_RULE
        `ab <= 2 EXP 256 * p
         ==> 2 EXP 256 * t < ab + 2 EXP 256 * p ==> t < 2 * p`)) THEN
      EXPAND_TAC "t" THEN
      REWRITE_TAC[GSYM REAL_OF_NUM_CLAUSES; bignum_of_wordlist] THEN
      REWRITE_TAC[p_256; REAL_ARITH `a:real < b + c <=> a - b < c`] THEN
      ASM_REWRITE_TAC[] THEN BOUNDER_TAC[];
      REWRITE_TAC[REAL_CONGRUENCE; p_256] THEN CONV_TAC NUM_REDUCE_CONV THEN
      EXPAND_TAC "t" THEN
      REWRITE_TAC[GSYM REAL_OF_NUM_CLAUSES; bignum_of_wordlist] THEN
      ASM_REWRITE_TAC[] THEN REAL_INTEGER_TAC];
    ACCUMULATOR_POP_ASSUM_LIST(K ALL_TAC)] THEN
  X86_ACCSTEPS_TAC ECP_NISTZ256_POINT_ADD_AFFINE_EXEC
   [149;151;152;154;155] (149--164) THEN
  ENSURES_FINAL_STATE_TAC THEN
  ASM_REWRITE_TAC[] THEN
  CONV_TAC(ONCE_DEPTH_CONV BIGNUM_LEXPAND_CONV) THEN ASM_REWRITE_TAC[WORD_ADD_0] THEN
  CONV_TAC(LAND_CONV(REWRITE_CONV[bignum_of_wordlist; MULT_CLAUSES; ADD_CLAUSES])) THEN
  TRANS_TAC EQ_TRANS `t MOD p_256` THEN CONJ_TAC THENL
   [ALL_TAC;
    REWRITE_TAC[GSYM CONG] THEN FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP
     (NUMBER_RULE
       `(e * t == a * b) (mod p)
        ==> (e * i == 1) (mod p) ==> (t == i * a * b) (mod p)`)) THEN
    REWRITE_TAC[INVERSE_MOD_RMUL_EQ; COPRIME_REXP; COPRIME_2] THEN
    REWRITE_TAC[p_256] THEN CONV_TAC NUM_REDUCE_CONV] THEN
  CONV_TAC SYM_CONV THEN MATCH_MP_TAC EQUAL_FROM_CONGRUENT_MOD_MOD THEN
  MAP_EVERY EXISTS_TAC
   [`256`; `if t < p_256 then &t:real else &t - &p_256`] THEN
  REPEAT CONJ_TAC THENL
   [REWRITE_TAC[GSYM REAL_OF_NUM_CLAUSES] THEN BOUNDER_TAC[];
    REWRITE_TAC[p_256] THEN ARITH_TAC;
    REWRITE_TAC[p_256] THEN ARITH_TAC;
    ALL_TAC;
    ASM_SIMP_TAC[MOD_CASES] THEN
    GEN_REWRITE_TAC LAND_CONV [COND_RAND] THEN
    SIMP_TAC[REAL_OF_NUM_SUB; GSYM NOT_LT]] THEN
  SUBGOAL_THEN `carry_s155 <=> t < p_256` SUBST_ALL_TAC THENL
   [MATCH_MP_TAC FLAG_FROM_CARRY_LT THEN EXISTS_TAC `320` THEN
    EXPAND_TAC "t" THEN
    REWRITE_TAC[p_256; bignum_of_wordlist; GSYM REAL_OF_NUM_CLAUSES] THEN
    CONV_TAC NUM_REDUCE_CONV THEN
    ACCUMULATOR_POP_ASSUM_LIST(MP_TAC o end_itlist CONJ o DECARRY_RULE) THEN
    DISCH_THEN(fun th -> REWRITE_TAC[th]) THEN BOUNDER_TAC[];
    ALL_TAC] THEN
  COND_CASES_TAC THEN ASM_REWRITE_TAC[] THEN EXPAND_TAC "t" THEN
  REWRITE_TAC[GSYM REAL_OF_NUM_CLAUSES; bignum_of_wordlist; p_256] THEN
  ACCUMULATOR_POP_ASSUM_LIST(MP_TAC o end_itlist CONJ o DESUM_RULE) THEN
  ASM_REWRITE_TAC[BITVAL_CLAUSES; VAL_WORD_BITVAL] THEN
  DISCH_THEN(fun th -> REWRITE_TAC[th]) THEN REAL_INTEGER_TAC);;

let ECP_NISTZ256_SQR_MONTQ_CORRECT = time prove
 (`!z pa a0 a1 a2 a3 pc tbl stackpointer returnaddress.
     riprel32_within_bounds tbl (pc + 2146) /\
     riprel32_within_bounds tbl (pc + 2137) /\
     nonoverlapping (word pc,0x9fe) (z,32) /\
     nonoverlapping (word tbl,200) (z,32) /\
     nonoverlapping (stackpointer,8) (z,32)
     ==> ensures x86
          (\s. bytes_loaded s (word pc) (ecp_nistz256_point_add_affine_mc pc tbl) /\
               read RIP s = word(pc + 0x7a0) /\
               read RSP s = stackpointer /\
               read (memory :> bytes64 stackpointer) s = returnaddress /\
               read (memory :> bytes64 (word(tbl + 8))) s = word 0xffffffff /\
               read (memory :> bytes64 (word(tbl + 24))) s = word 0xffffffff00000001 /\
               read RDI s = z /\ read RSI s = pa /\
               read RAX s = a0 /\ read R14 s = a1 /\ read R15 s = a2 /\ read R8 s = a3 /\
               read (memory :> bytes64 pa) s = a0 /\
               read (memory :> bytes64 (word_add pa (word 8))) s = a1 /\
               read (memory :> bytes64 (word_add pa (word 16))) s = a2 /\
               read (memory :> bytes64 (word_add pa (word 24))) s = a3)
          (\s. read RIP s = returnaddress /\
               read RSP s = word_add stackpointer (word 8) /\
               (bignum_of_wordlist [a0;a1;a2;a3] EXP 2 <= 2 EXP 256 * p_256
                ==> bignum_from_memory (z,4) s =
                      (inverse_mod p_256 (2 EXP 256) *
                       bignum_of_wordlist [a0;a1;a2;a3] EXP 2) MOD p_256 /\
                    bignum_of_wordlist [read R12 s; read R13 s; read R14 s; read R15 s] =
                      (inverse_mod p_256 (2 EXP 256) *
                       bignum_of_wordlist [a0;a1;a2;a3] EXP 2) MOD p_256))
          (MAYCHANGE [RIP; RSP; RAX; RCX; RDX; RSI; RBP; R8; R9; R10; R11;
                      R12; R13; R14; R15] ,,
           MAYCHANGE SOME_FLAGS ,, MAYCHANGE [events] ,,
           MAYCHANGE [memory :> bytes(z,8 * 4)])`,
  MAP_EVERY X_GEN_TAC
   [`z:int64`; `pa:int64`; `a0:int64`; `a1:int64`; `a2:int64`; `a3:int64`;
    `pc:num`; `tbl:num`; `stackpointer:int64`; `returnaddress:int64`] THEN
  REWRITE_TAC[C_ARGUMENTS; C_RETURN; SOME_FLAGS; NONOVERLAPPING_CLAUSES] THEN
  DISCH_THEN(REPEAT_TCL CONJUNCTS_THEN ASSUME_TAC) THEN
  ENSURES_INIT_TAC "s0" THEN RIPREL_TAC 2154 2146 THEN RIPREL_TAC 2161 2137 THEN
  MAP_EVERY (fun n ->
    X86_STEPS_TAC ECP_NISTZ256_POINT_ADD_AFFINE_EXEC [n] THEN
    TRY(ACCUMULATE_ARITH_TAC("s"^string_of_int n))) (1--109) THEN
  ABBREV_TAC
   `t = bignum_of_wordlist
          [sum_s103; sum_s104; sum_s106; sum_s107; word(bitval carry_s107)]` THEN
  ASM_CASES_TAC `bignum_of_wordlist [a0;a1;a2;a3] EXP 2 <= 2 EXP 256 * p_256` THENL
   [ALL_TAC;
    X86_STEPS_TAC ECP_NISTZ256_POINT_ADD_AFFINE_EXEC (110--125) THEN
    ENSURES_FINAL_STATE_TAC THEN ASM_REWRITE_TAC[]] THEN
  SUBGOAL_THEN
   `2 EXP 256 * t =
    bignum_of_wordlist [a0;a1;a2;a3] EXP 2 +
    p_256 * bignum_of_wordlist [mullo_s41; sum_s68; sum_s78; sum_s88]`
  ASSUME_TAC THENL
   [RULE_ASSUM_TAC(REWRITE_RULE[VAL_WORD_BITVAL]) THEN
    ACCUMULATOR_POP_ASSUM_LIST
     (STRIP_ASSUME_TAC o end_itlist CONJ o DECARRY_RULE) THEN
    EXPAND_TAC "t" THEN
    REWRITE_TAC[GSYM REAL_OF_NUM_EQ; GSYM REAL_OF_NUM_CLAUSES;
                bignum_of_wordlist; VAL_WORD_BITVAL; p_256] THEN
    ASM_REWRITE_TAC[] THEN REAL_ARITH_TAC;
    ACCUMULATOR_POP_ASSUM_LIST(K ALL_TAC)] THEN
  SUBGOAL_THEN
   `t < 2 * p_256 /\
    (2 EXP 256 * t == bignum_of_wordlist [a0;a1;a2;a3] EXP 2) (mod p_256)`
  STRIP_ASSUME_TAC THENL
   [CONJ_TAC THENL
     [MP_TAC(ISPECL [`[mullo_s41; sum_s68; sum_s78; sum_s88]:int64 list`]
        BIGNUM_OF_WORDLIST_BOUND_LENGTH) THEN
      REWRITE_TAC[LENGTH] THEN CONV_TAC NUM_REDUCE_CONV THEN
      UNDISCH_TAC `bignum_of_wordlist [a0;a1;a2;a3] EXP 2 <= 2 EXP 256 * p_256` THEN
      UNDISCH_TAC
       `2 EXP 256 * t =
        bignum_of_wordlist [a0;a1;a2;a3] EXP 2 +
        p_256 * bignum_of_wordlist [mullo_s41; sum_s68; sum_s78; sum_s88]` THEN
      SPEC_TAC(`bignum_of_wordlist [mullo_s41; sum_s68; sum_s78; sum_s88]`,`q:num`) THEN
      SPEC_TAC(`bignum_of_wordlist [a0;a1;a2;a3] EXP 2`,`aa:num`) THEN
      REWRITE_TAC[p_256] THEN ARITH_TAC;
      ASM_REWRITE_TAC[] THEN CONV_TAC NUMBER_RULE];
    ALL_TAC] THEN
  X86_ACCSTEPS_TAC ECP_NISTZ256_POINT_ADD_AFFINE_EXEC
   [110;112;113;115;116] (110--125) THEN
  ENSURES_FINAL_STATE_TAC THEN ASM_REWRITE_TAC[] THEN
  CONV_TAC(ONCE_DEPTH_CONV BIGNUM_LEXPAND_CONV) THEN ASM_REWRITE_TAC[WORD_ADD_0] THEN
  CONV_TAC(LAND_CONV(REWRITE_CONV[bignum_of_wordlist; MULT_CLAUSES; ADD_CLAUSES])) THEN
  TRANS_TAC EQ_TRANS `t MOD p_256` THEN CONJ_TAC THENL
   [ALL_TAC;
    REWRITE_TAC[GSYM CONG] THEN FIRST_X_ASSUM(MATCH_MP_TAC o MATCH_MP
     (NUMBER_RULE
       `(e * t == a) (mod p)
        ==> (e * i == 1) (mod p) ==> (t == i * a) (mod p)`)) THEN
    REWRITE_TAC[INVERSE_MOD_RMUL_EQ; COPRIME_REXP; COPRIME_2] THEN
    REWRITE_TAC[p_256] THEN CONV_TAC NUM_REDUCE_CONV] THEN
  CONV_TAC SYM_CONV THEN MATCH_MP_TAC EQUAL_FROM_CONGRUENT_MOD_MOD THEN
  MAP_EVERY EXISTS_TAC
   [`256`; `if t < p_256 then &t:real else &t - &p_256`] THEN
  REPEAT CONJ_TAC THENL
   [REWRITE_TAC[GSYM REAL_OF_NUM_CLAUSES] THEN BOUNDER_TAC[];
    REWRITE_TAC[p_256] THEN ARITH_TAC;
    REWRITE_TAC[p_256] THEN ARITH_TAC;
    ALL_TAC;
    ASM_SIMP_TAC[MOD_CASES] THEN
    GEN_REWRITE_TAC LAND_CONV [COND_RAND] THEN
    SIMP_TAC[REAL_OF_NUM_SUB; GSYM NOT_LT]] THEN
  SUBGOAL_THEN `carry_s116 <=> t < p_256` SUBST_ALL_TAC THENL
   [MATCH_MP_TAC FLAG_FROM_CARRY_LT THEN EXISTS_TAC `320` THEN
    EXPAND_TAC "t" THEN
    REWRITE_TAC[p_256; bignum_of_wordlist; GSYM REAL_OF_NUM_CLAUSES; VAL_WORD_BITVAL] THEN
    CONV_TAC NUM_REDUCE_CONV THEN
    ACCUMULATOR_POP_ASSUM_LIST(MP_TAC o end_itlist CONJ o DECARRY_RULE) THEN
    DISCH_THEN(fun th -> REWRITE_TAC[th]) THEN BOUNDER_TAC[];
    ALL_TAC] THEN
  COND_CASES_TAC THEN ASM_REWRITE_TAC[] THEN EXPAND_TAC "t" THEN
  REWRITE_TAC[GSYM REAL_OF_NUM_CLAUSES; bignum_of_wordlist; p_256; VAL_WORD_BITVAL] THEN
  ACCUMULATOR_POP_ASSUM_LIST(MP_TAC o end_itlist CONJ o DESUM_RULE) THEN
  ASM_REWRITE_TAC[BITVAL_CLAUSES; VAL_WORD_BITVAL] THEN
  DISCH_THEN(fun th -> REWRITE_TAC[th]) THEN REAL_INTEGER_TAC);;
