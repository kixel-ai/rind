(*
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0
 *)

(* ========================================================================= *)
(* 16-byte constant-time compare, as rind's build emits it.                  *)
(* ========================================================================= *)

(* The asm! block in rind's low::aarch64::cpu::ct_compare_16, whose two
   64-bit halves of each block arrive in X0, X1 and X2, X3: X0 ends zero
   exactly when the blocks are equal. The block has no branch or memory
   access, so its trace is empty whatever the inputs. *)

needs "arm/proofs/base.ml";;

(* admin/prove writes the block's bytes, as rind's release build emits them,
   to aarch64/ct_compare_16.bin, and the definition fails unless they are
   these. *)
let ct_compare_16_mc = define_assert_word_list "ct_compare_16_mc"
  (term_of_bytes (load_file "aarch64/ct_compare_16.bin"))
[
  0xca020000;       (* arm_EOR X0 X0 X2 *)
  0xca030021;       (* arm_EOR X1 X1 X3 *)
  0xaa010000        (* arm_ORR X0 X0 X1 *)
];;

let CT_COMPARE_16_EXEC = ARM_MK_EXEC_RULE ct_compare_16_mc;;

let CT_COMPARE_16_CORRECT = prove
 (`!a0 a1 b0 b1 pc.
        ensures arm
          (\s. aligned_bytes_loaded s (word pc) ct_compare_16_mc /\
               read PC s = word pc /\
               read X0 s = a0 /\ read X1 s = a1 /\
               read X2 s = b0 /\ read X3 s = b1)
          (\s. read PC s = word (pc + 0xc) /\
               (read X0 s = word 0 <=> a0 = b0 /\ a1 = b1))
          (MAYCHANGE [PC; X0; X1] ,, MAYCHANGE [events])`,
  MAP_EVERY X_GEN_TAC [`a0:int64`; `a1:int64`; `b0:int64`; `b1:int64`; `pc:num`] THEN
  REWRITE_TAC[fst CT_COMPARE_16_EXEC] THEN
  ENSURES_INIT_TAC "s0" THEN
  ARM_STEPS_TAC CT_COMPARE_16_EXEC (1--3) THEN
  ENSURES_FINAL_STATE_TAC THEN ASM_REWRITE_TAC[] THEN
  REWRITE_TAC[WORD_OR_EQ_0; WORD_XOR_EQ_0]);;

let CT_COMPARE_16_SAFE = prove
 (`exists f_events.
       forall e a0 a1 b0 b1 pc.
           ensures arm
           (\s. aligned_bytes_loaded s (word pc) ct_compare_16_mc /\
                read PC s = word pc /\
                read X0 s = a0 /\ read X1 s = a1 /\
                read X2 s = b0 /\ read X3 s = b1 /\
                read events s = e)
           (\s. read PC s = word (pc + 0xc) /\
                exists e2.
                    read events s = APPEND e2 e /\
                    e2 = f_events pc /\
                    memaccess_inbounds e2 [] [])
           (\s s'. true)`,
  EXISTS_TAC `\pc:num. []:uarch_event list` THEN
  MAP_EVERY X_GEN_TAC [`e:uarch_event list`; `a0:int64`; `a1:int64`;
                       `b0:int64`; `b1:int64`; `pc:num`] THEN
  REWRITE_TAC[fst CT_COMPARE_16_EXEC] THEN
  ENSURES_INIT_TAC "s0" THEN
  ARM_STEPS_TAC CT_COMPARE_16_EXEC (1--3) THEN
  ENSURES_FINAL_STATE_TAC THEN ASM_REWRITE_TAC[] THEN
  EXISTS_TAC `[]:uarch_event list` THEN
  REWRITE_TAC[APPEND; memaccess_inbounds; ALL]);;
