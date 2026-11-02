# [M] Wipe only what a value owns, everywhere

## Goal

Every backend and layer of rind wipes exactly the secrets a returned value
owns (keys, keyed state) on drop, and no per-call temporary, scratch value,
or copy, as `AGENTS.md` requires. The zeroing tests cover exactly the owned
secrets.

## Plan

Decided with the maintainer on 2026-11-02, from
[moq-dev/rind#216](https://github.com/moq-dev/rind/pull/216): audit all of
rind ✅ / only the files #216 named.

- #216 removed armv7 RSA's per-call wipes. The same pattern remains in, for
  example, `mid/mlkem768.rs` and `mid/arm/{ed25519,p256,mlkem768}.rs`, and in
  the generic backends.
- For each `Drop` that zeroes and each explicit `zeroise` call, decide whether
  the value outlives the call as something the caller owns. Keep those; drop
  the rest.
- Follow aws-lc-rs where ownership is unclear. Keep ctgrind and the zeroing
  tests passing, and make the zeroing tests name each owned secret.
- Removing work cannot slow anything down, so no bench is needed beyond the
  nightly.
