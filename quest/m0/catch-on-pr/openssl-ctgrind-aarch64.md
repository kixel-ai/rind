# [S] rind-openssl's ctgrind passes on aarch64

## Goal

ctgrind's aarch64 jobs, `build (ubuntu-24.04-arm, --release)` and `aarch64-portable`, pass `rind-openssl`'s `tests/ctgrind.rs`, as the x86_64 jobs do. Valgrind reports only what rind's secrets reach, not errors inside OpenSSL's own setup.

## Plan

- What fails: on main at 561555b3f ([run 44116789846](https://github.com/kixel-ai/rind/actions/runs/44116789846)), and on kixel-ai/rind#812's branch ([run 44106492654](https://github.com/kixel-ai/rind/actions/runs/44106492654)), `admin/ctgrind --run` on `rind-openssl`'s `ctgrind` test exits 99 with 2945 errors from 32 contexts. Every other crate's ctgrind tests pass in the same jobs. The last scheduled run, which passed on 2026-11-14, predates [kixel-ai/rind#658](https://github.com/kixel-ai/rind/pull/658), which added these tests, and [kixel-ai/rind#805](https://github.com/kixel-ai/rind/pull/805), which last changed them.
- Where: "Conditional jump or move depends on uninitialised value(s)" inside OpenSSL 3.5.9's `libcrypto.so.3` from nixpkgs, in `OPENSSL_strlcpy` under `OSSL_LIB_CTX_load_config` (`ctgrind::context`, `ctgrind.rs:96`) and under `EVP_PKEY_new_raw_private_key_ex`'s name-map setup (`ctgrind::private_key`, `ctgrind.rs:103`), both setup calls. So valgrind trips on libcrypto's own aarch64 string code or its config loading, not on a secret.
- Recommended: reproduce under `admin/ctgrind` on an aarch64 host, then fix it at the cause. Either set up OpenSSL's library context before the test marks anything secret, or suppress exactly those libcrypto frames, with the reason, in the suppressions `admin/ctgrind` already passes. A suppression broad enough to hide a secret-dependent branch in the provider is not a fix.

## Related

- [Failures show up on the PR that causes them](/quest/m0/catch-on-pr/README.md) - ctgrind's aarch64 jobs skip pull requests, so this reached main unseen.
