<h1 align="center">rind-rcgen</h1>
<img width="40%" align="right" src="https://raw.githubusercontent.com/moq-dev/rind/main/admin/logo.png">

[![Latest release](https://img.shields.io/crates/v/rind-rcgen)](https://crates.io/crates/rind-rcgen)
[![Documentation](https://img.shields.io/docsrs/rind-rcgen)](https://docs.rs/rind-rcgen/)

This crate provides a signing key for [rcgen](https://github.com/rustls/rcgen), backed by [rind](https://github.com/moq-dev/rind/), a fork of [Graviola](https://github.com/ctz/graviola/).
It generates and loads ECDSA P-256 and P-384 and Ed25519 keys, and loads RSA keys.

Build rcgen with `default-features = false` so it compiles no other crypto backend.
rcgen then needs each certificate's serial number set explicitly.

```rust
// Refuses a CPU missing a feature rind requires.
rind_rcgen::check()?;

let key = rind_rcgen::KeyPair::generate(&rcgen::PKCS_ECDSA_P256_SHA256)?;

let mut params = rcgen::CertificateParams::new(["localhost".to_string()])?;
params.serial_number = Some(rind_rcgen::serial_number());

let cert = params.self_signed(&key)?;
let key = key.to_pkcs8();
```

rind panics on a CPU missing a feature it requires, so call `rind_rcgen::check()`
before using a `KeyPair`.

License: Apache-2.0 OR ISC OR MIT-0
