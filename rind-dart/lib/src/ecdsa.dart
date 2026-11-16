// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

part of 'bindings.dart';

/// An algorithm an [EcdsaKeyPair] signs with: a curve, a hash, and a
/// signature encoding, ASN.1 DER or fixed-length `r || s`.
enum EcdsaSigningAlgorithm {
  /// ECDSA on P-256 with SHA-256, DER-encoded.
  p256Sha256Asn1(0),

  /// ECDSA on P-256 with SHA-256, fixed-length, as JWS's ES256.
  p256Sha256Fixed(1),

  /// ECDSA on P-384 with SHA-384, DER-encoded.
  p384Sha384Asn1(2),

  /// ECDSA on P-384 with SHA-384, fixed-length, as JWS's ES384.
  p384Sha384Fixed(3),

  /// ECDSA on P-521 with SHA-512, DER-encoded.
  p521Sha512Asn1(4),

  /// ECDSA on P-521 with SHA-512, fixed-length, as JWS's ES512.
  p521Sha512Fixed(5);

  const EcdsaSigningAlgorithm(this._id);

  final int _id;
}

/// An algorithm an [EcdsaPublicKey] verifies with: a curve, a hash, and a
/// signature encoding.
///
/// Each verifies what the [EcdsaSigningAlgorithm] of the same name signs.
enum EcdsaVerificationAlgorithm {
  /// ECDSA on P-256 with SHA-256, DER-encoded.
  p256Sha256Asn1(0),

  /// ECDSA on P-256 with SHA-384, DER-encoded.
  p256Sha384Asn1(1),

  /// ECDSA on P-256 with SHA-512, DER-encoded.
  p256Sha512Asn1(2),

  /// ECDSA on P-384 with SHA-256, DER-encoded.
  p384Sha256Asn1(3),

  /// ECDSA on P-384 with SHA-384, DER-encoded.
  p384Sha384Asn1(4),

  /// ECDSA on P-384 with SHA-512, DER-encoded.
  p384Sha512Asn1(5),

  /// ECDSA on P-521 with SHA-256, DER-encoded.
  p521Sha256Asn1(6),

  /// ECDSA on P-521 with SHA-384, DER-encoded.
  p521Sha384Asn1(7),

  /// ECDSA on P-521 with SHA-512, DER-encoded.
  p521Sha512Asn1(8),

  /// ECDSA on P-256 with SHA-256, fixed-length.
  p256Sha256Fixed(9),

  /// ECDSA on P-384 with SHA-384, fixed-length.
  p384Sha384Fixed(10),

  /// ECDSA on P-521 with SHA-512, fixed-length.
  p521Sha512Fixed(11);

  const EcdsaVerificationAlgorithm(this._id);

  final int _id;
}

/// An ECDSA public key, bound to the one algorithm it verifies with.
final class EcdsaPublicKey extends _Handle {
  EcdsaPublicKey._(Pointer<Void> pointer)
    : super(pointer, _ecdsaPublicKeyFinalizer);

  EcdsaPublicKey._parse(
    EcdsaVerificationAlgorithm algorithm,
    int spki,
    Uint8List bytes,
  ) : this._(
        _newHandle(
          (out) => _ecdsaPublicKeyNew(
            algorithm._id,
            spki,
            bytes.address,
            bytes.length,
            out,
          ),
        ),
      );

  /// Parses an X9.62 uncompressed [point] for [algorithm], throwing
  /// [RindError.keyRejected] for a malformed one, a compressed one, or one
  /// off the curve.
  EcdsaPublicKey(EcdsaVerificationAlgorithm algorithm, Uint8List point)
    : this._parse(algorithm, 0, point);

  /// Parses a `SubjectPublicKeyInfo` for [algorithm], throwing
  /// [RindError.keyRejected] for a malformed one or one naming another
  /// algorithm or curve.
  EcdsaPublicKey.fromSpki(EcdsaVerificationAlgorithm algorithm, Uint8List der)
    : this._parse(algorithm, 1, der);

