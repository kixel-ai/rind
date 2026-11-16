// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

/// RSA signatures and RSA-OAEP encryption, imported `as rsa`.
///
/// Algorithms only legacy protocols should use are in
/// `package:rind/rsa_legacy.dart`.
library;

export 'src/rsa.dart'
    hide
        oaepSha1,
        pkcs1Min1024Sha1,
        pkcs1Min1024Sha256,
        pkcs1Min1024Sha512,
        pkcs1Min3072Sha384,
        pkcs1Sha1;
