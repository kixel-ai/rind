# [XL] rind as an OpenSSL 3 provider

## Goal

A `rind-openssl` crate builds a shared library that OpenSSL 3 loads as a
provider through `openssl.cnf`, offering the algorithms where rind is faster
than OpenSSL's default provider (on an i7-8700: Ed25519 and X25519 about 3-4x,
P-384 about 4x, and P-521), so a Node, Python, Ruby, or nginx deployment
gets them with no code change.

## Plan

Planned by the maintainer on 2026-11-04 in m4.

- OpenSSL's property queries pick the provider per algorithm at fetch time,
  set by configuration: that is a choice made at setup, not a runtime
  fallback, so the default provider keeps every algorithm rind does not
  register. The documented `openssl.cnf` activates `default` beside rind,
  since activating any provider stops OpenSSL loading it implicitly, and
  prefers rind with `default_properties = ?provider=rind`.
- The documented `openssl.cnf` also sets `config_diagnostics = 1`. Without
  it OpenSSL carries on past a configuration error: "access will be allowed
  but the desired configuration will not be used"
  ([config(5)](https://docs.openssl.org/3.5/man5/config/)). A rind provider
  that refuses to load, as it must on a CPU missing a required feature,
  would then leave every algorithm on `default` without a word, which is the
  fallback `AGENTS.md` forbids. Test that such a load fails the process's
  OpenSSL initialization with rind's error.
- Register only what measures faster, on `openssl speed` and on a Node and a
  Python workload, and keys must round-trip through OpenSSL's encoders and
  decoders so mixed use works.
- Pass OpenSSL's own test suite for each registered algorithm with the
  provider loaded, and keep the C ABI layer thin and fuzzed. rind-dart's
  library already exports a C ABI (`rind-dart/src/lib.rs`), but its callers
  are rind's own Dart bindings; this is the first C ABI whose callers rind
  does not write.

## Waiting

- Maintainer: decide whether rind-openssl builds rind with `wipe`. `AGENTS.md` keeps wiping opt-in because safe Rust cannot read freed memory, and that reason does not hold here: the provider's heap is the host process's, which C code reads, and private keys cross the boundary in `OSSL_PARAM` buffers. Options: always build with `wipe` and wipe the buffers the provider fills (recommended, since OpenSSL's own providers cleanse keys, so anything less is a regression for whoever switches); leave it to a build flag, off by default as in rind; or wipe nothing, as rind does. An agent cannot settle it: it decides how the wipe rule reads outside safe Rust. Done once the choice is in the Plan and this item is deleted.
