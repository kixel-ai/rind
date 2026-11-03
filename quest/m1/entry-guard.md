# [S] Every public entry point runs inside the entry guard

## Goal

Every public rind function that does work enters through `low::Entry`, secret or public as its inputs require, so AArch64 DIT is enabled for every computation on secrets and the CPU-feature check runs everywhere.

## Plan

Planned with the maintainer on 2026-11-03 from an external audit. HMAC, HKDF, PBKDF2, digest, and constant-time comparison (`high/{hmac,hkdf,pbkdf2,digest,constant_time}.rs`) never create an `Entry`, so their secret keys and inputs run without DIT on AArch64.

- Audit every public function in `high/` and `mid/`, not only those five, and add the right `Entry` at each one that computes; keep it off trivial accessors, as `entry.rs` says.
- Add a check that keeps it that way, such as a test or lint over the public entry points, rather than relying on review.
- Measure HMAC and digest on small inputs: entering DIT costs two system-register writes per call.
