use std::fmt;
use std::sync::Arc;

use rind::hpke::{self, Kem, PrivateKey, PublicKey, Recipient, Sender, Suite};
use rustls::crypto::hpke::{
    EncapsulatedSecret, Hpke, HpkeOpener, HpkePrivateKey, HpkePublicKey, HpkeSealer, HpkeSuite,
};
use rustls::internal::msgs::enums::{HpkeAead, HpkeKdf, HpkeKem};
use rustls::internal::msgs::handshake::HpkeSymmetricCipherSuite;
use rustls::{Error, OtherError};

/// Every HPKE suite this crate supports: each KEM with its own hash's KDF
/// and each AEAD, as rustls's aws-lc-rs provider offers them.
pub static ALL_SUPPORTED_SUITES: &[&dyn Hpke] = &[
    DH_KEM_P256_HKDF_SHA256_AES_128,
    DH_KEM_P256_HKDF_SHA256_AES_256,
    DH_KEM_P256_HKDF_SHA256_CHACHA20_POLY1305,
    DH_KEM_P384_HKDF_SHA384_AES_128,
    DH_KEM_P384_HKDF_SHA384_AES_256,
    DH_KEM_P384_HKDF_SHA384_CHACHA20_POLY1305,
    DH_KEM_P521_HKDF_SHA512_AES_128,
    DH_KEM_P521_HKDF_SHA512_AES_256,
    DH_KEM_P521_HKDF_SHA512_CHACHA20_POLY1305,
    DH_KEM_X25519_HKDF_SHA256_AES_128,
    DH_KEM_X25519_HKDF_SHA256_AES_256,
    DH_KEM_X25519_HKDF_SHA256_CHACHA20_POLY1305,
];

