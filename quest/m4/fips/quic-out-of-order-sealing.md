# [M] The FIPS module seals QUIC packets in any order

## Goal

A FIPS build of rind-rustls seals QUIC packets in whatever order concurrent `&self` callers reach it, as rustls's aws-lc-rs provider does, through a `rind-fips` module service that builds each nonce itself, so a packet number sealed before a lower one no longer fails with `EncryptError`. No nonce is ever used twice under a key, and the module's state for it is bounded. This is separate from [m3's QUIC packet path](/quest/m3/quic-path.md), which is about AES-GCM speed on AMD CPUs and has nothing to do with sealing order.

## Plan

[FIPS builds of rind-rustls and rind-aws-lc-rs](/quest/m4/fips/adapters.md) maps a QUIC packet number `n` to the TLS record sequence `2^63 | n`, so it can use `TlsRecordSealingKey`, which seals a record only if its sequence number is above the last one's (`rind-fips/README.md`, "AES-GCM IVs"). Sealing packet `n + 1` before `n`, which concurrent `&self` sealing does, then fails in a FIPS build where the aws-lc-rs provider seals.

[steelhead99x/rind#216](https://github.com/steelhead99x/rind/pull/216) (`claude/fips-quic-out-of-order`, a fork PR stacked on [steelhead99x/rind#157](https://github.com/steelhead99x/rind/pull/157)) carries the work, decided by the owner on 2026-11-19: a module service, not accept-and-document.

- New module service `rind_fips_quic_sealing_key_new` and `rind_fips_quic_seal`, exposed as `rind_fips::aead::quic::PacketSealingKey`. The module takes the packet protection IV at key creation and builds each nonce itself (IV XOR packet number, RFC 9001 section 5.3), so the caller never supplies a nonce.
- It keeps the highest packet number sealed and a 1024-bit bitmap of which of the 1024 numbers ending there were sealed: 136 bytes of state, wiped on drop like the key. A repeat, or a number 1024 or more below the highest, fails with `MessageLimitReached` and zeroes the buffer. Anything else, in any order, seals. A key update makes a new key with fresh state.
- Nonce uniqueness is unchanged: XOR with a fixed IV is one-to-one on all of `u64`, and the module seals each packet number at most once per key, so no nonce is used twice under a key. SP 800-38D 8.2.1 requires the invocation field to be unique, not monotonic.
- rind-rustls's `ModulePacketKey` seals through it and the `2^63` priming hack is gone. Every `u64` is still accepted as a first packet number. `TlsRecordSealingKey` is untouched.

Measured and tested in #216: `quic_packet_sealing_key_seals_out_of_order_as_rind_does` (rind's bytes exactly, out of order, repeats and far-below numbers refused with the buffer zeroed, packet numbers 0, 2^40, 2^62, and `u64::MAX`) and `quic_packet_sealing_key_window_slides` in `rind-fips/tests/aes.rs`; `quic_packets_seal_out_of_order_as_aws_lc_rs_does` in `rind-rustls/tests/fips.rs` (pn + 1 before pn and reversed runs from six starting numbers equal rustls's aws-lc-rs provider byte for byte, and under `fips` each repeat is refused); `rind-rustls`'s allocation test passes natively and under Intel SDE on every tier; `admin/ctgrind fips` finds 0 errors with the new seal under a secret key and plaintext. A review by a model other than the writer scored it 9.6/10 with no High or Medium finding. Its strict gate passed every module except `site`, which timed out on a browser check at a load average of about 35 and passed at an earlier head. Not run: aarch64, and a test that reads the module's freed heap block for the wipe (no test hook into the module's allocator).

What is not settled is FIPS honesty. IG C.H's scenario 5 names TLS 1.3's monotonic sequence and does not name QUIC. This service is module-managed uniqueness enforcement with the module constructing the nonce, as scenario 5's module-managed counter does, but the enforcement is a bounded replay window, not a counter. Whether a CMVP lab accepts that reading is for the lab. rind has no lab contract today ([the scope](/quest/m4/fips/README.md) dropped it until a consumer funds one), so the reading is recorded, not tested.

Decision rule, by which the work is taken or refused:

- Take it if the maintainer accepts the bounded replay window as a reading of IG C.H for QUIC, and the quest [FIPS builds of rind-rustls and rind-aws-lc-rs](/quest/m4/fips/adapters.md) has landed: out-of-order sealing is what rustls's aws-lc-rs FIPS provider does, so a provider that refuses it is not a swap.
- Refuse it, and have rind-rustls's FIPS provider document that QUIC packets must be sealed in increasing order, if the maintainer holds that only a counter satisfies scenario 5: the window's extra state is then a compliance risk that outweighs the ordering failure.
- Either way, `TlsRecordSealingKey` and the TLS path stay as they are.

## Waiting

- Maintainer: whether a bounded replay window counts as module-managed uniqueness enforcement for QUIC under IG C.H. Options: (A) accept it as written, the module builds each nonce and refuses a repeat or a number 1024 below the highest; (B) ask a CMVP lab first, once one is engaged; (C) refuse it and keep QUIC sealing in increasing order only, documented in rind-rustls's README. Recommendation: A, because the nonce is unique by construction and the module builds it, so the risk is a lab's reading and not a nonce reuse, and C makes the FIPS provider differ from aws-lc-rs's for every concurrent sender.
- Maintainer: where the work lands. Options: (A) its own PR after the rind-rustls FIPS quest, whose `TlsRecordSealingKey` mapping it replaces; (B) folded into that quest's claim ([kixel-ai/rind#873](https://github.com/kixel-ai/rind/pull/873)). Recommendation: A, since it adds a module service and an ABI entry the lab-facing review should see on their own.

## Required

- [FIPS builds of rind-rustls and rind-aws-lc-rs](/quest/m4/fips/adapters.md) - the FIPS provider and the `2^63 | n` mapping this replaces

## Related

- [rind builds a FIPS 140-3 module ready for validation](/quest/m4/fips/README.md) - the module's scope and its IV rules
