# [S] Wipe copied Python secret buffers and failed output buffers in rind-python

## Goal

Every owned heap buffer that `rind-python` allocates for caller-provided secrets or partial outputs is wiped before it is freed, matching `README.md`'s and `SECURITY.md`'s wiping guarantees, with regression tests covering both paths.

## Plan

Found by the 2026-11-21 repository audit (`/quest-plan`). Decided with the maintainer: ✅ create an m0 fix quest, since leaving copied secret buffers unwiped breaks a published package's (`pyrind`) wiping promise (rejected: defer to m2; skip).

- Culprit PR: [kixel-ai/rind#459](https://github.com/kixel-ai/rind/pull/459) (`feat(python): pyrind, rind's API for Python`), which introduced `Bytes(Cow<'a, [u8]>)`, `copy_buffer`, and `bytes_with` in `rind-python/src/lib.rs`.
- `rind-python/src/lib.rs` (`Bytes` and `copy_buffer`, lines 96-138): mutable Python buffers (`bytearray`, `memoryview`, `array`, the standard Python idiom for zeroizable secrets) are copied into an owned `Vec<u8>` via `PyBuffer_ToContiguous` and dropped with no wipe. Wipe `Cow::Owned` bytes on `Drop` (through `zeroize` or `rind`'s wiping helper) before the `Vec` frees.
- `rind-python/src/lib.rs` (`bytes_with`, lines 191-213): if `fill` returns `Err` after partially writing sensitive output (such as decrypted plaintext or key material) into the freshly allocated `PyBytes` buffer, wipe that buffer before releasing the `PyBytes` object.
- Add tests exercising both paths (including a `bytearray` key/secret input and a failing `fill` path) and verify under `admin/coverage` and `sh/python.sh test`.
