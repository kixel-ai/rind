# Handoff: SLH-DSA SHAKE on x86_64

Delete this file before merging into `quest/m4/pq/slh-dsa-shake-x86`. It is notes for the next agent, not part of the quest. Merging it onto that branch would put it on the upstream claim.

## Claim

The claim branch is `quest/m4/pq/slh-dsa-shake-x86` on `steelhead99x/rind`, empty commit `1f473cb7c7511391e15dd4329fc87818a9a1c5f1` (`chore(quest): claim quest/m4/pq/slh-dsa-shake-x86.md`, `Quest-Claim: 7869b23a8f326c95`) whose tree matches its parent, kixel-ai/rind `main` at `fdeaebc2a0a46f01656f2c164dfdbff0f945a8e9`.

No open kixel-ai/rind pull request used that head when the branch was pushed. This agent could not open the draft on kixel-ai/rind: its GitHub credential is an installation token for `steelhead99x/rind`, and `POST /repos/kixel-ai/rind/pulls` returns 403 `Resource not accessible by integration`. Open the claim from an account that can, and keep it a draft:

```sh
gh pr create --repo kixel-ai/rind \
  --head steelhead99x:quest/m4/pq/slh-dsa-shake-x86 \
  --base main --draft \
  --title "SLH-DSA's SHAKE sets on x86_64 match the SPHINCS+ AVX2 C" \
  --body "Claims [quest/m4/pq/slh-dsa-shake-x86.md](https://github.com/kixel-ai/rind/blob/main/quest/m4/pq/slh-dsa-shake-x86.md)."
```

Compare URL: https://github.com/kixel-ai/rind/compare/main...steelhead99x:rind:quest/m4/pq/slh-dsa-shake-x86?expand=1

Title and body are what `quest start` writes (the `[M]` size tag stripped). After it exists, add this fork pull request's URL to that body. `steelhead99x/rind#142` was opened against the fork's `main` by mistake and is closed. Leave it closed.

## Goal