  /// Checks that [signature] is the key's signature of [message], throwing
  /// [RindError.badSignature] if not.
  void verify(Uint8List message, Uint8List signature) {
    _check(
      _ecdsaPublicKeyVerify(
        _pointer,
        message.address,
        message.length,
        signature.address,
        signature.length,
      ),
    );
  }

  /// The key's X9.62 uncompressed point, as [EcdsaPublicKey.new] takes it.
  Uint8List get bytes => _export(0);

  /// Encodes the key as a `SubjectPublicKeyInfo`.
  Uint8List toSpki() => _export(1);

  Uint8List _export(int spki) => _output(
    _exportLength,
    (out) => _ecdsaPublicKeyExport(_pointer, spki, out.address, out.length),
  );
}

/// An ECDSA key pair, bound to the one algorithm it signs with.
final class EcdsaKeyPair extends _Handle {
  EcdsaKeyPair._(
    this.algorithm,
    int source,
    Uint8List bytes, [
    Uint8List? publicKey,
  ]) : super(
         _new(algorithm, source, bytes, publicKey ?? Uint8List(0)),
         _ecdsaKeyPairFinalizer,
       );

  static Pointer<Void> _new(
    EcdsaSigningAlgorithm algorithm,
    int source,
    Uint8List bytes,
    Uint8List publicKey,
  ) => _newHandle(
    (out) => _ecdsaKeyPairNew(
      algorithm._id,
      source,
      bytes.address,
      bytes.length,
      publicKey.address,
      publicKey.length,
      out,
    ),
  );

  /// Generates a random key pair for [algorithm].
  EcdsaKeyPair.generate(EcdsaSigningAlgorithm algorithm)
    : this._(algorithm, 0, Uint8List(0));

  /// Parses a PKCS#8 private key for [algorithm]'s curve, throwing
  /// [RindError.keyRejected] for a malformed one or one on another curve.
  EcdsaKeyPair.fromPkcs8(EcdsaSigningAlgorithm algorithm, Uint8List der)
    : this._(algorithm, 1, der);

  /// Parses a SEC1 `ECPrivateKey` for [algorithm]'s curve, throwing
  /// [RindError.keyRejected] for a malformed one or one on another curve.
  EcdsaKeyPair.fromSec1(EcdsaSigningAlgorithm algorithm, Uint8List der)
    : this._(algorithm, 2, der);

  /// Loads a fixed-length big-endian [scalar], refused unless [publicKey],
  /// an X9.62 point, is its public key, as a JWK's `d` and `x`/`y` carry
  /// them.
  EcdsaKeyPair.fromScalarAndPublicKey(
    EcdsaSigningAlgorithm algorithm,
    Uint8List scalar,
    Uint8List publicKey,
  ) : this._(algorithm, 3, scalar, publicKey);

  /// The algorithm the key pair signs with.
  final EcdsaSigningAlgorithm algorithm;

  /// The public key, which verifies the key pair's signatures.
  late final EcdsaPublicKey publicKey = EcdsaPublicKey._(
    _newHandle((out) => _ecdsaKeyPairPublicKey(_pointer, out)),
  );

  /// Signs [message].
  Uint8List sign(Uint8List message) => _output(
    _modulusLength,
    (out) => _ecdsaSign(
      _pointer,
      message.address,
      message.length,
      out.address,
      out.length,
    ),
  );

  Uint8List _export(int what) => _output(
    _exportLength,
    (out) => _ecdsaKeyPairExport(_pointer, what, out.address, out.length),
  );

  /// Encodes the private key as PKCS#8.
  Uint8List toPkcs8() => _export(1);

  /// Encodes the private key as a SEC1 `ECPrivateKey`.
  Uint8List toSec1() => _export(2);

  /// The private key's fixed-length big-endian scalar.
  Uint8List toScalar() => _export(3);
}
