//! An [OpenMLS] provider backed by rind, offering exactly the API of
//! [openmls_rust_crypto], which it replaces.
//!
//! [OpenMLS]: https://github.com/openmls/openmls
//! [openmls_rust_crypto]: https://docs.rs/openmls_rust_crypto

// Library code never panics by accident: what can fail returns an error, and
// what cannot states why it holds. Tests may panic (clippy.toml).
#![warn(
    clippy::allow_attributes_without_reason,
    clippy::indexing_slicing,
    clippy::panic,
    clippy::unwrap_used
)]
#![cfg_attr(not(test), warn(clippy::arithmetic_side_effects))]

pub use openmls_memory_storage::{MemoryStorage, MemoryStorageError};
use openmls_traits::OpenMlsProvider;

mod provider;
pub use provider::*;

/// An OpenMLS provider: rind's cryptography and randomness, with in-memory storage.
///
/// `Clone` needs the `test-utils` feature, as upstream's does.
#[derive(Default, Debug)]
#[cfg_attr(feature = "test-utils", derive(Clone))]
pub struct OpenMlsRustCrypto {
    crypto: RustCrypto,
    key_store: MemoryStorage,
}

impl OpenMlsProvider for OpenMlsRustCrypto {
    type CryptoProvider = RustCrypto;
    type RandProvider = RustCrypto;
    type StorageProvider = MemoryStorage;

    fn storage(&self) -> &Self::StorageProvider {
        &self.key_store
    }

    fn crypto(&self) -> &Self::CryptoProvider {
        &self.crypto
    }

    fn rand(&self) -> &Self::RandProvider {
        &self.crypto
    }
}
