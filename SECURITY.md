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

## Advisories and CVEs

A confirmed vulnerability is fixed in the private GitHub security advisory
its report opened, and rind requests its CVE through that advisory, from
GitHub as the CVE Numbering Authority, before publishing it with the fixed
releases. [security.txt](https://rind.kixel.ai/.well-known/security.txt)
points scanners here.

## Supply chain

- **Dependencies.** `cargo vet` holds every crate the published `rind` crate
  can build with, on any target and feature, to a safe-to-deploy audit:
  imported from Mozilla's, Google's, or the Bytecode Alliance's audits, rind's
  own in [supply-chain/audits.toml](supply-chain/audits.toml), or an exemption
  in [supply-chain/config.toml](supply-chain/config.toml) for a version rind
  used before it began vetting. A new crate or version fails CI until one
  covers it. `cargo deny` checks every crate the workspace uses against
  RustSec's advisories, licenses, and sources.
- **Provenance.** A release attests, through GitHub's artifact attestations
  (SLSA build provenance signed through Sigstore), the `.crate` files it
  published to crates.io, pyrind's and pyrind-cryptography's files on PyPI,
  and rind-dart's prebuilt libraries on its GitHub release. Check a file with
  `gh attestation verify <file> --repo kixel-ai/rind`; cargo keeps each
  crate it downloaded under `~/.cargo/registry/cache/`.
- **Reproducible builds.** Each build of rind-dart's prebuilt libraries and
  pyrind's wheels, nightly and for a release, runs twice from a clean target
  directory, and a release stops unless both match bit for bit. Both builds
  run on one runner, at the same paths and with the same toolchain: the Apple
  libraries record their build path, and the release takes the Rust stable of
  its day.
- **CI.** Every third-party GitHub Action is pinned to a commit, and a pull
  request's workflows get a read-only token. OpenSSF Scorecard scores the
  repository weekly:
  [its report](https://scorecard.dev/viewer/?uri=github.com/kixel-ai/rind).

## Supported versions

Only the latest release of each package rind publishes gets fixes: the
`rind` crate and its `rind-<consumer>` adapter crates on crates.io, and its
packages on pub.dev and PyPI. A fix ships as a new release of each package
it affects.

A fixed vulnerability gets a GitHub security advisory and a RustSec advisory.
