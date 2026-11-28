# [S] rind-acvp answers every ACVP set the module needs

## Goal

[rind-acvp](/rind-acvp/README.md) answers ACVP test sets for every
algorithm in rind's FIPS module, including the ones the module does not
offer yet, on the sample sets `admin/sync-acvp` keeps.

## Plan

The wrapper, its registration (ML-KEM at all three parameter sets), and its
offline run on each CPU path landed in
[kixel-ai/rind#789](https://github.com/kixel-ai/rind/pull/789). AES-GCM
sealing with internal IVs (`ivGen: internal`), which the module offers since
[kixel-ai/rind#771](https://github.com/kixel-ai/rind/pull/771), is registered
and answered: `AES-GCM/seal` takes an empty nonce, and replies the
ciphertext, tag, and the 12-byte IV the module generated in one string, as
aws-lc's `acvptool` reads it; the offline test checks each IV and tag by
opening.

- Decided 2026-11-24 (maintainer, /quest-run): ✅ no NIST ACVP demo
  server credentials (rejected: request them now; defer the request). The
  offline sample runs cover the wrapper; the lab's production run is the
  first against NIST's server.
