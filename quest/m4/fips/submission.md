# [L] Validate rind's FIPS module through a lab and the CMVP

## Goal

rind's FIPS module holds a FIPS 140-3 Level 1 certificate on Linux x86_64
and aarch64, with CAVP certificates for each algorithm and CPU path.

## Plan

From [the scope](/quest/m4/fips/README.md), 2026-11-11.

- Operational environments: four, as aws-lc 3.1's certificate tests: one
  recent Intel or AMD server and one Graviton or Ampere server, each on one
  Linux distribution, with and without processor acceleration where the
  module runs without it. Each further environment is an OEUP submission
  ($2,500 to NIST plus the lab).
- rind writes the security policy and the lab's evidence itself (the
  boundary, services, SSP table, self-tests, zeroization, and build
  instructions naming one source archive by hash), from aws-lc's
  [policy for #5298](https://csrc.nist.gov/CSRC/media/projects/cryptographic-module-validation-program/documents/security-policies/140sp5298.pdf),
  rather than hiring a consultant.
- Cost, 2026: NIST's cost recovery fee for a Level 1 full submission is
  $16,000, plus up to $3,000 of extended cost recovery; vendors who sell FIPS
  services estimate a Level 1 software lab engagement at $50,000 to $75,000
  and more with many environments and algorithms. Labs publish no prices.
- Time: the lab's testing, then the CMVP queue, which averaged 348 days over
  its last 30 validations in January 2026; aws-lc 3 entered the queue around
  December 2024 and was certified on 2026-06-03.
- After certification: the frozen module branch takes only fixes the lab
  agrees to submit (UPDT, $5,500 to NIST plus the lab), and the certificate
  sunsets after five years.

## Waiting

- Maintainer: name the vendor, the legal entity on the certificate that signs the lab contract and pays: moq-dev's sponsor, the maintainer's company, or a funding consumer. An agent cannot commit an organization. Done once the entity is named here and this item is deleted.
- Maintainer: approve the budget (about $70,000 to $100,000 for one certificate, from the Plan's figures) and request quotes from at least two accredited labs on [the CMVP's list of accredited labs](https://csrc.nist.gov/projects/testing-laboratories): atsec, which tested aws-lc's modules, and one other (recommended), once the module, DRBG, IV, and ACVP quests have merged so the quote is for a finished module. Contacting a lab is outward-facing, so an agent only drafts the request. Done once a lab is contracted and this item is deleted.

## Required

- [The module](/quest/m4/fips/module.md) - what the lab tests
- [The ACVP wrapper](/quest/m4/fips/acvp.md) - how the lab runs CAVP testing
- [AES-GCM with internal IVs](/quest/m4/fips/gcm-iv.md) - approved AES-GCM sealing
