# [S] ML-KEM encapsulates from a caller-supplied message

## Goal

A caller whose interface hands it the random source, such as the KEM traits' `encapsulate_with_rng`, or a test that replays known-answer vectors, encapsulates ML-KEM with 32 random bytes it supplies, through `rind::kem`'s public API, and the shared secret is FIPS 203's for that message, byte for byte. Nothing changes for the caller that encapsulates with the system random source.

## Plan

`rind::kem` draws ML-KEM's 32-byte message from the system source with no way to supply it. An adapter that ignored the caller's RNG would silently drop the randomness the caller chose, so [rind implements RustCrypto's traits](/quest/m2/rustcrypto/traits.md) cannot honestly implement `kem` 0.3's `Encapsulate`, and a known-answer replay through the public API is impossible. [kixel-ai/rind#896](https://github.com/kixel-ai/rind/pull/896) holds that quest's claim and lists the KEM traits; this quest does not touch its adapters.

[steelhead99x/rind#162](https://github.com/steelhead99x/rind/pull/162) (`claude/kem-supplied-message`, a fork PR) carries the work. Its measured and tested results: Wycheproof's and ACVP's ML-KEM encapsulation vectors pass through the public type for all three sets; aws-lc-rs decapsulates what a supplied message encapsulates; a dropped `Message` is zero in every byte (`rind/tests/zeroing.rs`); `admin/ctgrind unit --release -- high::kem` runs 18 tests with 0 errors under valgrind; `admin/mutants --in-diff` found one missed mutant (`Debug for Message`), killed by a test added afterwards; and its strict gate (`CI_STRICT=1`) passed. A review by a model other than the writer scored it 9.5/10 with no High or Medium finding.

The decision, with the rejected alternatives:

- Add one public type, `kem::Message`, in the shape the repo already uses for caller-supplied secret randomness (`ed25519::Seed`, `ml_dsa::Seed`, `vrf::Seed`, X-Wing's `Seed<A>`): a newtype that wipes on drop ✅ (rejected: the three below).
  - `Message::from_random_bytes(&mut [u8; 32])` takes fresh random bytes and zeroes the caller's array, so the caller keeps no copy to reuse.
  - `Message::encapsulate(self, &EncapsulationKey<A>)` consumes the message, so one message is used once. The type has no `Clone`, `Copy`, `Default`, or public bytes, and its `Debug` prints none.
  - Its docs say the bytes must be fresh, uniform, from a CSPRNG, and never reused, guessable, or attacker-chosen, because the secret derives from them; the type cannot check that.
  - `EncapsulationKey::encapsulate` stays the one way to encapsulate with the system source. `Message` is a value the caller holds, not a second method on the key, and it is not a shim: nothing could do its job without it.
  - Only the public `Message` wipes on drop. `mid::mlkem::Message` stays unwiped, so the message `encapsulate` draws is an unwiped stack temporary, as REVIEW.md says, and `Message::encapsulate` copies its 32 bytes into that type for the call.
- Rejected, so don't raise them again without new evidence:
  - Breaking `encapsulate` to take a random source or a `Message` each call, which is what `quest context`'s "make the breaking change to `foo`" would mean. Every caller that wants the system source then builds one by hand, it breaks `rind-rustls`, `rind-openmls`, `rind-aws-lc-rs`, and the benches for the sake of one adapter, and it makes `rind::rng::RandomSource` public.
  - `EncapsulationKey::encapsulate_with_message(&[u8; 32])`. It is the `foo_with_x` form `quest context` forbids, and a borrowed array can be reused, logged, or kept, so the secret is easy to repeat by accident.
  - Leaving the KEM traits out of the RustCrypto adapter and deleting that line of its quest. The adapter then cannot serve generic code over `kem`, which is what the quest is for.
- No existing public or crate-visible seam does the job: `mid::mlkem`'s `encaps_internal` is `pub(crate)`, and a feature or `doc(hidden)` export of it would be the same second entry point with fewer guards.
- X-Wing's derandomized encapsulation takes a 64-byte seed and HPKE derives its keys separately, so neither reuses this 32-byte type; it stays ML-KEM's.
- It is additive and adds no wire change, so no `!`.

Decision rule, by which the work is taken or refused:

- Take it if the maintainer picks option A under Waiting: land #162's `Message` as its own quest PR, with its tests: the vectors for all three sets, same message and key giving the same ciphertext and secret and another message not, aws-lc-rs decapsulating the result, the zeroing test, and `admin/ctgrind` marking the message secret. The traits quest's `rind-kem` then calls `Message::from_random_bytes(&mut m).encapsulate(&key)` on the bytes the trait's `CryptoRng` fills.
- Refuse it, delete this quest, and delete the KEM traits line from [rind implements RustCrypto's traits](/quest/m2/rustcrypto/traits.md) if the maintainer picks D: with no way to supply the message, `rind-kem` cannot honestly implement the trait.
- B or C replace the type with the form chosen; the tests above carry over to it unchanged.

## Waiting

- Maintainer: how `rind::kem` accepts a caller's ML-KEM message, which `kem` 0.3's `Encapsulate::encapsulate_with_rng` needs and the review of the fork draft finds close to the `foo_with_x` rule. Options: (A) a public `rind::kem::Message` newtype (32 secret bytes, wiped on drop, no `Clone` or `Copy`, consumed by `Message::encapsulate(key)`), with `EncapsulationKey::encapsulate()` unchanged, additive; (B) `EncapsulationKey::encapsulate_with_message(&[u8; 32])`, which `quest context` forbids and which leaves reuse and kept copies easy; (C) a breaking change to `encapsulate` to take a random-source handle, which breaks rind-rustls, rind-openmls, and rind-aws-lc-rs and makes `rind::rng::RandomSource` public; (D) leave the KEM traits out of the adapter and delete that line of the traits quest. Recommendation: A, because it is additive, one-use, and wiped, and is the only option that serves the trait without a breaking change. The owner has chosen A. Done when this item is removed and the PR merges.
- Maintainer: the route. Options: (A) land this quest first, as its own small PR; (B) land it with the adapter work under #896's claim. Recommendation: A, since it is a public API addition that deserves its own review and #896's adapters need it only for the `kem-0_3` family.

## Related

- [rind implements RustCrypto's traits](/quest/m2/rustcrypto/traits.md) - the consumer, `rind-kem`'s `Encapsulate::encapsulate_with_rng`
