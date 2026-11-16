// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

/// Ed25519 signatures (RFC 8032), imported `as ed25519`.
library;

import 'src/bindings.dart' show Ed25519KeyPair, Ed25519PublicKey;

export 'src/error.dart' show RindError, RindException;

/// An Ed25519 public key.
typedef PublicKey = Ed25519PublicKey;

/// An Ed25519 key pair.
typedef KeyPair = Ed25519KeyPair;
