# [S] rind-dimpl accepts the NIST-curve key shares aws-lc-rs accepts

## Goal

rind-dimpl's P-256 and P-384 key exchanges accept or refuse a peer's share exactly as dimpl's aws-lc-rs provider does, so `fuzz/fuzzer/dimpl.rs`'s `key_share` check passes and the weekly `fuzz` run's `Fuzz dimpl` job is green again.

## Plan

Found on 2026-11-14 by `fuzz.yml`. Both main's scheduled [run 43525080590](https://github.com/kixel-ai/rind/actions/runs/43525080590) and [run 43530778796](https://github.com/kixel-ai/rind/actions/runs/43530778796), dispatched from [kixel-ai/rind#743](https://github.com/kixel-ai/rind/pull/743), fail at `fuzz/fuzzer/dimpl.rs:231` with `Secp384r1`: rind refuses a share that aws-lc-rs accepts (`left: false`, `right: true`). The 23-byte input reproduces it every time with main's x86_64 fuzz binary:

```
09a0ff97fbffffff970100000340002b01db0d250c0c06
```

(`xxd -r -p` rebuilds it). [Run 43647578465](https://github.com/kixel-ai/rind/actions/runs/43647578465), dispatched from the same PR, failed the same check on `Secp256r1` with the 18-byte input `Av9paRCkAHn///cAAP8AAAIK` (base64), so the cause is likely shared by the NIST curves rather than P-384's. Decode which share the input builds before choosing a side. If aws-lc-rs accepts an encoding that rind's own P-384 agreement refuses as hostile, such as a compressed or otherwise non-canonical point, decide by AGENTS.md's rule (follow aws-lc-rs) and by what dimpl's DTLS peers send. If the harness built a share that only one side should see, fix the harness instead. Either way, add the input to the target's seeds so the corpus keeps it.

## Handoff

Groundwork is on this branch. The fix is not. `sh/fuzz-seed.sh` writes both inputs into `fuzz/corpus/dimpl`, and `rind-dimpl/tests/provider.rs`'s `nist_hybrid_key_shares_match_aws_lc` is ignored because it fails: rind refuses the share aws-lc-rs accepts.

Both inputs decode, with arbitrary 1.5.0's `arbitrary_take_rest` as libfuzzer-sys 0.4 calls it, to `Input::KeyShare` with `Share::Edited`. The group byte selects `rind-dimpl`'s `kx::ALL`: `251 % 3 = 2` is `Secp384r1`, `16 % 3 = 1` is `Secp256r1`.

| Input | Edit | Share the harness builds |
| --- | --- | --- |
| `09a0ff97fbffffff970100000340002b01db0d250c0c06` | flips `[(0, 3)]`, cut `0` | aws-lc's fresh P-384 point, 97 bytes, prefix `0x04 ^ 0x03 = 0x07` |
| `Av9paRCkAHn///cAAP8AAAIK` | flips `[(247, 0), (0, 2)]`, cut `0` | aws-lc's fresh P-256 point, 65 bytes, prefix `0x04 ^ 0x02 = 0x06`. Index `247 % 65 = 52` is XORed with 0, so it does not change. |

The share bytes are not in the input. `fuzz/fuzzer/dimpl.rs` builds them by calling aws-lc-rs `start_exchange`, taking `pub_key()` (uncompressed SEC1), then applying that edit. One matching run produced P-384 `07e2c4d91648ead2df995e5e57914a879bca39ee8d38d964457a3de7700e8b0460753377e4863887d9b0c5cc7fb01589a43ddca560a7d5d9969d01a218de4166c787c0b7ecbda136b7c37b7dd4ff3705e5464f6c737c2986162ab18965fecd4447` (`0x07`, `y` odd) and P-256 `063a0cadbebc3cd7a98bba7bd44656a06cb3f035fdbebae96f82d1db844cdc18d80d4f9aac516861ce187c2af6584950d840c5af1dddd627daffd93e99adea59d8` (`0x06`, `y` even). `0x06` and `0x07` are SEC1 hybrid points: the same coordinates as uncompressed, with `y`'s parity also stored in the prefix.

Reproduced with `cargo +nightly fuzz build dimpl` and the x86_64 address-sanitizer binary `target/x86_64-unknown-linux-gnu/release/dimpl`. The assert at `fuzz/fuzzer/dimpl.rs:231` is `left: false, right: true` (`Secp384r1` or `Secp256r1`) exactly when the generated point's `y` parity matches the hybrid prefix. A mismatch makes both sides refuse, so that run stays green. One libFuzzer process often executes the input twice, so most replays crash, which is why the CI input looks reliable. A single execution does not crash every time.

aws-lc-rs 1.19 (`ParsedPublicKey::new` in `aws-lc-rs-1.19.0/src/agreement.rs`) parses `0x06` and `0x07` through `EC_POINT_oct2point`. aws-lc-sys 0.47's `crypto/fipsmodule/ec/oct.c` `ec_point_from_hybrid` accepts them only at the uncompressed length and only when `is_hybrid_bytes_consistent` says the prefix's low bit equals the last byte's low bit, then checks the point is on the curve. rind's `PrivateKey::agree` calls `from_x962_uncompressed`, which returns `KeyFormatError::Compressed` for every prefix other than `0x04` (`rind/src/mid/p256.rs`, `rind/src/mid/p384.rs`). `PublicKey::new` does not save this: `rind/src/high/sec1.rs` refuses a hybrid point on purpose.

The harness is right to show both providers the same bytes. Change rind-dimpl, following AGENTS.md. dimpl does not filter the share first. DTLS 1.3 passes `key_share.entry.key_exchange` to `complete` (`src/dtls13/client.rs`, `src/dtls13/server.rs`), and DTLS 1.2 does the same in `CryptoContext::compute_shared_secret`. Conforming peers send the uncompressed point: RFC 8422 section 5.4.1 and RFC 8446 section 4.2.8. dimpl's own share is the provider's `pub_key()`, which both rind and aws-lc emit as `0x04`. Accepting hybrid does not change that handshake. It matches aws-lc on a hostile share.

Recommended fix, kept to `rind-dimpl/src/kx.rs` `Exchange::complete` so `PrivateKey::agree` stays uncompressed-only. kixel-ai/rind#792 only appends a test module at the end of that file.

- If the share is `0x06` or `0x07`, has the group's uncompressed length, and the prefix's low bit equals `y`'s, copy it, set the prefix to `0x04`, and `agree`.
- If the share is compressed `0x02` or `0x03`, decompress with `agreement::PublicKey::new` and `agree` on that uncompressed point. These two seeds do not build a compressed share, but the same `Edit` can: flip the prefix to `0x02` or `0x03` and cut `y` off. aws-lc accepts that too, and the next fuzz run can fail there.
- Leave every other encoding, including the point at infinity (`0x00`), to `agree`. aws-lc rejects infinity in `EC_KEY_set_public_key`.

Then drop the `#[ignore]` on `nist_hybrid_key_shares_match_aws_lc`. The mismatch half of that test should stay a refusal on both sides.
