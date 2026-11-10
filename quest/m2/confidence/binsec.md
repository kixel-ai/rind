# [M] BINSEC checks RSA's private operation, ChaCha20's AVX2 kernel, and aarch64

## Goal

`admin/ct-binsec`'s nightly job covers the secret paths its first harnesses leave out: RSA's private operation past the Montgomery products and the key check's reduction, x86_64's AVX2 ChaCha20 kernel, and every harness on aarch64, where it runs only four. TESTING.md's constant-time cells then name those harnesses without exceptions.

`admin/ct-binsec` runs BINSEC's checkct from a core dump taken as each `ct_binsec_...` test enters its region, on x86_64, aarch64, and the portable backend. Each harness finishes in seconds where BINSEC decodes its path. What it leaves out:
- RSA-2048 signing explored about a million instructions in eight minutes and 5.6 GB without finishing, and with no timeout it ran out of memory at 22 GB. So `ct_binsec_mont_mul` checks the Montgomery products at RSA's CRT widths, `ct_binsec_reduce_even` the key check's reduction, and `ct_binsec_rsa_oaep_padding` OAEP's padding check. The exponentiation's window table lookups (aws-lc's `bn_scatter5` and `bn_gather5`, and RSAZ's), and the CRT recombination, stay with ctgrind and `admin/ct-sde`.
- On GitHub's arm64 runner, BINSEC 0.11.3 stops in most harnesses at an instruction it cannot decode: glibc's SVE `memcpy`, the `mrs x3, tpidr_el0` early in its `malloc`, and the `tbl` of vpaes (the AES that runs with the crypto extension denied) and of aws-lc's NEON ChaCha20-Poly1305. So the aarch64 row runs only X25519, the Montgomery products, one ChaCha20 block, and `constant_time::verify`, which pass.
- LLVM compiles rind's AVX2 ChaCha20 kernel (`low::x86_64::chacha20::cipher_avx2`) with `vinsertf128`, which BINSEC 0.11.3 cannot decode, even from `_mm256_inserti128_si256`. So `ct_binsec_chacha20` checks one block, the SSSE3 kernel's.

## Plan

- RSA: harness each piece of the exponentiation separately, at RSA-2048's widths, such as one window's gather from a table of secret entries and one exponentiation by a short secret exponent, so each finishes in the job's eight-minute timeout. A piece that cannot is recorded in TESTING.md's RSA cell.
- ChaCha20: stub `vinsertf128` in `admin/ct-binsec`'s `STUBS`, as `movmskps` is, or report the gap to BINSEC upstream and take the release that decodes it.
- aarch64: replace glibc's `memcpy`, `memmove`, and `memset` in the BINSEC script with byte loops at the addresses the executable's GOT resolves them to, as valgrind replaces them, and give `mrs` of `tpidr_el0` the value gdb reads. Give `tbl` its effect as a stub if BINSEC's script language can express a lane select without a branch; otherwise report it upstream and leave vpaes and NEON ChaCha20 to ctgrind.
- Where the search stays tractable, make public lengths symbolic, such as an AEAD's message length below a few blocks, rather than fixed.
- Where a s2n-bignum variant with a `_SAFE` theorem exists for a routine rind runs without one, such as aarch64's X25519 `_byte` routines, measure it first: switching is cheaper than relying on the harness if it is as fast at every size.

Guidance:
- Keep each harness well under the job's timeout: a harness that cannot finish is a finding for TESTING.md, not a reason to raise it.
- TESTING.md records the limits: each harness fixes its public inputs, and BINSEC's lifter merges a branch whose two sides are empty ([arXiv 2501.04183](https://arxiv.org/abs/2501.04183)).

## Related

- [A constant-time check on every tier](/quest/m3/confidence/ct-tiers.md) - the test-based checks on the tiers BINSEC cannot decode
