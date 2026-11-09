# [M] rind's assembly is byte-identical to the proven object code

## Goal

CI proves that every routine rind imports with a published proof (s2n-bignum's by `admin/parse-asm`, Vale's by `admin/import-hacl`, aws-lc's proven SHA-512) assembles, in rind's build, to the same instruction bytes as the object code the proof checked. Alternatively it proves a recorded, justified difference, such as an appended `vzeroupper`. The transliteration then leaves the trust base, and ALGORITHMS.md drops its "they check s2n-bignum's own build, not rind's transliteration" caveat.

s2n-bignum's constant-time theorems (its `_SAFE` ones: the instructions executed and addresses accessed are independent of secrets, and no variable-time instruction runs) then cover rind's bytes too. ALGORITHMS.md says which routines rind runs carry them, and TESTING.md's constant-time cells cite them, so those routines are proven constant-time for every input rather than only for the inputs ctgrind's tests run.

## Plan

Moved from m4 into m3 with the maintainer on 2026-11-09. Since late 2025 s2n-bignum proves its routines constant-time as well as correct ([SOUNDNESS.md](https://github.com/awslabs/s2n-bignum/blob/main/SOUNDNESS.md)), and rind's pin (`b4f17ee`, 2026-11-06) carries those theorems, so this check is what turns them into a guarantee about rind.

- Scope (decided with the maintainer on 2026-11-09): every proven source, with the constant-time theorems added ✅ (rejected: s2n-bignum only in m3, with Vale and aws-lc left in m4).
- Build each upstream's object code at its pinned revision, extract each routine's bytes, and compare them with the bytes in rind's compiled `asm!` and naked functions. Relocations and alignment padding need a normalization step, documented in the check.
- `admin/prove`'s `asm_block` already extracts an `asm!` block's bytes from rind's release build for the HOL Light proofs in `proofs/hol-light/`; extend it rather than write a second extractor, so both checks read the same bytes.
- A recorded difference also says why the routine's constant-time theorem still holds with it, as for an appended `vzeroupper`, which touches no secret.
- Run it for x86_64 and aarch64, and fail when a re-import changes bytes without a matching proof revision.

## Related

- [BINSEC checks the secret paths no proof covers](/quest/m3/confidence/binsec.md) - leaves the routines these theorems cover to them
