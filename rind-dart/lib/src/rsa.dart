// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

part of 'bindings.dart';

/// The modulus size of a generated RSA key.
enum RsaKeySize {
  /// A 2048-bit modulus.
  rsa2048,

  /// A 3072-bit modulus.
  rsa3072,

  /// A 4096-bit modulus.
  rsa4096,

  /// A 6144-bit modulus.
  rsa6144,

  /// An 8192-bit modulus.
  rsa8192,
}

/// An algorithm an [RsaKeyPair] signs with: a padding and a hash.
enum RsaSigningAlgorithm {
  /// RSASSA-PKCS1-v1_5 with SHA-256.
  pkcs1Sha256(0),

  /// RSASSA-PKCS1-v1_5 with SHA-384.
  pkcs1Sha384(1),

  /// RSASSA-PKCS1-v1_5 with SHA-512.
  pkcs1Sha512(2),

  /// RSASSA-PSS with SHA-256, MGF1-SHA-256, and a salt as long as the hash.
  pssSha256(3),

  /// RSASSA-PSS with SHA-384, MGF1-SHA-384, and a salt as long as the hash.
  pssSha384(4),

  /// RSASSA-PSS with SHA-512, MGF1-SHA-512, and a salt as long as the hash.
  pssSha512(5);

  const RsaSigningAlgorithm(this._id);

  final int _id;
}

/// An algorithm an [RsaPublicKey] verifies with: a padding, a hash, and the
/// smallest modulus it accepts.
///
/// Each verifies what the [RsaSigningAlgorithm] of the same name signs, and
/// accepts moduli of 2048 to 8192 bits.
final class RsaVerificationAlgorithm {
  const RsaVerificationAlgorithm._(this._id, this._name);

  final int _id;
  final String _name;

  /// RSASSA-PKCS1-v1_5 with SHA-256.
  static const pkcs1Sha256 = RsaVerificationAlgorithm._(0, 'RSA_PKCS1_SHA256');

  /// RSASSA-PKCS1-v1_5 with SHA-384.
  static const pkcs1Sha384 = RsaVerificationAlgorithm._(1, 'RSA_PKCS1_SHA384');

  /// RSASSA-PKCS1-v1_5 with SHA-512.
  static const pkcs1Sha512 = RsaVerificationAlgorithm._(2, 'RSA_PKCS1_SHA512');

  /// RSASSA-PSS with SHA-256 and a salt as long as the hash.
  static const pssSha256 = RsaVerificationAlgorithm._(3, 'RSA_PSS_SHA256');

  /// RSASSA-PSS with SHA-384 and a salt as long as the hash.
  static const pssSha384 = RsaVerificationAlgorithm._(4, 'RSA_PSS_SHA384');

  /// RSASSA-PSS with SHA-512 and a salt as long as the hash.
  static const pssSha512 = RsaVerificationAlgorithm._(5, 'RSA_PSS_SHA512');

  /// RSASSA-PSS with SHA-256 and a salt of any length.
  static const pssSha256AnySalt = RsaVerificationAlgorithm._(
    6,
    'RSA_PSS_SHA256_ANY_SALT',
  );

  /// RSASSA-PSS with SHA-384 and a salt of any length.
  static const pssSha384AnySalt = RsaVerificationAlgorithm._(
    7,
    'RSA_PSS_SHA384_ANY_SALT',
  );

  /// RSASSA-PSS with SHA-512 and a salt of any length.
  static const pssSha512AnySalt = RsaVerificationAlgorithm._(
    8,
    'RSA_PSS_SHA512_ANY_SALT',
  );

  @override
  String toString() => _name;
}

/// RSASSA-PKCS1-v1_5 with SHA-1, for old signatures.
const rsaPkcs1Sha1 = RsaVerificationAlgorithm._(100, 'RSA_PKCS1_SHA1');

/// RSASSA-PKCS1-v1_5 with SHA-1, for old keys of 1024 bits or more.
const rsaPkcs1Min1024Sha1 = RsaVerificationAlgorithm._(
  101,
  'RSA_PKCS1_1024_SHA1',
);

