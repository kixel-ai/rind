# [M] ESP32-S3 SHA-512 runs its unrolled block from IRAM, or the rolled loop stays

## Goal

On `xtensa-esp32s3-espidf`, SHA-384, SHA-512, SHA-512/256 and their HMACs run an unrolled compression block placed in IRAM, with its constants in DRAM and an `esp32s3-sha512-flash` feature that keeps main's rolled loop for firmware that cannot spare the IRAM; or the maintainer refuses it and the quest's PR records that, deleting the quest.

## Plan

[kixel-ai/rind#793](https://github.com/kixel-ai/rind/pull/793) (merged 2026-11-19) narrowed the rolled SHA-512 to 32-bit microcontrollers and put the SHA-256 body in IRAM, but left SHA-512 as a rolled loop in flash text. The fork PR [steelhead99x/rind#94](https://github.com/steelhead99x/rind/pull/94) (head `49dc5409`, built before #793 merged and never proposed upstream) adds the SHA-512 half. Its numbers are the case; the maintainer decides whether the cost is worth it.

- What it adds: on the ESP32-S3 only, an unrolled SHA-512 body (sixteen-round groups with constant indexes, an uninitialized window, an `l32i`/`ssai`/`src` message load) so nothing outlines into flash at any opt-level. On `xtensa-esp32s3-espidf` the block and its literal pool go in `.iram1.text` and the 640-byte `K` in `.dram1.rodata`. Every other 32-bit target keeps the rolled loop, so its size is unchanged. The driver `sha512_compress_blocks` and its length assert stay in flash.
- Board gain, ESP32-S3 at 240 MHz with flash at 80 MHz, five interleaved rounds against main: SHA-512, SHA-512/256 and HMAC-SHA384 rows take 0.911 to 0.918 of main's cycles, and rind's one-shot SHA-256 rows are unchanged within 0.1%.
- Cost: free heap at boot falls by 19,072 B (153,072 B to 134,000 B). The block takes 18,533 B of IRAM with its literal pool at opt-level 3 (17,792 B at s, 17,797 B at z), capped at 20,480 B, plus 640 B of DRAM.
- Opt-out: `esp32s3-sha512-flash` builds main's rolled loop, with no IRAM or DRAM section. It measured 1.008 to 1.010 of main and keeps free heap at 153,072 B. An earlier opt-out, the unrolled block built into flash, was 11.3 to 13.1 times slower than the rolled loop, which is why the opt-out is the rolled loop and not the unrolled block.
- Checks it carries: `admin/esp32s3-sha512-layout` and its workflow verify the sections, a relocation allowlist, no call in the block, no flash reference, the IRAM ceiling at three opt-levels, and the opt-out's absence of IRAM sections. QEMU's ESP32-S3 CPU runs a message-load probe (every word at byte offsets 0, 1 and 3) and a FIPS 180-4 "abc" probe through the whole compressor.
- Port the branch onto `main` after #793, which shares `admin/esp32s3-sha256-layout` and the toolchain setup. Share that setup instead of copying it, and rerun the board comparison against the `main` that results, since the fork numbers predate #793 landing on main.
- The proof follows [the rolled SHA-2 proof quest](/quest/m4/verified/rolled-sha2-esp.md): if the unrolled block lands, that quest proves it instead of the rolled SHA-512 on espidf.

Decision rule: take the placement when the maintainer accepts the free-heap cost for a roughly 9% SHA-512 gain on the board; the gain is real but small, and 19 KB is a large share of an ESP32-S3's heap. If the cost is not accepted, refuse it and delete this quest, since the rolled loop is within 1% of main and #793's reasons for it stand.

## Waiting

- Maintainer: decide the default. Options: (A) take the IRAM placement as the default on `espidf`, with `esp32s3-sha512-flash` as the opt-out; (B) take it behind an opt-in feature, rolled loop by default; (C) refuse it and keep the rolled loop, deleting this quest. Recommendation: B, since the gain is about 9% on SHA-512 rows only and the default would cost every firmware 19,072 B of free heap that most of them do not spend on SHA-512.
- Maintainer: name the free-heap cost you accept for A or B. Options: (A) up to the PR's 19,072 B; (B) up to the 20,480 B IRAM cap but no more heap than the PR measures; (C) a smaller figure, which means shrinking the block before it can land. Recommendation: A, as the PR's measured figure, if the decision above is A or B.
- steelhead99x: rerun the board comparison on the ESP32-S3 after the port, `main` against the port with and without `esp32s3-sha512-flash`, interleaved, and post the cycle table and the free-heap figure here. The fork's numbers predate #793. Recommendation: do it before the maintainer decides.

## Related

- [The rolled SHA-256 and SHA-512 loops on microcontrollers are proven in Lean](/quest/m4/verified/rolled-sha2-esp.md) - proves the code this quest would extend
