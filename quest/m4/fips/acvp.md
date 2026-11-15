# [S] rind-acvp answers every ACVP set the module needs

## Goal

[rind-acvp](/rind-acvp/README.md) answers ACVP test sets for every
algorithm in rind's FIPS module, including the ones the module does not
offer yet, and answers fresh sets from NIST's demo server, not only the
sample sets `admin/sync-acvp` keeps.

## Plan

The wrapper, its registration, and its offline run on each CPU path landed
in [kixel-ai/rind#789](https://github.com/kixel-ai/rind/pull/789). What
remains:

- Register and answer AES-GCM sealing with internal IVs (`ivGen:
  internal`), which [the IV quest](/quest/m4/fips/gcm-iv.md) adds to the
  module: aws-lc's `acvptool` asks `AES-GCM/seal` with an empty nonce, and
  reads the ciphertext, tag, and 12-byte IV back in one string.
- Register and answer ML-KEM-512 and ML-KEM-1024 once
  [kixel-ai/rind#606](https://github.com/kixel-ai/rind/pull/606) adds them
  to the module: the lengths in `rind_fips::acvp` and the parameter set in
  `rind::fips::acvp`.
- Find why `acvptool` once exited without a message, after 61 s of the
  first CPU mask, in x86-cpu.yml's Diamond Rapids job
  ([run](https://github.com/kixel-ai/rind/actions/runs/43691180379/job/132741976547)).
  It passed on rerun and in five runs under SDE on an Intel host; GitHub's
  runners are AMD's. The offline test now prints `acvptool`'s exit status,
  so a recurrence names the signal; run the job repeatedly to reproduce.
- Once a credential exists, run fresh demo sets for every registered
  algorithm, once per CPU mask, in a scheduled job, as the offline test
  runs the samples.

## Required

- [AES-GCM with internal IVs](/quest/m4/fips/gcm-iv.md) - the module's sealing service

## Waiting

- Maintainer: request ACVP demo server credentials from NIST, which issues a TLS client certificate per organization, so fresh sets run before the lab's production run. An agent cannot contact NIST. Optional until the lab is engaged: the offline runs cover the wrapper meanwhile. Done once a credential is stored as a secret and this item is deleted.
