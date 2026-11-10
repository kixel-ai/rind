# Adoption beyond MoQ

## Goal

Popular projects that gain from rind's pure-Rust build or its ECC speed, and
whose crypto is less security-critical, can choose rind: through upstream
feature or provider-hook PRs, `rind-*` adapters, and rind packages for other
languages, with whatever rind itself lacks for them planned here too.

## Plan

Decided with the maintainer on 2026-11-04, in a planning interview. Settled;
don't ask again (✅ is the chosen option):

- Milestone: m2 ✅ / m3.
- Targets: rind-str0m, provider-neutral hooks (quinn, opendal), rustls's
  provider list and 0.24, Bun, Python, and Dart ✅. Node, React Native, Go, Java, .NET,
  Swift, Zig, and C libraries are out: they need OpenSSL's breadth or FIPS,
  which [m4](/quest/m4/README.md) holds, and rind wins there only on
  asymmetric ECC.
- opendal needs no quest: it already ships
  `http-transport-reqwest-rustls-no-provider`
  ([apache/opendal#7582](https://github.com/apache/opendal/pull/7582)), which
  the [migration prompt](/MIGRATE.md) can turn on.
- Big names on RustCrypto are marketing wins, since rind is several times
  faster ([BENCHMARKS.md](/BENCHMARKS.md)'s `nixos2`, an i7-8700: RSA-2048
  verify about 4.7x, P-256 sign and ECDH about 5x, ChaCha20-Poly1305 per
  packet about 3x, AES-GCM about 2x). Decided 2026-11-09 (maintainer,
  /quest-unblock): Deno and snow are dropped, Deno because it is
  deprecated and rind-snow by closing
  [#470](https://github.com/moq-dev/rind/pull/470) on purpose.
  Considered and left out: RustFS
  (already links aws-lc-rs), YARA-X, age, Turso, rustic (needs a raw
  Poly1305 API), Kanidm and Servo (forbid AI-written contributions; Servo
  dropped on 2026-11-07 in [#475](https://github.com/moq-dev/rind/pull/475)),
  Arti (security bar), and Bitwarden and Matrix (need wasm).
- Patches and issues to downstream projects: drop them and let projects pull
  rind themselves ✅ (rejected: keep preparing them). The maintainer dropped
  llrt, rusty-s3, librespot, Lemmy, tailscale-rs, and Apache Iggy on
  2026-11-07, and Deno and str0m's upstream fixes on 2026-11-09; Bun and
  rustls's provider list stay.
- No rind-graviola ✅: build it only if big crates use graviola directly.
  None does; every notable graviola user (llrt, rusty-s3, wtx, oxish) picks it
  with an optional feature, and `[patch]` cannot swap in a crate of another
  name, so a `rind` feature beside theirs is the path.
- Upstream PRs, issues, and discussions are outward-facing: each quest
  prepares the change and its text, then asks the maintainer before posting
  ✅ / starting the quest authorizes it. Posts carry the AI marker.
- Core-stack maintainers decline young providers by name
  ([quinn-rs/quinn#2253](https://github.com/quinn-rs/quinn/issues/2253),
  [transact-rs/sqlx#4408](https://github.com/transact-rs/sqlx/issues/4408)),
  so PRs to them are provider-neutral and stand on their own merits.
- Other-language packages live in this workspace as `rind-<consumer>` crates
  released by its CI ✅ / separate repositories; each language gets rind's own
  API and a second package with the popular library's interface ✅.
- rind-rustls's `default_provider()` keeps aws-lc-rs's algorithm list,
  P-521 included ✅ / drop P-521 as ring does (decided 2026-11-05 on
  [#375](https://github.com/moq-dev/rind/pull/375), which has the sizes): it
  is already smaller than aws-lc-rs's provider.
- Whatever these consumers need from rind itself is planned now: the
  WebCrypto set (AES-192, MD5, RSA-OAEP key labels and SPKI export, AES key
  wrap with padding, all landed) and platform coverage. RSA-2048 signing, which JWT's RS256 needs, is level with the
  fastest library on x86_64 in [BENCHMARKS.md](/BENCHMARKS.md).

## Required

- [rustls lists rind-rustls](/quest/m2/adoption/rustls-providers.md) - an entry in rustls's third-party provider list
- [quinn's rustls support works with any provider](/quest/m2/adoption/quinn.md) - quinn-proto stops forcing ring or aws-lc-rs
- [Bun's CryptoHasher takes SHA-3 from rind](/quest/m2/adoption/bun-sha3.md) - SHA-3 in Bun on rind, after the m1 Bun PR
- [pyrind-cryptography on PyPI](/quest/m2/adoption/pyrind-cryptography-pypi.md) - `pip install pyrind-cryptography`, published by release.yml
- [rind for Dart and Flutter](/quest/m2/adoption/rind-dart.md) - the `rind` package on pub.dev
- [rind as a Dart `cryptography` backend](/quest/m2/adoption/rind-dart-cryptography.md) - the `cryptography` package's interface on rind
- [rind-rustls supports rustls 0.24](/quest/m2/adoption/rind-rustls-0.24.md) - a release on 0.24 soon after it ships
- [rustls 0.24 is released](/quest/m2/adoption/rustls-0.24-release.md) - waiting on the release
- [rind replaces ring and aws-lc-rs throughout a binary's tree](/quest/m2/adoption/aws-lc-rs/README.md) - rind-aws-lc-rs, and git-only `ring` and `aws-lc-rs` patch shims
- [rind on every ring or aws-lc-rs target](/quest/m2/adoption/targets/README.md) - a portable backend for every architecture, and a compile-checked wasm32 build, so libraries can go rind-only
