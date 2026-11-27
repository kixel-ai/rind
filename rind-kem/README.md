# rind-kem

[RustCrypto](https://github.com/RustCrypto)'s [`kem`](https://crates.io/crates/kem) 0.3 traits on [rind](https://github.com/kixel-ai/rind), so code generic over `Kem`, `Encapsulate` and `Decapsulate` runs on rind by naming a different type. It mirrors RustCrypto's [`ml-kem`](https://crates.io/crates/ml-kem) 0.3: `MlKem512`, `MlKem768` and `MlKem1024`, generic `DecapsulationKey` and `EncapsulationKey`, and the `ml_kem_512`, `ml_kem_768` and `ml_kem_1024` modules' aliases. Each type is a thin wrapper that calls rind: this crate adds no primitive and no encoding.

This crate adapts one upstream, `kem`, and its version begins with that crate's breaking part: a new major of `kem` is a new major of `rind-kem`, and of no other adapter.

```toml
[dependencies]
rind-kem = "0.3"
```

```rust
use kem::{Decapsulate, Decapsulator, Encapsulate, KeyInit};
use rind_kem::ml_kem_768::DecapsulationKey;

let dk = DecapsulationKey::new_from_slice(&[0x42; 64]).unwrap();
// With kem's `getrandom` feature; `encapsulate_with_rng` takes any `CryptoRng`.
let (ciphertext, secret) = dk.encapsulation_key().encapsulate();
assert_eq!(dk.decapsulate(&ciphertext), secret);
```

Keys wipe themselves on drop, as rind's do. `Generate` copies the 64-byte seed it draws into a buffer it wipes once rind holds the key, and `Encapsulate` hands its 32 random bytes to rind's `kem::Message`, which zeroes them.

## What rind cannot back

- `ml-kem`'s inherent methods beyond the traits: expanded decapsulation keys (`from_expanded` and `ExpandedKeyEncoding`, deprecated there), `encapsulate_deterministic` with a caller-chosen message (rind takes one only as a consumed, wiped `kem::Message`, which `Encapsulate` uses), its PKCS#8 and SPKI encodings (its `pkcs8` feature), and serde. Keys come from `KeyInit` with their 64-byte seed or from `Generate`, and `KeyExport` gives the seed back.
