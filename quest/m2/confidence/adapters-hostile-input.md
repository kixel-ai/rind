# [M] Hostile peer bytes never panic an adapter

## Goal

A fuzz target feeds arbitrary bytes to every place a network peer's data enters rind-rustls, rind-dimpl, and rind-str0m, and none panics, hangs, or allocates without bound. It runs nightly with the other targets, and a crash fails the run. A panic it finds is reproduced and fixed here.

The inputs it covers:
- rind-rustls: TLS 1.2 and 1.3 records, QUIC packets and header-protection samples, key shares for every group including the hybrids and ML-KEM, session tickets, and certificate signatures and public keys;
- rind-dimpl: DTLS 1.2 and 1.3 records, record-number samples, key shares, and the peer certificate whose key verifies a signature;
- rind-str0m: SRTP and SRTCP packets under each profile.

## Plan

Found by the 2026-11-09 API and hostile-input audit, which read the entry points below and found no panic a peer can reach, apart from the `unwrap`s in `rind-rustls/src/aead.rs`, which [moq-dev/rind#572](https://github.com/moq-dev/rind/pull/572) confirmed no peer input reaches. It did not read `rind-str0m/src/dtls.rs` in full. Reading does not hold as the adapters change: [Adapters offer exactly their upstream's API](/quest/m0/adapters/README.md) is about to reshape them, and only a few unit tests feed them malformed input today, each a fixed case such as a one-byte key share or a truncated ticket.

Decided with the maintainer on 2026-11-09:
- Milestone: m2, in the confidence epic ✅ (rejected: redefine m3, move only the security check).

How this differs from its neighbours:
- The existing targets in `fuzz/fuzzer/`, and the two fuzz quests under Related, compare rind's primitives with aws-lc-rs. None links an adapter, so the glue between a protocol library and rind runs under no fuzzer.

The entry points, so none is missed:
- rind-rustls: `MessageDecrypter::decrypt` (`rind-rustls/src/aead.rs:117`, `:164`, `:266`), QUIC's `decrypt_in_place` for packets and headers (`rind-rustls/src/quic.rs:82`, `:158`), `start_and_complete` and `complete` on each group (`rind-rustls/src/kx_group.rs:97`, `kx_group/hybrid.rs:65` and `:105`, `kx_group/mlkem.rs:26` and `:60`), the ticketer's `decrypt` (`rind-rustls/src/ticketer.rs:96`), and `verify_signature` (`rind-rustls/src/verify.rs:181`).
- rind-dimpl: `Cipher::decrypt` (`rind-dimpl/src/suite.rs:81`), `encrypt_sn` (`:181`), `complete` (`rind-dimpl/src/kx.rs:66`), and `verify_signature`, which parses the peer's certificate (`rind-dimpl/src/sign.rs:107`).
- rind-str0m: each cipher's `decrypt` (`rind-str0m/src/srtp.rs:106`, `:199`, `:221`).

Guidance:
- Reach the adapters through the traits their upstreams call, with keys and lengths of the shape upstream derives, so the target survives the adapter API change and reports only what a peer can cause. A length only a direct trait caller could pass is outside the contract; say so in the target rather than fuzzing it.
- Also drive a whole connection: a rustls server and client, and a dimpl one, each on rind's provider, reading fuzzed bytes as the peer's flight. This reaches the same code through upstream's own parsing, which is how a real peer does.
- Where upstream ships a provider with the same entry point, compare results with it, as the existing targets compare with aws-lc-rs: a record rind opens and aws-lc-rs refuses is a finding too.
- A failed open must leave no plaintext in the caller's buffer. Assert it where the trait hands the buffer back.
- Each new target needs its `[[bin]]` in `fuzz/Cargo.toml`. `admin/testing` checks TESTING.md's table against that list, so give the adapters a row or teach it to skip them.
- Seed each corpus from a real handshake and a few sealed records, so the fuzzer starts past the first length check.

## Related

- [Adapter crates' surviving mutants](/quest/m2/confidence/mutants-adapters.md) - tests the adapters' values against upstream's, where this tests their handling of bad input
