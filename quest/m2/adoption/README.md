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
- Targets: graviola-precedent features (llrt, rusty-s3), rind-str0m,
  provider-neutral hooks (quinn, opendal, librespot), rustls's provider list
  and 0.24, Bun, Python, and Dart ✅. Deno is out (maintainer: Deno is
  deprecated). Node, React Native, Go, Java, .NET, Swift, Zig, and C
  libraries are out: they need OpenSSL's breadth or FIPS, which
  [m4](/quest/m4/README.md) holds, and rind wins there only on asymmetric ECC.
- No rind-graviola ✅: build it only if big crates use graviola directly.
  None does; every notable graviola user (llrt, rusty-s3, wtx, oxish) picks it
  with an optional feature, and Cargo cannot patch a renamed dependency, so
  a `rind` feature beside theirs is the path.
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
- Whatever these consumers need from rind itself is planned now: the
  [WebCrypto set](/quest/m2/adoption/webcrypto/README.md), platform coverage,
  and [RSA-2048 speed](/quest/m2/speed/rsa-2048.md) in the speed epic.

## Required

- [rustls lists rind-rustls](/quest/m2/adoption/rustls-providers.md) - an entry in rustls's third-party provider list
- [rusty-s3 offers rind](/quest/m2/adoption/rusty-s3.md) - a `rind` feature beside its `graviola` one
- [rind builds on every platform its packages ship](/quest/m2/adoption/platforms.md) - CI covers aarch64 Windows, musl, iOS, and Android
- [rind-str0m](/quest/m2/adoption/rind-str0m.md) - str0m's `CryptoProvider` on rind
- [quinn's rustls support works with any provider](/quest/m2/adoption/quinn.md) - quinn-proto stops forcing ring or aws-lc-rs
- [Bun runs its fastest asymmetric crypto on rind](/quest/m2/adoption/bun.md) - Ed25519, X25519, P-384, P-521, and SHA-3 in Bun on rind
- [pyrind on PyPI](/quest/m2/adoption/pyrind.md) - rind for Python with its own API
- [What WebCrypto adopters need](/quest/m2/adoption/webcrypto/README.md) - the AES modes, RSA-OAEP, and hashes llrt, pyca users, and Dart need
- [llrt offers rind](/quest/m2/adoption/llrt.md) - `crypto-rind` and `tls-rind` features in AWS's Lambda runtime
- [pyca-compatible pyrind](/quest/m2/adoption/pyrind-cryptography.md) - pyca's `hazmat` names on pyrind
- [Talk to pyca about rind](/quest/m2/adoption/pyca.md) - a discussion with pyca/cryptography's maintainers
- [rind for Dart and Flutter](/quest/m2/adoption/rind-dart.md) - the `rind` package on pub.dev
- [rind as a Dart `cryptography` backend](/quest/m2/adoption/rind-dart-cryptography.md) - the `cryptography` package's interface on rind
- [opendal builds rustls without a provider](/quest/m2/adoption/opendal.md) - a provider-neutral rustls feature
- [librespot builds rustls without ring](/quest/m2/adoption/librespot.md) - users pick their rustls provider
- [rind-rustls supports rustls 0.24](/quest/m2/adoption/rind-rustls-0.24.md) - a release on 0.24 soon after it ships
- [rustls 0.24 is released](/quest/m2/adoption/rustls-0.24-release.md) - waiting on the release
