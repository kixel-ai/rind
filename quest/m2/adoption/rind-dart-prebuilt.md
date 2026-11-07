# [M] rind for Dart installs without a Rust toolchain

## Goal

The `rind` Dart package's build hook downloads a prebuilt native library for the target, pinned by hash in the package, so Flutter and Dart app builders need no Rust toolchain. Building from source stays available as an explicit opt-in user-define, never a silent fallback when a download fails.

## Plan

Planned with the maintainer on 2026-11-07, a follow-up of [moq-dev/rind#462](https://github.com/moq-dev/rind/pull/462), which builds from source; needing Rust and its mobile targets is the largest barrier for app builders.

- Release CI builds each target's library, records its hash in the package, and attaches it to the release; the hook refuses a library whose hash doesn't match.
- Targets: those the package already cross-builds (Android, iOS, macOS, Linux, Windows).
