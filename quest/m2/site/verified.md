# [S] A visitor sees which operations run proven code on which CPU

## Goal

The site has a page that maps every operation rind exports to the CPUs where its whole computation is covered by a published formal proof, with a link to each proof, and shows the same for the other libraries. An operation with no proof yet is shown as plainly as one with.

## Plan

Decided 2026-11-12 (maintainer, /quest-plan): ✅ one of the three showpieces. The maintainer's next announcement is about correctness, which the launch post did not cover, so this page is what that post will point at.

- `benchmarks/verified.toml` is the source: each entry names the library, the operations, the architecture and CPU features, whose proof it is, and its link. Its header says what earns a ✓ and what does not; put that rule on the page in a few sentences, since the mark means nothing without it.
- BENCHMARKS.md's Verified code section renders the same file. Match what it shows.
- Draw it as operations against CPU tiers, so the gaps are visible as gaps. It fills in by itself as [the proofs](/quest/m4/verified/README.md) land, with no edit to the site.
- Say what the proofs trust and what they leave out (DER parsing, randomness), from the file's own header and `proofs/README.md`.
- The landing page's "verified where it counts" claim then links here.

## Required

- [The landing page builds from the repository](/quest/m2/site/landing.md) - the `site/` project this adds a page to

## Related

- [Every rind path is proven, with the smallest trust base](/quest/m4/verified/README.md) - the proofs that fill the map in
