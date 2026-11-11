(*
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0
 *)

(* ========================================================================= *)
(* Constant-time byte compare, as rind's build emits it.                     *)
(* ========================================================================= *)

(* The asm! block in rind's low::x86_64::cpu::ct_compare_bytes, which ORs
   together the XOR of each pair of bytes at RDI and RSI, RDX of them, into
   RAX, zero on entry. RAX ends below 256, and zero exactly when the bytes
   are equal. Its loads and branches depend only on RDI, RSI, and RDX. *)

needs "x86/proofs/base.ml";;

(* admin/prove writes the block's bytes, as rind's release build emits them,
   to x86_64/ct_compare_bytes.bin, and the definition fails unless they are
   these. *)
let ct_compare_bytes_mc = define_assert_word_list "ct_compare_bytes_mc"
  (term_of_bytes (load_file "x86_64/ct_compare_bytes.bin"))
[
  0x48; 0x83; 0xfa; 0x00;  (* CMP (% rdx) (Imm8 (word 0)) *)
  0x74; 0x1a;              (* JE (Imm8 (word 26)) *)
  0x0f; 0xb6; 0x0f;        (* MOVZX (% ecx) (Memop Byte (%% (rdi,0))) *)
  0x44; 0x0f; 0xb6; 0x06;  (* MOVZX (% r8d) (Memop Byte (%% (rsi,0))) *)
  0x44; 0x31; 0xc1;        (* XOR (% ecx) (% r8d) *)
  0x09; 0xc8;              (* OR (% eax) (% ecx) *)
  0x48; 0x83; 0xc7; 0x01;  (* ADD (% rdi) (Imm8 (word 1)) *)
  0x48; 0x83; 0xc6; 0x01;  (* ADD (% rsi) (Imm8 (word 1)) *)
  0x48; 0x83; 0xea; 0x01;  (* SUB (% rdx) (Imm8 (word 1)) *)
  0xeb; 0xe0               (* JMP (Imm8 (word 224)) *)
];;

let CT_COMPARE_BYTES_EXEC = X86_MK_EXEC_RULE ct_compare_bytes_mc;;

(* Two strings of i + 1 bytes are equal exactly when their first i bytes
   and their last bytes are. *)
let CT_COMPARE_BYTES_STEP = prove
 (`!x y i.
        x MOD 2 EXP (8 * (i + 1)) = y MOD 2 EXP (8 * (i + 1)) <=>
        x MOD 2 EXP (8 * i) = y MOD 2 EXP (8 * i) /\
        (word(x DIV 2 EXP (8 * i)):byte) = word(y DIV 2 EXP (8 * i))`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC[ARITH_RULE `8 * (i + 1) = 8 * i + 8`; EXP_ADD; MOD_MULT_MOD] THEN
  REWRITE_TAC[GSYM VAL_EQ; VAL_WORD; DIMINDEX_8] THEN
  CONV_TAC NUM_REDUCE_CONV THEN
  SIMP_TAC[LEXICOGRAPHIC_EQ; MOD_LT_EQ; EXP_EQ_0; ARITH_EQ] THEN
  CONV_TAC TAUT);;

(* A word below 256 is its low byte. *)
let CT_COMPARE_BYTES_VAL = prove
 (`!z:int64. val z < 256 <=> z = word_zx(word_zx z:byte)`,
  GEN_TAC THEN
  REWRITE_TAC[GSYM VAL_EQ; VAL_WORD_ZX_GEN; DIMINDEX_8; DIMINDEX_64] THEN
  CONV_TAC NUM_REDUCE_CONV THEN
  SIMP_TAC[MOD_LT; MOD_LT_EQ; ARITH_RULE `x < 256 ==> x < 18446744073709551616`;
           ARITH_EQ] THEN
  MESON_TAC[MOD_EQ_SELF; ARITH_EQ]);;

(* The byte at offset i of a string is its value's digit i. *)
let CT_COMPARE_BYTES_LOAD = prove
 (`!a n i x s.
        read (bytes(a,n)) s = x /\ i < n
        ==> read (bytes8 (word_add a (word i))) s = word(x DIV 2 EXP (8 * i))`,
  REPEAT STRIP_TAC THEN FIRST_X_ASSUM(SUBST1_TAC o SYM) THEN
  REWRITE_TAC[READ_BYTES_DIV] THEN
  ONCE_REWRITE_TAC[GSYM WORD_MOD_SIZE] THEN REWRITE_TAC[DIMINDEX_8] THEN
  REWRITE_TAC[ARITH_RULE `2 EXP 8 = 2 EXP (8 * 1)`; READ_BYTES_MOD] THEN
  ASM_SIMP_TAC[ARITH_RULE `i < n ==> MIN (n - i) 1 = 1`] THEN
  REWRITE_TAC[READ_BYTES_BYTES8; WORD_VAL; WORD_MOD_SIZE]);;

let T s g = (print_endline ("MARK " ^ s); ALL_TAC g);;
let CT_COMPARE_BYTES_CORRECT = prove
 (`!a b n x y pc.
        ensures x86
          (\s. bytes_loaded s (word pc) ct_compare_bytes_mc /\
               read RIP s = word pc /\
               read RDI s = a /\ read RSI s = b /\ read RDX s = n /\
               read RAX s = word 0 /\
               read (memory :> bytes(a,val n)) s = x /\
               read (memory :> bytes(b,val n)) s = y)
          (\s. read RIP s = word (pc + 0x20) /\
               val(read RAX s) < 256 /\
               (read RAX s = word 0 <=> x = y))
          (MAYCHANGE [RIP; RDI; RSI; RDX; RAX; RCX; R8] ,, MAYCHANGE SOME_FLAGS ,,
           MAYCHANGE [events])`,
  MAP_EVERY X_GEN_TAC [`a:int64`; `b:int64`] THEN
  W64_GEN_TAC `n:num` THEN MAP_EVERY X_GEN_TAC [`x:num`; `y:num`; `pc:num`] THEN
  REWRITE_TAC[SOME_FLAGS; fst CT_COMPARE_BYTES_EXEC] THEN
  T "a" THEN ASM_CASES_TAC `n = 0` THENL
   [ASM_REWRITE_TAC[] THEN
    ENSURES_INIT_TAC "s0" THEN T "b" THEN
    X86_STEPS_TAC CT_COMPARE_BYTES_EXEC (1--2) THEN T "c" THEN
    ENSURES_FINAL_STATE_TAC THEN T "d" THEN ASM_REWRITE_TAC[] THEN
    RULE_ASSUM_TAC(REWRITE_RULE[READ_COMPONENT_COMPOSE; READ_BYTES_TRIVIAL]) THEN
    REPEAT(FIRST_X_ASSUM(SUBST_ALL_TAC o SYM o check (is_var o rhs o concl))) THEN
    REWRITE_TAC[VAL_WORD_0] THEN CONV_TAC NUM_REDUCE_CONV;
    ALL_TAC] THEN T "loop" THEN
  ENSURES_WHILE_UP2_TAC `n:num` `pc + 0x6` `pc + 0x20`
   `\i s. read RDI s = word_add a (word i) /\
          read RSI s = word_add b (word i) /\
          read RDX s = word(n - i) /\
          val(read RAX s) < 256 /\
          read (memory :> bytes(a,n)) s = x /\
          read (memory :> bytes(b,n)) s = y /\
          (read RAX s = word 0 <=>
           x MOD 2 EXP (8 * i) = y MOD 2 EXP (8 * i))` THEN
  ASM_REWRITE_TAC[] THEN T "conj" THEN REPEAT CONJ_TAC THENL
   [T "init" THEN ENSURES_INIT_TAC "s0" THEN
    X86_STEPS_TAC CT_COMPARE_BYTES_EXEC (1--2) THEN
    ENSURES_FINAL_STATE_TAC THEN ASM_REWRITE_TAC[WORD_SUB_0] THEN
    REWRITE_TAC[VAL_WORD_0; WORD_ADD_0; SUB_0; MULT_CLAUSES; EXP; MOD_1] THEN
    CONV_TAC NUM_REDUCE_CONV;
    ALL_TAC;
    ENSURES_INIT_TAC "s0" THEN ENSURES_FINAL_STATE_TAC THEN
    ASM_REWRITE_TAC[] THEN
    BINOP_TAC THEN MATCH_MP_TAC MOD_LT THEN
    ASM_MESON_TAC[READ_BYTES_BOUND; READ_COMPONENT_COMPOSE]] THEN
  X_GEN_TAC `i:num` THEN STRIP_TAC THEN
  GHOST_INTRO_TAC `acc:int64` `read RAX` THEN
  ENSURES_INIT_TAC "s0" THEN
  MP_TAC(SPECL [`a:int64`; `n:num`; `i:num`; `x:num`; `read memory s0`]
    CT_COMPARE_BYTES_LOAD) THEN
  MP_TAC(SPECL [`b:int64`; `n:num`; `i:num`; `y:num`; `read memory s0`]
    CT_COMPARE_BYTES_LOAD) THEN
  REWRITE_TAC[GSYM READ_COMPONENT_COMPOSE] THEN ASM_REWRITE_TAC[] THEN
  REPEAT(DISCH_THEN ASSUME_TAC) THEN
  X86_STEPS_TAC CT_COMPARE_BYTES_EXEC (1--10) THEN
  ENSURES_FINAL_STATE_TAC THEN ASM_REWRITE_TAC[] THEN
  T "body" THEN
  SUBGOAL_THEN `word_sub (word (n - i)) (word 1):int64 = word(n - (i + 1))`
  SUBST1_TAC THENL
   [REWRITE_TAC[WORD_RULE
     `word_sub x (word 1):int64 = word y <=> x = word(y + 1)`] THEN
    AP_TERM_TAC THEN UNDISCH_TAC `i:num < n` THEN ARITH_TAC;
    ALL_TAC] THEN
  REWRITE_TAC[WORD_SUB_0] THEN VAL_INT64_TAC `n - (i + 1)` THEN
  ASM_REWRITE_TAC[VAL_WORD_0] THEN
  CONJ_TAC THENL
   [REWRITE_TAC[ARITH_RULE `n - (i + 1) = 0 <=> ~(i + 1 < n)`] THEN
    COND_CASES_TAC THEN ASM_REWRITE_TAC[];
    ALL_TAC] THEN
  CONJ_TAC THENL [CONV_TAC WORD_RULE; ALL_TAC] THEN
  CONJ_TAC THENL [CONV_TAC WORD_RULE; ALL_TAC] THEN
  T "acc" THEN
  SUBGOAL_THEN `?c:byte. acc:int64 = word_zx c`
   (X_CHOOSE_THEN `c:byte` SUBST_ALL_TAC) THENL
   [EXISTS_TAC `word_zx(acc:int64):byte` THEN
    REWRITE_TAC[GSYM VAL_EQ; VAL_WORD_ZX_GEN; DIMINDEX_8; DIMINDEX_64] THEN
    CONV_TAC NUM_REDUCE_CONV THEN ASM_SIMP_TAC[MOD_LT; ARITH_RULE
      `x < 256 ==> x < 18446744073709551616`];
    ALL_TAC] THEN
  REWRITE_TAC[CT_COMPARE_BYTES_STEP] THEN
  FIRST_X_ASSUM(fun th ->
    if is_iff(concl th) && free_in `c:byte` (concl th)
    then REWRITE_TAC[GSYM th] else failwith "not IH") THEN
  T "blast" THEN
  MAP_EVERY SPEC_TAC
   [`word(x DIV 2 EXP (8 * i)):byte`,`u:byte`;
    `word(y DIV 2 EXP (8 * i)):byte`,`v:byte`] THEN
  REPEAT GEN_TAC THEN
  REWRITE_TAC[CT_COMPARE_BYTES_VAL] THEN
  CONJ_TAC THEN BITBLAST_TAC);;

(* ------------------------------------------------------------------------- *)
(* Constant time: the trace of loads and branches is a function of the       *)
(* addresses, the length, and the PC alone, and each load is in bounds.      *)
(* ------------------------------------------------------------------------- *)

needs "x86/proofs/consttime.ml";;

let CT_COMPARE_BYTES_SAFE = prove
 (`exists f_events.
       forall e a b n pc.
           ensures x86
           (\s. bytes_loaded s (word pc) ct_compare_bytes_mc /\
                read RIP s = word pc /\
                read RDI s = a /\ read RSI s = b /\ read RDX s = n /\
                read events s = e)
           (\s. read RIP s = word (pc + 0x20) /\
                exists e2.
                    read events s = APPEND e2 e /\
                    e2 = f_events a b n pc /\
                    memaccess_inbounds e2 [a,val n; b,val n] [])
           (\s s'. true)`,
  CONCRETIZE_F_EVENTS_TAC
   `\(a:int64) (b:int64) (n:int64) (pc:num).
      if val n = 0 then f_ev_zero a b n pc
      else APPEND (f_ev_post a b n pc)
             (APPEND (ENUMERATEL (val n) (f_ev_loop a b n pc))
                     (f_ev_entry a b n pc))
      :(uarch_event) list` THEN
  REPEAT META_EXISTS_TAC THEN
  STRIP_TAC THEN
  MAP_EVERY X_GEN_TAC [`a:int64`; `b:int64`] THEN
  W64_GEN_TAC `n:num` THEN X_GEN_TAC `pc:num` THEN
  REWRITE_TAC[fst CT_COMPARE_BYTES_EXEC] THEN
  ASM_CASES_TAC `n = 0` THENL
   [ASM_REWRITE_TAC[] THEN T "s-zero" THEN
    X86_SIM_TAC ~preprocess_tac:(TRY STRIP_EXISTS_ASSUM_TAC)
    CT_COMPARE_BYTES_EXEC (1--2) THEN
    ASM_REWRITE_TAC[WORD_SUB_0; VAL_WORD_0] THEN
    DISCHARGE_SAFETY_PROPERTY_TAC;
    ALL_TAC] THEN
  ASM_REWRITE_TAC[] THEN T "s-loop" THEN
  ENSURES_EVENTS_WHILE_UP2_TAC `n:num` `pc + 0x6` `pc + 0x20`
   `\i s. read RDI s = word_add a (word i) /\
          read RSI s = word_add b (word i) /\
          read RDX s = word(n - i)` THEN
  ASM_REWRITE_TAC[] THEN REPEAT CONJ_TAC THENL
   [T "s-init" THEN
    X86_SIM_TAC ~preprocess_tac:(TRY STRIP_EXISTS_ASSUM_TAC)
    CT_COMPARE_BYTES_EXEC (1--2) THEN
    ASM_REWRITE_TAC[WORD_SUB_0; WORD_ADD_0; SUB_0; VAL_WORD_0] THEN
    DISCHARGE_SAFETY_PROPERTY_TAC;
    ALL_TAC;
    T "s-post" THEN
    ENSURES_INIT_TAC "s0" THEN TRY STRIP_EXISTS_ASSUM_TAC THEN
    ENSURES_FINAL_STATE_TAC THEN ASM_REWRITE_TAC[] THEN
    DISCHARGE_SAFETY_PROPERTY_TAC] THEN
  X_GEN_TAC `i:num` THEN STRIP_TAC THEN T "s-body" THEN
  X86_SIM_TAC ~preprocess_tac:(TRY STRIP_EXISTS_ASSUM_TAC)
    CT_COMPARE_BYTES_EXEC (1--10) THEN
  SUBGOAL_THEN `word_sub (word (n - i)) (word 1):int64 = word(n - (i + 1))`
  SUBST1_TAC THENL
   [REWRITE_TAC[WORD_RULE
     `word_sub x (word 1):int64 = word y <=> x = word(y + 1)`] THEN
    AP_TERM_TAC THEN UNDISCH_TAC `i:num < n` THEN ARITH_TAC;
    ALL_TAC] THEN
  REWRITE_TAC[WORD_SUB_0] THEN VAL_INT64_TAC `n - (i + 1)` THEN
  ASM_REWRITE_TAC[VAL_WORD_0] THEN
  CONJ_TAC THENL
   [REWRITE_TAC[ARITH_RULE `n - (i + 1) = 0 <=> ~(i + 1 < n)`] THEN
    COND_CASES_TAC THEN ASM_REWRITE_TAC[];
    ALL_TAC] THEN
  CONJ_TAC THENL [CONV_TAC WORD_RULE; ALL_TAC] THEN
  CONJ_TAC THENL [CONV_TAC WORD_RULE; ALL_TAC] THEN
  DISCHARGE_SAFETY_PROPERTY_TAC);;
