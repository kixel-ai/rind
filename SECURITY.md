# Security policy

## Reporting a vulnerability

Report it privately through GitHub: on the repository's Security tab, choose
[Report a vulnerability](https://github.com/kixel-ai/rind/security/advisories/new).
Don't open an issue, pull request, or quest for it, since those are public.

Say which package and version it affects, the target and CPU, and how to
reproduce it. If the flaw is in code rind took from another project, which
[ALGORITHMS.md](ALGORITHMS.md#sources) names, it may affect that project too:
report it there as well.

## What counts

These are the promises rind's code makes, and breaking one is a
vulnerability on every target, wasm included:

- **Hostile input.** A malformed key, signature, ciphertext, or encoding
  returns an error. A panic, or a cost the input can make unbounded, is a
  vulnerability.
- **Constant time.** No branch, memory index, or variable-time instruction in
  rind's secret-handling code depends on a secret.
- **Correct results.** rind computes what the algorithm's specification says,
  and accepts no forged signature or tag.
- **Wiping.** A key, keyed state, or heap scratch derived from a private key
  is wiped before it is freed, where [Wiping keys](README.md#wiping-keys) says
  rind wipes it.

Out of scope:

- The workspace's unpublished crates: rind-bench, rind-cpuid, rind-fips,
  rind-timing, and the fuzz targets. A flaw in rind's own code that rind-fips
  builds is a flaw in rind.
- What a wasm engine's compiler does to rind's constant-time code, which
  [PLATFORMS.md](PLATFORMS.md) says is unchecked. A secret-dependent branch or
  index in rind's own source is in scope.
- A flaw in a crate an adapter plugs into, such as rustls: report it to that
  project.

## Reviewing rind

[AUDIT.md](AUDIT.md) is where a security review of rind starts: its threat
model, where its code came from, what each check establishes, and where the
checks are thinnest.

## Supported versions

Below 1.0, only the latest release of each package rind publishes gets fixes:
the `rind` crate and its `rind-<consumer>` adapter crates on crates.io, and its
packages on pub.dev and PyPI. A fix lands on `main` and ships as a new release
of each package it affects, through the release PR that release-plz opens from
`main`. rind keeps no release branch below 1.0, so a fix is not backported: a
user on an earlier minor, such as 0.3 once 0.4 is out, takes the fix by moving
to the latest minor, which its changelog and [MIGRATING.md](MIGRATING.md)
describe.

From 1.0, the last minor of the previous major also gets security fixes for 6
months after the new major's first release, on a `release/<major>.<minor>`
branch, such as `release/1.4`, that release-plz opens its release PR from.
Every other earlier release takes the fix by upgrading.

A fix reaches crates.io and `pyrind` on PyPI when the release PR merges.
`pyrind-cryptography`'s version is bumped by hand, so a fix confined to it
publishes once its version is bumped and the `pyrind` it requires is released.
The Dart packages
on pub.dev publish from their own `rind-dart-v<version>` and
`rind-cryptography-v<version>` tags, so a fix reaches them once those tags'
workflows finish.

A fixed vulnerability gets a GitHub security advisory and a RustSec advisory.