SLH-DSA's SHAKE sets sign and verify on x86_64 with AVX2 at least as fast as the SPHINCS+ team's AVX2 build. On the measurement in [kixel-ai/rind#641](https://github.com/kixel-ai/rind/pull/641) they trail by up to about 1.2×: SHAKE-128s sign about 1.19×, SHAKE verify 1.1–1.15×. Key generation was already faster (0.57×), and SHAKE-128f sign was 0.96×. About 85% of SHAKE time is the four-way Keccak-f. s2n-bignum's `sha3_keccak4_f1600_alt` transposes its four states in and out on every call (257 ns). XKCP's `KeccakP1600times4`, which SPHINCS+ runs on states it keeps interleaved, took 240 ns.

## Done when

`rind-bench/benches/slhdsa.rs` shows SHAKE signing and verification at or below SPHINCS+'s AVX2 times on the same host, and `ALGORITHMS.md`'s SLH-DSA note is updated. The bench file's SHAKE rows are `slhdsa-shake-128s`, `slhdsa-shake-128f`, and `slhdsa-shake-256f`, each with `-sign` and `-verify`. SPHINCS+ is not a row in that file; #641 compared an external `shake-avx2` build. Keep the upstream claim a draft until those numbers are in the pull request. Parity is not demonstrated.

## Decision

Maintainer, 2026-11-13, recorded in `quest/m4/pq/slh-dsa-shake-x86.md` and in #641: port XKCP's four-way Keccak and plan its proof. The rejected alternatives were to keep s2n-bignum's verified permutation and accept the gap, or to drop the quest.

Scope from the quest: SLH-DSA only. ML-KEM and ML-DSA stay on s2n-bignum's proven permutation. `AGENTS.md` says to run the fastest source and plan its proof, so the proof plan goes in `ALGORITHMS.md` or in a new quest under `quest/m4/verified/`.

## Where the code is

- `rind/src/mid/sha3.rs` `shake256_x4`: SLH-DSA's four-lane SHAKE256. It keeps four separate `[u64; 25]` states and calls `sha3_keccak4_f1600` on every full block. This is the function whose states should stay in XKCP's interleaved layout across permutations, so only absorb and squeeze transpose.
- `rind/src/mid/slhdsa.rs` `thash`: multi-lane SHAKE calls `shake256_x4`. A single lane, which verification uses for the path up a tree, calls `shake256` and one state.
- `rind/src/low/x86_64/sha3_keccak4_f1600_shim.rs`: runtime `HaveAvx2` dispatch to s2n-bignum, else one state at a time. A new routine needs the same runtime gate. The x86_64 target does not enable AVX2 at compile time.
- `rind/src/low/x86_64/sha3_keccak4_f1600_alt.rs`: generated s2n-bignum. Leave it unchanged. Its comment shows the interleaved layout it builds on the stack and then writes back: lane `i` is `[state0[i], state1[i], state2[i], state3[i]]`.
- `Shake4x`, `shake256_batch`, and `SqueezingSponge4xShake128` in `sha3.rs` also call `sha3_keccak4_f1600`. Those serve ML-KEM. Leave them on s2n-bignum.
- One-, two-, and three-lane batches in `shake256_x4` call `sha3_keccak_nof4_f1600`. Signing uses four lanes when it can.
- `ALGORITHMS.md`: the x86_64 gap paragraph (SHAKE sets trail SPHINCS+ because of the transpose) and the `### SLH-DSA` section.
- Tests already covering this path: `shake256_x4_matches_single` in `rind/src/mid/sha3.rs`, the `crosschecks::slh_dsa_shake_*` tests, and the SLH-DSA ctgrind signing tests. A new secret-handling permutation needs a ctgrind run.

## Source to port

XKCP, CC0, AVX2 four-way Keccak-f[1600]:

- https://github.com/XKCP/XKCP/blob/master/lib/low/KeccakP-1600-times4/AVX2/KeccakP-1600-times4-AVX2.c
- https://github.com/XKCP/XKCP/blob/master/lib/low/KeccakP-1600-times4/AVX2/KeccakP-1600-times4-AVX2.h

The permutation is `KeccakP1600times4_AVX2_PermuteAll_24rounds`. The state is `KeccakP1600times4_SIMD256_states { V256 A[25] }`: 25 lanes, each a 32-byte vector of the same lane from four instances. `AddByte` addresses byte `instance * 8 + lane * 32 + offset_in_lane`.

SPHINCS+ runs that code from `shake-avx2` on branch `bas/fips205`: https://github.com/sphincs/sphincsplus/tree/bas/fips205/shake-avx2

Port it into the x86_64 backend as Rust. rind stays pure Rust, and exactly one backend compiles per target.

## Bench

On an x86_64 host whose `/proc/cpuinfo` flags include `avx2`. When this note was written, this VM's `/proc/cpuinfo` reported an Intel Xeon with `avx2`, `avx512f`, and `sha_ni`. Recheck the host you bench on. The s sets use a sample size of 10.

```sh
cargo bench -p rind-bench --bench slhdsa -- slhdsa-shake
```

Same host, SPHINCS+ AVX2, the three SHAKE sets that file benches:

```sh
git clone --branch bas/fips205 --depth 1 https://github.com/sphincs/sphincsplus
cd sphincsplus
for p in sphincs-shake-128s sphincs-shake-128f sphincs-shake-256f; do
  make -C shake-avx2 clean PARAMS=$p
  make -C shake-avx2 benchmarks PARAMS=$p
  make -C shake-avx2 benchmark PARAMS=$p
done
```

`benchmark.py` on that branch is the same `make -C shake-avx2 benchmark PARAMS=sphincs-<fn>-<size><f|s>` loop.

## CI

From the Nix dev shell, against upstream main or the quest branch. The fork's `origin/main` is a different history, last synced behind upstream, so pass the base explicitly:

```sh
nix develop --command just ci fdeaebc2a0a46f01656f2c164dfdbff0f945a8e9
```

The new permutation handles secrets, so it also needs ctgrind. Valgrind runs AVX2 and hides AVX-512, which this port should not use:

```sh
nix develop .#ctgrind --command admin/ctgrind unit --release -- slh_dsa shake256_x4
```

## Open questions

- Verification's one-lane `thash` calls `shake256`, so the four-way port may leave the 1.1–1.15× verify gap in place. Profile a SHAKE verify before treating the interleaved permutation as enough for the done-when bar.
- The proof plan can live in `ALGORITHMS.md` or as a quest under `quest/m4/verified/`. The quest allows either.
- Whether the one- to three-lane `shake256_x4` path is hot enough to interleave too. The measured cost is the four-lane permutation.