/// RSASSA-PKCS1-v1_5 with SHA-256, for old keys of 1024 bits or more.
const rsaPkcs1Min1024Sha256 = RsaVerificationAlgorithm._(
  102,
  'RSA_PKCS1_1024_SHA256',
);

/// RSASSA-PKCS1-v1_5 with SHA-512, for old keys of 1024 bits or more.
const rsaPkcs1Min1024Sha512 = RsaVerificationAlgorithm._(
  103,
  'RSA_PKCS1_1024_SHA512',
);

/// RSASSA-PKCS1-v1_5 with SHA-384, for keys of 3072 bits or more only.
const rsaPkcs1Min3072Sha384 = RsaVerificationAlgorithm._(
  104,
  'RSA_PKCS1_3072_SHA384',
);

/// An RSA public key, which verifies with any [RsaVerificationAlgorithm]
/// whose modulus floor it meets.
final class RsaPublicKey extends _Handle {
  RsaPublicKey._(Pointer<Void> pointer)
    : super(pointer, _rsaPublicKeyFinalizer);

  RsaPublicKey._parse(int source, Uint8List bytes, [Uint8List? exponent])
    : this._(_new(source, bytes, exponent ?? Uint8List(0)));

  static Pointer<Void> _new(int source, Uint8List bytes, Uint8List exponent) =>
      _newHandle(
        (out) => _rsaPublicKeyNew(
          source,
          bytes.address,
          bytes.length,
          exponent.address,
          exponent.length,
          out,
        ),
      );

  /// Parses a PKCS#1 `RSAPublicKey`, throwing [RindError.keyRejected] for a
  /// malformed one or a `SubjectPublicKeyInfo`, which
  /// [RsaPublicKey.fromSpki] takes.
  RsaPublicKey(Uint8List der) : this._parse(0, der);

  /// Parses a `SubjectPublicKeyInfo`, throwing [RindError.keyRejected] for a
  /// malformed one or one naming another algorithm.
  RsaPublicKey.fromSpki(Uint8List der) : this._parse(1, der);

  /// Loads a key from its big-endian modulus [n] and exponent [e], as a JWK
  /// carries them, throwing [RindError.keyRejected] for a malformed one.
  RsaPublicKey.fromComponents({required Uint8List n, required Uint8List e})
    : this._parse(2, n, e);

  /// Checks that [signature] is the key's signature of [message] under
  /// [algorithm], throwing [RindError.badSignature] if not, or
  /// [RindError.keyRejected] if the modulus is below [algorithm]'s floor.
  void verify(
    RsaVerificationAlgorithm algorithm,
    Uint8List message,
    Uint8List signature,
  ) {
    _check(
      _rsaPublicKeyVerify(
        _pointer,
        algorithm._id,
        message.address,
        message.length,
        signature.address,
        signature.length,
      ),
    );
  }

  /// The modulus's length in bytes, which is also its signatures' length.
  int get modulusLength => _check(_rsaPublicKeyModulusLen(_pointer));

  /// The key's PKCS#1 `RSAPublicKey` encoding, as [RsaPublicKey.new] takes
  /// it.
  Uint8List get bytes => _export(0);

  /// Encodes the key as a `SubjectPublicKeyInfo`.
  Uint8List toSpki() => _export(1);

  Uint8List _export(int spki) => _output(
    _exportLength,
    (out) => _rsaPublicKeyExport(_pointer, spki, out.address, out.length),
  );
}

/// An RSA key pair.
///
/// Generating a key and signing take milliseconds to seconds, so run them
/// off the UI isolate, as with `Isolate.run`.
final class RsaKeyPair extends _Handle {
  RsaKeyPair._(Pointer<Void> pointer) : super(pointer, _rsaKeyPairFinalizer);

  static Pointer<Void> _parse(int source, Uint8List der) => _native(
    der,
    (bytes) =>
        _newHandle((out) => _rsaKeyPairNew(source, 0, bytes, der.length, out)),
  );