macro_rules! suites {
    ($($(#[$doc:meta])* $name:ident: $kem:ident, $kdf:ident, $aead:ident = $rustls_aead:ident;)*) => {
        $(
            $(#[$doc])*
            pub static $name: &dyn Hpke = &RindHpke {
                suite: HpkeSuite {
                    kem: HpkeKem::$kem,
                    sym: HpkeSymmetricCipherSuite {
                        kdf_id: HpkeKdf::$kdf,
                        aead_id: HpkeAead::$rustls_aead,
                    },
                },
                kem: &hpke::$kem,
                rind: Suite {
                    kdf: &hpke::$kdf,
                    aead: &hpke::$aead,
                },
            };
        )*
    };
}

suites! {
    /// DHKEM(P-256, HKDF-SHA256), HKDF-SHA256, and AES-128-GCM.
    DH_KEM_P256_HKDF_SHA256_AES_128: DHKEM_P256_HKDF_SHA256, HKDF_SHA256, AES_128_GCM = AES_128_GCM;
    /// DHKEM(P-256, HKDF-SHA256), HKDF-SHA256, and AES-256-GCM.
    DH_KEM_P256_HKDF_SHA256_AES_256: DHKEM_P256_HKDF_SHA256, HKDF_SHA256, AES_256_GCM = AES_256_GCM;
    /// DHKEM(P-256, HKDF-SHA256), HKDF-SHA256, and ChaCha20-Poly1305.
    DH_KEM_P256_HKDF_SHA256_CHACHA20_POLY1305: DHKEM_P256_HKDF_SHA256, HKDF_SHA256, CHACHA20_POLY1305 = CHACHA20_POLY_1305;
    /// DHKEM(P-384, HKDF-SHA384), HKDF-SHA384, and AES-128-GCM.
    DH_KEM_P384_HKDF_SHA384_AES_128: DHKEM_P384_HKDF_SHA384, HKDF_SHA384, AES_128_GCM = AES_128_GCM;
    /// DHKEM(P-384, HKDF-SHA384), HKDF-SHA384, and AES-256-GCM.
    DH_KEM_P384_HKDF_SHA384_AES_256: DHKEM_P384_HKDF_SHA384, HKDF_SHA384, AES_256_GCM = AES_256_GCM;
    /// DHKEM(P-384, HKDF-SHA384), HKDF-SHA384, and ChaCha20-Poly1305.
    DH_KEM_P384_HKDF_SHA384_CHACHA20_POLY1305: DHKEM_P384_HKDF_SHA384, HKDF_SHA384, CHACHA20_POLY1305 = CHACHA20_POLY_1305;
    /// DHKEM(P-521, HKDF-SHA512), HKDF-SHA512, and AES-128-GCM.
    DH_KEM_P521_HKDF_SHA512_AES_128: DHKEM_P521_HKDF_SHA512, HKDF_SHA512, AES_128_GCM = AES_128_GCM;
    /// DHKEM(P-521, HKDF-SHA512), HKDF-SHA512, and AES-256-GCM.
    DH_KEM_P521_HKDF_SHA512_AES_256: DHKEM_P521_HKDF_SHA512, HKDF_SHA512, AES_256_GCM = AES_256_GCM;
    /// DHKEM(P-521, HKDF-SHA512), HKDF-SHA512, and ChaCha20-Poly1305.
    DH_KEM_P521_HKDF_SHA512_CHACHA20_POLY1305: DHKEM_P521_HKDF_SHA512, HKDF_SHA512, CHACHA20_POLY1305 = CHACHA20_POLY_1305;
    /// DHKEM(X25519, HKDF-SHA256), HKDF-SHA256, and AES-128-GCM.
    DH_KEM_X25519_HKDF_SHA256_AES_128: DHKEM_X25519_HKDF_SHA256, HKDF_SHA256, AES_128_GCM = AES_128_GCM;
    /// DHKEM(X25519, HKDF-SHA256), HKDF-SHA256, and AES-256-GCM.
    DH_KEM_X25519_HKDF_SHA256_AES_256: DHKEM_X25519_HKDF_SHA256, HKDF_SHA256, AES_256_GCM = AES_256_GCM;
    /// DHKEM(X25519, HKDF-SHA256), HKDF-SHA256, and ChaCha20-Poly1305.
    DH_KEM_X25519_HKDF_SHA256_CHACHA20_POLY1305: DHKEM_X25519_HKDF_SHA256, HKDF_SHA256, CHACHA20_POLY1305 = CHACHA20_POLY_1305;
}

struct RindHpke {
    suite: HpkeSuite,
    kem: &'static Kem,
    rind: Suite,
}

impl RindHpke {
    fn sender(&self, info: &[u8], pub_key: &HpkePublicKey) -> Result<(EncapsulatedSecret, Sealer), Error> {
        let public_key = PublicKey::new(self.kem, &pub_key.0).map_err(other)?;
        let (enc, sender) = Sender::new(self.rind, &public_key, info).map_err(other)?;
        Ok((EncapsulatedSecret(enc.as_ref().to_vec()), Sealer(sender)))
    }

    fn recipient(
        &self,
        enc: &EncapsulatedSecret,
        info: &[u8],
        secret_key: &HpkePrivateKey,
    ) -> Result<Opener, Error> {
        let private_key = PrivateKey::from_scalar(self.kem, secret_key.secret_bytes()).map_err(other)?;
        let recipient = Recipient::new(self.rind, &private_key, &enc.0, info).map_err(other)?;
        Ok(Opener(recipient))
    }
}

impl Hpke for RindHpke {
    fn seal(
        &self,
        info: &[u8],
        aad: &[u8],
        plaintext: &[u8],
        pub_key: &HpkePublicKey,
    ) -> Result<(EncapsulatedSecret, Vec<u8>), Error> {
        let (enc, mut sealer) = self.sender(info, pub_key)?;
        Ok((enc, sealer.seal(aad, plaintext)?))
    }

    fn setup_sealer(
        &self,
        info: &[u8],
        pub_key: &HpkePublicKey,
    ) -> Result<(EncapsulatedSecret, Box<dyn HpkeSealer + 'static>), Error> {
        let (enc, sealer) = self.sender(info, pub_key)?;
        Ok((enc, Box::new(sealer)))
    }

    fn open(
        &self,
        enc: &EncapsulatedSecret,
        info: &[u8],
        aad: &[u8],
        ciphertext: &[u8],
        secret_key: &HpkePrivateKey,
    ) -> Result<Vec<u8>, Error> {
        self.recipient(enc, info, secret_key)?
            .open(aad, ciphertext)
    }

    fn setup_opener(
        &self,
        enc: &EncapsulatedSecret,
        info: &[u8],
        secret_key: &HpkePrivateKey,
    ) -> Result<Box<dyn HpkeOpener + 'static>, Error> {
        Ok(Box::new(self.recipient(enc, info, secret_key)?))
    }

    fn generate_key_pair(&self) -> Result<(HpkePublicKey, HpkePrivateKey), Error> {
        let private_key = PrivateKey::generate(self.kem).map_err(other)?;
        let public_key = HpkePublicKey(private_key.public_key().as_ref().to_vec());
        let private_key = HpkePrivateKey::from(private_key.to_scalar().as_ref().to_vec());
        Ok((public_key, private_key))
    }

    fn suite(&self) -> HpkeSuite {
        self.suite
    }
}

impl fmt::Debug for RindHpke {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.suite.fmt(f)
    }
}

#[derive(Debug)]
struct Sealer(Sender);

impl HpkeSealer for Sealer {
    fn seal(&mut self, aad: &[u8], plaintext: &[u8]) -> Result<Vec<u8>, Error> {
        let mut in_out = plaintext.to_vec();
        self.0
            .seal_in_place_append_tag(aad, &mut in_out)
            .map_err(other)?;
        Ok(in_out)
    }
}

#[derive(Debug)]
struct Opener(Recipient);

impl HpkeOpener for Opener {
    fn open(&mut self, aad: &[u8], ciphertext: &[u8]) -> Result<Vec<u8>, Error> {
        let mut in_out = ciphertext.to_vec();
        let len = self
            .0
            .open_in_place(aad, &mut in_out)
            .map_err(other)?
            .len();
        in_out.truncate(len);
        Ok(in_out)
    }
}

/// As rustls's aws-lc-rs provider reports its HPKE errors.
fn other(err: rind::Error) -> Error {
    Error::Other(OtherError(Arc::new(err)))
}
