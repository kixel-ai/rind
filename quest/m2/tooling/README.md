# CI and tooling follow-ups

## Goal

Small CI and tooling gaps found while landing the speed work on 2026-11-02 are closed.

## Plan

Planned with the maintainer on 2026-11-02. Milestone m2.

## Required

- [COMPATIBILITY.md matches the CPU scans](/quest/m2/tooling/compatibility-table.md) - regenerated from the refreshed `admin/x86-cpus` scans
- [build.yml installs only what it uses](/quest/m2/tooling/build-valgrind.md) - drop valgrind from the Linux build if nothing needs it
