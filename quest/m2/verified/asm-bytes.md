# [M] rind's assembly is byte-identical to the proven object code

## Goal

CI proves that every routine rind imports with a published proof (s2n-bignum's by `admin/parse-asm`, Vale's by `admin/import-hacl`, aws-lc's proven SHA-512) assembles, in rind's build, to the same instruction bytes as the object code the proof checked. Alternatively it proves a recorded, justified difference, such as an appended `vzeroupper`. The transliteration then leaves the trust base, and ALGORITHMS.md drops its "they check s2n-bignum's own build, not rind's transliteration" caveat.

s2n-bignum's constant-time theorems (its `_SAFE` ones: the instructions executed and addresses accessed are independent of secrets, and no variable-time instruction runs) then cover rind's bytes too. ALGORITHMS.md says which routines rind runs carry them, and TESTING.md's constant-time cells cite them, so those routines are proven constant-time for every input rather than only for the inputs ctgrind's tests run.

## Plan

Moved from m4 into m3 with the maintainer on 2026-11-09, then into m2 the same day with the rest of the active assurance work ✅ (rejected: redefine m3, move only the security check). Since late 2025 s2n-bignum proves routines constant-time as well as correct, so far the ones AWS-LC uses ([SOUNDNESS.md](https://github.com/awslabs/s2n-bignum/blob/b4f17ee743ebc9b53a26c3cd1908f50f0658314f/SOUNDNESS.md#L99-L109)), and rind's pin (`b4f17ee`, 2026-11-06) carries those theorems, so this check is what turns them into a guarantee about rind.

- Scope (decided with the maintainer on 2026-11-09): every proven source, with the constant-time theorems added ✅ (rejected: s2n-bignum only in m3, with Vale and aws-lc left in m4).
- Not every s2n-bignum routine rind runs has a `_SAFE` theorem at the pin. aarch64's X25519 has none: [`curve25519_x25519_alt.ml`](https://github.com/awslabs/s2n-bignum/blob/b4f17ee743ebc9b53a26c3cd1908f50f0658314f/arm/proofs/curve25519_x25519_alt.ml) and [`curve25519_x25519base_alt.ml`](https://github.com/awslabs/s2n-bignum/blob/b4f17ee743ebc9b53a26c3cd1908f50f0658314f/arm/proofs/curve25519_x25519base_alt.ml), whose correctness theorems `proofs/Rind/Aarch64/S2nBignum.lean:27` and `:35` cite, define none, while the `_byte` variants AWS-LC calls and x86_64's four X25519 files do. Nor do x86_64's `mlkem_ntt.ml`, `mlkem_basemul_k3.ml`, and `bignum_kmul_16_32.ml` (checked 2026-11-09).
- So this check supplies the per-routine inventory: for each s2n-bignum routine rind runs, on each architecture, the `_SAFE` theorem that covers its bytes, or that none does. ALGORITHMS.md holds it, and [BINSEC](/quest/m2/confidence/binsec.md) checks the routines without one.
- Build each upstream's object code at its pinned revision, extract each routine's bytes, and compare them with the bytes in rind's compiled `asm!` and naked functions. Relocations and alignment padding need a normalization step, documented in the check. Extract rind's side with `asm_block` in `admin/prove`, which [moq-dev/rind#533](https://github.com/moq-dev/rind/pull/533) adds for the HOL Light proofs, rather than with a second extractor; it takes one `asm!` block per function and refuses a relocation today, so widen it where this check needs more.
- A recorded difference also says why the routine's constant-time theorem still holds with it, as for an appended `vzeroupper`, which touches no secret.
- Run it for x86_64 and aarch64, and fail when a re-import changes bytes without a matching proof revision.

## Required

- [rind's own HOL Light proofs live in proofs/hol-light](/quest/m3/verified/hol-light.md) - `admin/prove`'s extraction of the bytes rind's build emits for an `asm!` block, which this check compares

## Related

- [BINSEC checks the secret paths no proof covers](/quest/m2/confidence/binsec.md) - takes this check's inventory, and leaves the routines these theorems cover to them
