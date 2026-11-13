# [S] fedora joins the benchmark report as its AVX-512 host

## Goal

`fedora`, a Ryzen 9 9950X (Zen 5, with AVX-512, VAES, and IFMA), is a host in BENCHMARKS.md, measured by `admin/bench-report collect` like the others, so the host tables, which compare rind with every library and give each time, cover rind's AVX-512 paths.

## Plan

Decided 2026-11-12 (maintainer, /quest-audit): ✅ `fedora` joins the report (rejected: ad hoc runs only; leave the host list alone). This reopens the 2026-11-03 host list: none of the report's hosts has AVX-512 (`nixos` is Zen 3, `desktop` a Core Ultra 7 270K Plus, the two VPSes Haswell, `kixtop` an Apple M4), so no host table shows the AVX-512 AES-GCM kernel, the IFMA RSA routines, or ML-KEM's 8-way sampler.

The interview gave the maintainer a stronger reason than the code supports. It said those paths were timed only under SDE. They are not: BENCHMARKS.md's CPU tier table times them every night on GitHub's runners, whose EPYC 9V45 and 9V74 have AVX-512 (`benchmarks/data/tiers.json`; its `x86_64`, `no IFMA`, and `no AVX-512` columns exist to separate them). That table gives one number per row, rind's time over the faster of aws-lc-rs and ring, on a shared cloud core. What `fedora` adds is the host table's view of the same paths: each time, against OpenSSL, RustCrypto, and the other libraries, on a desktop core. The decision was made on the wrong claim, so it is under `Waiting` to confirm.

- ✅ Accept the noise, as [the Mac mini](/quest/m2/bench/mac-mini.md) does: the machine also runs CI runners and agents, so it benchmarks under plain `quest gate`, and its section says so.
- Add it as `kixtop` was added in [moq-dev/rind#435](https://github.com/moq-dev/rind/pull/435), starting with `admin/bench-report`'s `HOSTS`.
- Record which OpenSSL it compares against in its host data, since each distribution ships its own.
- Zen 5 does not lower its clock for 512-bit vectors, so this host cannot measure what [the 256-bit rule](/quest/m2/speed/avoid-zmm.md) is about. Say so in its section.
- Its first run is a `collect` on this host alone, added to the report the refresh left. Ask the maintainer then whether the other hosts rerun with it: rind 0.4 waits for more now than when the refresh was planned, so the report may be due another before the release anyway.
- A gap it shows that nobody decided is triaged as [the refresh](/quest/m2/bench/report-refresh.md)'s Plan sets out.

## Waiting

- Maintainer: confirm or drop this quest now that its reason is smaller than the interview said (the Plan's second paragraph). Keep it, which the audit still recommends: it is an S, the host is already on and already benchmarks rind ad hoc, and no host table compares rind's 512-bit AES-GCM with OpenSSL's. Or drop it and rely on the CPU tier table, which already catches a regression in these paths against aws-lc-rs and ring.

## Required

- [Benchmark report refresh, before rind 0.4](/quest/m2/bench/report-refresh.md) - the report without `nixos2`, which this adds a host to
