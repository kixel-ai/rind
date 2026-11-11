(*
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0
 *)

(* ========================================================================= *)
(* Constant-time byte compare, as rind's build emits it.                     *)
(* ========================================================================= *)

(* The asm! block in rind's low::aarch64::cpu::ct_compare_bytes, which ORs
   together the XOR of each pair of bytes at X0 and X1, X2 of them, into X3,
   zero on entry. X3 ends below 256, and zero exactly when the bytes are
   equal. Its loads and branches depend only on X0, X1, and X2. *)

needs "arm/proofs/base.ml";;

(* admin/prove writes the block's bytes, as rind's release build emits them,
   to aarch64/ct_compare_bytes.bin, and the definition fails unless they are
   these. *)
let ct_compare_bytes_mc = define_assert_word_list "ct_compare_bytes_mc"
  (term_of_bytes (load_file "aarch64/ct_compare_bytes.bin"))
[
  0xf100005f;       (* arm_CMP X2 (rvalue (word 0)) *)
  0x54000120;       (* arm_BEQ (word 36) *)
  0x39400004;       (* arm_LDRB W4 X0 (Immediate_Offset (word 0)) *)
  0x39400025;       (* arm_LDRB W5 X1 (Immediate_Offset (word 0)) *)
  0x4a050084;       (* arm_EOR W4 W4 W5 *)
  0x2a040063;       (* arm_ORR W3 W3 W4 *)
  0x91000400;       (* arm_ADD X0 X0 (rvalue (word 1)) *)
  0x91000421;       (* arm_ADD X1 X1 (rvalue (word 1)) *)
  0xd1000442;       (* arm_SUB X2 X2 (rvalue (word 1)) *)
  0x17fffff7        (* arm_B (word 268435420) *)
];;

let CT_COMPARE_BYTES_EXEC = ARM_MK_EXEC_RULE ct_compare_bytes_mc;;

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

let CT_COMPARE_BYTES_CORRECT = prove
 (`!a b n x y pc.
        ensures arm
          (\s. aligned_bytes_loaded s (word pc) ct_compare_bytes_mc /\
               read PC s = word pc /\
               read X0 s = a /\ read X1 s = b /\ read X2 s = n /\
               read X3 s = word 0 /\
               read (memory :> bytes(a,val n)) s = x /\
               read (memory :> bytes(b,val n)) s = y)
          (\s. read PC s = word (pc + 0x28) /\
               val(read X3 s) < 256 /\
               (read X3 s = word 0 <=> x = y))
          (MAYCHANGE [PC; X0; X1; X2; X3; X4; X5] ,, MAYCHANGE SOME_FLAGS ,,
           MAYCHANGE [events])`,
  MAP_EVERY X_GEN_TAC [`a:int64`; `b:int64`] THEN
  W64_GEN_TAC `n:num` THEN MAP_EVERY X_GEN_TAC [`x:num`; `y:num`; `pc:num`] THEN
  REWRITE_TAC[SOME_FLAGS; fst CT_COMPARE_BYTES_EXEC] THEN
  ASM_CASES_TAC `n = 0` THEN L
   [ASM_REWRITE_TAC[] THEN
    ENSURES_INIT_TAC "s0" THEN
    ARM_STEPS_TAC CT_COMPARE_BYTES_EXEC (1--2) THEN
    ENSURES_FINAL_STATE_TAC THEN ASM_REWRITE_TAC[] THEN
    RULE_ASSUM_TAC(REWRITE_RULE[READ_COMPONENT_COMPOSE; READ_BYTES_TRIVIAL]) THEN
    REPEAT(FIRST_X_ASSUM(SUBST_ALL_TAC o SYM o check (is_var o rhs o concl))) THEN
    REWRITE_TAC[VAL_WORD_0] THEN CONV_TAC NUM_REDUCE_CONV;
    ALL_TAC] THEN
  ENSURES_WHILE_UP2_TAC `n:num` `pc + 0x8` `pc + 0x28`
   `\i s. read X0 s = word_add a (word i) /\
          read X1 s = word_add b (word i) /\
          read X2 s = word(n - i) /\
          val(read X3 s) < 256 /\
          read (memory :> bytes(a,n)) s = x /\
          read (memory :> bytes(b,n)) s = y /\
          (read X3 s = word 0 <=>
           x MOD 2 EXP (8 * i) = y MOD 2 EXP (8 * i))` THEN
  ASM_REWRITE_TAC[] THEN REPEAT CONJ_TAC THEN L
   [ENSURES_INIT_TAC "s0" THEN
    ARM_STEPS_TAC CT_COMPARE_BYTES_EXEC (1--2) THEN
    ENSURES_FINAL_STATE_TAC THEN ASM_REWRITE_TAC[WORD_SUB_0] THEN
    REWRITE_TAC[VAL_WORD_0; WORD_ADD_0; SUB_0; MULT_CLAUSES; EXP; MOD_1] THEN
    CONV_TAC NUM_REDUCE_CONV;
    ALL_TAC;
    ENSURES_INIT_TAC "s0" THEN ENSURES_FINAL_STATE_TAC THEN
    ASM_REWRITE_TAC[] THEN
    BINOP_TAC THEN MATCH_MP_TAC MOD_LT THEN
    ASM_MESON_TAC[READ_BYTES_BOUND; READ_COMPONENT_COMPOSE]] THEN
  X_GEN_TAC `i:num` THEN STRIP_TAC THEN
  GHOST_INTRO_TAC `acc:int64` `read X3` THEN
  ENSURES_INIT_TAC "s0" THEN
  MP_TAC(SPECL [`a:int64`; `n:num`; `i:num`; `x:num`; `read memory s0`]
    CT_COMPARE_BYTES_LOAD) THEN
  MP_TAC(SPECL [`b:int64`; `n:num`; `i:num`; `y:num`; `read memory s0`]
    CT_COMPARE_BYTES_LOAD) THEN
  REWRITE_TAC[GSYM READ_COMPONENT_COMPOSE] THEN ASM_REWRITE_TAC[] THEN
  REPEAT(DISCH_THEN ASSUME_TAC) THEN
  ARM_STEPS_TAC CT_COMPARE_BYTES_EXEC (1--10) THEN
  ENSURES_FINAL_STATE_TAC THEN ASM_REWRITE_TAC[] THEN
  SUBGOAL_THEN `word_sub (word (n - i)) (word 1):int64 = word(n - (i + 1))`
  SUBST1_TAC THEN L
   [REWRITE_TAC[WORD_RULE
     `word_sub x (word 1):int64 = word y <=> x = word(y + 1)`] THEN
    AP_TERM_TAC THEN UNDISCH_TAC `i:num < n` THEN ARITH_TAC;
    ALL_TAC] THEN
  REWRITE_TAC[WORD_SUB_0] THEN VAL_INT64_TAC `n - (i + 1)` THEN
  ASM_REWRITE_TAC[VAL_WORD_0] THEN
  CONJ_TAC THEN L
   [REWRITE_TAC[ARITH_RULE `n - (i + 1) = 0 <=> ~(i + 1 < n)`] THEN
    COND_CASES_TAC THEN ASM_REWRITE_TAC[];
    ALL_TAC] THEN
  CONJ_TAC THEN L [CONV_TAC WORD_RULE; ALL_TAC] THEN
  CONJ_TAC THEN L [CONV_TAC WORD_RULE; ALL_TAC] THEN
  SUBGOAL_THEN `?c:byte. acc:int64 = word_zx c`
   (X_CHOOSE_THEN `c:byte` SUBST_ALL_TAC) THEN L
   [EXISTS_TAC `word_zx(acc:int64):byte` THEN
    REWRITE_TAC[GSYM VAL_EQ; VAL_WORD_ZX_GEN; DIMINDEX_8; DIMINDEX_64] THEN
    CONV_TAC NUM_REDUCE_CONV THEN ASM_SIMP_TAC[MOD_LT; ARITH_RULE
      `x < 256 ==> x < 18446744073709551616`];
    ALL_TAC] THEN
  REWRITE_TAC[CT_COMPARE_BYTES_STEP] THEN
  FIRST_X_ASSUM(fun th ->
    if is_iff(concl th) && free_in `c:byte` (concl th)
    then REWRITE_TAC[GSYM th] else failwith "not IH") THEN
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

needs "arm/proofs/consttime.ml";;

let CT_COMPARE_BYTES_SAFE = prove
 (`exists f_events.
       forall e a b n pc.
           ensures arm
           (\s. aligned_bytes_loaded s (word pc) ct_compare_bytes_mc /\
                read PC s = word pc /\
                read X0 s = a /\ read X1 s = b /\ read X2 s = n /\
                read events s = e)
           (\s. read PC s = word (pc + 0x28) /\
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
  ASM_CASES_TAC `n = 0` THEN L
   [ASM_REWRITE_TAC[] THEN
    ARM_SIM_TAC ~preprocess_tac:(TRY STRIP_EXISTS_ASSUM_TAC)
      ~canonicalize_pc_diff:false CT_COMPARE_BYTES_EXEC (1--2) THEN
    ASM_REWRITE_TAC[WORD_SUB_0; VAL_WORD_0] THEN
    DISCHARGE_SAFETY_PROPERTY_TAC;
    ALL_TAC] THEN
  ASM_REWRITE_TAC[] THEN
  ENSURES_EVENTS_WHILE_UP2_TAC `n:num` `pc + 0x8` `pc + 0x28`
   `\i s. read X0 s = word_add a (word i) /\
          read X1 s = word_add b (word i) /\
          read X2 s = word(n - i)` THEN
  ASM_REWRITE_TAC[] THEN REPEAT CONJ_TAC THEN L
   [ARM_SIM_TAC ~preprocess_tac:(TRY STRIP_EXISTS_ASSUM_TAC)
      ~canonicalize_pc_diff:false CT_COMPARE_BYTES_EXEC (1--2) THEN
    ASM_REWRITE_TAC[WORD_SUB_0; WORD_ADD_0; SUB_0; VAL_WORD_0] THEN
    DISCHARGE_SAFETY_PROPERTY_TAC;
    ALL_TAC;
    ARM_SIM_TAC ~preprocess_tac:(TRY STRIP_EXISTS_ASSUM_TAC)
      ~canonicalize_pc_diff:false CT_COMPARE_BYTES_EXEC [] THEN
    DISCHARGE_SAFETY_PROPERTY_TAC] THEN
  X_GEN_TAC `i:num` THEN STRIP_TAC THEN
  ARM_SIM_TAC ~preprocess_tac:(TRY STRIP_EXISTS_ASSUM_TAC)
    ~canonicalize_pc_diff:false CT_COMPARE_BYTES_EXEC (1--10) THEN
  SUBGOAL_THEN `word_sub (word (n - i)) (word 1):int64 = word(n - (i + 1))`
  SUBST1_TAC THEN L
   [REWRITE_TAC[WORD_RULE
     `word_sub x (word 1):int64 = word y <=> x = word(y + 1)`] THEN
    AP_TERM_TAC THEN UNDISCH_TAC `i:num < n` THEN ARITH_TAC;
    ALL_TAC] THEN
  REWRITE_TAC[WORD_SUB_0] THEN VAL_INT64_TAC `n - (i + 1)` THEN
  ASM_REWRITE_TAC[VAL_WORD_0] THEN
  CONJ_TAC THEN L
   [REWRITE_TAC[ARITH_RULE `n - (i + 1) = 0 <=> ~(i + 1 < n)`] THEN
    COND_CASES_TAC THEN ASM_REWRITE_TAC[];
    ALL_TAC] THEN
  CONJ_TAC THEN L [CONV_TAC WORD_RULE; ALL_TAC] THEN
  CONJ_TAC THEN L [CONV_TAC WORD_RULE; ALL_TAC] THEN
  DISCHARGE_SAFETY_PROPERTY_TAC);;
