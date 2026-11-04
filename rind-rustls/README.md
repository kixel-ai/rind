<h1 align="center">rind-rustls</h1>
<img width="40%" align="right" src="https://raw.githubusercontent.com/moq-dev/rind/main/admin/logo.png">

[![Latest release](https://img.shields.io/crates/v/rind-rustls)](https://crates.io/crates/rind-rustls)
[![Documentation](https://img.shields.io/docsrs/rind-rustls)](https://docs.rs/rind-rustls/)

This crate provides an integration between [rustls](https://github.com/rustls/rustls) and [rind](https://github.com/moq-dev/rind/), a fork of [Graviola](https://github.com/ctz/graviola/).

Use it like:

```rust
rind_rustls::default_provider()?.install_default().unwrap();
```

And then use rustls as normal.

A binary links only the algorithms its provider names, so one that needs
few fills in `empty_provider()` with just those:

```rust
use rind_rustls::{cipher_suite, kx_group, sign, verify};
use rustls::SignatureScheme;
use rustls::crypto::{CryptoProvider, WebPkiSupportedAlgorithms};

static P256: WebPkiSupportedAlgorithms = WebPkiSupportedAlgorithms {
    all: &[verify::ECDSA_P256_SHA256],
    mapping: &[(
        SignatureScheme::ECDSA_NISTP256_SHA256,
        &[verify::ECDSA_P256_SHA256],
    )],
};

let provider = CryptoProvider {
    cipher_suites: vec![cipher_suite::TLS13_AES_128_GCM_SHA256],
    kx_groups: vec![kx_group::X25519],
    signature_verification_algorithms: P256,
    key_provider: sign::ECDSA_P256,
    ..rind_rustls::empty_provider()?
};
```

rind panics on a CPU missing a feature it requires, so `default_provider()`,
`empty_provider()`, and `Ticketer::new()` check first and return an error
instead. Build any provider from this crate's statics on `empty_provider()`.

License: Apache-2.0 OR ISC OR MIT-0
