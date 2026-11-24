(*
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0
 *)

(* ========================================================================= *)
(* A32 execution and proof automation.                                       *)
(* ========================================================================= *)

let aarch32_print_log = ref false;;

let aarch32_execute = define
 `aarch32_execute = \i:(aarch32state->aarch32state->bool). i`;;

(* One step decodes the word at PC, advances PC by four bytes, and applies
   the decoded instruction, which sees PC as its own address plus 4. *)

let aarch32 = define
 `aarch32 s s' <=>
    ?instr. aarch32_decode s (read PC s) instr /\
            (PC := word_add (read PC s) (word 4) ,,
             aarch32_execute instr) s s'`;;

(* ------------------------------------------------------------------------- *)
(* Forward symbolic execution, as for RV32: `read PC s` must be `word pc` or *)
(* `word (pc + n)` for the code's symbolic base `pc`.                        *)
(* ------------------------------------------------------------------------- *)

let AARCH32_THM =
  let pth = prove
   (`read PC s = word pc ==> aarch32_decode s (word pc) instr ==>
     (aarch32 s s' <=> (PC := word (pc + 4) ,, instr) s s')`,
    REPEAT STRIP_TAC THEN REWRITE_TAC[aarch32] THEN
    ASM_REWRITE_TAC[GSYM WORD_ADD; aarch32_execute] THEN
    ASM_MESON_TAC[aarch32_decode_unique]) in
  fun (execth2:thm option array) loaded_mc_th pc_th ->
    let th = MATCH_MP pth pc_th in
    let pc_ofs =
      let pc_expr = snd (dest_comb (snd (dest_eq (concl pc_th)))) in
      if is_var pc_expr then 0
      else
        try
          let _,ofs = dest_binary "+" pc_expr in
          dest_small_numeral ofs
        with Failure _ ->
          failwith
            ("AARCH32_THM: cannot decompose PC expression: " ^
             string_of_term (concl pc_th)) in
    let _ =
      if pc_ofs >= Array.length execth2 then
        failwith
          ("AARCH32_THM: no decoded instruction at `pc + " ^
           string_of_int pc_ofs ^ "`") in
    let _ =
      if !aarch32_print_log then
        let opt = option_get execth2.(pc_ofs) in
        let t = snd (strip_forall (concl opt)) in
        let t = snd (dest_imp t) in
        let term = snd (dest_comb t) in
        Printf.printf "Instruction at `pc + %d (%#x)`: `%s`\n"
          pc_ofs pc_ofs (string_of_term term) in
    MATCH_MP th (MATCH_MP (option_get execth2.(pc_ofs)) loaded_mc_th);;

let AARCH32_ENSURES_SUBLEMMA_TAC =
  ENSURES_SUBLEMMA_TAC o
  MATCH_MP aligned_bytes_loaded_update o CONJUNCT1;;

let AARCH32_ENSURES_SUBSUBLEMMA_TAC =
  ENSURES_SUBSUBLEMMA_TAC o
  map (MATCH_MP aligned_bytes_loaded_update o CONJUNCT1);;

let is_read_pc = is_read_named_component "PC";;

let is_read_events = is_read_named_component "events";;

(* The assumptions that say what a flag holds, which decide a conditional
   instruction's condition: `read F s`, its negation, or `read F s <=> b`. *)

let aarch32_flag_ths =
  let flags = [`NF`; `ZF`; `CF`; `VF`] in
  let is_flag_read t =
    is_binary "read" t && mem (fst (dest_binary "read" t)) flags in
  filter (fun th ->
    let c = concl th in
    let c = if is_neg c then dest_neg c else c in
    is_flag_read c || (is_eq c && is_flag_read (lhs c)));;

(* Decides `aligned n (word m)` for numerals, as a branch to a concrete
   address needs. *)

let AARCH32_ALIGNED_NUMERAL_CONV =
  let conv =
    GEN_REWRITE_CONV I [aligned] THENC
    DEPTH_CONV(WORD_RED_CONV ORELSEC DIMINDEX_CONV ORELSEC NUM_RED_CONV) THENC
    DEPTH_CONV DIVIDES_CONV THENC
    REWRITE_CONV[] in
  fun tm ->
    match tm with
      Comb(Comb(Const("aligned",_),n),Comb(Const("word",_),m))
        when is_numeral n && is_numeral m -> conv tm
    | _ -> failwith "AARCH32_ALIGNED_NUMERAL_CONV";;

(* Folds a constant offset from R15's value, `word (pc + a)`, into it, as far
   as it stays at or after `pc`: what ADR and a literal load compute. The
   offset is added, perhaps as a negative number's 32-bit encoding, or
   subtracted. *)

let AARCH32_PC_RELATIVE_CONV =
  let pth_add = (UNDISCH o prove)
   (`a + b = c ==> word_add (word (pc + a)) (word b):int32 = word (pc + c)`,
    DISCH_THEN(SUBST1_TAC o SYM) THEN REWRITE_TAC[WORD_ADD] THEN
    CONV_TAC WORD_RULE)
  and pth_wrap = (UNDISCH o prove)
   (`a + b = c + 4294967296
     ==> word_add (word (pc + a)) (word b):int32 = word (pc + c)`,
    DISCH_TAC THEN
    SUBGOAL_THEN `word 4294967296:int32 = word 0` ASSUME_TAC THENL
     [REWRITE_TAC[WORD_EQ; DIMINDEX_32; CONG] THEN CONV_TAC NUM_REDUCE_CONV;
      ALL_TAC] THEN
    REWRITE_TAC[GSYM WORD_ADD; GSYM ADD_ASSOC] THEN ASM_REWRITE_TAC[] THEN
    ASM_REWRITE_TAC[WORD_ADD] THEN CONV_TAC WORD_RULE)
  and pth_sub = (UNDISCH o prove)
   (`b + c = a ==> word_sub (word (pc + a)) (word b):int32 = word (pc + c)`,
    DISCH_THEN(SUBST1_TAC o SYM) THEN REWRITE_TAC[WORD_ADD] THEN
    CONV_TAC WORD_RULE)
  and two32 = pow2 32
  and ea,eb,ec,epc = `a:num`,`b:num`,`c:num`,`pc:num` in
  let finish pth pc a b c =
    let th = INST [pc,epc; a,ea; b,eb; mk_numeral c,ec] pth in
    PROVE_HYP (EQT_ELIM(NUM_REDUCE_CONV(hd(hyp th)))) th in
  fun tm ->
    match tm with
      Comb(Comb(Const(op,_),
             Comb(Const("word",_),Comb(Comb(Const("+",_),pc),a))),
           Comb(Const("word",_),b))
        when is_numeral a && is_numeral b && type_of tm = `:int32` ->
          let na = dest_numeral a and nb = dest_numeral b in
          if op = "word_add" && na +/ nb </ two32 then
            finish pth_add pc a b (na +/ nb)
          else if op = "word_add" && nb </ two32 then
            finish pth_wrap pc a b (na +/ nb -/ two32)
          else if op = "word_sub" && nb <=/ na then
            finish pth_sub pc a b (na -/ nb)
          else failwith "AARCH32_PC_RELATIVE_CONV"
    | _ -> failwith "AARCH32_PC_RELATIVE_CONV";;

(* Fails unless every conditional instruction's condition is decided, and
   every address and branch target an instruction needs aligned is known to
   be, since the state after one that is not is no single update. *)

let AARCH32_CHECK_DECIDED_CONV tm =
  let rel_tys = [`:aarch32state->bool`; `:aarch32state->aarch32state->bool`] in
  if can (find_term (fun t ->
            is_cond t && mem (type_of t) rel_tys)) tm
  then failwith
   ("AARCH32_CONV: a conditional instruction's condition is undecided, or " ^
    "an address or branch target is not known to be aligned; establish " ^
    "the flags it reads, or assume `aligned 4` of the address, first")
  else REFL tm;;

(* Convert one symbolic machine step to the explicit state update for the
   instruction at the current PC. `ths` must hold the current `read PC`
   equation and the code's `aligned_bytes_loaded` fact, and `tm` is
   `aarch32 s s'`. *)

let AARCH32_CONV (decode_ths:thm option array) (ths:thm list) tm =
  let pc_th =
    try
      find
        (fun th ->
          let c = concl th in
          is_eq c && is_read_pc (fst (dest_eq c)))
        ths
    with Failure _ ->
      failwith "AARCH32_CONV: cannot find `read PC .. = ..`" in
  let aligned_bytes_loaded_mc_ths =
    let the_mc =
      option_bind decode_ths.(0)
        (fun th ->
          let t = concl th in
          let loaded = fst (dest_imp (snd (strip_forall t))) in
          let mc = last (snd (strip_comb loaded)) in
          if is_const mc then Some mc else None) in
    let loaded_tm = `aligned_bytes_loaded` in
    let res =
      filter
        (fun th ->
          let c,args = strip_comb (concl th) in
          c = loaded_tm &&
          (the_mc = None || last args = option_get the_mc))
        ths in
    if res = [] then
      failwith "AARCH32_CONV: cannot find aligned code-loading assumption"
    else
      res in
  let eth =
    try
      tryfind
        (fun loaded_mc_th ->
          GEN_REWRITE_CONV I
            [AARCH32_THM decode_ths loaded_mc_th pc_th] tm)
        aligned_bytes_loaded_mc_ths
    with Failure _ ->
      failwith "AARCH32_CONV: cannot match code loading to the current PC" in
  let flag_ths = aarch32_flag_ths ths in
  let aligned_ths =
    map (MATCH_MP aligned_bytes_loaded_aligned) aligned_bytes_loaded_mc_ths @
    ths in
  (* A branch target is a loaded word, which the assumptions give only at
     its address's normal form, and an address may be a known base's
     offset, which is aligned or not only once the sum is taken. *)
  let target_conv =
    SUB_ALIGNED_WORD_CONV
     (TOP_DEPTH_CONV
       (GEN_REWRITE_CONV I (filter (is_eq o concl) ths) ORELSEC
        WORD_RED_CONV ORELSEC
        NORMALIZE_RELATIVE_ADDRESS_CONV)) in
  (K eth THENC
   REWRITE_CONV
    ([aarch32_execute; aarch32_cond; SEQ] @ AARCH32_INSTRUCTIONS) THENC
   REWRITE_CONV[LET_DEF; LET_END_DEF] THENC
   TOP_DEPTH_CONV BETA_CONV THENC
   REWRITE_CONV AARCH32_CONDITION_CLAUSES THENC
   TOP_DEPTH_CONV COMPONENT_READ_OVER_WRITE_CONV THENC
   REWRITE_CONV (READ_RVALUE :: flag_ths) THENC
   target_conv THENC
   ALIGNED_WORD_EXTENDED_CONV aligned_ths THENC
   ONCE_DEPTH_CONV AARCH32_ALIGNED_NUMERAL_CONV THENC
   REWRITE_CONV[] THENC
   AARCH32_CHECK_DECIDED_CONV THENC
   REWRITE_CONV[SEQ] THENC
   GEN_REWRITE_CONV TOP_DEPTH_CONV [assign] THENC
   REWRITE_CONV[] THENC
   TOP_DEPTH_CONV COMPONENT_READ_OVER_WRITE_CONV THENC
   REWRITE_CONV (READ_RVALUE :: WRITE_RVALUE :: WORD_ADD_0 ::
                 CONJUNCTS AARCH32_OPERAND_READS) THENC
   TOP_DEPTH_CONV COMPONENT_READ_OVER_WRITE_CONV THENC
   WORD_REDUCE_CONV THENC
   ONCE_REWRITE_CONV[WORD_SUB_ADD] THENC
   ONCE_DEPTH_CONV
    (REWR_CONV (GSYM ADD_ASSOC) THENC RAND_CONV NUM_REDUCE_CONV) THENC
   ONCE_DEPTH_CONV
    (GEN_REWRITE_CONV I [GSYM WORD_ADD] THENC
     GEN_REWRITE_CONV (RAND_CONV o TOP_DEPTH_CONV) [GSYM ADD_ASSOC] THENC
     RAND_CONV NUM_REDUCE_CONV) THENC
   TOP_DEPTH_CONV AARCH32_PC_RELATIVE_CONV THENC
   TOP_DEPTH_CONV COMPONENT_WRITE_OVER_WRITE_CONV THENC
   GEN_REWRITE_CONV (SUB_COMPONENTS_CONV o TOP_DEPTH_CONV) ths THENC
   (* An address with a register offset the assumptions give a value. *)
   SUB_COMPONENTS_CONV (DEPTH_CONV WORD_RED_CONV) THENC
   GEN_REWRITE_CONV TOP_DEPTH_CONV [WORD_VAL] THENC
   ONCE_DEPTH_CONV WORD_PC_PLUS_CONV THENC
   ONCE_DEPTH_CONV NORMALIZE_RELATIVE_ADDRESS_CONV THENC
   ONCE_DEPTH_CONV NORMALIZE_RELATIVE_ADDRESS_CONV) tm;;

let AARCH32_BASIC_STEP_TAC =
  GEN_BASIC_STEP_TAC "AARCH32" `aarch32` `:aarch32state` AARCH32_CONV ALL_TAC;;

let AARCH32_STEP_TAC (mc_length_th,decode_ths) subths sname
      (store_inst_term_to:term ref option)
      (strip_component_tac:thm_tactic) =
  GEN_STEP_TAC AARCH32_BASIC_STEP_TAC ALL_TAC aligned_bytes_loaded_update
    (fun th thl ->
      if !aarch32_print_log then begin
        Printf.printf "State update: `%s`\n" (string_of_thm th);
        List.iter
          (fun th' ->
            Printf.printf "New component: `%s`\n" (string_of_thm th'))
          thl
      end)
    (mc_length_th,decode_ths) subths sname
    store_inst_term_to strip_component_tac;;

let AARCH32_VERBOSE_STEP_TAC =
  GEN_VERBOSE_STEP_TAC AARCH32_STEP_TAC;;

let AARCH32_VERBOSE_SUBSTEP_TAC =
  GEN_VERBOSE_SUBSTEP_TAC AARCH32_STEP_TAC;;

let DISCARD_FLAGS_TAC =
  DISCARD_MATCHING_ASSUMPTIONS
   [`read CF s = y`; `read ZF s = y`;
    `read NF s = y`; `read VF s = y`];;

let DISCARD_STATE_TAC =
  GEN_DISCARD_STATE_TAC `:aarch32state`;;

let DISCARD_OLDSTATE_TAC =
  GEN_DISCARD_OLDSTATE_TAC `:aarch32state` aarch32_print_log;;

let AARCH32_SINGLE_STEP_TAC =
  GEN_SINGLE_STEP_TAC AARCH32_VERBOSE_STEP_TAC DISCARD_OLDSTATE_TAC;;

let AARCH32_VSTEPS_TAC =
  GEN_VSTEPS_TAC AARCH32_VERBOSE_STEP_TAC;;

let AARCH32_STEPS_TAC =
  GEN_STEPS_TAC AARCH32_SINGLE_STEP_TAC;;

let AARCH32_SIM_TAC ?(preprocess_tac:tactic option)
    ?(canonicalize_pc_diff=true) execth snums =
  REWRITE_TAC(!simulation_precanon_thms) THEN
  ENSURES_INIT_TAC "s0" THEN
  (match preprocess_tac with Some t -> t | None -> ALL_TAC) THEN
  AARCH32_STEPS_TAC execth snums THEN
  ENSURES_FINAL_STATE_TAC THEN
  ASM_REWRITE_TAC[] THEN
  (if canonicalize_pc_diff then
    REWRITE_TAC[VAL_WORD_SUB_EQ_0] THEN ASM_REWRITE_TAC[]
   else
    ALL_TAC);;

(* ------------------------------------------------------------------------- *)
(* Simulate through a core correctness theorem.                              *)
(* ------------------------------------------------------------------------- *)

let (AARCH32_BIGSTEP_TAC:(thm*thm option array)->string->tactic) =
  GEN_BIGSTEP_TAC
    "AARCH32" aligned_bytes_loaded_update DISCARD_OLDSTATE_TAC;;

(* ------------------------------------------------------------------------- *)
(* The flags, for MAYCHANGE lists.                                           *)
(* ------------------------------------------------------------------------- *)

let SOME_FLAGS = new_definition
 `SOME_FLAGS = [NF; ZF; CF; VF]`;;

(* ------------------------------------------------------------------------- *)
(* The 32-bit counterparts of W64_GEN_TAC and VAL_INT64_TAC.                 *)
(* ------------------------------------------------------------------------- *)

let W32_GEN_TAC =
  let pth = prove
   (`(!x:int32. P (val x) x) <=>
     (!x. x < 2 EXP 32 /\ val(word x:int32) = x
          ==> P x (word x))`,
    GEN_REWRITE_TAC LAND_CONV [FORALL_VAL_GEN] THEN
    MESON_TAC[VAL_WORD_EQ_EQ; DIMINDEX_32]) in
  let tac = GEN_REWRITE_TAC I [pth] in
  fun w -> tac THEN X_GEN_TAC w THEN STRIP_TAC;;

let VAL_INT32_TAC =
  let pth = prove
   (`!n. n < 4294967296 ==> val(word n:int32) = n`,
    REWRITE_TAC[VAL_WORD_EQ_EQ; DIMINDEX_32] THEN ARITH_TAC) in
  fun t -> MP_TAC(SPEC t pth) THEN
           ANTS_TAC THENL [SIMPLE_ARITH_TAC THEN NO_TAC; DISCH_TAC];;

(* ------------------------------------------------------------------------- *)
(* The AAPCS's integer arguments, in R0-R3, and result, in R0.               *)
(* ------------------------------------------------------------------------- *)

let C_ARGUMENTS = define
 `(C_ARGUMENTS [a1;a2;a3;a4] s <=>
        read R0 s = a1 /\ read R1 s = a2 /\ read R2 s = a3 /\
        read R3 s = a4) /\
  (C_ARGUMENTS [a1;a2;a3] s <=>
        read R0 s = a1 /\ read R1 s = a2 /\ read R2 s = a3) /\
  (C_ARGUMENTS [a1;a2] s <=>
        read R0 s = a1 /\ read R1 s = a2) /\
  (C_ARGUMENTS [a1] s <=>
        read R0 s = a1) /\
  (C_ARGUMENTS [] s <=>
        T)`;;

let C_RETURN = define
 `C_RETURN = read R0`;;

(* The AAPCS lets a subroutine change R0-R3, R12, the flags, and LR, which
   it returns through and may use as scratch once saved; it keeps R4-R11 and
   SP. *)

let MODIFIABLE_GPRS = define
 `MODIFIABLE_GPRS = [R0; R1; R2; R3; R12; LR]`;;

let MAYCHANGE_REGS_AND_FLAGS_PERMITTED_BY_ABI = REWRITE_RULE
  [SOME_FLAGS; MODIFIABLE_GPRS]
  (new_definition `MAYCHANGE_REGS_AND_FLAGS_PERMITTED_BY_ABI =
      MAYCHANGE [PC] ,, MAYCHANGE MODIFIABLE_GPRS ,,
      MAYCHANGE SOME_FLAGS ,, MAYCHANGE [events]`);;

(* ------------------------------------------------------------------------- *)
(* Promote core correctness theorems to AAPCS subroutine theorems, as        *)
(* s2n-bignum's RISCV_ADD_RETURN_NOSTACK_TAC and RISCV_ADD_RETURN_STACK_TAC  *)
(* do. The subroutine theorem assumes `aligned 4 returnaddress`: it covers   *)
(* an A32 caller, since returning to a Thumb one leaves the model. One with  *)
(* a stack frame assumes `aligned 4 stackpointer` too, as the AAPCS keeps SP *)
(* at every instruction.                                                     *)
(* ------------------------------------------------------------------------- *)

let AARCH32_CHECK_FORALLVARS_TAC:tactic =
  GEN_CHECK_FORALLVARS_TAC
    [`read LR s`; `read events s`; `read SP s`];;

(* Promote a core theorem whose postcondition stops just before the final
   `bx lr`:

       add r0, r0, #1     @ covered by coreth
       bx lr              @ executed by this tactic

   The promoted theorem returns to LR and widens the frame to what the AAPCS
   lets a callee change. *)

let AARCH32_ADD_RETURN_NOSTACK_TAC =
  fun execth coreth ->
    let is_coreth_safety = is_exists (concl coreth) in

    (fun (asl,w) ->
      if is_coreth_safety <> is_exists w then
        failwith "coreth must be `exists ..` iff the conclusion is"
      else ALL_TAC (asl,w)) THEN

    (if is_coreth_safety then
      ASSUME_CALLEE_SAFETY_TAC coreth "" THEN
      META_EXISTS_TAC THEN
      AARCH32_CHECK_FORALLVARS_TAC THEN
      FIRST_X_ASSUM
        (fun th -> MP_TAC (ONCE_REWRITE_RULE[SUBROUTINE_APPEND_FORALL] th)) THEN
      REPEAT
       (CONV_TAC (LAND_CONV (ONCE_REWRITE_CONV[SWAP_FORALL_THM])) THEN
        MATCH_MP_TAC SUBROUTINE_MONO_FORALL2 THEN GEN_TAC)
     else
      AARCH32_CHECK_FORALLVARS_TAC THEN
      MP_TAC coreth THEN
      REPEAT(MATCH_MP_TAC MONO_FORALL THEN GEN_TAC)) THEN

    REWRITE_TAC[MAYCHANGE_REGS_AND_FLAGS_PERMITTED_BY_ABI] THEN
    REWRITE_TAC[NONOVERLAPPING_CLAUSES; ALLPAIRS; ALL] THEN
    REWRITE_TAC[C_ARGUMENTS; C_RETURN; SOME_FLAGS;
                MAYCHANGE_REGS_AND_FLAGS_PERMITTED_BY_ABI] THEN
    DISCH_THEN(fun th ->
      REPEAT GEN_TAC THEN
      TRY(DISCH_THEN(REPEAT_TCL CONJUNCTS_THEN ASSUME_TAC)) THEN
      MP_TAC th) THEN
    ASM_REWRITE_TAC[] THEN
    (if is_coreth_safety then
      ONCE_REWRITE_TAC[GSYM LEFT_EXISTS_IMP_THM] THEN META_EXISTS_TAC
     else ALL_TAC) THEN
    TRY(ANTS_TAC THENL
     [REPEAT CONJ_TAC THEN
      ((ASM_REWRITE_TAC[] THEN NO_TAC) ORELSE
       (ALIGNED_WORD_TAC THEN NO_TAC) ORELSE
       (TRY DISJ2_TAC THEN NONOVERLAPPING_TAC));
      ALL_TAC]) THEN
    DISCH_THEN(fun th ->
      REWRITE_TAC(!simulation_precanon_thms) THEN
      ENSURES_INIT_TAC "s0" THEN MP_TAC th) THEN
    AARCH32_BIGSTEP_TAC execth "s1" THEN
    (if is_coreth_safety then
      TRY
       (TRY(GEN_REWRITE_TAC I [SUBROUTINE_APPEND_PREFIX_NIL]) THEN
        TRY(CONV_TAC (LAND_CONV CONS_TO_APPEND_CONV)) THEN
        BINOP_TAC THENL [UNIFY_REFL_TAC; REFL_TAC] THEN NO_TAC)
     else ALL_TAC) THEN
    AARCH32_STEPS_TAC execth [2] THEN
    ENSURES_FINAL_STATE_TAC THEN
    ASM_REWRITE_TAC[];;

(* Promote a core theorem surrounded by a stack prologue and epilogue:

       push {r4, r5, lr}  @ prologue
       ...                @ covered by coreth
       pop {r4, r5, pc}   @ epilogue, which returns

   `reglist` names the callee-saved registers the prologue saves and
   `stackoff` is the frame's size in bytes. The prologue is `pre_n` steps
   and the epilogue with its return `post_n`, each one unless
   `pre_post_nsteps` says otherwise, as for `pop {r4, r5, lr}` and `bx lr`.
   The tactic runs them, proves that SP and the listed registers are
   restored, and applies the AAPCS frame. *)

let AARCH32_ADD_RETURN_STACK_TAC =
  let sp_tm = `SP` in
  fun ?(pre_post_nsteps = (1,1))
      ?(core_precondition_tac = ALL_TAC)
      execth coreth reglist stackoff ->
    let is_coreth_safety = is_exists (concl coreth) in
    let regs = dest_list reglist in
    let pre_n,post_n = pre_post_nsteps in

    (fun (asl,w) ->
      if is_coreth_safety <> is_exists w then
        failwith "coreth must be `exists ..` iff the conclusion is"
      else ALL_TAC (asl,w)) THEN

    (if is_coreth_safety then
      ASSUME_CALLEE_SAFETY_TAC coreth "" THEN
      META_EXISTS_TAC THEN
      AARCH32_CHECK_FORALLVARS_TAC THEN
      FIRST_X_ASSUM
        (fun th -> MP_TAC (ONCE_REWRITE_RULE[SUBROUTINE_APPEND_FORALL] th))
     else
      AARCH32_CHECK_FORALLVARS_TAC THEN MP_TAC coreth) THEN

    REWRITE_TAC[MAYCHANGE_REGS_AND_FLAGS_PERMITTED_BY_ABI; fst execth] THEN
    (if is_coreth_safety then
      REPEAT
       (CONV_TAC (LAND_CONV (ONCE_REWRITE_CONV[SWAP_FORALL_THM])) THEN
        MATCH_MP_TAC SUBROUTINE_MONO_FORALL3 THEN GEN_TAC) THEN
      CONV_TAC (LAND_CONV (ONCE_REWRITE_CONV[SWAP_FORALL_THM]))
     else
      REPEAT(MATCH_MP_TAC SUBROUTINE_MONO_FORALL2 THEN GEN_TAC)) THEN
    (if vfree_in sp_tm (concl coreth) then
      DISCH_THEN(fun th -> WORD_FORALL_OFFSET_TAC stackoff THEN MP_TAC th) THEN
      MATCH_MP_TAC MONO_FORALL THEN GEN_TAC
     else
      MATCH_MP_TAC MONO_FORALL THEN GEN_TAC THEN
      DISCH_THEN(fun th ->
        WORD_FORALL_OFFSET_TAC stackoff THEN MP_TAC th)) THEN
    REWRITE_TAC[NONOVERLAPPING_CLAUSES; PAIRWISE; ALLPAIRS; ALL] THEN
    REWRITE_TAC[C_ARGUMENTS; C_RETURN; SOME_FLAGS] THEN
    DISCH_THEN(fun th ->
      REPEAT GEN_TAC THEN
      TRY(DISCH_THEN(REPEAT_TCL CONJUNCTS_THEN ASSUME_TAC)) THEN
      MP_TAC th) THEN
    ASM_REWRITE_TAC[] THEN
    (if is_coreth_safety then
      ONCE_REWRITE_TAC[GSYM LEFT_EXISTS_IMP_THM] THEN META_EXISTS_TAC
     else ALL_TAC) THEN
    TRY(ANTS_TAC THENL
     [REPEAT CONJ_TAC THEN
      ((ASM_REWRITE_TAC[] THEN NO_TAC) ORELSE
       (ALIGNED_WORD_TAC THEN NO_TAC) ORELSE
       (TRY DISJ2_TAC THEN NONOVERLAPPING_TAC));
      ALL_TAC]) THEN
    DISCH_THEN(fun th ->
      ((ENSURES_EXISTING_PRESERVED_TAC sp_tm THEN
        MAP_EVERY
         (fun c ->
           ENSURES_PRESERVED_TAC ("init_" ^ fst(dest_const c)) c)
         regs)
       ORELSE
       FAIL_TAC
        "callee-save registers are still in MAYCHANGE, or `read SP s` is absent") THEN
      REWRITE_TAC(!simulation_precanon_thms) THEN
      ENSURES_INIT_TAC "s0" THEN
      AARCH32_STEPS_TAC execth (1--pre_n) THEN
      MP_TAC th) THEN
    AARCH32_BIGSTEP_TAC execth ("s" ^ string_of_int(pre_n + 1)) THEN
    (if is_coreth_safety then
      TRY
       (TRY(GEN_REWRITE_TAC I [SUBROUTINE_APPEND_PREFIX_NIL]) THEN
        TRY(CONV_TAC (LAND_CONV CONS_TO_APPEND_CONV)) THEN
        BINOP_TAC THENL [UNIFY_REFL_TAC; REFL_TAC] THEN NO_TAC)
     else ALL_TAC) THEN
    REWRITE_TAC(!simulation_precanon_thms) THEN
    TRY(core_precondition_tac THEN NO_TAC) THEN
    AARCH32_STEPS_TAC execth
      ((pre_n + 2)--(pre_n + post_n + 1)) THEN
    ENSURES_FINAL_STATE_TAC THEN
    ASM_REWRITE_TAC[];;

(* ------------------------------------------------------------------------- *)
(* The wrappers, a literal load, and a load at a known base's offset, proven *)
(* of four small routines as this file loads, as                             *)
(* riscv/tutorial/subroutine.ml proves s2n-bignum's.                         *)
(* ------------------------------------------------------------------------- *)

let AARCH32_SUBROUTINE_TESTS =
  let define name words =
    define_assert_word_list name
     (mk_flist
       (flat (map (fun w ->
                map (fun i -> mk_comb(`word:num->byte`,
                       mk_small_numeral ((w lsr (8 * i)) land 0xff)))
                    (0--3))
              words)))
     words in
  (* add r0, r0, #1; bx lr *)
  let nostack_mc = define "aarch32_test_nostack_mc" [0xe2800001; 0xe12fff1e] in
  let nostack_exec = AARCH32_MK_EXEC_RULE nostack_mc in
  let nostack_core = prove
   (`!pc a.
      ensures aarch32
        (\s. aligned_bytes_loaded s (word pc) aarch32_test_nostack_mc /\
             read PC s = word pc /\
             C_ARGUMENTS [a] s)
        (\s. read PC s = word (pc + 4) /\
             C_RETURN s = word_add a (word 1))
        (MAYCHANGE [PC] ,, MAYCHANGE [R0])`,
    REWRITE_TAC[fst nostack_exec; C_ARGUMENTS; C_RETURN] THEN
    REPEAT STRIP_TAC THEN
    AARCH32_SIM_TAC nostack_exec [1]) in
  let nostack = prove
   (`!pc a (returnaddress:int32).
      aligned 4 returnaddress
      ==> ensures aarch32
        (\s. aligned_bytes_loaded s (word pc) aarch32_test_nostack_mc /\
             read PC s = word pc /\
             read LR s = returnaddress /\
             C_ARGUMENTS [a] s)
        (\s. read PC s = returnaddress /\
             C_RETURN s = word_add a (word 1))
        MAYCHANGE_REGS_AND_FLAGS_PERMITTED_BY_ABI`,
    REWRITE_TAC[fst nostack_exec] THEN
    AARCH32_ADD_RETURN_NOSTACK_TAC nostack_exec
      (REWRITE_RULE[fst nostack_exec] nostack_core)) in
  (* push {r4, lr}; mov r4, r0; add r0, r4, #1; pop {r4, pc} *)
  let stack_mc = define "aarch32_test_stack_mc"
    [0xe92d4010; 0xe1a04000; 0xe2840001; 0xe8bd8010] in
  let stack_exec = AARCH32_MK_EXEC_RULE stack_mc in
  let stack_core = prove
   (`!pc a.
      ensures aarch32
        (\s. aligned_bytes_loaded s (word pc) aarch32_test_stack_mc /\
             read PC s = word (pc + 4) /\
             C_ARGUMENTS [a] s)
        (\s. read PC s = word (pc + 12) /\
             C_RETURN s = word_add a (word 1))
        (MAYCHANGE [PC] ,, MAYCHANGE [R0; R4])`,
    REWRITE_TAC[fst stack_exec; C_ARGUMENTS; C_RETURN] THEN
    REPEAT STRIP_TAC THEN
    AARCH32_SIM_TAC stack_exec [1;2]) in
  let stack = prove
   (`!pc a (stackpointer:int32) (returnaddress:int32).
      aligned 4 returnaddress /\ aligned 4 stackpointer /\
      nonoverlapping
        ((word pc):int32,LENGTH aarch32_test_stack_mc)
        (word_sub stackpointer (word 8),8)
      ==> ensures aarch32
        (\s. aligned_bytes_loaded s (word pc) aarch32_test_stack_mc /\
             read PC s = word pc /\
             read SP s = stackpointer /\
             read LR s = returnaddress /\
             C_ARGUMENTS [a] s)
        (\s. read PC s = returnaddress /\
             read SP s = stackpointer /\
             C_RETURN s = word_add a (word 1))
        (MAYCHANGE_REGS_AND_FLAGS_PERMITTED_BY_ABI ,,
         MAYCHANGE
          [memory :> bytes (word_sub stackpointer (word 8),8)])`,
    REWRITE_TAC[fst stack_exec] THEN
    AARCH32_ADD_RETURN_STACK_TAC stack_exec
      (REWRITE_RULE[fst stack_exec] stack_core)
      `[R4]` 8) in
  (* ldr r0, [pc, #4]; sub r1, pc, #12; bx lr; then two words of data, the
     second of which is no instruction. *)
  let literal_mc = define "aarch32_test_literal_mc"
    [0xe59f0004; 0xe24f100c; 0xe12fff1e; 0xffffffff; 0x12345678] in
  let literal_exec = AARCH32_MK_EXEC_RULE literal_mc in
  let literal = prove
   (`!pc v.
      ensures aarch32
        (\s. aligned_bytes_loaded s (word pc) aarch32_test_literal_mc /\
             read PC s = word pc /\
             read (memory :> bytes32 (word (pc + 12))) s = v)
        (\s. read PC s = word (pc + 8) /\
             read R0 s = v /\ read R1 s = word pc)
        (MAYCHANGE [PC] ,, MAYCHANGE [R0; R1] ,, MAYCHANGE [events])`,
    REWRITE_TAC[fst literal_exec] THEN
    REPEAT STRIP_TAC THEN
    AARCH32_SIM_TAC literal_exec [1;2]) in
  (* ldrd r4, r5, [r0, #3], at an address that only the sum aligns. *)
  let offset_mc = define "aarch32_test_offset_mc" [0xe1c040d3] in
  let offset_exec = AARCH32_MK_EXEC_RULE offset_mc in
  let offset = prove
   (`!pc.
      ensures aarch32
        (\s. aligned_bytes_loaded s (word pc) aarch32_test_offset_mc /\
             read PC s = word pc /\
             read R0 s = word 0x1001)
        (\s. read PC s = word (pc + 4))
        (MAYCHANGE [PC] ,, MAYCHANGE [R4; R5] ,, MAYCHANGE [events])`,
    REWRITE_TAC[fst offset_exec] THEN
    REPEAT STRIP_TAC THEN
    AARCH32_SIM_TAC offset_exec [1]) in
  [nostack; stack; literal; offset];;
