// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

/// rind's cryptography for Dart and Flutter, through FFI to the pure-Rust
/// rind library.
///
/// Signatures are in `package:rind/ecdsa.dart`, `package:rind/ed25519.dart`,
/// and `package:rind/rsa.dart`, with RSA-OAEP, each imported under its
/// name. Algorithms only legacy protocols should use are in
/// `package:rind/legacy.dart` and `package:rind/rsa_legacy.dart`.
library;

export 'src/bindings.dart'
    hide
        DecryptingKey,
        EcdsaKeyPair,
        EcdsaPublicKey,
        EcdsaSigningAlgorithm,
        EcdsaVerificationAlgorithm,
        Ed25519KeyPair,
        Ed25519PublicKey,
        EncryptingKey,
        KeySize,
        OaepAlgorithm,
        RsaKeyPair,
        RsaPublicKey,
        RsaSigningAlgorithm,
        RsaVerificationAlgorithm,
        digestMd5,
        digestSha1,
        hkdfSha1,
        hmacSha1,
        oaepSha1,
        pbkdf2HmacSha1,
        pkcs1Min1024Sha1,
        pkcs1Min1024Sha256,
        pkcs1Min1024Sha512,
        pkcs1Min3072Sha384,
        pkcs1Sha1;
export 'src/error.dart';
