// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

/// RSA signatures and RSA-OAEP encryption, imported `as rsa`.
///
/// Algorithms only legacy protocols should use are in
/// `package:rind/rsa_legacy.dart`.
library;

import 'src/bindings.dart'
    show
        RsaKeyPair,
        RsaPublicKey,
        RsaSigningAlgorithm,
        RsaVerificationAlgorithm;

export 'src/bindings.dart'
    show DecryptingKey, EncryptingKey, KeySize, OaepAlgorithm;
export 'src/error.dart' show RindError, RindException;

/// An RSA signing algorithm: a padding and a hash.
typedef SigningAlgorithm = RsaSigningAlgorithm;

/// An RSA verification algorithm: a padding, a hash, and a modulus floor.
typedef VerificationAlgorithm = RsaVerificationAlgorithm;

/// An RSA public key, which verifies with any algorithm whose floor it meets.
typedef PublicKey = RsaPublicKey;

/// An RSA key pair.
typedef KeyPair = RsaKeyPair;
