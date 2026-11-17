# [M] P-384 earns the ✓ from pyca/verified-garbage's proof

## Goal

Every VG routine P-384 runs is imported as a theorem, so P-384 ECDSA earns the ✓ on the tiers that run it: VG's `d·G` (`vg_ec_p384_public_key`, and its BMI2 and ADX variant on x86_64), which ECDSA's key generation and each signature's `k·G` take on x86_64 and aarch64, and its ECDSA verification (`vg_ecdsa_p384_verify`, and its ADX variant), on x86_64 for every key and on aarch64 for a key's first verification (`low/<arch>/p384_vg.rs`, vendored by `admin/import-vg`).

## Plan

- Import each routine's VG theorem as one axiom about rind's opaque wrapper, under [the m3 epic's composition rule](/quest/m3/verified/README.md), as [the epic](/quest/m2/verified-garbage/README.md)'s Plan settles, and add the `benchmarks/verified.toml` entries for the switched tiers.
- Prove rind's glue around it as the m3 and m4 epics prove rind's other glue: `mid/p384.rs` encodes the scalar for `d·G` and reduces the x-coordinate of `k·G` mod n for `r`, checks the point is on the curve, and passes verification `r`, `s`, and `e` as bytes, `e` as the 48-byte digest VG reads its leftmost 384 bits of. Signing's `s`, rind's hedged nonce, and aarch64's verification of a reused key stay rind's, which [the m4 P-384 quest](/quest/m4/verified/p384.md) proves.
- P-384 ECDH keeps rind's comb for its key generation, under its existing ✓. Once VG's `d·G` theorem is imported here, agreement's key generation can take it too without losing that ✓, if the maintainer settles it in [kixel-ai/rind#847](https://github.com/kixel-ai/rind/pull/847).
- Model gaps, which the maintainer ruled on 2026-11-17 ([kixel-ai/rind#815](https://github.com/kixel-ai/rind/pull/815#issuecomment-6943056592)) as [the epic](/quest/m2/verified-garbage/README.md)'s Plan records: ✅ the stack-slot gap is reported upstream and this ✓ waits for VG's fix and a re-pin (rejected: a rind-side check that each stack load reads only bytes its own frame stored; accepting the model as is). ✅ The `NoResidue` undefined-flags gap is reported upstream and does not hold this ✓, since rind imports no `NoResidue` theorem (rejected: not reporting it).

## Waiting

- pyca/verified-garbage: fix the stack-slot model, [pyca/verified-garbage#5321](https://github.com/pyca/verified-garbage/issues/5321) (a freed frame's bytes keep their values in the model, so a proof can read back a value hardware may have lost); then re-pin `admin/import-vg`'s `REV`, which `admin/import-vg-models` also reads, to a commit with the fix. Check: the issue is closed by a merged fix.
