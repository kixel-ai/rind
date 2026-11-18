// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

part of 'cryptography.dart';

final class _Hkdf extends Hkdf {
  _Hkdf(this.hmac, this.outputLength)
    : _algorithm = _hkdfOf(hmac.hashAlgorithm),
      super.constructor() {
    // HKDF's counter is one byte, so it expands at most 255 blocks.
    final max = 255 * hmac.hashAlgorithm.hashLengthInBytes;
    RangeError.checkValueInInterval(outputLength, 1, max, 'outputLength');
  }

  @override
  final Hmac hmac;

  @override
  final int outputLength;

  final rind.HkdfAlgorithm _algorithm;

  static rind.HkdfAlgorithm _hkdfOf(HashAlgorithm algorithm) =>
      switch (algorithm) {
        Sha1() => rind.hkdfSha1,
        Sha256() => rind.HkdfAlgorithm.sha256,
        Sha384() => rind.HkdfAlgorithm.sha384,
        Sha512() => rind.HkdfAlgorithm.sha512,
        _ => throw _unsupported('HKDF over $algorithm'),
      };

  @override
  Future<SecretKeyData> deriveKey({
    required SecretKey secretKey,
    List<int> nonce = const <int>[],
    List<int> info = const <int>[],
  }) async {
    final prk = rind.HkdfSalt(
      _algorithm,
      _bytes(nonce),
    ).extract(_bytes(await secretKey.extractBytes()));
    return SecretKeyData(
      prk.expand([_bytes(info)], outputLength),
      overwriteWhenDestroyed: true,
    );
  }
}

final class _Pbkdf2 extends Pbkdf2 {
  _Pbkdf2(this.macAlgorithm, this.iterations, this.bits)
    : _algorithm = _pbkdf2Of(macAlgorithm),
      super.constructor() {
    RangeError.checkValueInInterval(iterations, 1, 0xffffffff, 'iterations');
    if (bits < 1) throw RangeError.range(bits, 1, null, 'bits');
  }

  @override
  final MacAlgorithm macAlgorithm;

  @override
  final int iterations;

  @override
  final int bits;

  final rind.Pbkdf2Algorithm _algorithm;

  static rind.Pbkdf2Algorithm _pbkdf2Of(MacAlgorithm algorithm) {
    if (algorithm is! Hmac) throw _unsupported('PBKDF2 over $algorithm');
    return switch (algorithm.hashAlgorithm) {
      Sha1() => rind.pbkdf2HmacSha1,
      Sha256() => rind.Pbkdf2Algorithm.hmacSha256,
      Sha384() => rind.Pbkdf2Algorithm.hmacSha384,
      Sha512() => rind.Pbkdf2Algorithm.hmacSha512,
      _ => throw _unsupported('PBKDF2 over $algorithm'),
    };
  }

  @override
  Future<SecretKey> deriveKey({
    required SecretKey secretKey,
    required List<int> nonce,
  }) async {
    final secret = rind.Pbkdf2Secret(
      _algorithm,
      _bytes(await secretKey.extractBytes()),
    );
    // A partial last byte is kept whole, as the Dart implementation does.
    final derived = secret.derive(iterations, _bytes(nonce), (bits + 7) ~/ 8);
    return SecretKeyData(derived, overwriteWhenDestroyed: true);
  }
}

final class _Argon2id extends Argon2id {
  _Argon2id(this.memory, this.parallelism, this.iterations, this.hashLength)
    : super.constructor() {
    RangeError.checkValueInInterval(hashLength, 4, 0xffffffff, 'hashLength');
    // Builds the cost once here only to refuse a bad one where it is
    // constructed, as the package does.
    try {
      rind.Argon2Params(memory, iterations, parallelism);
    } on rind.RindException catch (e) {
      if (e.error != rind.RindError.unsupported) rethrow;
      throw ArgumentError(
        'Argon2id needs at least one iteration, one lane, and 8 KiB per '
        'lane, and fewer than 2^24 lanes',
      );
    }
  }

  @override
  final int memory;

  @override
  final int parallelism;

  @override
  final int iterations;

  @override
  final int hashLength;

  @override
  Future<SecretKey> deriveKey({
    required SecretKey secretKey,
    required List<int> nonce,
    List<int> optionalSecret = const <int>[],
    List<int> associatedData = const <int>[],
  }) async {
    if (optionalSecret.isNotEmpty || associatedData.isNotEmpty) {
      throw _unsupported('Argon2id with a secret or associated data');
    }
    if (nonce.length < 8) {
      throw ArgumentError.value(
        nonce,
        'nonce',
        'rind takes Argon2id salts of 8 bytes or more',
      );
    }
    final password = _bytes(await secretKey.extractBytes());
    final salt = _bytes(nonce);
    final (memory, iterations, parallelism, hashLength) = (
      this.memory,
      this.iterations,
      this.parallelism,
      this.hashLength,
    );
    // Off this isolate, since Argon2id is built to take long: a handle
    // cannot cross isolates, so the cost and password are rebuilt there.
    final derived = await Isolate.run(
      () => rind.Argon2Secret(password).derive(
        rind.Argon2Params(memory, iterations, parallelism),
        salt,
        hashLength,
      ),
    );
    return SecretKeyData(derived, overwriteWhenDestroyed: true);
  }
}
