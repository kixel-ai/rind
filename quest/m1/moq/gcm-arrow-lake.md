# [XS] Short AES-GCM on Arrow Lake runs its fastest path after #409

## Goal

On Arrow Lake (VAES-AVX2), QUIC-sized AES-GCM seals are at least as fast after [moq-dev/rind#409](https://github.com/moq-dev/rind/pull/409) as before, and the open crossovers between by-8 and Vale's kernel are set from Arrow Lake measurements.

## Plan

Decided with the maintainer on 2026-11-06: merge #409 on Zen 3 and GitHub runner numbers, and measure Arrow Lake here once `desktop` is free. On 2026-11-07 the maintainer freed `desktop` for agents and asked for an E-core pass too. The open crossovers are being set on the combined code by the agent on [moq-dev/rind#430](https://github.com/moq-dev/rind/pull/430), which was asked to fold this quest in; if that PR deletes this file, it is done. #409 moved every VAES-AVX2 seal to by-8; #391's own control had by-8 5-9% faster than Vale on Arrow Lake under a 32 B AAD.

- On `desktop`, under `quest gate --host`, run `cargo bench -p rind-bench --bench aes_gcm -- 'aes(128|256)-gcm/rind/quic'` on `main` and on #409's parent, comparing only matching `CPU:` lines. If seals regressed, move the seal crossover back.
- Pin a P-core and, separately, an E-core (Skymont): Arrow Lake is hybrid, and crossovers set on P-cores may be wrong on E-cores. Report both, and pick crossovers that hold on both or favour the P-cores, saying which.
- Run the `probe_paths` test from the throwaway branch [`probe/gcm-partial-aad`](https://github.com/moq-dev/rind/tree/probe/gcm-partial-aad) to time by-8 against Vale for opens, and move the open crossover (now under 256 B on Vale) if by-8 wins. Delete the branch afterwards.
