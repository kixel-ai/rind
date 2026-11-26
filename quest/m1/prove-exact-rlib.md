# [XS] admin/prove reads the rlib its own build produced

## Goal

`admin/prove` extracts rind's codegen units from the rlib that its own cargo build just produced, whatever older `librind-*.rlib` files the build directory still holds. Today `rind_index` passes the glob `deps/librind-*.rlib` to `llvm-ar x`, and a leftover rlib from an earlier build with other features matches it too, so a local or agent run fails until someone deletes the file. CI starts from a clean directory, so it never sees this.

## Plan

Planned with the maintainer on 2026-11-26, after an agent hit it on [kixel-ai/rind#1088](https://github.com/kixel-ai/rind/pull/1088) and worked around it by deleting the stale file.

- ✅ Take the path from the build's own record of what it produced, such as cargo's `--message-format=json` `compiler-artifact` message for rind's `lib` target (rejected: the newest by mtime, which [kixel-ai/rind#875](https://github.com/kixel-ai/rind/pull/875) does today, since a fresh build cargo reuses can be older than a leftover one; only relying on #875).
- [kixel-ai/rind#875](https://github.com/kixel-ai/rind/pull/875), open, changes the same line. Whichever lands second keeps this quest's version.