  /// Generates a random key pair of [size].
  RsaKeyPair.generate(RsaKeySize size)
    : this._(
        _newHandle((out) => _rsaKeyPairNew(0, size.index, nullptr, 0, out)),
      );

  /// Parses a PKCS#8 private key, throwing [RindError.keyRejected] for a
  /// malformed one.
  RsaKeyPair.fromPkcs8(Uint8List der) : this._(_parse(1, der));

  /// Parses a PKCS#1 `RSAPrivateKey`, throwing [RindError.keyRejected] for a
  /// malformed one.
  RsaKeyPair.fromPkcs1(Uint8List der) : this._(_parse(2, der));

  /// The public key, which verifies the key pair's signatures.
  late final RsaPublicKey publicKey = RsaPublicKey._(
    _newHandle((out) => _rsaKeyPairPublicKey(_pointer, out)),
  );

  /// Signs [message] with [algorithm].
  Uint8List sign(RsaSigningAlgorithm algorithm, Uint8List message) =>
      _native(message, (input) {
        return _native(Uint8List(_modulusLength), (out) {
          final len = _check(
            _rsaSign(
              _pointer,
              algorithm._id,
              input,
              message.length,
              out,
              _modulusLength,
            ),
          );
          return Uint8List.fromList(out.asTypedList(len));
        });
      });

  /// Encodes the private key as PKCS#8.
  Uint8List toPkcs8() => _output(
    _exportLength,
    (out) => _rsaKeyPairExport(_pointer, 1, out.address, out.length),
  );
}

/// An RSA-OAEP algorithm: its hash, which MGF1 uses too.
final class OaepAlgorithm {
  const OaepAlgorithm._(this._id, this._name);

  final int _id;
  final String _name;

  /// RSA-OAEP with SHA-256.
  static const sha256 = OaepAlgorithm._(0, 'RSA-OAEP-SHA256');

  /// RSA-OAEP with SHA-384.
  static const sha384 = OaepAlgorithm._(1, 'RSA-OAEP-SHA384');

  /// RSA-OAEP with SHA-512.
  static const sha512 = OaepAlgorithm._(2, 'RSA-OAEP-SHA512');

  @override
  String toString() => _name;
}

/// RSA-OAEP with SHA-1, for protocols that still require it.
const oaepSha1 = OaepAlgorithm._(100, 'RSA-OAEP-SHA1');

/// An RSA private key that decrypts RSA-OAEP ciphertexts.
///
/// Generating a key and decrypting take milliseconds to seconds, so run
/// them off the UI isolate, as with `Isolate.run`.
final class RsaDecryptingKey extends _Handle {
  RsaDecryptingKey._(this.algorithm, int source, int size, Uint8List der)
    : super(
        _native(
          der,
          (bytes) => _newHandle(
            (out) => _decryptingKeyNew(
              algorithm._id,
              source,
              size,
              bytes,
              der.length,
              out,
            ),
          ),
        ),
        _decryptingKeyFinalizer,
      );

  /// Generates a random key of [size] for [algorithm].
  RsaDecryptingKey.generate(OaepAlgorithm algorithm, RsaKeySize size)
    : this._(algorithm, 0, size.index, Uint8List(0));

  /// Parses a PKCS#8 private key for [algorithm], throwing
  /// [RindError.keyRejected] for a malformed one.
  RsaDecryptingKey.fromPkcs8(OaepAlgorithm algorithm, Uint8List der)
    : this._(algorithm, 1, 0, der);

  /// Parses a PKCS#1 `RSAPrivateKey` for [algorithm], throwing
  /// [RindError.keyRejected] for a malformed one.
  RsaDecryptingKey.fromPkcs1(OaepAlgorithm algorithm, Uint8List der)
    : this._(algorithm, 2, 0, der);

  /// The algorithm the key decrypts with.
  final OaepAlgorithm algorithm;

  /// The public key, which encrypts to this key.
  late final RsaEncryptingKey publicKey = RsaEncryptingKey._(
    algorithm,
    _newHandle((out) => _decryptingKeyPublicKey(_pointer, out)),
  );

