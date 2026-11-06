# [XS] Benchmark collections on one host can't clobber each other

## Goal

`admin/bench-report collect` takes a per-host lock before it touches a host's copy, so two sessions collecting on the same host never delete or measure over each other's run; a held lock records the host as busy and skips it.

## Plan

During [moq-dev/rind#397](https://github.com/moq-dev/rind/pull/397), one session's `collect --host kixtop` cleared the host's copy while [moq-dev/rind#399](https://github.com/moq-dev/rind/pull/399)'s collection was running there, breaking its build-cost step: `collect` clears a host's copy before any busy check. #397 already takes a nonblocking `flock` on the OVH VPS hosts, held through copying, running, and cleanup. Decided with the maintainer on 2026-11-06: extend the same lock to every host, local and remote, taken before the copy is cleared.
