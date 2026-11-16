// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

part of 'bindings.dart';

/// An Ed25519 public key.
final class Ed25519PublicKey extends _Handle {
  Ed25519PublicKey._(Pointer<Void> pointer)
    : super(pointer, _ed25519PublicKeyFinalizer);

  Ed25519PublicKey._parse(int spki, Uint8List bytes)
    : this._(
        _newHandle(
          (out) => _ed25519PublicKeyNew(spki, bytes.address, bytes.length, out),
        ),
      );

  /// Parses a key's 32 [bytes], throwing [RindError.keyRejected] for
  /// another length, a point off the curve, or one of small order.
  Ed25519PublicKey(Uint8List bytes) : this._parse(0, bytes);

  /// Parses a `SubjectPublicKeyInfo`, throwing [RindError.keyRejected] for a
  /// malformed one or one naming another algorithm.
  Ed25519PublicKey.fromSpki(Uint8List der) : this._parse(1, der);

  /// Checks that [signature] is the key's signature of [message], throwing
  /// [RindError.badSignature] if not.
  void verify(Uint8List message, Uint8List signature) {
    _check(
      _ed25519PublicKeyVerify(
        _pointer,
        message.address,
        message.length,
        signature.address,
        signature.length,
      ),
    );
  }

  /// The key's 32 bytes, as [Ed25519PublicKey.new] takes them.
  Uint8List get bytes => _export(0);

  /// Encodes the key as a `SubjectPublicKeyInfo`.
  Uint8List toSpki() => _export(1);

  Uint8List _export(int spki) => _output(
    _exportLength,
    (out) => _ed25519PublicKeyExport(_pointer, spki, out.address, out.length),
  );
}

/// An Ed25519 key pair.
final class Ed25519KeyPair extends _Handle {
  Ed25519KeyPair._(int source, Uint8List bytes, [Uint8List? publicKey])
    : super(
        _new(source, bytes, publicKey ?? Uint8List(0)),
        _ed25519KeyPairFinalizer,
      );

  static Pointer<Void> _new(int source, Uint8List bytes, Uint8List publicKey) =>
      _newHandle(
        (out) => _ed25519KeyPairNew(
          source,
          bytes.address,
          bytes.length,
          publicKey.address,
          publicKey.length,
          out,
        ),
      );

  /// Generates a random key pair.
  Ed25519KeyPair.generate() : this._(0, Uint8List(0));

  /// Parses a PKCS#8 v1 or v2 private key, throwing [RindError.keyRejected]
  /// for a malformed one.
  Ed25519KeyPair.fromPkcs8(Uint8List der) : this._(1, der);

  /// Loads a key pair from its 32-byte seed.
  Ed25519KeyPair.fromSeed(Uint8List seed) : this._(2, seed);

  /// Loads a key pair from its 32-byte seed, refused unless [publicKey] is
  /// its public key.
  Ed25519KeyPair.fromSeedAndPublicKey(Uint8List seed, Uint8List publicKey)
    : this._(3, seed, publicKey);

  /// The public key, which verifies the key pair's signatures.
  late final Ed25519PublicKey publicKey = Ed25519PublicKey._(
    _newHandle((out) => _ed25519KeyPairPublicKey(_pointer, out)),
  );

  /// Signs [message].
  Uint8List sign(Uint8List message) => _output(
    64,
    (out) => _ed25519Sign(
      _pointer,
      message.address,
      message.length,
      out.address,
      out.length,
    ),
  );

  Uint8List _export(int what) => _output(
    _exportLength,
    (out) => _ed25519KeyPairExport(_pointer, what, out.address, out.length),
  );

  /// Encodes the private key as PKCS#8 v2, with its public key.
  Uint8List toPkcs8() => _export(1);

  /// Encodes the private key as PKCS#8 v1, without its public key.
  Uint8List toPkcs8v1() => _export(2);

  /// The private key's 32-byte seed.
  Uint8List toSeed() => _export(3);
}

// --- Native functions ---

@Native<_Free>(symbol: 'rind_dart_ed25519_key_pair_free')
external void _ed25519KeyPairFree(Pointer<Void> pair);
final _ed25519KeyPairFinalizer = _finalizer(
  Native.addressOf(_ed25519KeyPairFree),
);

@Native<
  IntPtr Function(
    Uint32,
    Pointer<Uint8>,
    Size,
    Pointer<Uint8>,
    Size,
    Pointer<Pointer<Void>>,
  )
>(symbol: 'rind_dart_ed25519_key_pair_new', isLeaf: true)
external int _ed25519KeyPairNew(
  int source,
  Pointer<Uint8> bytes,
  int bytesLen,
  Pointer<Uint8> publicKey,
  int publicKeyLen,
  Pointer<Pointer<Void>> out,
);

@Native<
  IntPtr Function(Pointer<Void>, Pointer<Uint8>, Size, Pointer<Uint8>, Size)
>(symbol: 'rind_dart_ed25519_sign', isLeaf: true)
external int _ed25519Sign(
  Pointer<Void> pair,
  Pointer<Uint8> message,
  int messageLen,
  Pointer<Uint8> out,
  int outLen,
);

@Native<IntPtr Function(Pointer<Void>, Uint32, Pointer<Uint8>, Size)>(
  symbol: 'rind_dart_ed25519_key_pair_export',
  isLeaf: true,
)
external int _ed25519KeyPairExport(
  Pointer<Void> pair,
  int what,
  Pointer<Uint8> out,
  int outLen,
);

@Native<IntPtr Function(Pointer<Void>, Pointer<Pointer<Void>>)>(
  symbol: 'rind_dart_ed25519_key_pair_public_key',
  isLeaf: true,
)
external int _ed25519KeyPairPublicKey(
  Pointer<Void> pair,
  Pointer<Pointer<Void>> out,
);

@Native<_Free>(symbol: 'rind_dart_ed25519_public_key_free')
external void _ed25519PublicKeyFree(Pointer<Void> key);
final _ed25519PublicKeyFinalizer = _finalizer(
  Native.addressOf(_ed25519PublicKeyFree),
);

@Native<IntPtr Function(Uint32, Pointer<Uint8>, Size, Pointer<Pointer<Void>>)>(
  symbol: 'rind_dart_ed25519_public_key_new',
  isLeaf: true,
)
external int _ed25519PublicKeyNew(
  int spki,
  Pointer<Uint8> bytes,
  int bytesLen,
  Pointer<Pointer<Void>> out,
);

@Native<
  IntPtr Function(Pointer<Void>, Pointer<Uint8>, Size, Pointer<Uint8>, Size)
>(symbol: 'rind_dart_ed25519_public_key_verify', isLeaf: true)
external int _ed25519PublicKeyVerify(
  Pointer<Void> key,
  Pointer<Uint8> message,
  int messageLen,
  Pointer<Uint8> signature,
  int signatureLen,
);

@Native<IntPtr Function(Pointer<Void>, Uint32, Pointer<Uint8>, Size)>(
  symbol: 'rind_dart_ed25519_public_key_export',
  isLeaf: true,
)
external int _ed25519PublicKeyExport(
  Pointer<Void> key,
  int spki,
  Pointer<Uint8> out,
  int outLen,
);
