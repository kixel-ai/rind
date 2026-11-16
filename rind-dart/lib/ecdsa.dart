// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

/// ECDSA signatures on P-256, P-384, and P-521, imported `as ecdsa`.
library;

import 'src/bindings.dart'
    show
        EcdsaKeyPair,
        EcdsaPublicKey,
        EcdsaSigningAlgorithm,
        EcdsaVerificationAlgorithm;

export 'src/error.dart' show RindError, RindException;

/// An ECDSA signing algorithm: a curve, a hash, and a signature encoding.
typedef SigningAlgorithm = EcdsaSigningAlgorithm;

/// An ECDSA verification algorithm: a curve, a hash, and a signature encoding.
typedef VerificationAlgorithm = EcdsaVerificationAlgorithm;

/// An ECDSA public key, bound to the one algorithm it verifies with.
typedef PublicKey = EcdsaPublicKey;

/// An ECDSA key pair, bound to the one algorithm it signs with.
typedef KeyPair = EcdsaKeyPair;
