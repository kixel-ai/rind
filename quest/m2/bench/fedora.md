# [S] fedora joins the benchmark report as its AVX-512 host

## Goal

`fedora`, a Ryzen 9 9950X (Zen 5, with AVX-512, VAES, and IFMA), is a host in BENCHMARKS.md, measured by `admin/bench-report collect` like the others, so the report times rind's AVX-512 paths on real hardware.

## Plan

Decided 2026-11-12 (maintainer, /quest-audit): ✅ `fedora` joins the report (rejected: ad hoc runs only; leave the host list alone). This reopens the 2026-11-03 host list on new evidence: none of the report's hosts has AVX-512, so the AVX-512 AES-GCM kernel, the IFMA RSA routines, and ML-KEM's 8-way sampler have been timed only under SDE, whose times mean nothing.

- ✅ Accept the noise, as [the Mac mini](/quest/m2/bench/mac-mini.md) does: the machine also runs CI runners and agents, so it benchmarks under plain `quest gate`, and its section says so.
- Add it as `kixtop` was added in [moq-dev/rind#435](https://github.com/moq-dev/rind/pull/435), starting with `admin/bench-report`'s `HOSTS`.
- Record which OpenSSL it compares against in its host data, since each distribution ships its own.
- Zen 5 does not lower its clock for 512-bit vectors, so this host cannot measure what [the 256-bit rule](/quest/m2/speed/avoid-zmm.md) is about. Say so in its section.
- Its first run is a `collect` on this host alone, added to the report the refresh left. Ask the maintainer then whether the other hosts rerun with it: rind 0.4 waits for more now than when the refresh was planned, so the report may be due another before the release anyway.
- A gap it shows that nobody decided is triaged as [the refresh](/quest/m2/bench/report-refresh.md)'s Plan sets out.

## Required

- [Benchmark report refresh, before rind 0.4](/quest/m2/bench/report-refresh.md) - the report without `nixos2`, which this adds a host to
