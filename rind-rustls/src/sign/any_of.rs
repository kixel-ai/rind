use core::fmt::Write;
use std::sync::Arc;

use rustls::crypto::KeyProvider;
use rustls::pki_types::PrivateKeyDer;
use rustls::sign::SigningKey;

/// A key provider that loads a key with each of its key providers in turn.
///
/// ```rust
/// use rind_rustls::sign;
/// use rustls::crypto::CryptoProvider;
///
/// static KEYS: sign::AnyOf = sign::AnyOf(&[sign::ECDSA_P256, sign::ED25519]);
///
/// # fn main() -> Result<(), rind_rustls::MissingFeature> {
/// let provider = CryptoProvider {
///     key_provider: &KEYS,
///     ..rind_rustls::empty_provider()?
/// };
/// # Ok(())
/// # }
/// ```
#[derive(Debug)]
pub struct AnyOf(pub &'static [&'static dyn KeyProvider]);

impl KeyProvider for AnyOf {
    fn load_private_key(
        &self,
        key_der: PrivateKeyDer<'static>,
    ) -> Result<Arc<dyn SigningKey>, rustls::Error> {
        let mut errors = String::new();
        for provider in self.0 {
            let err = match provider.load_private_key(key_der.clone_key()) {
                Ok(key) => return Ok(key),
                Err(err) => err,
            };
            if !errors.is_empty() {
                errors.push_str("; ");
            }
            match err {
                rustls::Error::General(err) => errors.push_str(&err),
                err => write!(errors, "{err}").unwrap(),
            }
        }
        if errors.is_empty() {
            errors.push_str("no key provider");
        }
        Err(rustls::Error::General(errors))
    }
}
