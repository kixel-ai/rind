# [S] Android armv7 passes the build workflow again

## Goal

The `build` workflow's `android (armv7-linux-androideabi, RIND_TEST_ARM_NEON=1 RIND_TEST_ARM_CRYPTO_EXT=1)` job passes on `main`. Since [run 42733808737](https://github.com/moq-dev/rind/actions/runs/42733808737) on `1175aab5` (2026-11-10), every test that reaches the armv7 crypto-extension AES fails `low::abi`'s check, `aes_hw_set_encrypt_key broke its ABI: the stack pointer: 0x416806a8 before, 0x0 after`, and fail-fast cancels the other Android rows. [Run 42526310328](https://github.com/moq-dev/rind/actions/runs/42526310328) on `fcfb32f8` (2026-11-08) was the last pass.

## Plan

- The job's definition did not change between the two runs; it runs `cross test` in cross's Android image, under qemu-user with the crypto extension. Bisect `fcfb32f8..1175aab5` with `cross test -p rind --release --target armv7-linux-androideabi aead::gcm` on an x86_64 host. [moq-dev/rind#530](https://github.com/moq-dev/rind/pull/530) touched AES, and the cross image and its qemu are unpinned, so an unchanged commit that now fails points at the image.
- A stack pointer of 0 after the call may be the ABI harness's register capture under this qemu rather than AES itself; `just armv7` runs the same routine under the Linux qemu and tells them apart. Fix whichever is wrong; if the image regressed, pin a working one.
