# [XS] x86_64 RSA enters verified-garbage's internal routines through typed naked entries

## Goal

`low::x86_64::rsa_ifma` calls VG's parameterless internal routines `vg_rsa_public_precomputed_checked_ifma`, `vg_rsa_private_crt_precomputed_ifma`, and `vg_rsa_private_crt_precomputed_ifma512` through naked entries that declare their contracts' parameters and `jmp` to them, rather than transmuting `unsafe extern "sysv64" fn()` to a function pointer with parameters, which the Rust reference leaves undefined.

## Plan

- Found by review of [kixel-ai/rind#1024](https://github.com/kixel-ai/rind/pull/1024), which gave `low::aarch64::sha512::compress_vg` the same shape for `vg_sha512_compress_sha512`: one `b` to the routine, leaving every register and the return address as the caller set them.
- Keep VG's vendored text unchanged, as `admin/import-vg` requires; the entries are rind's. Update each axiom's trusted note in `proofs/Rind/X86_64/` that names the wrapper's call, as `Rind/Aarch64/VgSha512.lean` does.
- Test with `gh workflow run x86-cpu --ref <branch>`, which runs the pushed branch rather than main and whose SDE matrix checks AVX-512 IFMA RSA dispatch; a hosted runner may lack IFMA and fall back.
