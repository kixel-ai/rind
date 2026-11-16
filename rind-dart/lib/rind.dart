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
    hide digestMd5, digestSha1, hkdfSha1, hmacSha1, pbkdf2HmacSha1;
export 'src/error.dart';
