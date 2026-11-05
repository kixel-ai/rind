# [M] rind builds on every platform its packages ship

## Goal

rind builds and passes its tests in CI on every target that Bun, pyrind's
wheels, and the Dart package ship: Linux glibc and musl, macOS, and Windows on
x86_64 and aarch64, iOS on aarch64, and Android on aarch64, armv7, and x86_64.

## Plan

- CI tests x86_64 Linux, macOS, and Windows, and aarch64 Linux, and builds
  armv7 Android today. aarch64 Windows (COFF assembly syntax), musl, iOS, and
  Android aarch64 and x86_64 have never been tried.
- Run the tests natively where GitHub has a runner (windows-11-arm, macOS for
  iOS's simulator) and under emulation otherwise; a target only built is
  noted as such.
- Fix what fails at the source; a target that cannot work fails to compile,
  as `AGENTS.md` requires, and is named in the README.
