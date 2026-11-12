# [L] x86_64 SHA-256 on AVX2 without SHA-NI is proven

## Goal

SHA-256, and HMAC, HKDF, and PBKDF2 over it, earn the ✓ on x86_64 CPUs with AVX2 but without SHA-NI: Intel's cores from Haswell through Comet Lake and Cascade Lake, still common in clouds.

## Plan

- Runs: OpenSSL's `sha256_block_data_order_avx2` (`low/x86_64/openssl/`), which aws-lc leaves out: 1.12x faster than aws-lc's AVX routine on an i7-8700 and 1.13x on Arrow Lake.
- Route: a HOL Light proof in s2n-bignum's x86_64 model against [awslabs/s2n-bignum#415](https://github.com/awslabs/s2n-bignum/pull/415)'s FIPS 180-4 SHA-256 spec, sharing the AVX2 model work with [x86_64 SHA-512 on AVX2](/quest/m4/verified/sha512-x86-avx2.md). It enters `proofs/Rind/X86_64/ShaBlocks.lean` as an axiom.
- Spec pin: build on [awslabs/s2n-bignum#415](https://github.com/awslabs/s2n-bignum/pull/415)'s spec at a pinned commit while it is unmerged, and move to the merged version when it lands; `benchmarks/verified.toml`'s ✓ notes the pin (decided with the maintainer on 2026-11-07 on [moq-dev/rind#448](https://github.com/moq-dev/rind/pull/448)).
- Upstream: offering this work to awslabs/s2n-bignum is optional, and there is no standing approval: stop and ask the maintainer before posting there or anywhere outside the moq-dev and kixelated orgs (decided with the maintainer on 2026-11-07 on [moq-dev/rind#448](https://github.com/moq-dev/rind/pull/448)).

## Done

[moq-dev/rind#636](https://github.com/moq-dev/rind/pull/636) holds `proofs/hol-light/x86_64/sha256_block_data_order_avx2.ml`, whose every theorem is proved:

- The x86 model patch gains VEX `vpshufd`, with cosimulation cases.
- `SHA256_AVX2_K256`: the table's rows, masks, and the loop's exit bytes.
- `SHA256_AVX2_BLOCK_A`: from the loop head (`pc + 0x80`) to block A's stored state (`pc + 0x105b`), block A's 64 rounds, with block B's schedule words plus constants left at `base + sha256_avx2_slot t`. It takes about 14 minutes.
- `SHA256_AVX2_BLOCK_B`: from `pc + 0x1065` to the `jbe` at `pc + 0x13f5`, block B's rounds, its feed-forward, and the next pair's pointer and flags. It takes about 10 minutes.
- Helpers for the composition:
  - The frame the prologue makes (`SHA256_AVX2_BASE`, `_STACK_SUBSUMED`, `_PUSH_NONOVERLAP`, `_BASE_NONOVERLAP`).
  - The input pointer's comparisons (`_PTRS`).
  - The message as one ghost read (`_DATA`, `SHA256_READ_SLICE32`).
  - The table as a plain read (`_BYTES_LOADED`).

## Remaining

1. **`SHA256_AVX2_SUBROUTINE_CORRECT`**, shaped like `SHA256_HW_SUBROUTINE_CORRECT` on aarch64.
   - Hypotheses:
     - `0 < n`, `val data + 64 * (n + 1) < 2 EXP 64`, and `1648 <= val stackpointer`.
     - `aligned 64 (word k256)`.
     - `riprel32_within_bounds` for `(k256 + 544, pc + 114)`, `(k256 + 576, pc + 122)`, `(k256 + 512, pc + 136)`, and `(k256, pc + 204)`.
     - `ALLPAIRS nonoverlapping [(word_sub stackpointer (word 1648),1656); (ctx,32)] [(word pc,0x1423); (data,64 * n); (word k256,640)]`, plus the stack region nonoverlapping `(ctx,32)`.
   - Frame: `MAYCHANGE [RSP] ,, MAYCHANGE_REGS_AND_FLAGS_PERMITTED_BY_ABI ,, MAYCHANGE [memory :> bytes(ctx,32); memory :> bytes(word_sub stackpointer (word 1648),1648)]`.
   - Setup, checked interactively:
     - Abbreviate `base = word_sub (word_and (word_sub stackpointer (word 592)) (word 18446744073709550592)) (word 32)`.
     - Derive the frame facts from the helpers.
     - Rewrite `MAYCHANGE_REGS_AND_FLAGS_PERMITTED_BY_ABI` before `ENSURES_PRESERVED_TAC` on RBX, RBP, and R12 to R15.
     - Narrow to a core frame with `ENSURES_FRAME_SUBSUMED`. The core frame is the registers, ZMM0 to ZMM15, the flags, the events, ctx, `bytes(base,576)`, and `bytes(word_sub stackpointer (word 48),48)`.
     - Introduce `dv = read (memory :> bytes(data,64 * n))` with `GHOST_INTRO_TAC`, and case-split on its per-word fact.
2. **The prologue to the loop head.**
   - Keep stack addresses as `word_sub stackpointer (word k)`. `SHA256_PTR_CONV`'s `word_add stackpointer (word (2^64 - k))` form defeats `NONOVERLAPPING_TAC`.
   - After `add $0x1c0,%rsp`, rewrite RSP to `word_add base (word 480)`.
   - Every step through the stores went through. One step near the YMM8/YMM9 loads at `0x6a`/`0x72` ran for more than 25 minutes without finishing; find out why first.
3. **The pair loop.**
   - `ENSURES_WHILE_UP_TAC (n DIV 2) (pc + 0x80) (pc + 0x13f5)`.
   - The invariant at pair `i`:
     - RSP is `base + 480`, and RSI is `data + 64(2i + 1)`.
     - R12 is `if 2i + 1 = n then base + 480 else RSI`.
     - CF is `2i + 1 < n`, and ZF is `2i + 1 = n`.
     - The registers and ctx hold `sha256_hash_blocks m H (2i)`.
     - YMM8/YMM9 hold the masks, and the table is read as bytes.
     - `dv` holds, and so do `base + 544/560/568`, the pushed registers, and the return address.
   - The body: `X86_BIGSTEP_TAC` over block A, `cmp`/`je`, then block B, with the data facts from `SHA256_AVX2_DATA`.
   - `n = 1` cannot use the loop, so case-split it.
   - The odd tail: `jbe` taken, block A with the stack as a dummy B, then `je` to `0x13ff`.
   - The even exit: `jbe` falls through.
   - The epilogue: restore from `[base + 568] - 48 ..` and `rep ret`.
4. **Wiring.**
   - Add the file to `admin/prove`'s `hol_light_proofs`.
   - Add the Lean axiom to `proofs/Rind/X86_64/ShaBlocks.lean` (discharging `avx2`).
   - Mark the ✓ with the spec pin in `benchmarks/verified.toml`, and update `proofs/README.md`.
5. **Long runs.** A session's background command stops at two hours, which one toplevel holding both block lemmas reaches while developing the composition. During development, load the block lemmas as `mk_thm` stand-ins and reprove them only in the final `admin/prove` run, which takes about 30 minutes in one go.
