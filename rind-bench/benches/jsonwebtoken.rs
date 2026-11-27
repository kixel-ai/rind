//! Per-token cost of each jsonwebtoken provider.
//!
//! jsonwebtoken builds a signer or verifier from the key on every token, so
//! `token` is what a caller pays, and `load` is the part spent on the key.

mod common;

use std::hint::black_box;

use aws_lc_rs::rand::SystemRandom;
use aws_lc_rs::signature::{
    ECDSA_P256_SHA256_FIXED_SIGNING, ECDSA_P384_SHA384_FIXED_SIGNING, EcdsaKeyPair,
    EcdsaSigningAlgorithm, Ed25519KeyPair, KeyPair,
};
use common::Dit;
use jsonwebtoken::crypto::{CryptoProvider, aws_lc};
use jsonwebtoken::{Algorithm, DecodingKey, EncodingKey};

// The header and claims of a typical token, as jsonwebtoken signs them.
const MESSAGE: &[u8] = b"eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb290IjoiZGVtbyIsInB1dCI6WyIiXSwiZ2V0IjpbIiJdLCJleHAiOjE3OTI4MTYwMDAsImlhdCI6MTc2MTI4MDAwMH0";

fn ecdsa(signing: &'static EcdsaSigningAlgorithm) -> (EncodingKey, DecodingKey) {
    let pkcs8 = EcdsaKeyPair::generate_pkcs8(signing, &SystemRandom::new()).unwrap();
    let pair = EcdsaKeyPair::from_pkcs8(signing, pkcs8.as_ref()).unwrap();
    (
        EncodingKey::from_ec_der(pkcs8.as_ref()),
        DecodingKey::from_ec_der(pair.public_key().as_ref()),
    )
}

// Keys in the forms a JWK becomes: PKCS#8 that carries the public key, and
// RSA verified from its modulus and exponent.
fn keys(algorithm: Algorithm) -> (EncodingKey, DecodingKey) {
    match algorithm {
        Algorithm::HS256 => {
            let secret = b"a shared secret of thirty-two by";
            (
                EncodingKey::from_secret(secret).unwrap(),
                DecodingKey::from_secret(secret).unwrap(),
            )
        }
        Algorithm::ES256 => ecdsa(&ECDSA_P256_SHA256_FIXED_SIGNING),
        Algorithm::ES384 => ecdsa(&ECDSA_P384_SHA384_FIXED_SIGNING),
        Algorithm::EdDSA => {
            let ed25519 = Ed25519KeyPair::generate_pkcs8(&SystemRandom::new()).unwrap();
            let public = Ed25519KeyPair::from_pkcs8(ed25519.as_ref())
                .unwrap()
                .public_key()
                .as_ref()
                .to_vec();
            (
                EncodingKey::from_ed_der(ed25519.as_ref()),
                DecodingKey::from_ed_der(&public),
            )
        }
        Algorithm::RS256 => {
            let rsa = include_bytes!("../../rind/src/high/rsa/rsa2048.der");
            let pair = rind::rsa::KeyPair::from_pkcs1(rsa).unwrap();
            let (n, e) =
                (aws_lc::DEFAULT_PROVIDER
                    .key_utils
                    .rsa_pub_components_from_public_key)(pair.public_key().as_ref())
                .unwrap();
            (
                EncodingKey::from_rsa_der(rsa),
                DecodingKey::from_rsa_raw_components(&n, &e),
            )
        }
        _ => unreachable!("no row times {algorithm:?}"),
    }
}

/// A provider, a key pair under one algorithm, and a token's signature by it.
struct Input {
    provider: &'static CryptoProvider,
    algorithm: Algorithm,
    encoding: EncodingKey,
    decoding: DecodingKey,
    signature: Vec<u8>,
}

impl Input {
    fn new(algorithm: Algorithm, provider: &'static CryptoProvider) -> Self {
        let (encoding, decoding) = keys(algorithm);
        let signature = (aws_lc::DEFAULT_PROVIDER.signer_factory)(&algorithm, &encoding)
            .unwrap()
            .try_sign(MESSAGE)
            .unwrap();
        Self {
            provider,
            algorithm,
            encoding,
            decoding,
            signature,
        }
    }

    fn sign_token(&self) -> Vec<u8> {
        let signer = (self.provider.signer_factory)(&self.algorithm, &self.encoding).unwrap();
        signer.try_sign(MESSAGE).unwrap()
    }

    fn sign_load(&self) -> impl Sized + use<> {
        (self.provider.signer_factory)(&self.algorithm, &self.encoding).unwrap()
    }

    fn verify_token(&self) {
        let verifier = (self.provider.verifier_factory)(&self.algorithm, &self.decoding).unwrap();
        verifier.verify(MESSAGE, &self.signature).unwrap();
    }

    fn verify_load(&self) -> impl Sized + use<> {
        (self.provider.verifier_factory)(&self.algorithm, &self.decoding).unwrap()
    }
}

/// The `token` and `load` rows of one step, sign or verify, for each
/// provider. A module named after a provider shadows its crate, so paths in
/// it go through `super`.
macro_rules! rows {
    ($step:ident, $algorithm:ident, $token:ident, $load:ident) => {
        mod $step {
            use super::*;

            mod aws_lc_rs {
                use super::*;
                use swole::bench;

                fn input() -> Input {
                    Input::new(Algorithm::$algorithm, &aws_lc::DEFAULT_PROVIDER)
                }

                #[bench(setup = input)]
                fn token(input: &Input) {
                    black_box(input.$token());
                }

                #[bench(setup = input)]
                fn load(input: &Input) {
                    black_box(input.$load());
                }
            }

            mod rind {
                use super::*;
                use swole::bench;

                fn input() -> Dit<Input> {
                    Dit::hold(Input::new(
                        Algorithm::$algorithm,
                        &rind_jsonwebtoken::DEFAULT_PROVIDER,
                    ))
                }

                #[bench(setup = input)]
                fn token(input: &Dit<Input>) {
                    black_box(input.$token());
                }

                #[bench(setup = input)]
                fn load(input: &Dit<Input>) {
                    black_box(input.$load());
                }
            }
        }
    };
}

rows!(jwt_hs256_sign, HS256, sign_token, sign_load);
rows!(jwt_es256_sign, ES256, sign_token, sign_load);
rows!(jwt_es384_sign, ES384, sign_token, sign_load);
rows!(jwt_eddsa_sign, EdDSA, sign_token, sign_load);
rows!(jwt_rs256_sign, RS256, sign_token, sign_load);
rows!(jwt_hs256_verify, HS256, verify_token, verify_load);
rows!(jwt_es256_verify, ES256, verify_token, verify_load);
rows!(jwt_es384_verify, ES384, verify_token, verify_load);
rows!(jwt_eddsa_verify, EdDSA, verify_token, verify_load);
rows!(jwt_rs256_verify, RS256, verify_token, verify_load);

fn main() {
    swole::main();
}