  /// Decrypts [ciphertext] sealed with [label], throwing
  /// [RindError.decryptFailed] if it does not decrypt.
  Uint8List decrypt(Uint8List ciphertext, {Uint8List? label}) {
    label ??= Uint8List(0);
    return _native(ciphertext, (input) {
      return _native(label!, (labelPointer) {
        return _native(Uint8List(_modulusLength), (out) {
          final len = _check(
            _decrypt(
              _pointer,
              input,
              ciphertext.length,
              labelPointer,
              label!.length,
              out,
              _modulusLength,
            ),
          );
          return Uint8List.fromList(out.asTypedList(len));
        });
      });
    });
  }

  /// Encodes the private key as PKCS#8.
  Uint8List toPkcs8() => _output(
    _exportLength,
    (out) => _decryptingKeyExport(_pointer, 1, out.address, out.length),
  );
}

/// An RSA public key that encrypts with RSA-OAEP.
final class RsaEncryptingKey extends _Handle {
  RsaEncryptingKey._(this.algorithm, Pointer<Void> _pointer)
    : super(_pointer, _encryptingKeyFinalizer);

  RsaEncryptingKey._parse(
    this.algorithm,
    int source,
    Uint8List bytes, [
    Uint8List? exponent,
  ]) : super(
         _new(algorithm, source, bytes, exponent ?? Uint8List(0)),
         _encryptingKeyFinalizer,
       );

  static Pointer<Void> _new(
    OaepAlgorithm algorithm,
    int source,
    Uint8List bytes,
    Uint8List exponent,
  ) => _newHandle(
    (out) => _encryptingKeyNew(
      algorithm._id,
      source,
      bytes.address,
      bytes.length,
      exponent.address,
      exponent.length,
      out,
    ),
  );

  /// Parses a PKCS#1 `RSAPublicKey` for [algorithm], throwing
  /// [RindError.keyRejected] for a malformed one, a modulus below 2048 bits,
  /// or a `SubjectPublicKeyInfo`, which [RsaEncryptingKey.fromSpki] takes.
  RsaEncryptingKey(OaepAlgorithm algorithm, Uint8List der)
    : this._parse(algorithm, 0, der);

  /// Parses a `SubjectPublicKeyInfo` for [algorithm], throwing
  /// [RindError.keyRejected] for a malformed one, one naming another
  /// algorithm, or a modulus below 2048 bits.
  RsaEncryptingKey.fromSpki(OaepAlgorithm algorithm, Uint8List der)
    : this._parse(algorithm, 1, der);

  /// Loads a key for [algorithm] from its big-endian modulus [n] and
  /// exponent [e], as a JWK carries them, throwing [RindError.keyRejected]
  /// for a malformed one or a modulus below 2048 bits.
  RsaEncryptingKey.fromComponents(
    OaepAlgorithm algorithm, {
    required Uint8List n,
    required Uint8List e,
  }) : this._parse(algorithm, 2, n, e);

  /// The algorithm the key encrypts with.
  final OaepAlgorithm algorithm;

  /// Encrypts [message] with [label], returning a ciphertext as long as the
  /// modulus, and throwing [RindError.wrongLength] for a message longer
  /// than [maxMessageLength].
  Uint8List encrypt(Uint8List message, {Uint8List? label}) {
    label ??= Uint8List(0);
    return _output(
      _modulusLength,
      (out) => _encrypt(
        _pointer,
        message.address,
        message.length,
        label!.address,
        label.length,
        out.address,
        out.length,
      ),
    );
  }

  /// The longest message the key encrypts, in bytes.
  int get maxMessageLength => _check(_encryptingKeyMaxMessageLen(_pointer));

  /// The key's PKCS#1 `RSAPublicKey` encoding, as [RsaEncryptingKey.new]
  /// takes it.
  Uint8List get bytes => _export(0);

  /// Encodes the key as a `SubjectPublicKeyInfo`.
  Uint8List toSpki() => _export(1);

  Uint8List _export(int spki) => _output(
    _exportLength,
    (out) => _encryptingKeyExport(_pointer, spki, out.address, out.length),
  );
}
